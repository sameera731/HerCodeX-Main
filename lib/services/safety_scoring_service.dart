import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Grid-based safety scoring service.
///
/// Computes a safety score for any grid cell based on:
///   • Proximity to police stations (closer = safer)
///   • Time of day (night hours = higher risk)
///
/// Scores are normalized to 0.0 (unsafe) – 1.0 (safest).
class SafetyScoringService {
  /// Cached police station positions in LatLng.
  final List<LatLng> _policeStations;

  /// Pre-computed grid conversion closures (injected from map screen).
  final int Function(double lon) _xFromLon;
  final int Function(double lat) _yFromLat;

  /// Cached police station grid cells.
  late final List<({int x, int y})> _policeGridCells;

  /// Maximum distance (in grid cells) beyond which police effect is zero.
  /// ~500m at 3m cell size ≈ 167 cells.
  static const int _policeMaxRadius = 167;

  SafetyScoringService({
    required List<LatLng> policeStations,
    required int Function(double lon) xFromLon,
    required int Function(double lat) yFromLat,
  })  : _policeStations = policeStations,
        _xFromLon = xFromLon,
        _yFromLat = yFromLat {
    // Pre-compute police station grid positions once.
    _policeGridCells = _policeStations.map((s) {
      return (x: _xFromLon(s.longitude), y: _yFromLat(s.latitude));
    }).toList();
  }

  /// Returns a safety score in [0.0, 1.0] for the grid cell at (x, y).
  ///
  /// Factors:
  ///   • policeScore:  1.0 when very close to police, 0.0 when far away
  ///   • timeScore:    1.0 during day, reduced at night
  ///
  /// The final score is a weighted blend of these factors.
  double getSafetyScore(int x, int y) {
    final policeScore = _policeSafetyScore(x, y);
    final timeScore = _timeSafetyScore();

    // Weights — police proximity is the dominant signal.
    const policeWeight = 0.7;
    const timeWeight = 0.3;

    final raw = policeWeight * policeScore + timeWeight * timeScore;
    return raw.clamp(0.0, 1.0);
  }

  /// Computes the average safety score across a list of grid cells.
  ///
  /// Returns 0.0 if the list is empty.
  double computeRouteSafetyScore(List<({int x, int y})> gridCells) {
    if (gridCells.isEmpty) return 0.0;

    // Sample every Nth cell to avoid O(route × stations) explosion.
    // For a typical route with thousands of cells, sample ~100 points.
    final sampleInterval = math.max(1, gridCells.length ~/ 100);

    double totalScore = 0.0;
    int count = 0;
    for (int i = 0; i < gridCells.length; i += sampleInterval) {
      final cell = gridCells[i];
      totalScore += getSafetyScore(cell.x, cell.y);
      count++;
    }

    return count > 0 ? totalScore / count : 0.0;
  }

  /// Selects the safest route from a list of routes (each is a list of LatLng).
  ///
  /// Returns the index of the safest route and the scored routes for debugging.
  ({int safestIndex, List<double> scores}) selectSafestRoute(
    List<List<LatLng>> routes,
  ) {
    if (routes.isEmpty) return (safestIndex: -1, scores: []);
    if (routes.length == 1) return (safestIndex: 0, scores: [1.0]);

    final scores = <double>[];

    for (final route in routes) {
      final gridCells = route.map((p) {
        return (x: _xFromLon(p.longitude), y: _yFromLat(p.latitude));
      }).toList();
      scores.add(computeRouteSafetyScore(gridCells));
    }

    // Find the route with the highest safety score.
    int safestIndex = 0;
    double maxScore = scores[0];
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > maxScore) {
        maxScore = scores[i];
        safestIndex = i;
      }
    }

    return (safestIndex: safestIndex, scores: scores);
  }

  // =========================================================================
  // PRIVATE — individual scoring factors
  // =========================================================================

  /// Police proximity score: 1.0 at a police station, drops to 0.0 at
  /// [_policeMaxRadius] cells away. Uses the nearest station.
  double _policeSafetyScore(int x, int y) {
    if (_policeGridCells.isEmpty) return 0.5; // neutral if no data

    double minDist = double.infinity;
    for (final station in _policeGridCells) {
      final dx = (x - station.x).abs();
      final dy = (y - station.y).abs();
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < minDist) minDist = dist;
    }

    if (minDist <= 0) return 1.0;
    if (minDist >= _policeMaxRadius) return 0.0;

    // Linear falloff from 1.0 → 0.0 over the radius.
    return 1.0 - (minDist / _policeMaxRadius);
  }

  /// Time-of-day safety score.
  ///
  ///   06:00–18:00 → 1.0 (daytime, safest)
  ///   22:00–05:00 → 0.3 (late night, riskiest)
  ///   18:00–22:00 / 05:00–06:00 → smooth transition
  double _timeSafetyScore() {
    final now = DateTime.now();
    final hour = now.hour + now.minute / 60.0;

    if (hour >= 6.0 && hour < 18.0) {
      // Daytime — safest
      return 1.0;
    } else if (hour >= 22.0 || hour < 5.0) {
      // Late night — riskiest
      return 0.3;
    } else if (hour >= 18.0 && hour < 22.0) {
      // Evening transition: 1.0 at 18:00 → 0.3 at 22:00
      return 1.0 - 0.7 * ((hour - 18.0) / 4.0);
    } else {
      // Early morning transition: 0.3 at 05:00 → 1.0 at 06:00
      return 0.3 + 0.7 * ((hour - 5.0) / 1.0);
    }
  }
}

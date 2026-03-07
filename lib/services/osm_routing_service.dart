import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service that fetches driving routes from the public OSRM demo server.
///
/// Returns lists of [LatLng] points representing route polylines.
/// Uses the OSRM "route" endpoint with `overview=full&geometries=geojson`
/// to get full GeoJSON coordinate arrays for each route.
class OsmRoutingService {
  static const String _baseUrl = 'https://router.project-osrm.org';

  /// Fetches the shortest driving route between [start] and [end].
  ///
  /// Returns an empty list if no route is found or on network error.
  static Future<List<LatLng>> fetchRoute(LatLng start, LatLng end) async {
    final routes = await fetchRoutes(start, end);
    return routes.isNotEmpty ? routes.first : [];
  }

  /// Fetches multiple alternative driving routes between [start] and [end].
  ///
  /// Returns a list of routes, where each route is a list of [LatLng] points.
  /// The first route is always the shortest. Additional routes are alternatives
  /// returned by OSRM when available.
  ///
  /// Returns an empty list if no route is found or on network error.
  static Future<List<List<LatLng>>> fetchRoutes(
    LatLng start,
    LatLng end,
  ) async {
    final url =
        '$_baseUrl/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson&alternatives=true';

    debugPrint('OSRM request: $url');

    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'HerCodeX-App/1.0',
      });

      if (response.statusCode != 200) {
        debugPrint('OSRM HTTP error: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final code = data['code'] as String?;
      if (code != 'Ok') {
        debugPrint('OSRM response code: $code');
        return [];
      }

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        debugPrint('OSRM returned no routes');
        return [];
      }

      debugPrint('OSRM returned ${routes.length} route(s)');

      final decoded = <List<LatLng>>[];
      for (int i = 0; i < routes.length; i++) {
        final route = routes[i];
        final geometry = route['geometry'] as Map<String, dynamic>;
        final coordinates = geometry['coordinates'] as List<dynamic>;

        // GeoJSON coordinates are [longitude, latitude]
        final points = coordinates.map((coord) {
          final c = coord as List<dynamic>;
          final lon = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          return LatLng(lat, lon);
        }).toList();

        debugPrint('Route $i: ${points.length} points');
        if (points.isNotEmpty) {
          debugPrint('  First: ${points.first.latitude}, ${points.first.longitude}');
          debugPrint('  Last:  ${points.last.latitude}, ${points.last.longitude}');
        }

        if (points.isNotEmpty) {
          decoded.add(points);
        }
      }

      debugPrint('Requested destination: ${end.latitude}, ${end.longitude}');

      return decoded;
    } catch (e, stackTrace) {
      debugPrint('OSRM fetch error: $e');
      debugPrint('$stackTrace');
      return [];
    }
  }
}

import 'dart:collection';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/geocode.dart' as geo;

// ---------------------------------------------------------------------------
// A* node — stores grid position, costs, and parent for path reconstruction
// ---------------------------------------------------------------------------
class _AStarNode {
  final int x, y;
  final double g; // cost from start
  final double f; // g + heuristic
  final _AStarNode? parent;

  const _AStarNode(this.x, this.y, this.g, this.f, this.parent);
}

// ---------------------------------------------------------------------------
// Nominatim suggestion model
// ---------------------------------------------------------------------------
class _NominatimPlace {
  final String displayName;
  final double lat;
  final double lon;
  const _NominatimPlace(this.displayName, this.lat, this.lon);
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _center = LatLng(18.4636, 73.8682);
  static final _base36Pattern = RegExp(r'^[0-9A-Z]{5}$');

  final _mapController = MapController();
  double _zoom = 15.0;
  bool showGrid = true;

  // ---- user location state ----
  LatLng? _userLocation;

  // ---- input controllers ----
  final _startController = TextEditingController(text: 'My Location');
  final _destController = TextEditingController();

  // ---- resolved lat/lon for routing ----
  LatLng? _startPoint;
  LatLng? _endPoint;
  bool _startIsMyLocation = true;

  // ---- code lookup marker + highlighted cell ----
  LatLng? _codeLookupMarker;
  ({int x, int y})? _highlightedCell; // single cell to highlight

  // ---- suggestion dropdowns ----
  List<_NominatimPlace> _startSuggestions = [];
  List<_NominatimPlace> _destSuggestions = [];
  bool _showStartSuggestions = false;
  bool _showDestSuggestions = false;

  // ---- routing state ----
  List<LatLng> _shortestRoute = [];
  List<LatLng> _safestRoute = [];
  bool _showShortest = true;
  bool _isRouting = false;

  @override
  void initState() {
    super.initState();
    _initUserLocation();
  }

  @override
  void dispose() {
    _startController.dispose();
    _destController.dispose();
    super.dispose();
  }

  // --- snackbar helper ---
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ========================================================================
  // USER LOCATION
  // ========================================================================
  Future<void> _initUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _userLocation = userLatLng;
        if (_startIsMyLocation) {
          _startPoint = userLatLng;
        }
      });
      _mapController.move(userLatLng, 15.0);
    } catch (_) {
      // fall back to _center
    }
  }

  // ========================================================================
  // INPUT PARSING
  // ========================================================================
  bool _isBase36Code(String input) {
    return _base36Pattern.hasMatch(input.trim().toUpperCase());
  }

  LatLng _resolveCode(String code) {
    final result = geo.codeToLatlon(code.trim().toUpperCase());
    return LatLng(result.lat, result.lon);
  }

  // ========================================================================
  // NOMINATIM SEARCH
  // ========================================================================
  Future<List<_NominatimPlace>> _searchNominatim(String query) async {
    if (query.trim().length < 3) return [];
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(query.trim())}'
      '&format=json'
      '&limit=5'
      '&countrycodes=in'
      '&addressdetails=1'
      '&viewbox=73.65,18.65,74.05,18.25'
      '&bounded=1',
    );
    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'HerCodeX-App/1.0',
      });
      if (response.statusCode != 200) return [];
      final List data = json.decode(response.body);
      return data
          .map((e) => _NominatimPlace(
                e['display_name'] as String,
                double.parse(e['lat'] as String),
                double.parse(e['lon'] as String),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ========================================================================
  // START FIELD HANDLING
  // ========================================================================
  void _onStartChanged(String value) async {
    final trimmed = value.trim();

    if (trimmed.toLowerCase() == 'my location') {
      setState(() {
        _startIsMyLocation = true;
        _startPoint = _userLocation;
        _startSuggestions = [];
        _showStartSuggestions = false;
      });
      return;
    }

    _startIsMyLocation = false;

    if (trimmed.length == 5 && _isBase36Code(trimmed)) {
      setState(() {
        _startPoint = _resolveCode(trimmed);
        _startSuggestions = [];
        _showStartSuggestions = false;
      });
      return;
    }

    setState(() => _startPoint = null);

    if (trimmed.length >= 3) {
      final results = await _searchNominatim(trimmed);
      if (!mounted) return;
      setState(() {
        _startSuggestions = results;
        _showStartSuggestions = results.isNotEmpty;
      });
    } else {
      setState(() {
        _startSuggestions = [];
        _showStartSuggestions = false;
      });
    }
  }

  void _onStartSuggestionTap(_NominatimPlace place) {
    setState(() {
      _startController.text = place.displayName;
      _startPoint = LatLng(place.lat, place.lon);
      _startIsMyLocation = false;
      _startSuggestions = [];
      _showStartSuggestions = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _useMyLocation() {
    setState(() {
      _startController.text = 'My Location';
      _startIsMyLocation = true;
      _startPoint = _userLocation;
      _startSuggestions = [];
      _showStartSuggestions = false;
    });
  }

  // ========================================================================
  // DESTINATION FIELD HANDLING
  // ========================================================================
  void _onDestChanged(String value) async {
    final trimmed = value.trim();

    if (trimmed.length == 5 && _isBase36Code(trimmed)) {
      setState(() {
        _endPoint = _resolveCode(trimmed);
        _destSuggestions = [];
        _showDestSuggestions = false;
      });
      return;
    }

    setState(() => _endPoint = null);

    if (trimmed.length >= 3) {
      final results = await _searchNominatim(trimmed);
      if (!mounted) return;
      setState(() {
        _destSuggestions = results;
        _showDestSuggestions = results.isNotEmpty;
      });
    } else {
      setState(() {
        _destSuggestions = [];
        _showDestSuggestions = false;
      });
    }
  }

  void _onDestSuggestionTap(_NominatimPlace place) {
    setState(() {
      _destController.text = place.displayName;
      _endPoint = LatLng(place.lat, place.lon);
      _destSuggestions = [];
      _showDestSuggestions = false;
    });
    FocusScope.of(context).unfocus();
  }

  // ========================================================================
  // CODE LOOKUP — jump camera + highlight cell (NO routing)
  // ========================================================================
  void _locateCode(String fieldValue) {
    final trimmed = fieldValue.trim().toUpperCase();
    if (trimmed.length != 5 || !_isBase36Code(trimmed)) {
      _showSnack('Invalid 5-character code');
      return;
    }
    final target = _resolveCode(trimmed);
    final gx = _xFromLon(target.longitude);
    final gy = _yFromLat(target.latitude);
    debugPrint('Locate code "$trimmed" → lat=${target.latitude}, lon=${target.longitude}, grid=($gx,$gy)');

    setState(() {
      _codeLookupMarker = target;
      _highlightedCell = (x: gx, y: gy);
    });
    _mapController.move(target, 19); // zoom to cell level
  }

  /// Standalone button action: checks Destination field only.
  void _onLocateCodeButton() {
    final destText = _destController.text.trim().toUpperCase();
    if (destText.length == 5 && _isBase36Code(destText)) {
      _locateCode(destText);
      return;
    }
    _showSnack('Enter a valid 5-character code in Destination');
  }

  // ========================================================================
  // FIND ROUTE — deliberate action with validation + debug logging
  // ========================================================================
  void _onFindRoute() {
    // ---- Validate start ----
    if (_startPoint == null) {
      _showSnack('Start not resolved. Enter a code, address, or use My Location.');
      return;
    }
    // ---- Validate destination ----
    if (_endPoint == null) {
      _showSnack('Destination not resolved. Enter a code or address.');
      return;
    }

    // ---- Debug: print resolved lat/lon ----
    debugPrint('=== FIND ROUTE ===');
    debugPrint('Start:  lat=${_startPoint!.latitude}, lon=${_startPoint!.longitude}');
    debugPrint('Dest:   lat=${_endPoint!.latitude}, lon=${_endPoint!.longitude}');

    // ---- Convert to grid and validate ----
    final sx = _xFromLon(_startPoint!.longitude);
    final sy = _yFromLat(_startPoint!.latitude);
    final ex = _xFromLon(_endPoint!.longitude);
    final ey = _yFromLat(_endPoint!.latitude);
    debugPrint('Grid:   start=($sx, $sy)  dest=($ex, $ey)');
    debugPrint('Grid size: ${geo.gridCellsPerSide}');

    final maxCell = geo.gridCellsPerSide;
    if (sx < 0 || sx >= maxCell || sy < 0 || sy >= maxCell) {
      _showSnack('Start location is outside the grid area.');
      debugPrint('ERROR: Start ($sx,$sy) outside grid [0, $maxCell)');
      return;
    }
    if (ex < 0 || ex >= maxCell || ey < 0 || ey >= maxCell) {
      _showSnack('Destination is outside the grid area.');
      debugPrint('ERROR: Dest ($ex,$ey) outside grid [0, $maxCell)');
      return;
    }

    // ---- Dismiss suggestions & keyboard ----
    setState(() {
      _showStartSuggestions = false;
      _showDestSuggestions = false;
      _isRouting = true;
      _shortestRoute = [];
      _safestRoute = [];
    });
    FocusScope.of(context).unfocus();

    // ---- Run A* synchronously with stopwatch ----
    final stopwatch = Stopwatch()..start();

    try {
      final shortest = _runAStar(_startPoint!, _endPoint!, safest: false);
      debugPrint('Shortest done: ${shortest.length} points, ${stopwatch.elapsedMilliseconds}ms');

      final safest = _runAStar(_startPoint!, _endPoint!, safest: true);
      debugPrint('Safest done:   ${safest.length} points, ${stopwatch.elapsedMilliseconds}ms');

      stopwatch.stop();

      if (shortest.isEmpty && safest.isEmpty) {
        setState(() => _isRouting = false);
        _showSnack('No route found within grid area.');
        debugPrint('WARNING: A* returned empty paths');
        return;
      }

      setState(() {
        _shortestRoute = shortest;
        _safestRoute = safest;
        _isRouting = false;
      });
      debugPrint('Routes set. Shortest=${shortest.length}, Safest=${safest.length}');
    } catch (e, stackTrace) {
      stopwatch.stop();
      debugPrint('A* EXCEPTION: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => _isRouting = false);
      _showSnack('Route calculation failed: $e');
    }
  }

  // ========================================================================
  // MAP TAP (info bottom sheet + highlight cell)
  // ========================================================================
  void _onMapTap(TapPosition _, LatLng point) {
    final gx = _xFromLon(point.longitude);
    final gy = _yFromLat(point.latitude);
    setState(() {
      _showStartSuggestions = false;
      _showDestSuggestions = false;
      _codeLookupMarker = point;
      _highlightedCell = (x: gx, y: gy);
    });
    final code = geo.latlonToCode(point.latitude, point.longitude);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Latitude:  ${point.latitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Longitude: ${point.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Code: $code',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // GRID HELPERS
  // ========================================================================
  int _xFromLon(double lon) =>
      ((lon - geo.leftLon) * geo.metersPerDegLon) ~/ geo.cellSizeM;

  int _yFromLat(double lat) =>
      ((geo.topLat - lat) * geo.metersPerDegLat) ~/ geo.cellSizeM;

  double _lonAtX(int x) =>
      geo.leftLon + (x * geo.cellSizeM / geo.metersPerDegLon);

  double _latAtY(int y) =>
      geo.topLat - (y * geo.cellSizeM / geo.metersPerDegLat);

  LatLng _gridToLatLng(int x, int y) {
    final lon = geo.leftLon +
        ((x * geo.cellSizeM + geo.cellSizeM / 2) / geo.metersPerDegLon);
    final lat = geo.topLat -
        ((y * geo.cellSizeM + geo.cellSizeM / 2) / geo.metersPerDegLat);
    return LatLng(lat, lon);
  }

  // ========================================================================
  // A* PATHFINDING — uses PriorityQueue (fixed)
  // ========================================================================
  double _safetyScore(int x, int y) => 0.5;

  double _heuristic(int x1, int y1, int x2, int y2) {
    return ((x1 - x2).abs() + (y1 - y2).abs()).toDouble();
  }

  List<LatLng> _runAStar(LatLng start, LatLng end, {required bool safest}) {
    final sx = _xFromLon(start.longitude);
    final sy = _yFromLat(start.latitude);
    final ex = _xFromLon(end.longitude);
    final ey = _yFromLat(end.latitude);

    final int minX = (sx < ex ? sx : ex) - 50;
    final int maxX = (sx > ex ? sx : ex) + 50;
    final int minY = (sy < ey ? sy : ey) - 50;
    final int maxY = (sy > ey ? sy : ey) + 50;

    const dxDir = [1, -1, 0, 0];
    const dyDir = [0, 0, 1, -1];

    // PriorityQueue from package:collection — sorts by f score
    final openQueue = PriorityQueue<_AStarNode>(
      (a, b) => a.f.compareTo(b.f),
    );
    final gScores = HashMap<int, double>();

    // Encode (x,y) into a single int key for fast lookup
    int encodeKey(int x, int y) => x * 100000 + y;

    double stepCost(int nx, int ny) {
      if (safest) return 1.0 + (1.0 - _safetyScore(nx, ny));
      return 1.0;
    }

    final startNode = _AStarNode(sx, sy, 0, _heuristic(sx, sy, ex, ey), null);
    openQueue.add(startNode);
    gScores[encodeKey(sx, sy)] = 0;

    _AStarNode? goalNode;

    while (openQueue.isNotEmpty) {
      final current = openQueue.removeFirst();

      if (current.x == ex && current.y == ey) {
        goalNode = current;
        break;
      }

      // Skip if we've already found a better path to this node
      final currentKey = encodeKey(current.x, current.y);
      final bestG = gScores[currentKey];
      if (bestG != null && current.g > bestG) continue;

      for (var i = 0; i < 4; i++) {
        final nx = current.x + dxDir[i];
        final ny = current.y + dyDir[i];

        if (nx < minX || nx > maxX || ny < minY || ny > maxY) continue;

        final tentativeG = current.g + stepCost(nx, ny);
        final nKey = encodeKey(nx, ny);
        final existingG = gScores[nKey];

        if (existingG == null || tentativeG < existingG) {
          gScores[nKey] = tentativeG;
          final f = tentativeG + _heuristic(nx, ny, ex, ey);
          final node = _AStarNode(nx, ny, tentativeG, f, current);
          openQueue.add(node);
        }
      }
    }

    // Reconstruct path
    final path = <LatLng>[];
    var n = goalNode;
    while (n != null) {
      path.add(_gridToLatLng(n.x, n.y));
      n = n.parent;
    }
    return path.reversed.toList();
  }

  // ========================================================================
  // GRID LINES
  // ========================================================================
  List<Polyline> _buildGridLines() {
    if (!showGrid || _zoom < 19) return [];

    final bounds = _mapController.camera.visibleBounds;
    final xMin = _xFromLon(bounds.west);
    final xMax = _xFromLon(bounds.east);
    final yMin = _yFromLat(bounds.north);
    final yMax = _yFromLat(bounds.south);

    if ((xMax - xMin + 1) * (yMax - yMin + 1) > 20000) return [];

    final lines = <Polyline>[];
    const color = Color(0xFFBDBDBD);

    for (var y = yMin; y <= yMax + 1; y++) {
      final lat = _latAtY(y);
      lines.add(Polyline(
        points: [LatLng(lat, _lonAtX(xMin)), LatLng(lat, _lonAtX(xMax + 1))],
        strokeWidth: 1,
        color: color,
      ));
    }
    for (var x = xMin; x <= xMax + 1; x++) {
      final lon = _lonAtX(x);
      lines.add(Polyline(
        points: [LatLng(_latAtY(yMin), lon), LatLng(_latAtY(yMax + 1), lon)],
        strokeWidth: 1,
        color: color,
      ));
    }
    return lines;
  }

  // ========================================================================
  // HIGHLIGHTED CELL POLYGON
  // ========================================================================
  List<Polygon> _buildHighlightedCell() {
    if (_highlightedCell == null) return [];
    final cx = _highlightedCell!.x;
    final cy = _highlightedCell!.y;

    // Four corners of the cell
    final topLeft = LatLng(_latAtY(cy), _lonAtX(cx));
    final topRight = LatLng(_latAtY(cy), _lonAtX(cx + 1));
    final bottomRight = LatLng(_latAtY(cy + 1), _lonAtX(cx + 1));
    final bottomLeft = LatLng(_latAtY(cy + 1), _lonAtX(cx));

    return [
      Polygon(
        points: [topLeft, topRight, bottomRight, bottomLeft],
        color: Colors.green.withValues(alpha: 0.4),
        borderColor: Colors.green.shade700,
        borderStrokeWidth: 2,
      ),
    ];
  }

  // ========================================================================
  // ROUTE POLYLINES
  // ========================================================================
  List<Polyline> _buildRoutePolylines() {
    final polylines = <Polyline>[];
    if (_safestRoute.isNotEmpty) {
      polylines.add(Polyline(
        points: _safestRoute,
        strokeWidth: 5.0,
        color: Colors.green,
      ));
    }
    if (_showShortest && _shortestRoute.isNotEmpty) {
      polylines.add(Polyline(
        points: _shortestRoute,
        strokeWidth: 3.0,
        color: Colors.blue,
      ));
    }
    return polylines;
  }

  // ========================================================================
  // MARKERS
  // ========================================================================
  List<Marker> _buildRouteMarkers() {
    final markers = <Marker>[];
    if (_startPoint != null) {
      markers.add(Marker(
        point: _startPoint!,
        width: 40,
        height: 40,
        child: const Icon(Icons.trip_origin, color: Colors.green, size: 32),
      ));
    }
    if (_endPoint != null) {
      markers.add(Marker(
        point: _endPoint!,
        width: 40,
        height: 40,
        child: const Icon(Icons.flag, color: Colors.red, size: 32),
      ));
    }
    return markers;
  }

  // ========================================================================
  // SUGGESTION DROPDOWN HELPER
  // ========================================================================
  Widget _buildSuggestionList(
    List<_NominatimPlace> suggestions,
    void Function(_NominatimPlace) onTap,
  ) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: suggestions.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 12, endIndent: 12),
        itemBuilder: (_, i) {
          final place = suggestions[i];
          return ListTile(
            dense: true,
            title: Text(
              place.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            onTap: () => onTap(place),
          );
        },
      ),
    );
  }

  // ========================================================================
  // BUILD
  // ========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Container(), // logo placeholder
        title: const Text('HerCodeX'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ---- Map ----
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: _onMapTap,
              onPositionChanged: (camera, hasGesture) {
                if (camera.zoom != _zoom) {
                  setState(() => _zoom = camera.zoom);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.hercodex_app',
              ),
              PolylineLayer(polylines: _buildGridLines()),
              // Highlighted cell (drawn under routes)
              PolygonLayer(polygons: _buildHighlightedCell()),
              PolylineLayer(polylines: _buildRoutePolylines()),
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.my_location,
                          color: Colors.blue, size: 32),
                    ),
                  ],
                ),
              // Code lookup marker
              if (_codeLookupMarker != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _codeLookupMarker!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin,
                          color: Colors.deepPurple, size: 40),
                    ),
                  ],
                ),
              MarkerLayer(markers: _buildRouteMarkers()),
            ],
          ),

          // ---- Input overlay (Start + Destination + Find Route) ----
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---- START field ----
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(10),
                  child: TextField(
                    controller: _startController,
                    decoration: InputDecoration(
                      hintText: 'Start location or code',
                      prefixIcon: const Icon(Icons.trip_origin,
                          color: Colors.green, size: 20),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.pin_drop,
                                color: Colors.deepPurple, size: 20),
                            tooltip: 'Locate Code',
                            onPressed: () =>
                                _locateCode(_startController.text),
                          ),
                          IconButton(
                            icon: const Icon(Icons.my_location,
                                color: Colors.blue, size: 20),
                            tooltip: 'Use My Location',
                            onPressed: _useMyLocation,
                          ),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                    onChanged: _onStartChanged,
                    onTap: () => setState(() {
                      _showDestSuggestions = false;
                    }),
                  ),
                ),

                if (_showStartSuggestions && _startSuggestions.isNotEmpty)
                  _buildSuggestionList(
                      _startSuggestions, _onStartSuggestionTap),

                const SizedBox(height: 6),

                // ---- DESTINATION field ----
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(10),
                  child: TextField(
                    controller: _destController,
                    decoration: InputDecoration(
                      hintText: 'Destination or code',
                      prefixIcon: const Icon(Icons.flag,
                          color: Colors.red, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.pin_drop,
                            color: Colors.deepPurple, size: 20),
                        tooltip: 'Locate Code',
                        onPressed: () =>
                            _locateCode(_destController.text),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                    onChanged: _onDestChanged,
                    onTap: () => setState(() {
                      _showStartSuggestions = false;
                    }),
                  ),
                ),

                if (_showDestSuggestions && _destSuggestions.isNotEmpty)
                  _buildSuggestionList(
                      _destSuggestions, _onDestSuggestionTap),

                const SizedBox(height: 8),

                // ---- FIND ROUTE button ----
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isRouting ? null : _onFindRoute,
                    icon: _isRouting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.directions),
                    label: Text(_isRouting ? 'Calculating…' : 'Find Route'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---- Toggle: Show/Hide Shortest route (bottom-left) ----
          if (_shortestRoute.isNotEmpty || _safestRoute.isNotEmpty)
            Positioned(
              bottom: 100,
              left: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(24),
                color: _showShortest ? Colors.blue : Colors.grey,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () =>
                      setState(() => _showShortest = !_showShortest),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showShortest
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _showShortest ? 'Shortest ON' : 'Shortest OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ---- Route legend (bottom-right) ----
          if (_shortestRoute.isNotEmpty || _safestRoute.isNotEmpty)
            Positioned(
              bottom: 100,
              right: 16,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 16, height: 3, color: Colors.green),
                          const SizedBox(width: 6),
                          const Text('Safest',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 16, height: 3, color: Colors.blue),
                          const SizedBox(width: 6),
                          const Text('Shortest',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // ---- Bottom-right buttons: Locate Code + Hide Grid ----
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Locate Code button
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.deepPurple,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _onLocateCodeButton,
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pin_drop,
                              color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Locate Code',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Hide Grid button
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(24),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => setState(() => showGrid = !showGrid),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            showGrid ? Icons.grid_off : Icons.grid_on,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            showGrid ? 'Hide Grid' : 'Show Grid',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

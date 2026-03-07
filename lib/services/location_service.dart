import 'package:geolocator/geolocator.dart';

/// Centralized location service for the entire app.
///
/// Rules:
///   • Does NOT auto-fetch location on startup.
///   • Does NOT show dialogs or snackbars — callers handle UI feedback.
///   • Caches last known [Position] in a static variable.
///   • Permission is requested only once (first call).
class LocationService {
  /// In-memory cache of the most recent position.
  static Position? _cachedPosition;

  /// Returns the current device location, requesting permission if needed.
  ///
  /// Returns `null` if:
  ///   • Location services are disabled
  ///   • Permission is denied or permanently denied
  ///   • An error occurs during fetch
  ///
  /// On success the result is cached — subsequent calls return instantly.
  static Future<Position?> getCurrentLocation() async {
    if (_cachedPosition != null) return _cachedPosition;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _cachedPosition = position;
      return position;
    } catch (_) {
      return null;
    }
  }

  /// Clears the cached position, forcing a fresh GPS fetch on next call.
  static void clearCache() {
    _cachedPosition = null;
  }
}

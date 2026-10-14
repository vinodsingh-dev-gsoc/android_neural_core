/// Core location service that polls GPS and pushes to Supabase.
/// This runs inside a background isolate to keep tracking alive
/// even when the Flutter UI is not visible.
library;

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:android_neural_core/services/location_model.dart';
import 'package:android_neural_core/services/supabase_service.dart';

class LocationTracker {
  final _supabase = SupabaseService();
  Timer? _timer;

  /// Polling interval — set to 2 minutes as requested
  static const Duration interval = Duration(minutes: 2);

  bool _isTracking = false;

  bool get isTracking => _isTracking;

  /// Start the periodic location polling.
  /// Will automatically stop after calling [stop].
  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;

    // Track immediately on start
    _pollAndUpload();

    // Then repeat every `interval`
    _timer = Timer.periodic(interval, (_) => _pollAndUpload());
  }

  /// Stop all location polling.
  void stopTracking() {
    _isTracking = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Single poll: get GPS position and upload to Supabase.
  Future<void> _pollAndUpload() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );

      final point = LocationPoint.fromGeoPosition(position);
      await _supabase.insertLocation(point);
      print('[Tracker] Uploaded: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}');
    } catch (e) {
      print('[Tracker] Failed to capture/upload location: $e');
    }
  }
}
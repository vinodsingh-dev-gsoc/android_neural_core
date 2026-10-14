/// Background service implementation using flutter_background_service.
/// Runs in a separate Dart isolate so location collection continues
/// even when the user navigates away or kills the app.
library;

import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:android_neural_core/config/supabase_config.dart';
import 'package:android_neural_core/services/location_model.dart';
import 'package:android_neural_core/services/supabase_service.dart';

/// Entry point for the background isolate.
/// Must be top-level (not inside a class) for the background service to find it.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Required: register plugins for the background isolate
  DartPluginRegistrant.ensureInitialized();

  // CRITICAL: background isolates have separate memory from main().
  // Supabase.instance is NOT available here unless we re-initialize it.
  await SupabaseConfig.init();

  // Poll loop: capture GPS every 5 minutes and upload to Supabase.
  // Changed from 2 min to 5 min to reduce UI redraw contention and battery drain.
  final supabase = SupabaseService();
  LocationPoint? lastPoint;
  final timer = Timer.periodic(const Duration(minutes: 5), (timer) async {
    try {
      // Skip poll if location services are disabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[BgService] Location services disabled, skipping poll');
        return;
      }

      // Use defaultTargetPlatform instead of Theme.of(null) which would crash
      // in a background isolate with no BuildContext available.
      final isAndroid = defaultTargetPlatform == TargetPlatform.android;
      final LocationSettings settings = isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 20),
            )
          : AppleSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 20),
              pauseLocationUpdatesAutomatically: true,
            );

      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );

      // Distance-based triggering: only upload if user moved >100m
      if (lastPoint != null) {
        final distance = Geolocator.distanceBetween(
          lastPoint!.latitude,
          lastPoint!.longitude,
          position.latitude,
          position.longitude,
        );
        if (distance < 100) {
          debugPrint('[BgService] Moved <100m, skipping upload');
          return;
        }
      }

      final point = LocationPoint.fromGeoPosition(position);
      await supabase.insertLocation(point);
      lastPoint = point;

      // Push the latest position to the foreground UI
      service.invoke('onLocationUpdate', {
        'latitude': point.latitude,
        'longitude': point.longitude,
        'timestamp': point.timestamp.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[BgService] Error: $e');
      // Do NOT rethrow — keep the timer running.
    }
  });

  // Listen for stop command — cancel timer to free resources
  service.on('stopService').listen((event) {
    timer.cancel();
    service.stopSelf();
  });
}

/// Configure and start the background service.
/// Call this from the main Flutter UI after user grants permissions.
Future<bool> startBackgroundService() async {
  final service = FlutterBackgroundService();

  bool isRunning = await service.isRunning();
  if (isRunning) {
    debugPrint('[BgService] Already running');
    return true;
  }

  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
    androidConfiguration: AndroidConfiguration(
      autoStart: true,
      onStart: onStart,
      isForegroundMode: true,
      notificationChannelId: 'location_tracker',
      initialNotificationTitle: 'Fitness Tracker',
      initialNotificationContent: 'Tracking your location...',
      foregroundServiceNotificationId: 8888,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
  );

  await service.startService();
  debugPrint('[BgService] Started successfully');
  return true;
}

/// iOS background fetch handler — runs briefly (15-20s max).
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // CRITICAL: re-initialize Supabase in this isolate's memory space.
  await SupabaseConfig.init();

  try {
    // For iOS background fetch, we use a tighter timeout
    final position = await Geolocator.getCurrentPosition(
      locationSettings: AppleSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
        pauseLocationUpdatesAutomatically: true,
      ),
    );
    final point = LocationPoint.fromGeoPosition(position);
    await SupabaseService().insertLocation(point);
  } catch (e) {
    debugPrint('[iOS BgService] Error: $e');
  }

  return true;
}

/// Stop the background service.
Future<void> stopBackgroundService() async {
  final service = FlutterBackgroundService();
  service.invoke('stopService');
  debugPrint('[BgService] Stopped');
}
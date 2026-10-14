/// Minimal home screen for Fitness Tracker — only shows essential status + location.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:android_neural_core/services/background_service.dart';
import 'package:android_neural_core/services/location_model.dart';
import 'package:android_neural_core/services/supabase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = SupabaseService();
  LocationPoint? _lastLocation;
  bool _isTracking = false;
  bool _isLoading = true;
  String _statusMessage = 'Initializing...';
  StreamSubscription<dynamic>? _bgSubscription;

  @override
  void initState() {
    super.initState();
    _loadLastLocation();
    _setupBackgroundListener();
    _checkTrackingStatus();
    // Auto-start location tracking as soon as the app opens
    _autoStartTracking();
  }

  /// Automatically starts tracking on app open.
  /// If the background service is already running, does nothing.
  /// Otherwise requests permissions and starts immediately.
  Future<void> _autoStartTracking() async {
    final service = FlutterBackgroundService();
    final alreadyRunning = await service.isRunning();
    if (alreadyRunning) return; // already pushing — nothing to do

    // Check if we already have location permission (no dialog if granted)
    final locationStatus = await Permission.location.status;
    final bgLocationStatus = await Permission.locationAlways.status;

    if (locationStatus.isGranted) {
      // Permissions already granted — start silently
      await startBackgroundService();
      if (mounted) {
        setState(() {
          _isTracking = true;
          _statusMessage = 'Auto-tracking active — every 5 min';
        });
      }
    } else {
      // Need to ask — request permissions then start
      await _startTracking();
    }
  }

  @override
  void dispose() {
    _bgSubscription?.cancel();
    super.dispose();
  }

  void _setupBackgroundListener() {
    _bgSubscription =
        FlutterBackgroundService().on('onLocationUpdate').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _lastLocation = LocationPoint(
            latitude: (event['latitude'] as num).toDouble(),
            longitude: (event['longitude'] as num).toDouble(),
            timestamp: DateTime.parse(event['timestamp']),
          );
          _statusMessage = 'Last: ${_lastLocation!.timestamp.toLocal().toString().split('.')[0]}';
        });
      }
    });
  }

  Future<void> _loadLastLocation() async {
    setState(() => _isLoading = true);
    final latest = await _supabase.getLatestLocation();
    setState(() {
      _lastLocation = latest;
      _isLoading = false;
    });
  }

  Future<void> _checkTrackingStatus() async {
    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    setState(() => _isTracking = running);
  }

  Future<void> _startTracking() async {
    setState(() => _statusMessage = 'Requesting permissions...');

    final locationStatus = await Permission.location.request();
    final bgLocationStatus = await Permission.locationAlways.request();

    if (!mounted) return;

    if (locationStatus.isPermanentlyDenied || bgLocationStatus.isPermanentlyDenied) {
      setState(() => _statusMessage = 'Denied. Enable in Settings.');
      return;
    }

    if (!locationStatus.isGranted) {
      setState(() => _statusMessage = 'Permission denied');
      return;
    }

    await startBackgroundService();
    setState(() {
      _isTracking = true;
      _statusMessage = 'Tracking active — 5 min intervals';
    });
  }

  Future<void> _stopTracking() async {
    await stopBackgroundService();
    setState(() {
      _isTracking = false;
      _statusMessage = 'Tracking stopped';
    });
  }

  Future<void> _refreshLocation() async {
    setState(() => _statusMessage = 'Refreshing...');
    await _loadLastLocation();
    setState(() => _statusMessage = 'Ready');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness Tracker'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
            tooltip: _isTracking ? 'Stop' : 'Start',
            onPressed: _isTracking ? _stopTracking : _startTracking,
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Status indicator
                    Card(
                      color: _isTracking ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              _isTracking ? Icons.fitness_center : Icons.pause_circle,
                              color: _isTracking ? Colors.green : Colors.orange,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isTracking ? 'Tracking Active' : 'Tracking Stopped',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isTracking ? Colors.green : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Last location
                    if (_lastLocation != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Last Location',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.map, size: 20, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${_lastLocation!.latitude.toStringAsFixed(4)}, ${_lastLocation!.longitude.toStringAsFixed(4)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_lastLocation!.altitude != null) ...[
                                Text(
                                  'Alt: ${_lastLocation!.altitude!.toInt()}m',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                              if (_lastLocation!.accuracy != null) ...[
                                Text(
                                  'Acc: ${_lastLocation!.accuracy!.toInt()}m',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                              Text(
                                'At: ${_lastLocation!.timestamp.toLocal().toString().split('.')[0]}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No location yet. Tap ▶ to start.'),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isTracking ? _stopTracking : _startTracking,
                          icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                          label: Text(_isTracking ? 'Stop' : 'Start'),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: _refreshLocation,
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }}
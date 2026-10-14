/// Web dashboard showing location data on a map.
/// Uses flutter_map with OpenStreetMap tiles (no API key needed).
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:android_neural_core/services/supabase_service.dart';
import 'package:android_neural_core/services/location_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = SupabaseService();
  List<LocationPoint> _locations = [];
  bool _isLoading = true;
  String _statusMessage = 'Loading...';
  MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  /// Fetch locations from Supabase and refresh the map.
  Future<void> _fetchLocations() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Refreshing...';
    });

    try {
      final locations = await _supabase.fetchRecentLocations(limit: 500);
      if (mounted) {
        setState(() {
          _locations = locations;
          _isLoading = false;
          _statusMessage =
              '${locations.length} locations loaded';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📍 Location Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh locations',
            onPressed: _fetchLocations,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _locations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_locations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No locations yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(_statusMessage),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchLocations,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.green.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total', _locations.length.toString()),
              _buildStatItem(
                'Latest',
                _locations.first.timestamp.toLocal().toString().split('.')[0],
              ),
              _buildStatItem(
                'Coverage',
                '${_locations.length} points',
              ),
            ],
          ),
        ),
        // Map takes remaining space
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  LatLng(_locations.first.latitude, _locations.first.longitude),
              initialZoom: 13,
              maxZoom: 18,
              minZoom: 3,
            ),
            children: [
              // OpenStreetMap tiles (free, no API key)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'android_neural_core.dashboard',
              ),
              // Location markers
              MarkerLayer(
                markers: _locations.map((location) {
                  return Marker(
                    point: LatLng(location.latitude, location.longitude),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 28,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

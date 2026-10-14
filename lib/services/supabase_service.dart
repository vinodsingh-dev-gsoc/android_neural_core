/// Handles all Supabase database operations for location tracking.
/// Manages inserting new position points and fetching history.
library;

import 'package:android_neural_core/services/location_model.dart';
import 'package:android_neural_core/config/supabase_config.dart';

class SupabaseService {
  final _db = SupabaseConfig.client.from('locations');

  /// Insert a single GPS fix into Supabase.
  /// Returns true on success, throws on error.
  Future<bool> insertLocation(LocationPoint point) async {
    try {
      await _db.insert(point.toSupabaseMap());
      print('[Supabase] Inserted location: (${point.latitude}, ${point.longitude})');
      return true;
    } catch (e) {
      print('[Supabase] Insert error: $e');
      rethrow;
    }
  }

  /// Fetch the most recent N locations, ordered by newest first.
  Future<List<LocationPoint>> fetchRecentLocations({int limit = 100}) async {
    try {
      final response = await _db
          .select('id, lat, lon, created_at')
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map((row) {
        return LocationPoint(
          latitude: (row['lat'] as num).toDouble(),
          longitude: (row['lon'] as num).toDouble(),
          timestamp: DateTime.parse(row['created_at']),
        );
      }).toList();
    } catch (e) {
      print('[Supabase] Fetch error: $e');
      return [];
    }
  }

  /// Get the very latest location point (for status display).
  Future<LocationPoint?> getLatestLocation() async {
    final recent = await fetchRecentLocations(limit: 1);
    return recent.isEmpty ? null : recent.first;
  }
}

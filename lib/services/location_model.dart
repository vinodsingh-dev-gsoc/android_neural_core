/// Location data model representing a single GPS fix.
/// Stored in Supabase as a row in the `locations` table.
library;

import 'package:json_annotation/json_annotation.dart';

part 'location_model.g.dart';

@JsonSerializable()
class LocationPoint {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final DateTime timestamp;

  const LocationPoint({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    required this.timestamp,
  });

  factory LocationPoint.fromGeoPosition(dynamic position) {
    // Geolocator returns Position object with lat/lng as getters
    return LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
    );
  }

  /// Convert to a map for Supabase INSERT
  /// created_at is NOT included — Supabase DEFAULT now() fills it automatically.
  Map<String, dynamic> toSupabaseMap() => {
        'lat': latitude,
        'lon': longitude,
        'altitude': altitude,
        'accuracy': accuracy,
      };

  factory LocationPoint.fromJson(Map<String, dynamic> json) =>
      _$LocationPointFromJson(json);

  Map<String, dynamic> toJson() => _$LocationPointToJson(this);
}

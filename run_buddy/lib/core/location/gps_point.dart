class GpsPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speedMps;
  final double accuracyM;
  final DateTime recordedAt;

  GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speedMps,
    required this.accuracyM,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'speedMps': speedMps,
        'accuracyM': accuracyM,
        'recordedAt': recordedAt.toIso8601String(),
      };
}


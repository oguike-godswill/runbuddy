import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'gps_point.dart';

class GpsEngine {
  StreamSubscription<Position>? _positionStream;
  Timer? _simTimer;
  bool _isSimulating = false;
  final List<GpsPoint> _bufferedPoints = [];
  final List<GpsPoint> _routePoints = [];

  GpsPoint? _lastValidPoint;
  double _totalDistanceMeters = 0.0;
  bool _isTracking = false;

  final StreamController<GpsPoint> _pointController =
      StreamController<GpsPoint>.broadcast();
  final StreamController<double> _distanceController =
      StreamController<double>.broadcast();

  Stream<GpsPoint> get pointStream => _pointController.stream;
  Stream<double> get distanceStream => _distanceController.stream;
  double get totalDistanceKm => _totalDistanceMeters / 1000.0;
  List<GpsPoint> get routePoints => List.unmodifiable(_routePoints);
  List<GpsPoint> get offlineBuffer => List.unmodifiable(_bufferedPoints);
  bool get isSimulating => _isSimulating;

  Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  void startTracking() {
    _isTracking = true;
    _positionStream?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3, // meters
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen(_onPositionReceived);
  }

  void pauseTracking() {
    _isTracking = false;
  }

  void resumeTracking() {
    _isTracking = true;
  }

  void stopTracking() {
    _isTracking = false;
    _positionStream?.cancel();
    _positionStream = null;
    stopSimulation();
  }

  void reset() {
    stopTracking();
    _totalDistanceMeters = 0.0;
    _lastValidPoint = null;
    _routePoints.clear();
    _bufferedPoints.clear();
    _isSimulating = false;
  }

  void toggleSimulation() {
    if (_isSimulating) {
      stopSimulation();
    } else {
      startSimulation();
    }
  }

  void startSimulation({double speedMps = 3.2}) {
    _isSimulating = true;
    _isTracking = true;
    _simTimer?.cancel();

    double currentLat = _lastValidPoint?.latitude ?? 37.7749;
    double currentLng = _lastValidPoint?.longitude ?? -122.4194;

    _simTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isTracking || !_isSimulating) return;

      currentLat += 0.0000288;
      final now = DateTime.now();
      final point = GpsPoint(
        latitude: currentLat,
        longitude: currentLng,
        altitude: 15.0,
        speedMps: speedMps,
        accuracyM: 5.0,
        recordedAt: now,
      );

      _totalDistanceMeters += speedMps;
      _lastValidPoint = point;
      _routePoints.add(point);
      _bufferedPoints.add(point);

      _pointController.add(point);
      _distanceController.add(totalDistanceKm);
    });
  }

  void stopSimulation() {
    _isSimulating = false;
    _simTimer?.cancel();
    _simTimer = null;
  }

  void _onPositionReceived(Position position) {
    if (!_isTracking) return;

    // 1. Accuracy Filter (reject inaccurate points > 25m)
    if (position.accuracy > 25.0) return;

    final now = DateTime.now();
    final candidate = GpsPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speedMps: position.speed,
      accuracyM: position.accuracy,
      recordedAt: now,
    );

    // 2. Teleportation / Sanity check (max human sprint ~ 13 m/s)
    if (_lastValidPoint != null) {
      final deltaSec = now.difference(_lastValidPoint!.recordedAt).inMilliseconds / 1000.0;
      if (deltaSec > 0) {
        final dist = _haversineDistance(
          _lastValidPoint!.latitude,
          _lastValidPoint!.longitude,
          candidate.latitude,
          candidate.longitude,
        );

        final impliedSpeed = dist / deltaSec;
        if (impliedSpeed > 14.0) {
          // Reject impossible GPS jitter jump
          return;
        }

        _totalDistanceMeters += dist;
      }
    }

    _lastValidPoint = candidate;
    _routePoints.add(candidate);
    _bufferedPoints.add(candidate);

    _pointController.add(candidate);
    _distanceController.add(totalDistanceKm);
  }

  void clearOfflineBuffer() {
    _bufferedPoints.clear();
  }

  // Haversine formula for exact distance between two lat/lng coordinates
  double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  void dispose() {
    stopTracking();
    _pointController.close();
    _distanceController.close();
  }
}


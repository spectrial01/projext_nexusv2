import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;

  void dispose() {
    _positionStream?.cancel();
  }

  Future<bool> checkLocationRequirements() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission is required to continue.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied. Please enable them from app settings.');
    }

    return true;
  }

  Future<void> startHighPrecisionTracking({
    required Function(Position) onLocationUpdate,
    required Function(String) onError,
  }) async {
    if (_isTracking) {
      print("LocationService: Tracking is already active.");
      return;
    }

    try {
      await checkLocationRequirements();

      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, // meters
      );

      _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position position) {
          _currentPosition = position;
          onLocationUpdate(position);
        },
        onError: (e) {
          print("LocationService: Error in position stream: $e");
          onError("Failed to get location updates. GPS signal may be weak.");
          _isTracking = false;
        }
      );
      _isTracking = true;
    } catch (e) {
      // Re-throw the exception from checkLocationRequirements
      throw e;
    }
  }

  Future<Position> forceLocationRefresh() async {
    try {
      await checkLocationRequirements();
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
      );
      return _currentPosition!;
    } on TimeoutException {
      throw Exception("Could not get a location fix in time. Please check your GPS signal.");
    } catch (e) {
      print('LocationService: Error forcing location refresh: $e');
      throw Exception('Failed to refresh location. Ensure GPS is enabled and you have a clear view of the sky.');
    }
  }

  // Other helper methods can remain the same
  String getAccuracyStatus() {
    if (_currentPosition == null) return "N/A";
    if (_currentPosition!.accuracy < 10) return "High (±${_currentPosition!.accuracy.toStringAsFixed(1)}m)";
    if (_currentPosition!.accuracy < 20) return "Medium (±${_currentPosition!.accuracy.toStringAsFixed(1)}m)";
    return "Low (±${_currentPosition!.accuracy.toStringAsFixed(1)}m)";
  }

  String getLocationSource() {
    if (_currentPosition == null) return "N/A";
    return _currentPosition!.isMocked ? "Mocked" : "GPS/Network";
  }

  String getMovementStatus() {
    if (_currentPosition == null || _currentPosition!.speed < 0.5) return "Stationary";
    return "Moving";
  }
}
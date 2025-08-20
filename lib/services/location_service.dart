import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  bool _isLocationEnabled = false;
  bool _hasLocationPermission = false;
  bool _isInitializing = false;
  
  // Callbacks for location updates
  Function(Position)? _onLocationUpdate;
  Function(String)? _onLocationError;

  // Getters
  Position? get currentPosition => _currentPosition;
  bool get isLocationEnabled => _isLocationEnabled;
  bool get hasLocationPermission => _hasLocationPermission;

  Future<bool> checkLocationRequirements() async {
    print('LocationService: Checking location requirements...');
    
    final permissionStatus = await Permission.location.status;
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    
    _hasLocationPermission = permissionStatus.isGranted;
    _isLocationEnabled = serviceEnabled;
    
    print('LocationService: Permission granted: $_hasLocationPermission, Service enabled: $_isLocationEnabled');
    
    return _hasLocationPermission && _isLocationEnabled;
  }

  Future<PermissionStatus> requestLocationPermission() async {
    print('LocationService: Requesting location permission...');
    
    // Request location permission
    final status = await Permission.location.request();
    _hasLocationPermission = status.isGranted;
    
    // Also request precise location permission on Android
    if (status.isGranted) {
      try {
        final preciseStatus = await Permission.locationWhenInUse.request();
        print('LocationService: Precise location permission: $preciseStatus');
      } catch (e) {
        print('LocationService: Error requesting precise location: $e');
      }
    }
    
    return status;
  }

  Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
    Duration? timeout,
  }) async {
    if (_isInitializing) {
      print('LocationService: Already initializing, waiting...');
      await Future.delayed(const Duration(seconds: 2));
    }
    
    _isInitializing = true;
    
    try {
      print('LocationService: Getting current position with ${accuracy.toString()} accuracy...');
      
      // First check if we have permission and service is enabled
      final hasRequirements = await checkLocationRequirements();
      if (!hasRequirements) {
        throw 'Location permission or service not available';
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeout ?? const Duration(seconds: 15),
        forceAndroidLocationManager: false, // Use Google Play Services for better accuracy
      );
      
      _currentPosition = position;
      print('LocationService: Position obtained - Lat: ${position.latitude}, Lng: ${position.longitude}, Accuracy: ±${position.accuracy.toStringAsFixed(1)}m');
      
      return position;
    } catch (e) {
      print('LocationService: Error getting current position: $e');
      _onLocationError?.call('Failed to get location: $e');
      return null;
    } finally {
      _isInitializing = false;
    }
  }

  Stream<Position> getHighPrecisionPositionStream() {
    print('LocationService: Creating high-precision position stream...');
    
    // High precision settings for Google Maps-like accuracy
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation, // Highest accuracy available
      distanceFilter: 1, // Update every 1 meter movement
      timeLimit: Duration(seconds: 30), // Shorter timeout for faster updates
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  void startHighPrecisionTracking({
    required Function(Position) onLocationUpdate,
    Function(String)? onError,
  }) {
    print('LocationService: Starting high-precision location tracking...');
    
    _onLocationUpdate = onLocationUpdate;
    _onLocationError = onError;
    
    // Stop any existing subscription
    stopLocationTracking();
    
    try {
      // Get initial position first to provide immediate feedback
      getCurrentPosition().then((initialPosition) {
        if (initialPosition != null) {
          print('LocationService: Initial position obtained, starting stream...');
          _onLocationUpdate?.call(initialPosition);
        }
      }).catchError((e) {
        print('LocationService: Error getting initial position: $e');
        // Continue with stream anyway
      });
      
      // Start the position stream
      _positionSubscription = getHighPrecisionPositionStream().listen(
        (position) {
          _currentPosition = position;
          print('LocationService: High-precision update - Lat: ${position.latitude}, Lng: ${position.longitude}, Accuracy: ±${position.accuracy.toStringAsFixed(1)}m, Speed: ${position.speed.toStringAsFixed(1)}m/s');
          
          _onLocationUpdate?.call(position);
        },
        onError: (error) {
          print('LocationService: High-precision stream error: $error');
          _onLocationError?.call('Location tracking error: $error');
          
          // Try to restart the stream after a delay
          Timer(const Duration(seconds: 5), () {
            print('LocationService: Attempting to restart location stream...');
            if (_onLocationUpdate != null) {
              startHighPrecisionTracking(
                onLocationUpdate: _onLocationUpdate!,
                onError: _onLocationError,
              );
            }
          });
        },
        cancelOnError: false, // Continue tracking even if there are temporary errors
      );
      
      print('LocationService: High-precision tracking started successfully');
    } catch (e) {
      print('LocationService: Error starting high-precision tracking: $e');
      _onLocationError?.call('Failed to start location tracking: $e');
    }
  }

  // Legacy method for backward compatibility
  void startLocationTracking(Function(Position) onLocationUpdate) {
    startHighPrecisionTracking(onLocationUpdate: onLocationUpdate);
  }

  void stopLocationTracking() {
    print('LocationService: Stopping location tracking...');
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  // Get location accuracy status
  String getAccuracyStatus() {
    if (_currentPosition == null) return 'No location';
    
    final accuracy = _currentPosition!.accuracy;
    if (accuracy <= 3) return 'Excellent (±${accuracy.toStringAsFixed(1)}m)';
    if (accuracy <= 10) return 'Good (±${accuracy.toStringAsFixed(1)}m)';
    if (accuracy <= 30) return 'Fair (±${accuracy.toStringAsFixed(1)}m)';
    return 'Poor (±${accuracy.toStringAsFixed(1)}m)';
  }

  // Get location source info
  String getLocationSource() {
    if (_currentPosition == null) return 'Unknown';
    
    // Estimate source based on accuracy
    final accuracy = _currentPosition!.accuracy;
    if (accuracy <= 5) return 'GPS + Network';
    if (accuracy <= 20) return 'GPS';
    if (accuracy <= 100) return 'Network';
    return 'Passive';
  }

  // Check if device is moving
  bool isMoving() {
    if (_currentPosition == null) return false;
    return _currentPosition!.speed > 0.5; // Moving if speed > 0.5 m/s
  }

  // Get movement status
  String getMovementStatus() {
    if (_currentPosition == null) return 'Unknown';
    
    final speed = _currentPosition!.speed;
    if (speed < 0.5) return 'Stationary';
    if (speed < 1.4) return 'Walking'; // ~5 km/h
    if (speed < 5.6) return 'Running'; // ~20 km/h
    if (speed < 13.9) return 'Cycling'; // ~50 km/h
    return 'Vehicle'; // >50 km/h
  }

  // Force location refresh with highest accuracy
  Future<Position?> forceLocationRefresh() async {
    print('LocationService: Forcing location refresh with highest accuracy...');
    
    try {
      // Use best possible accuracy and longer timeout for refresh
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 30),
        forceAndroidLocationManager: false,
      );
      
      _currentPosition = position;
      _onLocationUpdate?.call(position);
      
      print('LocationService: Forced refresh complete - Accuracy: ±${position.accuracy.toStringAsFixed(1)}m');
      return position;
    } catch (e) {
      print('LocationService: Error in forced refresh: $e');
      _onLocationError?.call('Failed to refresh location: $e');
      return null;
    }
  }

  // Get detailed location info
  Map<String, dynamic> getDetailedLocationInfo() {
    if (_currentPosition == null) {
      return {
        'available': false,
        'message': 'No location data available'
      };
    }

    final pos = _currentPosition!;
    return {
      'available': true,
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracy': pos.accuracy,
      'altitude': pos.altitude,
      'speed': pos.speed,
      'speedAccuracy': pos.speedAccuracy,
      'heading': pos.heading,
      'headingAccuracy': pos.headingAccuracy,
      'timestamp': pos.timestamp,
      'accuracyStatus': getAccuracyStatus(),
      'locationSource': getLocationSource(),
      'movementStatus': getMovementStatus(),
      'isMoving': isMoving(),
    };
  }

  void dispose() {
    print('LocationService: Disposing...');
    stopLocationTracking();
  }
}
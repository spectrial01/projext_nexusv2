import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/wake_lock_service.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _locationService = LocationService();
  final _wakeLockService = WakeLockService();

  Position? _currentPosition;
  String _errorMessage = '';
  bool _isLoading = true;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _wakeLockService.disableWakeLock();
    super.dispose();
  }

  Future<void> _initializeLocationTracking() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Enable wake lock to keep the screen on during tracking
      await _wakeLockService.enableWakeLock();

      // The start tracking method now handles permission checks internally.
      _locationService.startHighPrecisionTracking(
        onLocationUpdate: (position) {
          if (mounted) {
            setState(() {
              _currentPosition = position;
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _errorMessage = error;
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          // Catch errors from permission requests (e.g., user denies)
          _errorMessage = e.toString().replaceAll("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Location Tracker'),
      ),
      body: Center(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Acquiring GPS signal...'),
        ],
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Location Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _initializeLocationTracking, // Retry the whole process
            ),
          ],
        ),
      );
    }

    if (_currentPosition == null) {
      return const Text('Waiting for location data...');
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.gps_fixed, color: Colors.green, size: 48),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Current Position',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text('Latitude: ${_currentPosition!.latitude.toStringAsFixed(6)}'),
                  const SizedBox(height: 8),
                  Text('Longitude: ${_currentPosition!.longitude.toStringAsFixed(6)}'),
                  const SizedBox(height: 8),
                  Text('Accuracy: ±${_currentPosition!.accuracy.toStringAsFixed(1)} meters'),
                  const SizedBox(height: 8),
                  Text('Speed: ${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Force Refresh'),
            onPressed: () async {
              try {
                final position = await _locationService.forceLocationRefresh();
                if (mounted) {
                  setState(() {
                    _currentPosition = position;
                  });
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location refreshed!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                 if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                  );
                 }
              }
            },
          ),
        ],
      ),
    );
  }
}
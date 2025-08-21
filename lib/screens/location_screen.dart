// screens/location_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/wake_lock_service.dart';
import '../utils/responsive_utils.dart';

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
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text(
          'Live Location Tracker',
          style: ResponsiveTextStyles.getBodyLarge(context).copyWith(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
              Color(0xFF1A1A2E),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16.r(context)),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: const Color(0xFF26C6DA)),
            SizedBox(height: 16.h(context)),
            Text(
              'Acquiring GPS signal...',
              style: ResponsiveTextStyles.getBodyLarge(context).copyWith(color: Colors.white),
            ),
            SizedBox(height: 8.h(context)),
            Text(
              'This may take a few moments',
              style: ResponsiveTextStyles.getBodyMedium(context).copyWith(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16.r(context)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24.r(context)),
                decoration: BoxDecoration(
                  color: Colors.red[900]?.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red[400]!.withOpacity(0.5)),
                ),
                child: Icon(
                  Icons.location_off, 
                  color: Colors.red[400], 
                  size: 48.r(context)
                ),
              ),
              SizedBox(height: 16.h(context)),
              Text(
                'Location Error',
                style: ResponsiveTextStyles.getHeading3(context).copyWith(color: Colors.white),
              ),
              SizedBox(height: 8.h(context)),
              Container(
                padding: EdgeInsets.all(16.r(context)),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12.r(context)),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: ResponsiveTextStyles.getBodyMedium(context).copyWith(color: Colors.grey[400]),
                ),
              ),
              SizedBox(height: 24.h(context)),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r(context)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF26C6DA).withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: Icon(Icons.refresh, size: 20.r(context)),
                  label: Text(
                    'Retry Location Setup',
                    style: ResponsiveTextStyles.getBodyMedium(context).copyWith(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _initializeLocationTracking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF26C6DA),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 16.h(context)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r(context))),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentPosition == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: const Color(0xFF26C6DA)),
            SizedBox(height: 16.h(context)),
            Text(
              'Waiting for location data...',
              style: ResponsiveTextStyles.getBodyLarge(context).copyWith(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 20.h(context)),
          _buildLocationStatusIcon(),
          SizedBox(height: 32.h(context)),
          _buildLocationCard(),
          SizedBox(height: 24.h(context)),
          _buildRefreshButton(),
          SizedBox(height: 20.h(context)),
        ],
      ),
    );
  }

  Widget _buildLocationStatusIcon() {
    final accuracy = _currentPosition?.accuracy ?? 0;
    final isHighAccuracy = accuracy <= 10;
    
    return Center(
      child: Container(
        width: 120.r(context),
        height: 120.r(context),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (isHighAccuracy ? Colors.green[400]! : Colors.orange[400]!).withOpacity(0.2),
              (isHighAccuracy ? Colors.green[400]! : Colors.orange[400]!).withOpacity(0.1),
            ],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: isHighAccuracy ? Colors.green[400]! : Colors.orange[400]!, 
            width: 3
          ),
          boxShadow: [
            BoxShadow(
              color: (isHighAccuracy ? Colors.green[400]! : Colors.orange[400]!).withOpacity(0.4),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(
          isHighAccuracy ? Icons.gps_fixed : Icons.location_on,
          size: 60.r(context),
          color: isHighAccuracy ? Colors.green[400] : Colors.orange[400],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    if (_currentPosition == null) return const SizedBox.shrink();
    
    final accuracy = _currentPosition!.accuracy;
    final isHighAccuracy = accuracy <= 10;
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20.r(context)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24.r(context)),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.r(context)),
                  decoration: BoxDecoration(
                    color: (isHighAccuracy ? Colors.green[400] : Colors.orange[400])!.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12.r(context)),
                  ),
                  child: Icon(
                    isHighAccuracy ? Icons.gps_fixed : Icons.location_searching,
                    color: isHighAccuracy ? Colors.green[400] : Colors.orange[400],
                    size: 24.r(context),
                  ),
                ),
                SizedBox(width: 16.w(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Position',
                        style: ResponsiveTextStyles.getHeading3(context).copyWith(color: Colors.white),
                      ),
                      SizedBox(height: 4.h(context)),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w(context), vertical: 4.h(context)),
                        decoration: BoxDecoration(
                          color: (isHighAccuracy ? Colors.green[400] : Colors.orange[400])!.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8.r(context)),
                          border: Border.all(
                            color: isHighAccuracy ? Colors.green[400]! : Colors.orange[400]!,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '±${accuracy.toStringAsFixed(1)}m accuracy',
                          style: ResponsiveTextStyles.getCaption(context).copyWith(
                            color: isHighAccuracy ? Colors.green[400] : Colors.orange[400],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h(context)),
            Container(
              padding: EdgeInsets.all(20.r(context)),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16.r(context)),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  _buildLocationDataRow(
                    'Latitude',
                    '${_currentPosition!.latitude.toStringAsFixed(6)}°',
                    Icons.public,
                  ),
                  SizedBox(height: 16.h(context)),
                  _buildLocationDataRow(
                    'Longitude',
                    '${_currentPosition!.longitude.toStringAsFixed(6)}°',
                    Icons.public,
                  ),
                  SizedBox(height: 16.h(context)),
                  _buildLocationDataRow(
                    'Altitude',
                    '${_currentPosition!.altitude.toStringAsFixed(0)}m',
                    Icons.terrain,
                  ),
                  SizedBox(height: 16.h(context)),
                  _buildLocationDataRow(
                    'Speed',
                    '${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h',
                    Icons.speed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDataRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.r(context)),
          decoration: BoxDecoration(
            color: const Color(0xFF26C6DA).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8.r(context)),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF26C6DA),
            size: 16.r(context),
          ),
        ),
        SizedBox(width: 12.w(context)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: ResponsiveTextStyles.getCaption(context).copyWith(
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.h(context)),
              Text(
                value,
                style: ResponsiveTextStyles.getBodyMedium(context).copyWith(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r(context)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF26C6DA).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ElevatedButton.icon(
        icon: Icon(Icons.refresh, size: 24.r(context)),
        label: Text(
          'Force Refresh Location',
          style: ResponsiveTextStyles.getBodyLarge(context).copyWith(fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          try {
            setState(() => _isLoading = true);
            final position = await _locationService.forceLocationRefresh();
            if (mounted) {
              setState(() {
                _currentPosition = position;
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Location refreshed! Accuracy: ±${position?.accuracy.toStringAsFixed(1)}m',
                    style: ResponsiveTextStyles.getBodyMedium(context),
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r(context))),
                  margin: EdgeInsets.all(16.r(context)),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    e.toString(),
                    style: ResponsiveTextStyles.getBodyMedium(context),
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r(context))),
                  margin: EdgeInsets.all(16.r(context)),
                ),
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF26C6DA),
          foregroundColor: Colors.black,
          padding: EdgeInsets.symmetric(vertical: 18.h(context)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r(context))),
          elevation: 0,
        ),
      ),
    );
  }
}
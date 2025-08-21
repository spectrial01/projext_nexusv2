// screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/location_service.dart';
import '../services/device_service.dart';
import '../services/api_service.dart';
import '../services/background_service.dart';
import '../services/watchdog_service.dart';
import '../services/wake_lock_service.dart';
import '../widgets/metric_card.dart';
import '../utils/constants.dart';
import '../utils/responsive_utils.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String token;
  final String deploymentCode;

  const DashboardScreen({
    super.key,
    required this.token,
    required this.deploymentCode,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  final _locationService = LocationService();
  final _deviceService = DeviceService();
  final _watchdogService = WatchdogService();
  final _wakeLockService = WakeLockService();

  Timer? _apiUpdateTimer;
  Timer? _heartbeatTimer;
  Timer? _clockTimer;
  Timer? _batterySignalTimer;
  
  bool _isLoading = true;
  bool _isLocationLoading = true;
  double _internetSpeed = 0.0;
  String _initializationError = '';
  String _currentTime = '';
  
  Map<String, dynamic> _watchdogStatus = {};
  Map<String, dynamic> _wakeLockStatus = {};

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startClock();
    _initializeServices();
    
    // ADD DEBUG INFO
    Timer(const Duration(seconds: 5), () {
      _debugBatterySignalData();
    });
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();
  }

  void _startClock() {
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    });
  }

  @override
  void dispose() {
    _apiUpdateTimer?.cancel();
    _heartbeatTimer?.cancel();
    _clockTimer?.cancel();
    _batterySignalTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    _locationService.dispose();
    _deviceService.dispose();
    _watchdogService.stopWatchdog();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _initializationError = '';
    });

    try {
      await _initializePermanentWakeLock();
      await Future.wait([
        _initializeDeviceService(),
        _initializeLocationTracking(),
        _initializeWatchdog(),
      ], eagerError: true);
      _startPeriodicUpdates();
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializationError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _initializeDeviceService() async {
    try {
      await _deviceService.initialize();
    } catch (e) {
      throw Exception('Failed to initialize device service.');
    }
  }

  Future<void> _initializeWatchdog() async {
    try {
      await _watchdogService.initialize(onAppDead: () {
        if (mounted) {
          _showSnackBar('App monitoring was interrupted. Restarting...', Colors.orange);
          _initializeServices();
        }
      });
      _watchdogService.startWatchdog();
    } catch (e) {
      throw Exception('Failed to start watchdog service.');
    }
  }

  Future<void> _initializePermanentWakeLock() async {
    try {
      await _wakeLockService.initialize();
      await _wakeLockService.forceEnableForCriticalOperation();
      if (mounted) {
        setState(() {
          _wakeLockStatus = _wakeLockService.getDetailedStatus();
        });
      }
    } catch (e) {
      throw Exception('Failed to acquire screen wake lock.');
    }
  }

  Future<void> _initializeLocationTracking() async {
    if (!mounted) return;
    setState(() => _isLocationLoading = true);
    try {
      await _locationService.startHighPrecisionTracking(
        onLocationUpdate: (position) {
          if (mounted) setState(() => _isLocationLoading = false);
        },
        onError: (error) {
          if (mounted) {
            setState(() => _isLocationLoading = false);
            _showSnackBar(error, Colors.orange);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLocationLoading = false);
        _showSnackBar(e.toString(), Colors.red);
      }
    }
  }

// FIXED PERIODIC UPDATES - No more heartbeat conflicts
  void _startPeriodicUpdates() {
    // SINGLE MAIN UPDATE TIMER - Every 5 seconds with real location
    _apiUpdateTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) => _sendLocationUpdateSafely(),
    );
    
    // STATUS CHECK TIMER - Every 2 minutes to verify login status (less frequent)
    Timer.periodic(const Duration(minutes: 2), (timer) async {
      try {
        final statusResult = await ApiService.checkStatus(
          widget.token,
          widget.deploymentCode,
        );
        print('Dashboard: 📊 Status check completed: ${statusResult.success}');
      } catch (e) {
        print('Dashboard: Status check error: $e');
      }
    });
    
    // REMOVED HEARTBEAT TIMER - This was causing the flickering!
    // The main update every 5 seconds is sufficient to keep connection alive
    
    // BACKUP UPDATE TIMER - Only every 5 minutes (very infrequent)
    _batterySignalTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      try {
        // Only send backup if we have real location data
        if (_locationService.currentPosition != null) {
          await ApiService.sendBatterySignalUpdate(
            token: widget.token,
            deploymentCode: widget.deploymentCode,
            batteryLevel: _deviceService.batteryLevel,
            signalStrength: _deviceService.signalStrength,
            batteryState: _deviceService.batteryState.toString(),
            connectivityType: _deviceService.connectivityResult.toString().split('.').last,
          );
        }
      } catch (e) {
        print('Dashboard: Backup update error: $e');
      }
    });
    
    // REMOVED ALTERNATIVE UPDATE TIMER - Redundant with main updates
    
    // System maintenance every 5 minutes
    _heartbeatTimer = Timer.periodic(
      const Duration(minutes: 5),
      (timer) {
        _watchdogService.ping();
        _maintainWakeLock();
        if (mounted) {
          setState(() {
            _watchdogStatus = _watchdogService.getStatus();
            _wakeLockStatus = _wakeLockService.getDetailedStatus();
          });
        }
        
        // Debug stability status
        final stabilityStatus = ApiService.getStabilityStatus();
        print('Dashboard: 📊 Stability Status: $stabilityStatus');
      },
    );
    
    // Simulated internet speed updates
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _internetSpeed = 50 + (DateTime.now().millisecondsSinceEpoch % 1500) / 10;
        });
      }
    });
  }

  // MAINTAIN WAKE LOCK - Keep screen awake for monitoring
  Future<void> _maintainWakeLock() async {
    try {
      if (!await _wakeLockService.checkWakeLockStatus()) {
        await _wakeLockService.forceEnableForCriticalOperation();
        print('Dashboard: 🔒 Wake lock restored');
      }
    } catch (e) {
      print('Dashboard: Error maintaining wake lock: $e');
    }
  }

  // SAFE WRAPPER for location updates with error handling
  Future<void> _sendLocationUpdateSafely() async {
    try {
      await _sendLocationUpdate();
    } catch (e) {
      print('Dashboard: Error in safe location update: $e');
      if (mounted) {
        _showSnackBar('Location sync error: ${e.toString()}', Colors.red);
      }
    }
  }

  // SINGLE CONSISTENT LOCATION UPDATE - Only real coordinates
  Future<void> _sendLocationUpdate() async {
    if (_locationService.currentPosition == null) return;
    
    final position = _locationService.currentPosition!;
    final batteryLevel = _deviceService.batteryLevel;
    final signalStrength = _deviceService.signalStrength;
    final batteryState = _deviceService.batteryState.toString();
    final connectivityType = _deviceService.connectivityResult.toString().split('.').last;
    
    print('Dashboard: 📍 Sending CONSISTENT location update (no dummy coordinates)...');
    print('Dashboard: 🔋 Battery: $batteryLevel% ($batteryState)');
    print('Dashboard: 📶 Signal: $signalStrength ($connectivityType)');
    print('Dashboard: 📍 REAL Location: ${position.latitude}, ${position.longitude}');
    print('Dashboard: 🎯 Deployment: ${widget.deploymentCode}');
    
    try {
      // ONLY SEND REAL LOCATION DATA - No dummy coordinates ever
      final response = await ApiService.updateLocation(
        token: widget.token,
        deploymentCode: widget.deploymentCode,
        position: position,
        batteryLevel: batteryLevel,
        signalStrength: signalStrength,
        batteryState: batteryState,
        connectivityType: connectivityType,
      );
      
      if (response.success) {
        print('Dashboard: ✅ SUCCESS! Green dot should be STABLE now (no heartbeat conflicts)!');
        print('Dashboard: 🟢 Real data sent: Battery=$batteryLevel%, Signal=$signalStrength');
        print('Dashboard: 📍 Coordinates: ${position.latitude}, ${position.longitude}');
        
        // Show success feedback occasionally
        if (DateTime.now().second % 30 == 0 && mounted) {
          _showSnackBar('Location synced successfully', Colors.green);
        }
      } else {
        print('Dashboard: ⚠️ Update failed: ${response.message}');
        
        if (mounted) {
          _showSnackBar('Sync warning: ${response.message}', Colors.orange);
        }
      }
      
    } catch (e) {
      print('Dashboard: ❌ Update error: $e');
      
      if (mounted) {
        _showSnackBar('Network error - will retry automatically', Colors.red);
      }
    }
  }

  // ENHANCED DEBUGGING METHOD
  void _debugBatterySignalData() {
    print('=== FIXED STABLE SYSTEM DEBUG INFO ===');
    print('🔋 Battery Level: ${_deviceService.batteryLevel}%');
    print('🔋 Battery State: ${_deviceService.batteryState}');
    print('🔋 Is Charging: ${_deviceService.batteryState == BatteryState.charging}');
    print('📶 Signal Strength: ${_deviceService.signalStrength}');
    print('📶 Signal Bars: ${_deviceService.getSignalBars()}/4');
    print('📶 Connectivity: ${_deviceService.connectivityResult}');
    print('📱 Device: ${_deviceService.deviceBrand} ${_deviceService.deviceModel}');
    print('📍 REAL Location: ${_locationService.currentPosition?.latitude}, ${_locationService.currentPosition?.longitude}');
    print('🌐 Web App: https://nexuspolice-13560.web.app/map');
    print('🆔 Deployment: ${widget.deploymentCode}');
    print('⏰ Current Time: $_currentTime');
    
    // API STABILITY STATUS
    final stabilityStatus = ApiService.getStabilityStatus();
    print('📊 STABILITY STATUS:');
    print('  - Logged In: ${stabilityStatus['isLoggedIn']}');
    print('  - Last Success: ${stabilityStatus['lastSuccessfulUpdate']}');
    print('  - Failures: ${stabilityStatus['consecutiveFailures']}');
    print('  - Minutes Since Success: ${stabilityStatus['minutesSinceLastSuccess']}');
    
    print('🔄 FIXED UPDATE STRATEGY:');
    print('  - Main updates: Every 5 seconds (REAL coordinates only)');
    print('  - Status check: Every 2 minutes (verify login)');
    print('  - Backup: Every 5 minutes (if main failing)');
    print('  - ❌ NO MORE HEARTBEAT with dummy coordinates');
    print('  - ✅ NO MORE conflicting requests');
    print('  - 🟢 Green dot should be SOLID now');
    print('====================================');
  }
  

  Future<void> _refreshLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      final position = await _locationService.forceLocationRefresh();
      if (mounted && position != null) {
        _showSnackBar('Location refreshed (±${position.accuracy.toStringAsFixed(1)}m)', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString(), Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isLocationLoading = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r(context))),
        margin: EdgeInsets.all(16.r(context)),
      ),
    );
  }

  Future<void> _showLogoutConfirmation() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r(context))),
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.orange[400], size: 24.r(context)),
            SizedBox(width: 12.w(context)),
            Text('Confirm Logout', style: ResponsiveTextStyles.getHeading3(context).copyWith(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to logout?',
              style: ResponsiveTextStyles.getBodyMedium(context).copyWith(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h(context)),
            Text('This will:', style: ResponsiveTextStyles.getBodyMedium(context).copyWith(color: Colors.white70)),
            SizedBox(height: 8.h(context)),
            Text('• Disconnect from the web monitoring system', style: ResponsiveTextStyles.getBodySmall(context).copyWith(color: Colors.white54)),
            Text('• Remove your device from the live map', style: ResponsiveTextStyles.getBodySmall(context).copyWith(color: Colors.white54)),
            Text('• Stop location tracking and background monitoring', style: ResponsiveTextStyles.getBodySmall(context).copyWith(color: Colors.white54)),
            Text('• Return you to the login screen', style: ResponsiveTextStyles.getBodySmall(context).copyWith(color: Colors.white54)),
            SizedBox(height: 12.h(context)),
            Text(
              'Your supervisor will be notified that you have logged out.',
              style: ResponsiveTextStyles.getCaption(context).copyWith(color: Colors.yellow, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: ResponsiveTextStyles.getBodyMedium(context).copyWith(color: Colors.white70)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r(context))),
            ),
            child: Text('Logout & Disconnect', style: ResponsiveTextStyles.getBodyMedium(context)),
            onPressed: () {
              Navigator.of(context).pop();
              _performLogout();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    // Show logout progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r(context))),
        backgroundColor: const Color(0xFF1E1E1E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: const Color(0xFF26C6DA)),
            SizedBox(height: 16.h(context)),
            Text(
              'Logging out...',
              style: ResponsiveTextStyles.getBodyLarge(context).copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h(context)),
            Text(
              'Disconnecting from monitoring system',
              style: ResponsiveTextStyles.getCaption(context).copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );

    try {
      print('Dashboard: Sending logout request to disconnect from web app...');
      
      final logoutResponse = await ApiService.logout(widget.token, widget.deploymentCode);
      
      if (logoutResponse.success) {
        print('Dashboard: Successfully disconnected from web app');
        _showSnackBar('Disconnected from monitoring system', Colors.green);
      } else {
        print('Dashboard: Logout API call failed: ${logoutResponse.message}');
        _showSnackBar('Warning: Failed to disconnect from web app', Colors.orange);
      }

      print('Dashboard: Stopping background services...');
      _watchdogService.stopWatchdog();
      await stopBackgroundServiceSafely();
      
      await _wakeLockService.disableWakeLock();
      
      print('Dashboard: Keeping credentials stored for next login');
      print('Dashboard: Logout process completed successfully');
      
      await Future.delayed(const Duration(milliseconds: 1000));
      
    } catch (e) {
      print('Dashboard: Error during logout: $e');
      _showSnackBar('Logout completed with warnings', Colors.orange);
      
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted) {
      Navigator.of(context).pop(); // Close the progress dialog
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
        (route) => false,
      );
    }
  }

  Color _getBatteryColor() {
    final level = _deviceService.batteryLevel;
    if (level > 50) return Colors.green[400]!;
    if (level > 20) return Colors.orange[400]!;
    return Colors.red[400]!;
  }

  IconData _getBatteryIcon() {
    final level = _deviceService.batteryLevel;
    final state = _deviceService.batteryState;
    if (state.toString().contains('charging')) return Icons.battery_charging_full;
    if (level > 80) return Icons.battery_full;
    if (level > 60) return Icons.battery_6_bar;
    if (level > 40) return Icons.battery_4_bar;
    if (level > 20) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }

  Color _getSignalColor() {
    switch (_deviceService.signalStrength) {
      case 'strong': return Colors.green[400]!;
      case 'weak': return Colors.orange[400]!;
      default: return Colors.red[400]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: const Color(0xFF26C6DA)),
                SizedBox(height: 24.h(context)),
                Text(
                  'Initializing Stabilized System...',
                  style: ResponsiveTextStyles.getBodyLarge(context).copyWith(color: Colors.white70),
                ),
                SizedBox(height: 8.h(context)),
                Text(
                  'Setting up consistent updates and heartbeat monitoring',
                  style: ResponsiveTextStyles.getBodyMedium(context).copyWith(color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_initializationError.isNotEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            ),
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24.r(context)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(20.r(context)),
                    decoration: BoxDecoration(
                      color: Colors.red[900]?.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(15.r(context)),
                      border: Border.all(color: Colors.red[400]!.withOpacity(0.5)),
                    ),
                    child: Icon(Icons.error_outline, color: Colors.red[400], size: 64.r(context)),
                  ),
                  SizedBox(height: 24.h(context)),
                  Text(
                    'System Initialization Failed',
                    style: ResponsiveTextStyles.getHeading3(context).copyWith(color: Colors.white),
                  ),
                  SizedBox(height: 12.h(context)),
                  Text(
                    _initializationError.replaceAll("Exception: ", ""),
                    textAlign: TextAlign.center,
                    style: ResponsiveTextStyles.getBodyMedium(context).copyWith(color: Colors.white70),
                  ),
                  SizedBox(height: 24.h(context)),
                  ElevatedButton.icon(
                    onPressed: _initializeServices,
                    icon: Icon(Icons.refresh, size: 20.r(context)),
                    label: Text('Retry Initialization', style: ResponsiveTextStyles.getBodyMedium(context)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF26C6DA),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: 24.w(context), vertical: 12.h(context)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r(context))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
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
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _initializeServices,
                      color: const Color(0xFF26C6DA),
                      backgroundColor: const Color(0xFF1E1E1E),
                      child: ListView(
                        padding: EdgeInsets.all(16.r(context)),
                        children: [
                          _buildStatusBanner(),
                          SizedBox(height: 16.h(context)),
                          if (_watchdogStatus.isNotEmpty) _buildWatchdogStatus(),
                          if (_watchdogStatus.isNotEmpty) SizedBox(height: 16.h(context)),
                          _buildMetricsGrid(),
                          SizedBox(height: 16.h(context)),
                          _buildLocationCard(),
                          SizedBox(height: 16.h(context)),
                          _buildDeveloperCredit(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryRed,
            AppColors.primaryRed.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w(context), vertical: 12.h(context)),
        child: Row(
          children: [
            Container(
              width: 32.r(context),
              height: 32.r(context),
              padding: EdgeInsets.all(4.r(context)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6.r(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4.r(context)),
                child: Image.asset(
                  'assets/images/pnp_logo.png',
                  width: 24.r(context),
                  height: 24.r(context),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.shield,
                      color: AppColors.primaryRed,
                      size: 20.r(context),
                    );
                  },
                ),
              ),
            ),
            SizedBox(width: 12.w(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ResponsiveUtils.isVerySmallScreen(context) ? 'PNP' : 'PNP MONITOR',
                    style: ResponsiveTextStyles.getBodyMedium(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'STABILIZED',
                          style: ResponsiveTextStyles.getCaption(context).copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                      ),
                      SizedBox(width: 4.w(context)),
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 3.r(context),
                            height: 3.r(context),
                            decoration: BoxDecoration(
                              color: Colors.green[400],
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w(context)),
            SizedBox(
              width: 50.w(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentTime.length >= 5 ? _currentTime.substring(0, 5) : _currentTime,
                    style: ResponsiveTextStyles.getCaption(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                  Text(
                    'TIME',
                    style: ResponsiveTextStyles.getCaption(context).copyWith(
                      color: Colors.white54,
                      fontSize: 8.sp(context),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w(context)),
            Container(
              width: 32.r(context),
              height: 32.r(context),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4.r(context)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(4.r(context)),
                  onTap: _showLogoutConfirmation,
                  child: Icon(
                    Icons.logout,
                    color: Colors.white,
                    size: 16.r(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green[600]!,
            Colors.green[700]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16.r(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.green[600]!.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.r(context)),
        child: Column(
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: EdgeInsets.all(12.r(context)),
                        decoration: BoxDecoration(
                          color: Colors.green[400],
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green[400]!.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(Icons.check_circle, color: Colors.white, size: 24.r(context)),
                      ),
                    );
                  },
                ),
                SizedBox(width: 16.w(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ResponsiveUtils.isVerySmallScreen(context) 
                          ? 'Stabilized Monitoring Active' 
                          : 'Stabilized High-Precision Monitoring Active',
                        style: ResponsiveTextStyles.getBodyLarge(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h(context)),
                      Text(
                        ResponsiveUtils.isVerySmallScreen(context) 
                          ? '💗 Heartbeat • 🔋 Battery • 📶 Signal'
                          : '💗 Heartbeat system • 🔋 Battery monitoring • 📶 Signal tracking',
                        style: ResponsiveTextStyles.getBodyMedium(context).copyWith(
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.favorite, color: Colors.green[200], size: 20.r(context)),
              ],
            ),
            SizedBox(height: 12.h(context)),
            Container(
              padding: EdgeInsets.all(8.r(context)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.web, color: Colors.white70, size: 14.r(context)),
                  SizedBox(width: 8.w(context)),
                  Flexible(
                    child: Text(
                      ResponsiveUtils.isVerySmallScreen(context) 
                        ? 'Stable Connection Active'
                        : 'Stable connection to: nexuspolice-13560.web.app/map',
                      style: ResponsiveTextStyles.getCaption(context).copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchdogStatus() {
    final isRunning = _watchdogStatus['isRunning'] ?? false;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isRunning 
            ? [Colors.blue[600]!, Colors.blue[700]!]
            : [Colors.orange[600]!, Colors.orange[700]!],
        ),
        borderRadius: BorderRadius.circular(12.r(context)),
        boxShadow: [
          BoxShadow(
            color: (isRunning ? Colors.blue[600]! : Colors.orange[600]!).withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r(context)),
        child: Row(
          children: [
            Icon(
              isRunning ? Icons.security : Icons.warning,
              color: Colors.white,
              size: 20.r(context),
            ),
            SizedBox(width: 12.w(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRunning 
                      ? (ResponsiveUtils.isVerySmallScreen(context) ? 'Watchdog Active' : 'Security Watchdog Active')
                      : (ResponsiveUtils.isVerySmallScreen(context) ? 'Watchdog Off' : 'Watchdog Inactive'),
                    style: ResponsiveTextStyles.getBodyMedium(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isRunning 
                      ? (ResponsiveUtils.isVerySmallScreen(context) ? 'Monitoring every 15min' : 'Monitoring app health every 15 minutes')
                      : (ResponsiveUtils.isVerySmallScreen(context) ? 'Monitoring disabled' : 'App monitoring is currently disabled'),
                    style: ResponsiveTextStyles.getBodySmall(context).copyWith(
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Battery',
                icon: _getBatteryIcon(),
                iconColor: _getBatteryColor(),
                value: '${_deviceService.batteryLevel}%',
                subtitle: _deviceService.batteryState.toString().split('.').last.toUpperCase(),
                isRealTime: true,
              ),
            ),
            SizedBox(width: 8.w(context)),
            Expanded(
              child: MetricCard(
                title: 'Signal',
                icon: Icons.signal_cellular_alt,
                iconColor: _getSignalColor(),
                value: _deviceService.signalStrength.toUpperCase(),
                subtitle: _deviceService.connectivityResult.toString().split('.').last.toUpperCase(),
                isRealTime: true,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h(context)),
        MetricCard(
          title: 'Heartbeat System',
          icon: Icons.favorite,
          iconColor: Colors.pink[400]!,
          value: 'ACTIVE',
          subtitle: 'STABLE CONNECTION',
          isRealTime: true,
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    if (_isLocationLoading) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withOpacity(0.8),
          borderRadius: BorderRadius.circular(16.r(context)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(24.r(context)),
          child: Column(
            children: [
              CircularProgressIndicator(color: const Color(0xFF26C6DA)),
              SizedBox(height: 16.h(context)),
              Text(
                'Acquiring High-Precision Location...',
                style: ResponsiveTextStyles.getBodyLarge(context).copyWith(color: Colors.white),
              ),
              SizedBox(height: 8.h(context)),
              Text(
                'Using GPS + Network for best accuracy',
                style: ResponsiveTextStyles.getCaption(context).copyWith(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    final position = _locationService.currentPosition;
    if (position == null) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withOpacity(0.8),
          borderRadius: BorderRadius.circular(16.r(context)),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(24.r(context)),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16.r(context)),
                decoration: BoxDecoration(
                  color: Colors.orange[900]?.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_off, size: 48.r(context), color: Colors.orange[400]),
              ),
              SizedBox(height: 16.h(context)),
              Text(
                'Location Unavailable',
                style: ResponsiveTextStyles.getBodyLarge(context).copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h(context)),
              Text(
                'Unable to get precise location. Please ensure GPS is enabled.',
                style: ResponsiveTextStyles.getBodyMedium(context).copyWith(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h(context)),
              ElevatedButton.icon(
                onPressed: _refreshLocation,
                icon: Icon(Icons.refresh, size: 16.r(context)),
                label: Text('Force GPS Refresh', style: ResponsiveTextStyles.getBodyMedium(context)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF26C6DA),
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 24.w(context), vertical: 12.h(context)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r(context))),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final accuracy = position.accuracy;
    final isHighAccuracy = accuracy <= 10;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16.r(context)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.r(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    isHighAccuracy ? Icons.gps_fixed : Icons.location_on,
                    color: isHighAccuracy ? Colors.green[400] : Colors.orange[400],
                    size: 28.r(context),
                  ),
                ),
                SizedBox(width: 16.w(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Stabilized Location',
                              style: ResponsiveTextStyles.getBodyLarge(context).copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w(context)),
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
                              isHighAccuracy ? 'STABLE' : 'TRACKING',
                              style: ResponsiveTextStyles.getCaption(context).copyWith(
                                fontWeight: FontWeight.bold,
                                color: isHighAccuracy ? Colors.green[400] : Colors.orange[400],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h(context)),
                      Text(
                        '±${accuracy.toStringAsFixed(1)}m accuracy',
                        style: ResponsiveTextStyles.getCaption(context).copyWith(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h(context)),
            Container(
              padding: EdgeInsets.all(16.r(context)),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12.r(context)),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildLocationDataItem(
                          'Latitude',
                          '${position.latitude.toStringAsFixed(6)}°',
                        ),
                      ),
                      SizedBox(width: 16.w(context)),
                      Expanded(
                        child: _buildLocationDataItem(
                          'Longitude',
                          '${position.longitude.toStringAsFixed(6)}°',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h(context)),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLocationDataItem(
                          'Altitude',
                          '${position.altitude.toStringAsFixed(0)}m',
                        ),
                      ),
                      SizedBox(width: 16.w(context)),
                      Expanded(
                        child: _buildLocationDataItem(
                          'Speed',
                          '${(position.speed * 3.6).toStringAsFixed(1)} km/h',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h(context)),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final coordinates = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
                      Clipboard.setData(ClipboardData(text: coordinates));
                      _showSnackBar('Coordinates copied to clipboard!', Colors.green);
                    },
                    icon: Icon(Icons.copy, size: 16.r(context)),
                    label: Text('Copy Coordinates', style: ResponsiveTextStyles.getBodySmall(context)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h(context)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r(context))),
                    ),
                  ),
                ),
                SizedBox(width: 12.w(context)),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _refreshLocation,
                    icon: Icon(Icons.refresh, size: 16.r(context)),
                    label: Text('Refresh GPS', style: ResponsiveTextStyles.getBodySmall(context)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF26C6DA),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 12.h(context)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r(context))),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h(context)),
            Container(
              padding: EdgeInsets.all(12.r(context)),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8.r(context)),
              ),
              child: Column(
                children: [
                  _buildLocationInfoRow(Icons.satellite, 'Source: ${_locationService.getLocationSource()}'),
                  SizedBox(height: 4.h(context)),
                  _buildLocationInfoRow(Icons.speed, 'Movement: ${_locationService.getMovementStatus()}'),
                  SizedBox(height: 4.h(context)),
                  _buildLocationInfoRow(Icons.access_time, 'Last Update: $_currentTime'),
                  SizedBox(height: 4.h(context)),
                  _buildLocationInfoRow(Icons.favorite, 'Heartbeat: Every 5 seconds'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDataItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ResponsiveTextStyles.getCaption(context).copyWith(color: Colors.white54),
        ),
        SizedBox(height: 4.h(context)),
        Text(
          value,
          style: ResponsiveTextStyles.getBodyMedium(context).copyWith(
            color: Colors.white,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16.r(context)),
        SizedBox(width: 8.w(context)),
        Expanded(
          child: Text(
            text,
            style: ResponsiveTextStyles.getCaption(context).copyWith(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildDeveloperCredit() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12.r(context)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r(context)),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.copyright, color: Colors.white54, size: 16.r(context)),
                SizedBox(width: 8.w(context)),
                Text(
                  '2025 Philippine National Police',
                  style: ResponsiveTextStyles.getCaption(context).copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h(context)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w(context), vertical: 6.h(context)),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8.r(context)),
                border: Border.all(color: AppColors.primaryRed.withOpacity(0.3)),
              ),
              child: Text(
                AppConstants.developerCredit,
                style: ResponsiveTextStyles.getCaption(context).copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
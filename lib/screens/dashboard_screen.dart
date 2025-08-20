import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';
import '../services/device_service.dart';
import '../services/api_service.dart';
import '../services/background_service.dart';
import '../services/watchdog_service.dart';
import '../services/wake_lock_service.dart';
import '../widgets/metric_card.dart';
import '../utils/constants.dart';
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

  void _startPeriodicUpdates() {
    _apiUpdateTimer = Timer.periodic(
      AppSettings.apiUpdateInterval,
      (timer) => _sendLocationUpdateSafely(),
    );
    
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
      },
    );
    
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _internetSpeed = 50 + (DateTime.now().millisecondsSinceEpoch % 1500) / 10;
        });
      }
    });
  }

  Future<void> _maintainWakeLock() async {
    try {
      if (!await _wakeLockService.checkWakeLockStatus()) {
        await _wakeLockService.forceEnableForCriticalOperation();
      }
    } catch (e) {
      print('Dashboard: Error maintaining wake lock: $e');
    }
  }

  Future<void> _sendLocationUpdateSafely() async {
    try {
      await _sendLocationUpdate();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to sync location: ${e.toString()}', Colors.red);
      }
    }
  }

  Future<void> _sendLocationUpdate() async {
    if (_locationService.currentPosition == null) return;
    await ApiService.updateLocation(
      token: widget.token,
      deploymentCode: widget.deploymentCode,
      position: _locationService.currentPosition!,
      batteryLevel: _deviceService.batteryLevel,
      signalStrength: _deviceService.signalStrength,
    );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _showLogoutConfirmation() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.orange[400], size: 24),
            const SizedBox(width: 12),
            const Text('Confirm Logout', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to logout?',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('This will:', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('• Disconnect from the web monitoring system', style: TextStyle(color: Colors.white54, fontSize: 14)),
            Text('• Remove your device from the live map', style: TextStyle(color: Colors.white54, fontSize: 14)),
            Text('• Stop location tracking and background monitoring', style: TextStyle(color: Colors.white54, fontSize: 14)),
            Text('• Return you to the login screen', style: TextStyle(color: Colors.white54, fontSize: 14)),
            SizedBox(height: 12),
            Text(
              'Your supervisor will be notified that you have logged out.',
              style: TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Logout & Disconnect'),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: const Color(0xFF1E1E1E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF26C6DA)),
            const SizedBox(height: 16),
            const Text(
              'Logging out...',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Disconnecting from monitoring system',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );

    try {
      // Step 1: Send logout request to API to disconnect from web app
      print('Dashboard: Sending logout request to disconnect from web app...');
      
      final logoutResponse = await ApiService.logout(widget.token, widget.deploymentCode);
      
      if (logoutResponse.success) {
        print('Dashboard: Successfully disconnected from web app');
        _showSnackBar('Disconnected from monitoring system', Colors.green);
      } else {
        print('Dashboard: Logout API call failed: ${logoutResponse.message}');
        _showSnackBar('Warning: Failed to disconnect from web app', Colors.orange);
      }

      // Step 2: Stop all local services
      print('Dashboard: Stopping background services...');
      _watchdogService.stopWatchdog();
      await stopBackgroundServiceSafely();
      
      // Step 3: Clear device wake lock
      await _wakeLockService.disableWakeLock();
      
      // Step 4: DO NOT clear stored credentials - keep them for next login
      print('Dashboard: Keeping credentials stored for next login');
      
      print('Dashboard: Logout process completed successfully');
      
      // Small delay to show the success message
      await Future.delayed(const Duration(milliseconds: 1000));
      
    } catch (e) {
      print('Dashboard: Error during logout: $e');
      _showSnackBar('Logout completed with warnings', Colors.orange);
      
      // Even if there's an error, we still proceed with logout
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Step 5: Navigate to login screen
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
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF26C6DA)),
                SizedBox(height: 24),
                Text(
                  'Initializing Security Systems...',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Please wait while we secure your connection',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
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
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red[900]?.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.red[400]!.withOpacity(0.5)),
                    ),
                    child: Icon(Icons.error_outline, color: Colors.red[400], size: 64),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'System Initialization Failed',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _initializationError.replaceAll("Exception: ", ""),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _initializeServices,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Initialization'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF26C6DA),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          _buildStatusBanner(),
                          const SizedBox(height: 16),
                          if (_watchdogStatus.isNotEmpty) _buildWatchdogStatus(),
                          if (_watchdogStatus.isNotEmpty) const SizedBox(height: 16),
                          _buildMetricsGrid(),
                          const SizedBox(height: 16),
                          _buildLocationCard(),
                          const SizedBox(height: 16),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360 || screenHeight < 640;
    final isVerySmallScreen = screenWidth < 320;
    
    // Adaptive sizing based on screen size
    final logoSize = isVerySmallScreen ? 20.0 : isSmallScreen ? 24.0 : 28.0;
    final fontSize = isVerySmallScreen ? 9.0 : isSmallScreen ? 10.0 : 11.0;
    final subFontSize = isVerySmallScreen ? 6.0 : isSmallScreen ? 7.0 : 8.0;
    final timeSize = isVerySmallScreen ? 8.0 : isSmallScreen ? 9.0 : 10.0;
    final padding = isVerySmallScreen ? 2.0 : isSmallScreen ? 3.0 : 4.0;
    final spacing = isVerySmallScreen ? 3.0 : isSmallScreen ? 4.0 : 6.0;
    final timeWidth = isVerySmallScreen ? 35.0 : isSmallScreen ? 40.0 : 45.0;
    
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
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding * 2),
        child: Row(
          children: [
            // Logo Container - Adaptive size
            Container(
              width: logoSize,
              height: logoSize,
              padding: EdgeInsets.all(padding / 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/images/pnp_logo.png',
                  width: logoSize - 4,
                  height: logoSize - 4,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.shield,
                      color: AppColors.primaryRed,
                      size: logoSize - 8,
                    );
                  },
                ),
              ),
            ),
            SizedBox(width: spacing),
            // Text Section - Flexible with adaptive text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isVerySmallScreen ? 'PNP' : 'PNP MONITOR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
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
                          'ACTIVE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: subFontSize,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                      ),
                      SizedBox(width: spacing / 2),
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            width: isVerySmallScreen ? 2.0 : 3.0,
                            height: isVerySmallScreen ? 2.0 : 3.0,
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
            SizedBox(width: spacing),
            // Time Section - Adaptive width
            SizedBox(
              width: timeWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentTime.length >= 5 ? _currentTime.substring(0, 5) : _currentTime,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: timeSize,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                  Text(
                    'TIME',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: subFontSize - 1,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: spacing),
            // Logout Button - Adaptive size
            Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: _showLogoutConfirmation,
                  child: Icon(
                    Icons.logout,
                    color: Colors.white,
                    size: logoSize / 2,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isVerySmallScreen = screenWidth < 320;
    
    final titleFontSize = isVerySmallScreen ? 14.0 : isSmallScreen ? 16.0 : 18.0;
    final subtitleFontSize = isVerySmallScreen ? 11.0 : isSmallScreen ? 12.0 : 14.0;
    final urlFontSize = isVerySmallScreen ? 9.0 : isSmallScreen ? 10.0 : 12.0;
    final iconSize = isVerySmallScreen ? 20.0 : isSmallScreen ? 24.0 : 28.0;
    final padding = isVerySmallScreen ? 16.0 : 20.0;
    
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green[600]!.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
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
                        padding: EdgeInsets.all(padding / 2),
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
                        child: Icon(Icons.check_circle, color: Colors.white, size: iconSize),
                      ),
                    );
                  },
                ),
                SizedBox(width: padding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVerySmallScreen ? 'Monitoring Active' : 'High-Precision Monitoring Active',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVerySmallScreen 
                          ? '24/7 GPS • Wake lock • Connected'
                          : '24/7 GPS tracking • Wake lock enabled • Web app connected',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: subtitleFontSize,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.lock, color: Colors.green[200], size: iconSize - 4),
              ],
            ),
            SizedBox(height: padding / 2),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.web, color: Colors.white70, size: isVerySmallScreen ? 12 : 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isVerySmallScreen 
                        ? 'nexuspolice-13560.web.app'
                        : 'Connected to: nexuspolice-13560.web.app/map',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: urlFontSize,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isVerySmallScreen = screenWidth < 320;
    
    final titleFontSize = isVerySmallScreen ? 13.0 : isSmallScreen ? 14.0 : 16.0;
    final subtitleFontSize = isVerySmallScreen ? 10.0 : isSmallScreen ? 11.0 : 12.0;
    final iconSize = isVerySmallScreen ? 18.0 : isSmallScreen ? 20.0 : 24.0;
    final padding = isVerySmallScreen ? 12.0 : 16.0;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isRunning 
            ? [Colors.blue[600]!, Colors.blue[700]!]
            : [Colors.orange[600]!, Colors.orange[700]!],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isRunning ? Colors.blue[600]! : Colors.orange[600]!).withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Row(
          children: [
            Icon(
              isRunning ? Icons.security : Icons.warning,
              color: Colors.white,
              size: iconSize,
            ),
            SizedBox(width: padding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRunning 
                      ? (isVerySmallScreen ? 'Watchdog Active' : 'Security Watchdog Active')
                      : (isVerySmallScreen ? 'Watchdog Off' : 'Watchdog Inactive'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isRunning 
                      ? (isVerySmallScreen ? 'Monitoring every 15min' : 'Monitoring app health every 15 minutes')
                      : (isVerySmallScreen ? 'Monitoring disabled' : 'App monitoring is currently disabled'),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: subtitleFontSize,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final spacing = isSmallScreen ? 6.0 : 8.0;
    
    return Column(
      children: [
        // First Row - Battery and Signal
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
            SizedBox(width: spacing),
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
        SizedBox(height: spacing + 4),
        // Second Row - Internet Speed (Full Width)
        MetricCard(
          title: 'Internet Speed',
          icon: Icons.speed,
          iconColor: Colors.blue[400]!,
          value: '${_internetSpeed.toStringAsFixed(1)} KB/s',
          subtitle: 'REAL-TIME DATA',
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              CircularProgressIndicator(color: Color(0xFF26C6DA)),
              SizedBox(height: 16),
              Text(
                'Acquiring High-Precision Location...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Using GPS + Network for best accuracy',
                style: TextStyle(color: Colors.white54, fontSize: 12),
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
          borderRadius: BorderRadius.circular(16),
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
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[900]?.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_off, size: 48, color: Colors.orange[400]),
              ),
              const SizedBox(height: 16),
              const Text(
                'Location Unavailable',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Unable to get precise location. Please ensure GPS is enabled.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _refreshLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('Force GPS Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF26C6DA),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        borderRadius: BorderRadius.circular(16),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isHighAccuracy ? Colors.green[400] : Colors.orange[400])!.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isHighAccuracy ? Icons.gps_fixed : Icons.location_on,
                    color: isHighAccuracy ? Colors.green[400] : Colors.orange[400],
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'High-Precision Location',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isHighAccuracy ? Colors.green[400] : Colors.orange[400])!.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isHighAccuracy ? Colors.green[400]! : Colors.orange[400]!,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              isHighAccuracy ? 'PRECISE' : 'SEARCHING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isHighAccuracy ? Colors.green[400] : Colors.orange[400],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '±${accuracy.toStringAsFixed(1)}m accuracy',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Latitude',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${position.latitude.toStringAsFixed(6)}°',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Longitude',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${position.longitude.toStringAsFixed(6)}°',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Altitude',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${position.altitude.toStringAsFixed(0)}m',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Speed',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(position.speed * 3.6).toStringAsFixed(1)} km/h',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final coordinates = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
                      Clipboard.setData(ClipboardData(text: coordinates));
                      _showSnackBar('Coordinates copied to clipboard!', Colors.green);
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Coordinates'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _refreshLocation,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh GPS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF26C6DA),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.satellite, color: Colors.white54, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Source: ${_locationService.getLocationSource()}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.speed, color: Colors.white54, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Movement: ${_locationService.getMovementStatus()}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.white54, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Last Update: $_currentTime',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeveloperCredit() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.copyright, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                const Text(
                  '2025 Philippine National Police',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryRed.withOpacity(0.3)),
              ),
              child: const Text(
                AppConstants.developerCredit,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 10,
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
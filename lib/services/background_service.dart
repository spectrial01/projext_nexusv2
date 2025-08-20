import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const notificationChannelId = 'pnp_location_service';
const notificationId = 888;

Future<void> initializeService() async {
  try {
    print('BackgroundService: Starting initialization...');
    
    final service = FlutterBackgroundService();

    // Create notification channel for Android
    await _createNotificationChannel();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'PNP Device Monitor Active',
        initialNotificationContent: 'Monitoring device location and status',
        foregroundServiceNotificationId: notificationId,
        autoStartOnBoot: false,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    
    print('BackgroundService: Initialization completed successfully');
  } catch (e, stackTrace) {
    print('BackgroundService: Initialization failed: $e');
    print('BackgroundService: Stack trace: $stackTrace');
    // Don't rethrow - let the app continue without background service
  }
}

Future<void> _createNotificationChannel() async {
  try {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'PNP Location Service',
      description: 'Keeps the PNP Device Monitor running in background',
      importance: Importance.defaultImportance,
      playSound: false,
      enableVibration: false,
      showBadge: true,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    print('BackgroundService: Notification channel created');
  } catch (e) {
    print('BackgroundService: Error creating notification channel: $e');
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  try {
    DartPluginRegistrant.ensureInitialized();
    
    // Enable wake lock for iOS background
    await _enableWakeLockSafely();
    
    print('BackgroundService: iOS background service started with wake lock');
    return true;
  } catch (e) {
    print('BackgroundService: Error in iOS background: $e');
    return false;
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  try {
    DartPluginRegistrant.ensureInitialized();
    print('BackgroundService: Service started successfully');

    // Enable wake lock to keep device awake
    await _enableWakeLockSafely();

    // Initial notification
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "PNP Device Monitor",
        content: "Service starting with wake lock enabled...",
      );
    }

    // Listen for stop service requests
    service.on('stopService').listen((event) {
      print('BackgroundService: Stop service requested');
      try {
        // Disable wake lock when stopping
        _disableWakeLockSafely();
        service.stopSelf();
        print('BackgroundService: Service stopped and wake lock disabled');
      } catch (e) {
        print('BackgroundService: Error stopping service: $e');
      }
    });

    // Update notification immediately to show it's running
    Timer(const Duration(seconds: 2), () {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "PNP Device Monitor Active",
          content: "📱 Wake lock enabled • 📍 GPS tracking • Background monitoring",
        );
      }
    });

    // Periodic updates every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        final deploymentCode = prefs.getString('deploymentCode');
        
        if (token == null || deploymentCode == null) {
          print('BackgroundService: No credentials found, stopping service');
          timer.cancel();
          await _disableWakeLockSafely();
          service.stopSelf();
          return;
        }

        final now = DateTime.now();
        final timeString = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
        
        // Check wake lock status
        final wakeLockStatus = await _checkWakeLockStatus();
        
        // Get current location
        final position = await _getCurrentLocationSafe();
        
        if (position != null) {
          // Update notification with current time, location, and wake lock status
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: "PNP Device Monitor Active",
              content: "🔒 Wake: ${wakeLockStatus ? 'ON' : 'OFF'} • 📍 ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)} • $timeString",
            );
          }
          
          print('BackgroundService: Location update - ${position.latitude}, ${position.longitude}, Wake Lock: $wakeLockStatus');
          
          // Here you can send location to your API
          await _sendLocationToAPI(token, deploymentCode, position);
        } else {
          // Update notification even if location is not available
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: "PNP Device Monitor Active",
              content: "🔒 Wake: ${wakeLockStatus ? 'ON' : 'OFF'} • 📍 Location: Searching... • $timeString",
            );
          }
        }
        
        // Ensure wake lock stays enabled during monitoring
        if (!wakeLockStatus) {
          print('BackgroundService: Wake lock disabled, re-enabling...');
          await _enableWakeLockSafely();
        }
        
      } catch (e) {
        print('BackgroundService: Error in periodic task: $e');
        // Update notification with error status
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "PNP Device Monitor Active",
            content: "🔒 Wake lock enabled • Service running with limited functionality",
          );
        }
      }
    });
    
  } catch (e, stackTrace) {
    print('BackgroundService: Error in onStart: $e');
    print('BackgroundService: Stack trace: $stackTrace');
  }
}

// Safe wake lock enable function
Future<void> _enableWakeLockSafely() async {
  try {
    await WakelockPlus.enable();
    print('BackgroundService: Wake lock enabled successfully');
  } catch (e) {
    print('BackgroundService: Error enabling wake lock: $e');
  }
}

// Safe wake lock disable function
Future<void> _disableWakeLockSafely() async {
  try {
    await WakelockPlus.disable();
    print('BackgroundService: Wake lock disabled successfully');
  } catch (e) {
    print('BackgroundService: Error disabling wake lock: $e');
  }
}

// Check wake lock status
Future<bool> _checkWakeLockStatus() async {
  try {
    return await WakelockPlus.enabled;
  } catch (e) {
    print('BackgroundService: Error checking wake lock status: $e');
    return false;
  }
}

Future<Position?> _getCurrentLocationSafe() async {
  try {
    // Check permissions first
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      print('BackgroundService: Location permission denied');
      return null;
    }

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('BackgroundService: Location services disabled');
      return null;
    }

    // Get current position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 15),
    );
    
    return position;
  } catch (e) {
    print('BackgroundService: Error getting location: $e');
    return null;
  }
}

Future<void> _sendLocationToAPI(String token, String deploymentCode, Position position) async {
  try {
    // Here you can add your API call
    // This is just a placeholder - replace with your actual API service
    print('BackgroundService: Would send location to API: ${position.latitude}, ${position.longitude}');
    
    // Example:
    // await ApiService.updateLocation(
    //   token: token,
    //   deploymentCode: deploymentCode,
    //   position: position,
    //   batteryLevel: 80, // You'd get this from device service
    //   signalStrength: 'good',
    // );
    
  } catch (e) {
    print('BackgroundService: Error sending location to API: $e');
  }
}

// Helper function to start service safely
Future<bool> startBackgroundServiceSafely() async {
  try {
    print('BackgroundService: Attempting to start service...');
    
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    
    if (isRunning) {
      print('BackgroundService: Service already running');
      return true;
    }
    
    // Enable wake lock before starting service
    await _enableWakeLockSafely();
    
    final started = await service.startService();
    print('BackgroundService: Service start result: $started');
    
    // Give it a moment to start properly
    await Future.delayed(const Duration(seconds: 1));
    
    return started;
  } catch (e) {
    print('BackgroundService: Error starting service: $e');
    return false;
  }
}

// Helper function to stop service safely
Future<bool> stopBackgroundServiceSafely() async {
  try {
    print('BackgroundService: Attempting to stop service...');
    
    // Disable wake lock before stopping service
    await _disableWakeLockSafely();
    
    final service = FlutterBackgroundService();
    service.invoke("stopService");
    
    // Wait a bit for the service to stop
    await Future.delayed(const Duration(milliseconds: 1000));
    
    print('BackgroundService: Stop request sent and wake lock disabled');
    return true;
  } catch (e) {
    print('BackgroundService: Error stopping service: $e');
    return false;
  }
}
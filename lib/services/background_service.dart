import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'wake_lock_service.dart';

const notificationChannelId = 'pnp_location_service';
const notificationId = 888;

final _wakeLockService = WakeLockService();

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
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
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

Future<void> _createNotificationChannel() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId,
    'PNP Location Service',
    description: 'Keeps the PNP Device Monitor running in the background',
    importance: Importance.defaultImportance,
    playSound: false,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  try {
    await _enableWakeLockWithRetry();
    print('BackgroundService: iOS background service started with wake lock');
    return true;
  } catch (e) {
    print('BackgroundService: Error in iOS background: $e');
    // FIX: Added a return statement to the catch block.
    return false;
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();
  print('BackgroundService: Service instance started.');

  _enableWakeLockWithRetry();

  service.on('stopService').listen((event) {
    _disableWakeLockWithRetry();
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 30), (timer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final deploymentCode = prefs.getString('deploymentCode');

      if (token == null || deploymentCode == null) {
        timer.cancel();
        service.stopSelf();
        return;
      }

      final position = await _getCurrentLocationSafe();
      if (position != null) {
        await _sendLocationToAPI(token, deploymentCode, position);
      }

      final wakeLockStatus = await _wakeLockService.checkWakeLockStatus();
      if (!wakeLockStatus) {
        print('BackgroundService: Wake lock was disabled, re-enabling...');
        await _enableWakeLockWithRetry();
      }

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "PNP Device Monitor Active",
          content: "Monitoring location. Last check: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
        );
      }
    } catch (e) {
      print('BackgroundService: Error in periodic task: $e');
    }
  });
}

Future<void> _enableWakeLockWithRetry({int retries = 3}) async {
  for (int i = 0; i < retries; i++) {
    try {
      await _wakeLockService.enableWakeLock();
      print('BackgroundService: Wake lock enabled successfully');
      return;
    } catch (e) {
      print('BackgroundService: Error enabling wake lock (attempt ${i + 1}): $e');
      if (i < retries - 1) {
        await Future.delayed(const Duration(seconds: 2));
      } else {
        print('BackgroundService: Failed to enable wake lock after $retries attempts.');
      }
    }
  }
}

Future<void> _disableWakeLockWithRetry({int retries = 3}) async {
  for (int i = 0; i < retries; i++) {
    try {
      await _wakeLockService.disableWakeLock();
      print('BackgroundService: Wake lock disabled successfully');
      return;
    } catch (e) {
      print('BackgroundService: Error disabling wake lock (attempt ${i + 1}): $e');
      if (i < retries - 1) {
        await Future.delayed(const Duration(seconds: 2));
      } else {
        print('BackgroundService: Failed to disable wake lock after $retries attempts.');
      }
    }
  }
}

Future<Position?> _getCurrentLocationSafe() async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('BackgroundService: Location services disabled.');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      print('BackgroundService: Location permission denied.');
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 15),
    );
  } catch (e) {
    print('BackgroundService: Error getting location: $e');
    return null;
  }
}

Future<void> _sendLocationToAPI(String token, String deploymentCode, Position position) async {
  print('BackgroundService: Sending location to API: ${position.latitude}, ${position.longitude}');
  // This is where your http.post call would go.
}

Future<bool> startBackgroundServiceSafely() async {
  try {
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (isRunning) {
      print('BackgroundService: Service is already running.');
      return true;
    }
    await _enableWakeLockWithRetry();
    return await service.startService();
  } catch (e) {
    print('BackgroundService: Error starting service: $e');
    return false;
  }
}

Future<bool> stopBackgroundServiceSafely() async {
  try {
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke("stopService");
      print('BackgroundService: Stop request sent.');
    }
    await _disableWakeLockWithRetry();
    return true;
  } catch (e) {
    print('BackgroundService: Error stopping service: $e');
    return false;
  }
}
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // Check all required permissions
  Future<Map<String, bool>> checkAllPermissions() async {
    final permissions = {
      'location': await Permission.location.status,
      'camera': await Permission.camera.status,
      'notification': await Permission.notification.status,
      'ignoreBatteryOptimizations': await Permission.ignoreBatteryOptimizations.status,
    };

    return {
      'location': permissions['location']!.isGranted,
      'camera': permissions['camera']!.isGranted,
      'notification': permissions['notification']!.isGranted,
      'ignoreBatteryOptimizations': permissions['ignoreBatteryOptimizations']!.isGranted,
    };
  }

  // Request all permissions
  Future<Map<String, bool>> requestAllPermissions() async {
    print('PermissionService: Requesting all permissions...');
    
    final results = await [
      Permission.location,
      Permission.camera,
      Permission.notification,
      Permission.ignoreBatteryOptimizations,
    ].request();

    return {
      'location': results[Permission.location]?.isGranted ?? false,
      'camera': results[Permission.camera]?.isGranted ?? false,
      'notification': results[Permission.notification]?.isGranted ?? false,
      'ignoreBatteryOptimizations': results[Permission.ignoreBatteryOptimizations]?.isGranted ?? false,
    };
  }

  // Request specific permission
  Future<bool> requestPermission(Permission permission) async {
    final status = await permission.request();
    return status.isGranted;
  }

  // Check if all critical permissions are granted
  Future<bool> hasAllCriticalPermissions() async {
    final permissions = await checkAllPermissions();
    // Battery optimization is now considered critical for this app to run 24/7
    return permissions['location']! && permissions['notification']! && permissions['ignoreBatteryOptimizations']!;
  }

  // Show permission rationale dialog
  Future<void> showPermissionRationale(BuildContext context, String permissionType) async {
    String title = '';
    String content = '';
    
    switch (permissionType) {
      case 'location':
        title = 'Location Permission Required';
        content = 'This app needs location access to track your position for security purposes.';
        break;
      case 'camera':
        title = 'Camera Permission Required';
        content = 'Camera access is needed to scan QR codes and capture evidence when required.';
        break;
      case 'notification':
        title = 'Notification Permission Required';
        content = 'Notifications are essential to show that the app is running in background and for important alerts.';
        break;
      case 'ignoreBatteryOptimizations':
        title = 'Disable Battery Optimization';
        content = 'For 24/7 monitoring, this app must be exempt from battery optimization. Please allow this permission when prompted.';
        break;
    }

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // Get permission status text
  String getPermissionStatusText(bool isGranted) {
    return isGranted ? 'GRANTED' : 'DENIED';
  }

  // Get permission status color
  Color getPermissionStatusColor(bool isGranted) {
    return isGranted ? Colors.green : Colors.red;
  }

  // Get permission icon
  IconData getPermissionIcon(bool isGranted) {
    return isGranted ? Icons.check_circle : Icons.error;
  }
}
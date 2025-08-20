import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<Map<String, bool>> checkAllPermissions() async {
    final statuses = await [
      Permission.location,
      Permission.camera,
      Permission.notification,
      Permission.ignoreBatteryOptimizations,
    ].request();

    return {
      'location': statuses[Permission.location]?.isGranted ?? false,
      'camera': statuses[Permission.camera]?.isGranted ?? false,
      'notification': statuses[Permission.notification]?.isGranted ?? false,
      'ignoreBatteryOptimizations': statuses[Permission.ignoreBatteryOptimizations]?.isGranted ?? false,
    };
  }

  Future<void> requestAllPermissions() async {
    await [
      Permission.location,
      Permission.camera,
      Permission.notification,
      Permission.ignoreBatteryOptimizations,
    ].request();
  }

  Future<bool> requestPermission(Permission permission) async {
    final status = await permission.request();
    return status.isGranted;
  }
}
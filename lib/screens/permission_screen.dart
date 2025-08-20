import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/permission_status_widget.dart';
import '../services/permission_service.dart';
import '../utils/constants.dart';
import 'login_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final _permissionService = PermissionService();
  
  Map<String, bool> _permissions = {
    'location': false,
    'camera': false,
    'notification': false,
    'ignoreBatteryOptimizations': false,
  };
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAllPermissions();
  }

  Future<void> _checkAllPermissions() async {
    setState(() => _isLoading = true);
    
    try {
      final permissions = await _permissionService.checkAllPermissions();
      if (mounted) {
        setState(() {
          _permissions = permissions;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('PermissionScreen: Error checking permissions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isLoading = true);
    
    try {
      // Request standard permissions first
      await _requestSpecificPermission('location');
      await _requestSpecificPermission('camera');
      await _requestSpecificPermission('notification');
      
      // Then request battery optimization
      await _requestSpecificPermission('ignoreBatteryOptimizations');

      // Final check
      await _checkAllPermissions();

    } catch (e) {
      print('PermissionScreen: Error requesting permissions: $e');
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestSpecificPermission(String permissionType) async {
    Permission permission;
    switch (permissionType) {
      case 'location':
        permission = Permission.location;
        break;
      case 'camera':
        permission = Permission.camera;
        break;
      case 'notification':
        permission = Permission.notification;
        break;
      case 'ignoreBatteryOptimizations':
        permission = Permission.ignoreBatteryOptimizations;
        break;
      default:
        return;
    }

    try {
      final status = await permission.request();
      if (mounted) {
        setState(() {
          _permissions[permissionType] = status.isGranted;
        });
        
        if (status.isPermanentlyDenied) {
          await _permissionService.showPermissionRationale(context, permissionType);
        }
      }
    } catch (e) {
      print('PermissionScreen: Error requesting $permissionType permission: $e');
    }
  }

  bool get _canProceed => _permissions['location']! && _permissions['notification']! && _permissions['ignoreBatteryOptimizations']!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Permissions'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkAllPermissions,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Critical Permissions Required',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please grant the following permissions for full functionality.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Battery Optimization
                  PermissionStatusWidget(
                    status: _permissions['ignoreBatteryOptimizations']! ? PermissionStatus.granted : PermissionStatus.denied,
                    title: 'Battery Optimization',
                    description: 'CRITICAL: Required for 24/7 background monitoring. Please select "Allow".',
                    onRequest: () => _requestSpecificPermission('ignoreBatteryOptimizations'),
                  ),
                  const SizedBox(height: 16),

                  // Location Permission
                  PermissionStatusWidget(
                    status: _permissions['location']! ? PermissionStatus.granted : PermissionStatus.denied,
                    title: 'Location Permission',
                    description: 'CRITICAL: Required for GPS tracking and position monitoring.',
                    onRequest: () => _requestSpecificPermission('location'),
                  ),
                  const SizedBox(height: 16),

                  // Notification Permission
                  PermissionStatusWidget(
                    status: _permissions['notification']! ? PermissionStatus.granted : PermissionStatus.denied,
                    title: 'Notification Permission',
                    description: 'CRITICAL: Essential for background service alerts.',
                    onRequest: () => _requestSpecificPermission('notification'),
                  ),
                  const SizedBox(height: 16),
                  
                  // Camera Permission  
                  PermissionStatusWidget(
                    status: _permissions['camera']! ? PermissionStatus.granted : PermissionStatus.denied,
                    title: 'Camera Permission',
                    description: 'OPTIONAL: Used for QR code scanning for easier login.',
                    onRequest: () => _requestSpecificPermission('camera'),
                  ),
                  const SizedBox(height: 32),

                  // Grant All Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _requestAllPermissions,
                      icon: _isLoading 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.security),
                      label: Text(
                        _isLoading ? 'Requesting...' : 'Request All Permissions',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _canProceed
                          ? () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              )
                          : null,
                      icon: Icon(
                        _canProceed ? Icons.login : Icons.lock,
                      ),
                      label: Text(
                        _canProceed
                            ? 'Continue to Login'
                            : 'Critical Permissions Required',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canProceed
                            ? AppColors.tealAccent
                            : Colors.grey[700],
                        foregroundColor: _canProceed
                            ? Colors.black
                            : Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
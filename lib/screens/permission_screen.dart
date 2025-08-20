import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/permission_service.dart';
import 'login_screen.dart';

class PermissionStep {
  final String title;
  final String description;
  final IconData icon;
  final Permission permission;
  final bool isCritical;

  PermissionStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.permission,
    this.isCritical = true,
  });
}

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> with TickerProviderStateMixin {
  final _permissionService = PermissionService();
  int _currentStep = 0;
  bool _isLoading = false;

  late final List<PermissionStep> _permissionSteps;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _progressController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializePermissionSteps();
    _checkCurrentPermissionStatus();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _slideController.forward();
    _updateProgress();
  }

  void _initializePermissionSteps() {
    _permissionSteps = [
      PermissionStep(
        title: 'Battery Optimization',
        description: 'Essential for 24/7 monitoring. This allows the app to run continuously in the background without being killed by the system.',
        icon: Icons.battery_charging_full,
        permission: Permission.ignoreBatteryOptimizations,
      ),
      PermissionStep(
        title: 'Location Access',
        description: 'Required for real-time GPS tracking and position monitoring. This is the core functionality of the app.',
        icon: Icons.location_on,
        permission: Permission.location,
      ),
      PermissionStep(
        title: 'Notifications',
        description: 'Critical for background service alerts and system notifications. Keeps you informed of the app status.',
        icon: Icons.notifications,
        permission: Permission.notification,
      ),
      PermissionStep(
        title: 'Camera Access',
        description: 'Optional: Used for QR code scanning to make login easier and faster.',
        icon: Icons.camera_alt,
        permission: Permission.camera,
        isCritical: false,
      ),
    ];
  }

  void _updateProgress() {
    final progress = (_currentStep + 1) / _permissionSteps.length;
    _progressController.animateTo(progress);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentPermissionStatus() async {
    if (_currentStep >= _permissionSteps.length) {
      _navigateToLogin();
      return;
    }
    final status = await _permissionSteps[_currentStep].permission.status;
    if (status.isGranted) {
      _moveToNextStep();
    }
  }

  void _moveToNextStep() {
    setState(() {
      _currentStep++;
    });
    _updateProgress();
    if (_currentStep < _permissionSteps.length) {
      _slideController.reset();
      _slideController.forward();
    }
    _checkCurrentPermissionStatus();
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _grantCurrentPermission() async {
    setState(() => _isLoading = true);
    try {
      final permission = _permissionSteps[_currentStep].permission;
      final isGranted = await _permissionService.requestPermission(permission);

      if (!isGranted && await permission.isPermanentlyDenied) {
        _showPermissionRationale(_permissionSteps[_currentStep].title);
      } else {
        _moveToNextStep();
      }
    } catch (e) {
      print('PermissionScreen: Error requesting permission: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPermissionRationale(String permissionTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            Icon(Icons.settings, color: Colors.orange[400], size: 24),
            const SizedBox(width: 12),
            Text('$permissionTitle Required', style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This permission has been permanently denied.',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Please go to your device settings to enable it manually:',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 8),
            Text('1. Open device Settings', style: TextStyle(color: Colors.white54)),
            Text('2. Find this app', style: TextStyle(color: Colors.white54)),
            Text('3. Enable the required permission', style: TextStyle(color: Colors.white54)),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Skip', style: TextStyle(color: Colors.white70)),
            onPressed: () {
              Navigator.of(context).pop();
              _moveToNextStep();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Open Settings'),
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep >= _permissionSteps.length) {
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
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF26C6DA)),
                SizedBox(height: 24),
                Text(
                  'All Set! Preparing Login...',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Your permissions have been configured successfully',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentStepInfo = _permissionSteps[_currentStep];

    return Scaffold(
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
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          _buildPermissionIcon(currentStepInfo),
                          const SizedBox(height: 32),
                          _buildPermissionInfo(currentStepInfo),
                          const SizedBox(height: 40),
                          _buildActionButton(currentStepInfo),
                          const SizedBox(height: 24),
                          if (!currentStepInfo.isCritical) _buildSkipButton(),
                          const Spacer(),
                          _buildProgressIndicator(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1E1E),
            const Color(0xFF2A2A2A),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF26C6DA).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.security, color: Color(0xFF26C6DA), size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security Setup',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Configure essential permissions',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF26C6DA).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF26C6DA)),
            ),
            child: Text(
              '${_currentStep + 1}/${_permissionSteps.length}',
              style: const TextStyle(
                color: Color(0xFF26C6DA),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionIcon(PermissionStep step) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF26C6DA).withOpacity(0.2),
            const Color(0xFF26C6DA).withOpacity(0.1),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF26C6DA), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF26C6DA).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(
        step.icon,
        size: 60,
        color: const Color(0xFF26C6DA),
      ),
    );
  }

  Widget _buildPermissionInfo(PermissionStep step) {
    return Column(
      children: [
        Text(
          step.title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        if (!step.isCritical) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange),
            ),
            child: const Text(
              'OPTIONAL',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red),
            ),
            child: const Text(
              'REQUIRED',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Text(
            step.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(PermissionStep step) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF26C6DA).withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _grantCurrentPermission,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF26C6DA),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isLoading
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  'Processing...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 24),
                const SizedBox(width: 12),
                Text(
                  step.isCritical ? 'Grant Permission' : 'Grant Optional Permission',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return Container(
      width: double.infinity,
      child: TextButton(
        onPressed: _moveToNextStep,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white54,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.skip_next, size: 20),
            SizedBox(width: 8),
            Text(
              'Skip for now',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Setup Progress',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${_currentStep + 1} of ${_permissionSteps.length}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progressAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF26C6DA), Color(0xFF00BCD4)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF26C6DA).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_permissionSteps.length, (index) {
            final isCompleted = index < _currentStep;
            final isCurrent = index == _currentStep;
            
            return Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted 
                  ? const Color(0xFF26C6DA)
                  : isCurrent 
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
                border: isCurrent ? Border.all(color: const Color(0xFF26C6DA), width: 2) : null,
                boxShadow: isCompleted || isCurrent ? [
                  BoxShadow(
                    color: (isCompleted ? const Color(0xFF26C6DA) : Colors.white).withOpacity(0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ] : null,
              ),
            );
          }),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/permission_screen.dart';
import 'services/permission_service.dart';
import 'services/background_service.dart';
import 'services/wake_lock_service.dart';
import 'utils/constants.dart';

void main() async {
  // Ensure Flutter bindings are initialized before any async operations.
  WidgetsFlutterBinding.ensureInitialized();

  bool servicesInitialized = false;
  try {
    // Initialize critical services that must run before the app starts.
    await initializeService();
    await WakeLockService().initialize();
    servicesInitialized = true;
    print("main: All essential services initialized successfully.");
  } catch (e) {
    print("main: CRITICAL ERROR - Failed to initialize background services: $e");
    // If services fail, the app will show an error screen.
  }

  // Only run the main app if initialization was successful.
  if (servicesInitialized) {
    runApp(const MyApp());
  } else {
    runApp(const InitializationErrorApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PNP Device Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.primaryRed,
        scaffoldBackgroundColor: AppColors.darkBackground,
        cardColor: AppColors.cardBackground,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primaryRed,
          secondary: AppColors.tealAccent,
          surface: AppColors.surfaceColor,
          background: AppColors.darkBackground,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.primaryText),
          bodyMedium: TextStyle(color: AppColors.secondaryText),
          titleLarge: TextStyle(color: AppColors.primaryText),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.cardBackground,
          elevation: 0,
          titleTextStyle: AppTextStyles.h4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: AppBorders.small,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSettings.defaultPadding,
              vertical: 12,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardBackground,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: AppBorders.mediumRadius,
          ),
        ),
      ),
      home: const AuthCheck(),
    );
  }
}

// A simple, clean widget to display if core services fail to start.
class InitializationErrorApp extends StatelessWidget {
  const InitializationErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppColors.primaryGradient,
            ),
          ),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppColors.errorColor,
                    size: 64,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Critical System Error',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'A critical error occurred while starting the application. Please close and restart the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'If this problem persists, contact your system administrator.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white54,
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
}

// This widget checks for permissions and authentication status to direct the user to the correct screen.
class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  final _permissionService = PermissionService();
  late Future<Widget> _initialScreenFuture;

  @override
  void initState() {
    super.initState();
    _initialScreenFuture = _determineInitialScreen();
  }

  Future<Widget> _determineInitialScreen() async {
    try {
      print("AuthCheck: Starting initial screen determination...");
      
      // First check critical permissions
      final criticalPermissionsGranted = await _checkCriticalPermissions();
      if (!criticalPermissionsGranted) {
        print("AuthCheck: Critical permissions not granted. Navigating to PermissionScreen.");
        return const PermissionScreen();
      }

      // Check for stored credentials
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final deploymentCode = prefs.getString('deploymentCode');

      print("AuthCheck: Checking stored credentials...");
      print("AuthCheck: Token exists: ${token != null}");
      print("AuthCheck: Deployment code exists: ${deploymentCode != null}");

      if (token != null && token.isNotEmpty && deploymentCode != null && deploymentCode.isNotEmpty) {
        print("AuthCheck: Valid credentials found. Navigating to DashboardScreen.");
        print("AuthCheck: Token preview: ${token.substring(0, math.min(10, token.length))}...");
        
        // Validate that the credentials are actually usable
        if (_validateCredentials(token, deploymentCode)) {
          return DashboardScreen(token: token, deploymentCode: deploymentCode);
        } else {
          print("AuthCheck: Stored credentials are invalid. Clearing and going to login.");
          await _clearInvalidCredentials(prefs);
          return const LoginScreen();
        }
      } else {
        print("AuthCheck: No valid stored credentials found. Navigating to LoginScreen.");
        return const LoginScreen();
      }
    } catch (e) {
      print("AuthCheck: Error determining initial screen: $e");
      // Fallback to login screen in case of an unexpected error
      return const LoginScreen();
    }
  }

  bool _validateCredentials(String token, String deploymentCode) {
    // Basic validation - ensure they're not empty and have reasonable length
    if (token.length < 10 || deploymentCode.length < 3) {
      return false;
    }
    
    // You can add more sophisticated validation here
    // For example, check token format, expiration, etc.
    
    return true;
  }

  Future<void> _clearInvalidCredentials(SharedPreferences prefs) async {
    try {
      await prefs.remove('token');
      await prefs.remove('deploymentCode');
      print("AuthCheck: Invalid credentials cleared.");
    } catch (e) {
      print("AuthCheck: Error clearing invalid credentials: $e");
    }
  }

  Future<bool> _checkCriticalPermissions() async {
    try {
      final permissions = await _permissionService.checkAllPermissions();
      final allGranted = (permissions['location'] ?? false) &&
                         (permissions['notification'] ?? false) &&
                         (permissions['ignoreBatteryOptimizations'] ?? false);
      print("AuthCheck: Critical permission status - allGranted: $allGranted");
      print("AuthCheck: Location: ${permissions['location']}");
      print("AuthCheck: Notification: ${permissions['notification']}");
      print("AuthCheck: Battery Optimization: ${permissions['ignoreBatteryOptimizations']}");
      return allGranted;
    } catch (e) {
      print("AuthCheck: Error checking critical permissions: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.darkBackground,
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.primaryGradient,
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.tealAccent),
                    SizedBox(height: 24),
                    Text(
                      'Initializing Security Systems...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Checking credentials and permissions...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          print("AuthCheck: FutureBuilder error: ${snapshot.error}");
          return const LoginScreen(); // Fallback on error
        }

        return snapshot.data ?? const LoginScreen(); // Default to LoginScreen if data is null
      },
    );
  }
}
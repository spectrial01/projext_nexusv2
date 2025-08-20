import 'package:flutter/material.dart';

class AppConstants {
  static const String baseUrl = 'https://asia-southeast1-nexuspolice-13560.cloudfunctions.net/';
  static const String appTitle = 'Philippine National Police';
  static const String appMotto = 'SERVICE • HONOR • JUSTICE';
  static const String developerCredit = 'DEVELOPED BY RCC4A AND RICTMD4A';
  
  // Version info
  static const String appVersion = '2.0.0';
  static const String buildNumber = '1';
}

class AppColors {
  // Primary Colors
  static const Color primaryRed = Color(0xFFD32F2F);
  static const Color primaryGreen = Color(0xFF388E3C);
  static const Color tealAccent = Color(0xFF26C6DA);
  
  // Background Colors
  static const Color darkBackground = Color(0xFF0A0A0A);
  static const Color cardBackground = Color(0xFF1E1E1E);
  static const Color surfaceColor = Color(0xFF2A2A2A);
  
  // Gradient Colors
  static const List<Color> primaryGradient = [
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
    Color(0xFF0F3460),
  ];
  
  static const List<Color> cardGradient = [
    Color(0xFF1E1E1E),
    Color(0xFF2A2A2A),
  ];
  
  // Status Colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);
  
  // Text Colors
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFB0B0B0);
  static const Color hintText = Color(0xFF757575);
  
  // Accent Colors
  static const Color accentBlue = Color(0xFF1976D2);
  static const Color accentOrange = Color(0xFFFF6F00);
  static const Color accentPurple = Color(0xFF7B1FA2);
  
  // Border Colors
  static const Color borderLight = Color(0x33FFFFFF);
  static const Color borderMedium = Color(0x66FFFFFF);
  static const Color borderDark = Color(0x1AFFFFFF);
}

class AppTextStyles {
  // Headers
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
    letterSpacing: 0.5,
  );
  
  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
    letterSpacing: 0.5,
  );
  
  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    letterSpacing: 0.3,
  );
  
  static const TextStyle h4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    letterSpacing: 0.3,
  );
  
  // Body Text
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.primaryText,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.secondaryText,
    height: 1.4,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.hintText,
    height: 1.3,
  );
  
  // Special Text
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.hintText,
    letterSpacing: 1.0,
  );
  
  static const TextStyle monospace = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontFamily: 'monospace',
    color: AppColors.primaryText,
  );
  
  // Status Text
  static const TextStyle success = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.successColor,
  );
  
  static const TextStyle warning = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.warningColor,
  );
  
  static const TextStyle error = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.errorColor,
  );
}

class AppShadows {
  static List<BoxShadow> get soft => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 8,
      spreadRadius: 1,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 12,
      spreadRadius: 2,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get strong => [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 16,
      spreadRadius: 3,
      offset: const Offset(0, 6),
    ),
  ];
  
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.3),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];
}

class AppBorders {
  static BorderRadius get small => BorderRadius.circular(8);
  static BorderRadius get mediumRadius => BorderRadius.circular(12);
  static BorderRadius get large => BorderRadius.circular(16);
  static BorderRadius get circular => BorderRadius.circular(50);
  
  static Border get light => Border.all(color: AppColors.borderLight);
  static Border get mediumBorder => Border.all(color: AppColors.borderMedium);
  static Border get dark => Border.all(color: AppColors.borderDark);
}

class AppSettings {
  // Timing
  static const Duration locationTimeout = Duration(seconds: 15);
  static const Duration apiUpdateInterval = Duration(seconds: 5);
  static const Duration batteryUpdateInterval = Duration(seconds: 30);
  static const Duration networkUpdateInterval = Duration(seconds: 10);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 800);
  
  // Measurements
  static const int distanceFilter = 5;
  static const double defaultPadding = 16.0;
  static const double largePadding = 24.0;
  static const double smallPadding = 8.0;
  
  // Constraints
  static const double maxContentWidth = 600;
  static const double minButtonHeight = 48;
  static const double maxButtonHeight = 56;
  
  // Location Settings
  static const double highAccuracyThreshold = 10.0; // meters
  static const double mediumAccuracyThreshold = 30.0; // meters
  static const double movementThreshold = 0.5; // m/s
  
  // Network Settings
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration connectionTimeout = Duration(seconds: 30);
}

class AppIcons {
  // Status Icons
  static const IconData batteryFull = Icons.battery_full;
  static const IconData batteryCharging = Icons.battery_charging_full;
  static const IconData batteryLow = Icons.battery_1_bar;
  static const IconData signalStrong = Icons.signal_cellular_4_bar;
  static const IconData signalWeak = Icons.signal_cellular_alt;
  static const IconData signalPoor = Icons.signal_cellular_connected_no_internet_0_bar;
  
  // Location Icons
  static const IconData locationHigh = Icons.gps_fixed;
  static const IconData locationMedium = Icons.location_on;
  static const IconData locationOff = Icons.location_off;
  static const IconData locationSearching = Icons.location_searching;
  
  // Security Icons
  static const IconData shield = Icons.shield;
  static const IconData security = Icons.security;
  static const IconData lock = Icons.lock;
  static const IconData unlock = Icons.lock_open;
  
  // Action Icons
  static const IconData refresh = Icons.refresh;
  static const IconData copy = Icons.copy;
  static const IconData scan = Icons.qr_code_scanner;
  static const IconData upload = Icons.file_upload;
  static const IconData settings = Icons.settings;
  static const IconData logout = Icons.logout;
}

class AppMessages {
  // Success Messages
  static const String loginSuccess = 'Login successful! Welcome back.';
  static const String locationRefreshed = 'Location refreshed successfully';
  static const String coordinatesCopied = 'Coordinates copied to clipboard';
  static const String qrCodeScanned = 'QR Code scanned successfully';
  
  // Error Messages
  static const String loginFailed = 'Login failed. Please check your credentials.';
  static const String locationFailed = 'Failed to get location. Please check GPS.';
  static const String networkError = 'Network error. Please check your connection.';
  static const String permissionDenied = 'Permission denied. Please enable in settings.';
  
  // Info Messages
  static const String locationChecking = 'Checking location access...';
  static const String authenticating = 'Authenticating credentials...';
  static const String initializing = 'Initializing security systems...';
  static const String backgroundServiceActive = 'Background monitoring is active';
}

// Extension methods for enhanced functionality
extension ColorExtensions on Color {
  Color lighten([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }

  Color darken([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

extension TextStyleExtensions on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);
  
  TextStyle colored(Color color) => copyWith(color: color);
  TextStyle sized(double size) => copyWith(fontSize: size);
}
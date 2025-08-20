import 'package:flutter/material.dart';

class AppConstants {
  static const String baseUrl = 'https://asia-southeast1-nexuspolice-13560.cloudfunctions.net/';
  static const String appTitle = 'Philippine National Police';
  static const String appMotto = 'SERVICE • HONOR • JUSTICE';
  static const String developerCredit = 'DEVELOPED BY RCC4A AND RICTMD4A';
}

class AppColors {
  static const primaryRed = Color(0xFFD32F2F);
  static const primaryGreen = Color(0xFF388E3C);
  static const darkBackground = Color(0xFF1a1a2e);
  static const cardBackground = Color(0xFF16213e);
  static const tealAccent = Color(0xFF26C6DA);
}

class AppSettings {
  static const Duration locationTimeout = Duration(seconds: 15);
  static const Duration apiUpdateInterval = Duration(seconds: 5);
  static const Duration batteryUpdateInterval = Duration(seconds: 30);
  static const Duration networkUpdateInterval = Duration(seconds: 10);
  static const int distanceFilter = 5; // int, not double
}
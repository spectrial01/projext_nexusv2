// services/api_service.dart - FIXED VERSION (No dummy coordinates)
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/constants.dart';

class ApiService {
  // OFFICIAL API BASE URL from documentation
  static const String _baseUrl = 'https://asia-southeast1-nexuspolice-13560.cloudfunctions.net/';
  
  // STABILITY TRACKING
  static bool _isLoggedIn = false;
  static DateTime? _lastSuccessfulUpdate;
  static int _consecutiveFailures = 0;
  static String? _lastDeploymentCode;

  static Future<ApiResponse> login(String token, String deploymentCode) async {
    final url = Uri.parse('${_baseUrl}setUnit');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    
    final body = json.encode({
      'deploymentCode': deploymentCode,
      'action': 'login',
    });

    try {
      print('ApiService: 🔐 Logging in...');
      print('ApiService: Deployment Code: $deploymentCode');
      
      final response = await http.post(
        url, 
        headers: headers, 
        body: body,
      ).timeout(const Duration(seconds: 10));
      
      print('ApiService: Login response status: ${response.statusCode}');
      print('ApiService: Login response: ${response.body}');
      
      if (response.statusCode == 200) {
        _isLoggedIn = true;
        _lastDeploymentCode = deploymentCode;
        _consecutiveFailures = 0;
        print('ApiService: ✅ LOGIN SUCCESS - Unit is now logged in');
      } else {
        _isLoggedIn = false;
        print('ApiService: ❌ LOGIN FAILED - Status: ${response.statusCode}');
      }
      
      return ApiResponse.fromResponse(response);
    } catch (e) {
      print('ApiService: ❌ Login error: $e');
      _isLoggedIn = false;
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  static Future<ApiResponse> logout(String token, String deploymentCode) async {
    final url = Uri.parse('${_baseUrl}setUnit');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    
    final body = json.encode({
      'deploymentCode': deploymentCode,
      'action': 'logout',
    });

    try {
      print('ApiService: 🚪 Logging out...');
      final response = await http.post(
        url, 
        headers: headers, 
        body: body,
      ).timeout(const Duration(seconds: 10));
      
      print('ApiService: Logout response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        _isLoggedIn = false;
        _lastDeploymentCode = null;
        print('ApiService: ✅ LOGOUT SUCCESS');
      }
      
      return ApiResponse.fromResponse(response);
    } catch (e) {
      print('ApiService: Logout error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  // FIXED UPDATE METHOD - Only real coordinates, no dummy data
  static Future<ApiResponse> updateLocation({
    required String token,
    required String deploymentCode,
    required Position position,
    required int batteryLevel,
    required String signalStrength,
    String? batteryState,
    String? connectivityType,
  }) async {
    
    // Check if we need to re-login first
    if (!_isLoggedIn || _consecutiveFailures > 3) {
      print('ApiService: ⚠️ Not logged in or too many failures - attempting re-login');
      final loginResult = await login(token, deploymentCode);
      if (!loginResult.success) {
        print('ApiService: ❌ Re-login failed, cannot update location');
        return loginResult;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final url = Uri.parse('${_baseUrl}updateLocation');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    
    // ONLY REAL COORDINATES - exact API structure
    final body = json.encode({
      'deploymentCode': deploymentCode,
      'location': {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
      },
      'batteryStatus': batteryLevel,
      'signal': signalStrength,
    });

    try {
      print('ApiService: 📍 Sending REAL location data (no dummy coordinates)...');
      print('ApiService: 🔋 Battery: $batteryLevel% | 📶 Signal: $signalStrength');
      print('ApiService: 📍 REAL Lat: ${position.latitude}, Lng: ${position.longitude}');
      print('ApiService: 🎯 Deployment: $deploymentCode');
      
      final response = await http.post(
        url, 
        headers: headers, 
        body: body,
      ).timeout(const Duration(seconds: 15));
      
      print('ApiService: Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        _lastSuccessfulUpdate = DateTime.now();
        _consecutiveFailures = 0;
        print('ApiService: ✅ SUCCESS! Real coordinates sent - Green dot should be STABLE!');
        print('ApiService: 🟢 Last successful update: ${_lastSuccessfulUpdate}');
        
        try {
          final responseData = json.decode(response.body);
          final success = responseData['success'] ?? false;
          if (success) {
            print('ApiService: 🎯 SERVER CONFIRMED SUCCESS - Battery & Signal data received');
          } else {
            print('ApiService: ⚠️ Server responded 200 but success=false: ${responseData['message']}');
          }
        } catch (e) {
          print('ApiService: ⚠️ Could not parse response, but status 200 indicates success');
        }
        
      } else if (response.statusCode == 403) {
        _isLoggedIn = false;
        _consecutiveFailures++;
        print('ApiService: ❌ 403 FORBIDDEN - Unit not logged in! Will re-login on next attempt');
        print('ApiService: Response: ${response.body}');
      } else {
        _consecutiveFailures++;
        print('ApiService: ❌ UPDATE FAILED - Status: ${response.statusCode}');
        print('ApiService: Error response: ${response.body}');
        print('ApiService: Consecutive failures: $_consecutiveFailures');
      }
      
      return ApiResponse.fromResponse(response);
    } catch (e) {
      _consecutiveFailures++;
      print('ApiService: ❌ Network error during update: $e');
      print('ApiService: Consecutive failures: $_consecutiveFailures');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  // CHECK STATUS with better error handling
  static Future<ApiResponse> checkStatus(String token, String deploymentCode) async {
    final url = Uri.parse('${_baseUrl}checkStatus');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    
    final body = json.encode({
      'deploymentCode': deploymentCode,
    });

    try {
      print('ApiService: 🔍 Checking unit login status...');
      final response = await http.post(
        url, 
        headers: headers, 
        body: body,
      ).timeout(const Duration(seconds: 10));
      
      print('ApiService: Status check response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final isLoggedIn = data['isLoggedIn'] ?? false;
        _isLoggedIn = isLoggedIn;
        print('ApiService: 📊 Unit login status from server: $isLoggedIn');
        
        if (isLoggedIn) {
          final loginTime = data['loginTime'];
          final lastActivity = data['lastActivity'];
          print('ApiService: Login time: $loginTime');
          print('ApiService: Last activity: $lastActivity');
        }
      } else {
        print('ApiService: ❌ Status check failed: ${response.body}');
      }
      
      return ApiResponse.fromResponse(response);
    } catch (e) {
      print('ApiService: Status check error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  // REMOVED HEARTBEAT METHOD - This was causing the flickering!
  // The regular updateLocation calls every 5 seconds are sufficient

  // BACKUP METHOD - Only used with REAL coordinates (no dummy data)
  static Future<void> sendBatterySignalUpdate({
    required String token,
    required String deploymentCode,
    required int batteryLevel,
    required String signalStrength,
    String? batteryState,
    String? connectivityType,
  }) async {
    // Skip backup if main method is working
    if (_consecutiveFailures <= 1 && _lastSuccessfulUpdate != null) {
      final timeSinceLastSuccess = DateTime.now().difference(_lastSuccessfulUpdate!);
      if (timeSinceLastSuccess.inMinutes < 5) {
        print('ApiService: 🔄 Skipping backup - main method working fine');
        return;
      }
    }

    try {
      print('ApiService: 🔄 Sending backup update (ONLY if we have real location)...');
      
      // DON'T send backup with dummy coordinates - this causes flickering!
      // Instead, just skip the backup if we don't have real location data
      print('ApiService: ℹ️ Backup skipped - only real coordinates allowed');
      
    } catch (e) {
      print('ApiService: Backup error: $e');
    }
  }

  // ALTERNATIVE UPDATE - Only with real coordinates
  static Future<void> sendAlternativeUpdate({
    required String token,
    required String deploymentCode,
    required int batteryLevel,
    required String signalStrength,
    required Position position,
  }) async {
    // Only use if main method is consistently failing
    if (_consecutiveFailures <= 2) return;

    try {
      print('ApiService: 🔄 Sending alternative update with REAL coordinates...');
      
      final url = Uri.parse('${_baseUrl}updateLocation');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      // ONLY REAL COORDINATES
      final body = json.encode({
        'deploymentCode': deploymentCode,
        'location': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
        },
        'batteryStatus': batteryLevel,
        'signal': signalStrength,
      });

      final response = await http.post(
        url, 
        headers: headers, 
        body: body,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('ApiService: ✅ ALTERNATIVE SUCCESS with real coordinates');
        _consecutiveFailures = 0;
      }
      
    } catch (e) {
      print('ApiService: Alternative error: $e');
    }
  }

  // DIRECT WEB APP UPDATE - Only real coordinates
  static Future<void> sendDirectWebAppUpdate({
    required String deploymentCode,
    required int batteryLevel,
    required String signalStrength,
    required Position position,
    String? batteryState,
    String? connectivityType,
  }) async {
    // Only use as last resort
    if (_consecutiveFailures <= 5) return;

    try {
      print('ApiService: 🎯 Last resort - direct Firebase with REAL coordinates...');
      
      final firebaseUrl = Uri.parse('https://nexuspolice-13560-default-rtdb.firebaseio.com/unitlatest/$deploymentCode.json');
      final headers = {'Content-Type': 'application/json'};
      
      // ONLY REAL COORDINATES
      final payload = {
        'deploymentCode': deploymentCode,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'batteryStatus': batteryLevel,
        'signal': signalStrength,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'servertime': DateTime.now().toIso8601String(),
      };
      
      final response = await http.put(
        firebaseUrl, 
        headers: headers, 
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('ApiService: ✅ DIRECT FIREBASE SUCCESS with real coordinates!');
        _consecutiveFailures = 0;
      }
      
    } catch (e) {
      print('ApiService: Direct update error: $e');
    }
  }

  // Get stability status for debugging
  static Map<String, dynamic> getStabilityStatus() {
    return {
      'isLoggedIn': _isLoggedIn,
      'lastSuccessfulUpdate': _lastSuccessfulUpdate?.toIso8601String(),
      'consecutiveFailures': _consecutiveFailures,
      'deploymentCode': _lastDeploymentCode,
      'minutesSinceLastSuccess': _lastSuccessfulUpdate != null 
        ? DateTime.now().difference(_lastSuccessfulUpdate!).inMinutes 
        : null,
    };
  }
}

class ApiResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromResponse(http.Response response) {
    try {
      final body = json.decode(response.body);
      return ApiResponse(
        success: response.statusCode == 200 && (body['success'] ?? false),
        message: body['message'] ?? 'Request completed',
        data: body,
      );
    } catch (e) {
      return ApiResponse(
        success: response.statusCode == 200,
        message: response.statusCode == 200 ? 'Request successful' : 'Request failed',
        data: {'statusCode': response.statusCode, 'body': response.body},
      );
    }
  }

  factory ApiResponse.error(String message) {
    return ApiResponse(success: false, message: message);
  }
}
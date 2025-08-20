import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../utils/constants.dart';

class ApiService {
  static Future<ApiResponse> login(String token, String deploymentCode) async {
    final url = Uri.parse('${AppConstants.baseUrl}setUnit');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = json.encode({
      'deploymentCode': deploymentCode,
      'action': 'login',
      'timestamp': DateTime.now().toIso8601String(),
      'deviceInfo': {
        'platform': 'flutter',
        'version': AppConstants.appVersion,
      }
    });

    try {
      print('ApiService: Sending login request...');
      final response = await http.post(url, headers: headers, body: body);
      print('ApiService: Login response status: ${response.statusCode}');
      return ApiResponse.fromResponse(response);
    } catch (e) {
      print('ApiService: Login network error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  static Future<ApiResponse> logout(String token, String deploymentCode) async {
    final url = Uri.parse('${AppConstants.baseUrl}setUnit');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = json.encode({
      'deploymentCode': deploymentCode,
      'action': 'logout',
      'timestamp': DateTime.now().toIso8601String(),
      'disconnectFromWebApp': true, // Flag to ensure web app removes the device
      'reason': 'user_logout',
    });

    try {
      print('ApiService: Sending logout request to disconnect from web app...');
      final response = await http.post(url, headers: headers, body: body);
      print('ApiService: Logout response status: ${response.statusCode}');
      
      // Also send a secondary disconnect request to ensure web app is notified
      await _sendWebAppDisconnect(token, deploymentCode);
      
      return ApiResponse.fromResponse(response);
    } catch (e) {
      print('ApiService: Logout network error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  // Secondary method to ensure web app disconnect
  static Future<void> _sendWebAppDisconnect(String token, String deploymentCode) async {
    try {
      final disconnectUrl = Uri.parse('${AppConstants.baseUrl}disconnectDevice');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final body = json.encode({
        'deploymentCode': deploymentCode,
        'action': 'disconnect',
        'timestamp': DateTime.now().toIso8601String(),
        'webAppUrl': 'https://nexuspolice-13560.web.app/map',
      });

      print('ApiService: Sending additional web app disconnect request...');
      final response = await http.post(disconnectUrl, headers: headers, body: body);
      print('ApiService: Web app disconnect response: ${response.statusCode}');
    } catch (e) {
      print('ApiService: Web app disconnect error (non-critical): $e');
      // This is non-critical, so we don't throw an error
    }
  }

  static Future<ApiResponse> updateLocation({
    required String token,
    required String deploymentCode,
    required Position position,
    required int batteryLevel,
    required String signalStrength,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}updateLocation');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = json.encode({
      'deploymentCode': deploymentCode,
      'location': {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': position.timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
      },
      'deviceStatus': {
        'batteryLevel': batteryLevel,
        'batteryStatus': batteryLevel > 20 ? 'normal' : 'low',
        'signalStrength': signalStrength,
        'lastUpdate': DateTime.now().toIso8601String(),
      },
      'webAppSync': true, // Ensure this update reaches the web app
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      return ApiResponse.fromResponse(response);
    } catch (e) {
      print('ApiService: Location update error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  // New method to send status updates to web app
  static Future<ApiResponse> sendStatusUpdate({
    required String token,
    required String deploymentCode,
    required String status,
    String? message,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}updateStatus');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = json.encode({
      'deploymentCode': deploymentCode,
      'status': status,
      'message': message ?? '',
      'timestamp': DateTime.now().toIso8601String(),
      'webAppNotification': true,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  // Method to verify connection with web app
  static Future<bool> verifyWebAppConnection(String token, String deploymentCode) async {
    try {
      final url = Uri.parse('${AppConstants.baseUrl}verifyConnection');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final body = json.encode({
        'deploymentCode': deploymentCode,
        'webAppUrl': 'https://nexuspolice-13560.web.app/map',
        'timestamp': DateTime.now().toIso8601String(),
      });

      final response = await http.post(url, headers: headers, body: body);
      return response.statusCode == 200;
    } catch (e) {
      print('ApiService: Web app connection verification failed: $e');
      return false;
    }
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
        success: false,
        message: 'Invalid response format',
      );
    }
  }

  factory ApiResponse.error(String message) {
    return ApiResponse(success: false, message: message);
  }
}
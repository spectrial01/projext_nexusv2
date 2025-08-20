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
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      return ApiResponse.fromResponse(response);
    } catch (e) {
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
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return ApiResponse.error('Network error: ${e.toString()}');
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
      },
      'batteryStatus': batteryLevel,
      'signal': signalStrength,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return ApiResponse.error('Network error: ${e.toString()}');
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
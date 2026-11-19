// SentinelX - Backend API Service
// HTTP client for communicating with the Node.js Express backend.
// Handles base URL config, auth headers, response parsing, and error normalization.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

// ─── API Configuration ─────────────────────────────────────────────────────

class ApiConfig {
  // Change to your backend URL for production
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000', // Android emulator → host localhost
  );

  static const Duration timeout = Duration(seconds: 15);
  static const Duration detectTimeout = Duration(seconds: 30);
}

// ─── API Response Wrapper ──────────────────────────────────────────────────

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int statusCode;

  const ApiResponse({
    required this.success,
    this.data,
    this.error,
    required this.statusCode,
  });

  bool get isOk => success && data != null;

  @override
  String toString() => 'ApiResponse(success=$success, statusCode=$statusCode, error=$error)';
}

// ─── Custom Exceptions ─────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException() : super('Session expired. Please log in again.', 401);
}

// ─── API Service ───────────────────────────────────────────────────────────

class ApiService {
  final AuthService _authService;
  final http.Client _client;

  ApiService({AuthService? authService, http.Client? client})
      : _authService = authService ?? AuthService(),
        _client = client ?? http.Client();

  // ── Build request headers ────────────────────────────────────────────────
  Future<Map<String, String>> _headers({bool requireAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requireAuth) {
      final token = await _authService.getValidAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // ── Parse response ────────────────────────────────────────────────────────
  ApiResponse<Map<String, dynamic>> _parseResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: body['success'] == true,
        data: body,
        error: body['error'] as String?,
        statusCode: response.statusCode,
      );
    } catch (_) {
      return ApiResponse(
        success: false,
        error: 'Failed to parse server response.',
        statusCode: response.statusCode,
      );
    }
  }

  // ── Handle 401 → trigger token refresh ───────────────────────────────────
  Future<http.Response?> _handleUnauthorized(
    Future<http.Response> Function() requestFn,
  ) async {
    final response = await requestFn();
    if (response.statusCode == 401) {
      // Try to refresh tokens
      final refreshed = await _authService.refreshTokens();
      if (refreshed) {
        return requestFn(); // Retry with new token
      }
      throw UnauthorizedException();
    }
    return response;
  }

  // ── GET ───────────────────────────────────────────────────────────────────
  Future<ApiResponse<Map<String, dynamic>>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requireAuth = true,
    Duration? timeout,
  }) async {
    try {
      var uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final headers = await _headers(requireAuth: requireAuth);

      final response = await (_handleUnauthorized(
        () => _client.get(uri, headers: headers).timeout(timeout ?? ApiConfig.timeout),
      ));

      return _parseResponse(response!);
    } on UnauthorizedException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Request timed out. Check your connection.');
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  // ── POST ──────────────────────────────────────────────────────────────────
  Future<ApiResponse<Map<String, dynamic>>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
    Duration? timeout,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _headers(requireAuth: requireAuth);

      final response = await (_handleUnauthorized(
        () => _client
            .post(uri, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(timeout ?? ApiConfig.timeout),
      ));

      return _parseResponse(response!);
    } on UnauthorizedException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Request timed out. Check your connection.');
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  // ── PATCH ─────────────────────────────────────────────────────────────────
  Future<ApiResponse<Map<String, dynamic>>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _headers(requireAuth: requireAuth);

      final response = await (_handleUnauthorized(
        () => _client
            .patch(uri, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(ApiConfig.timeout),
      ));

      return _parseResponse(response!);
    } on UnauthorizedException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  Future<ApiResponse<Map<String, dynamic>>> delete(
    String endpoint, {
    bool requireAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _headers(requireAuth: requireAuth);

      final response = await (_handleUnauthorized(
        () => _client.delete(uri, headers: headers).timeout(ApiConfig.timeout),
      ));

      return _parseResponse(response!);
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  void dispose() => _client.close();
}

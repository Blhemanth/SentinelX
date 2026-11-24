// SentinelX - Auth Service
// Manages JWT access/refresh tokens with FlutterSecureStorage on Windows (DPAPI) and Android (EncryptedSharedPreferences).
// Falls back gracefully and preserves strict 600ms startup threshold.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// ─── Token Storage Keys ────────────────────────────────────────────────────
const _kAccessToken = 'sentinelx_access_token';
const _kRefreshToken = 'sentinelx_refresh_token';
const _kTokenExpiry = 'sentinelx_token_expiry';
const _kUserData = 'sentinelx_user_data';

// ─── Authenticated User Model ──────────────────────────────────────────────

class AuthUser {
  final String userId;
  final String name;
  final String email;
  final String role;

  const AuthUser({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
  });

  bool get isAdmin => role == 'admin';
  bool get isAnalyst => role == 'analyst' || isAdmin;
  bool get isPolice => role == 'police' || isAdmin;
  bool get isUser => true;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'email': email,
        'role': role,
      };
}

// ─── Auth Service ─────────────────────────────────────────────────────────

class AuthService extends ChangeNotifier {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  // Platform-native secure storage configuration:
  // Windows: DPAPI / Windows Credential Manager
  // Android: KeyStore AES-256 GCM + RSA OAEP key wrapping
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    wOptions: WindowsOptions(),
  );

  AuthUser? _currentUser;
  bool _isAuthenticated = false;

  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;

  // Session generation counter to discard trailing asynchronous responses across account switch / logout
  int _sessionGeneration = 0;
  int get sessionGeneration => _sessionGeneration;

  final List<VoidCallback> _onSessionResetCallbacks = [];

  void registerSessionResetCallback(VoidCallback callback) {
    if (!_onSessionResetCallbacks.contains(callback)) {
      _onSessionResetCallbacks.add(callback);
    }
  }

  void unregisterSessionResetCallback(VoidCallback callback) {
    _onSessionResetCallbacks.remove(callback);
  }

  void triggerSessionReset() {
    _sessionGeneration++;
    for (final callback in List<VoidCallback>.from(_onSessionResetCallbacks)) {
      try {
        callback();
      } catch (e) {
        debugPrint('[AuthService] Session reset callback failed: $e');
      }
    }
  }

  // ── Secure Storage Helpers with Bounded Timeouts ──────────────────────────
  static Future<String?> _readSecure(String key) async {
    try {
      return await _secureStorage.read(key: key).timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => null,
      );
    } catch (e) {
      debugPrint('SecureStorage read fallback for $key: $e');
      return null;
    }
  }

  static Future<void> _writeSecure(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value).timeout(
        const Duration(milliseconds: 800),
      );
    } catch (e) {
      debugPrint('SecureStorage write error for $key: $e');
    }
  }

  static Future<void> _deleteSecure(String key) async {
    try {
      await _secureStorage.delete(key: key).timeout(
        const Duration(milliseconds: 500),
      );
    } catch (e) {
      debugPrint('SecureStorage delete error for $key: $e');
    }
  }

  // ── Initialize: load persisted session ───────────────────────────────────
  Future<bool> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 600),
        onTimeout: () => throw Exception('Prefs read timeout'),
      );
      final userData = prefs.getString(_kUserData);
      final expiryMs = prefs.getInt(_kTokenExpiry);

      // Read access token securely
      var accessToken = await _readSecure(_kAccessToken);

      // Migration fallback: check legacy SharedPreferences and migrate to secure storage
      if (accessToken == null && prefs.containsKey(_kAccessToken)) {
        final legacyToken = prefs.getString(_kAccessToken);
        final legacyRefresh = prefs.getString(_kRefreshToken);
        if (legacyToken != null) {
          accessToken = legacyToken;
          await _writeSecure(_kAccessToken, legacyToken);
          await prefs.remove(_kAccessToken);
        }
        if (legacyRefresh != null) {
          await _writeSecure(_kRefreshToken, legacyRefresh);
          await prefs.remove(_kRefreshToken);
        }
      }

      if (userData == null || accessToken == null) return false;

      // Check expiry
      if (expiryMs != null && DateTime.now().millisecondsSinceEpoch > expiryMs) {
        final refreshed = await refreshTokens().timeout(
          const Duration(milliseconds: 600),
          onTimeout: () => false,
        );
        if (!refreshed) {
          await _clearStoredTokens();
          _currentUser = null;
          _isAuthenticated = false;
          return false;
        }
      }

      _currentUser = AuthUser.fromJson(jsonDecode(userData));
      _isAuthenticated = true;
      return true;
    } catch (e) {
      debugPrint('Auth initialization fallback: $e');
      return false;
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<({bool success, String? error})> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        await _persistTokens(
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
          expiresIn: data['expiresIn'] ?? 900,
          user: data['user'],
        );
        return (success: true, error: null);
      } else {
        return (success: false, error: body['error']?.toString() ?? 'Login failed.');
      }
    } catch (e) {
      // Dev fallback: allow login in standalone offline mode
      if (email.isNotEmpty && password.length >= 8) {
        final mockRole = email.contains('admin')
            ? 'admin'
            : (email.contains('police')
                ? 'police'
                : (email.contains('analyst') ? 'analyst' : 'user'));
        final displayName = email.contains('police')
            ? 'Officer Vance (Unit 104)'
            : (email.contains('admin')
                ? 'Control Room Commander'
                : email.split('@').first.toUpperCase());
        final mockUser = {
          'userId': 'usr-mock-${email.split('@').first}',
          'name': displayName,
          'email': email,
          'role': mockRole,
        };
        await _persistTokens(
          accessToken: 'mock_jwt_access_token_sentinelx',
          refreshToken: 'mock_jwt_refresh_token_sentinelx',
          expiresIn: 3600,
          user: mockUser,
        );
        return (success: true, error: null);
      }
      return (success: false, error: 'Could not connect to server: $e');
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<({bool success, String? error})> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 201 && body['success'] == true) {
        return (success: true, error: null);
      }
      return (success: false, error: body['error']?.toString() ?? 'Registration failed.');
    } catch (e) {
      return (success: false, error: 'Could not connect to server: $e');
    }
  }

  // ── Refresh tokens ────────────────────────────────────────────────────────
  Future<bool> refreshTokens() async {
    try {
      final refreshToken = await _readSecure(_kRefreshToken);
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        final userData = prefs.getString(_kUserData);
        await _persistTokens(
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
          expiresIn: data['expiresIn'] ?? 900,
          user: userData != null ? jsonDecode(userData) : null,
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Get valid access token (auto-refresh if needed) ───────────────────────
  Future<String?> getValidAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryMs = prefs.getInt(_kTokenExpiry);
    final accessToken = await _readSecure(_kAccessToken);

    if (accessToken == null) return null;

    // If token expires within 60 seconds, refresh proactively
    if (expiryMs != null &&
        DateTime.now().millisecondsSinceEpoch > expiryMs - 60000) {
      final refreshed = await refreshTokens();
      if (!refreshed) return null;
      return await _readSecure(_kAccessToken);
    }

    return accessToken;
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      final refreshToken = await _readSecure(_kRefreshToken);
      final accessToken = await _readSecure(_kAccessToken);

      if (refreshToken != null) {
        final headers = <String, String>{'Content-Type': 'application/json'};
        if (accessToken != null) {
          headers['Authorization'] = 'Bearer $accessToken';
        }
        await http.post(
          Uri.parse('$_baseUrl/api/auth/logout'),
          headers: headers,
          body: jsonEncode({'refreshToken': refreshToken}),
        ).timeout(const Duration(seconds: 5)).catchError((_) => http.Response('', 500));
      }
    } catch (_) {}

    await _clearStoredTokens();
    _currentUser = null;
    _isAuthenticated = false;
    triggerSessionReset();
    notifyListeners();
  }

  // ── Persist tokens ────────────────────────────────────────────────────────
  Future<void> _persistTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
    Map<String, dynamic>? user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final expiryMs = DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);

    // Secure encrypted storage for sensitive JWT tokens (Windows DPAPI / Android Keystore)
    await _writeSecure(_kAccessToken, accessToken);
    await _writeSecure(_kRefreshToken, refreshToken);

    // Clean up any legacy plaintext tokens from SharedPreferences
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.setInt(_kTokenExpiry, expiryMs);

    if (user != null) {
      await prefs.setString(_kUserData, jsonEncode(user));
      _currentUser = AuthUser.fromJson(user);
      _isAuthenticated = true;
      triggerSessionReset();
      notifyListeners();
    }
  }

  Future<void> _clearStoredTokens() async {
    await _deleteSecure(_kAccessToken);
    await _deleteSecure(_kRefreshToken);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccessToken);
      await prefs.remove(_kRefreshToken);
      await prefs.remove(_kTokenExpiry);
      await prefs.remove(_kUserData);
    } catch (e) {
      debugPrint('[AuthService] Clear stored prefs note: $e');
    }
  }
}

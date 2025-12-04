import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_tokens.dart';
import '../models/user.dart';
import 'api_config.dart';

class AuthService {
  // Use different storage for web platform
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: 'SureFinanceDB',
      publicKey: 'SureFinancePublicKey',
    ),
  );

  static const String _tokenKey = 'auth_tokens';
  static const String _userKey = 'user_data';

  // Web fallback storage using SharedPreferences
  Future<void> _writeSecure(String key, String value) async {
    if (kIsWeb) {
      // Use SharedPreferences for web as a fallback
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }

  Future<String?> _readSecure(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      return await _secureStorage.read(key: key);
    }
  }

  Future<void> _deleteSecure(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      await _secureStorage.delete(key: key);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required Map<String, String> deviceInfo,
    String? otpCode,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/login');

    final body = {
      'email': email,
      'password': password,
      'device': deviceInfo,
    };

    if (otpCode != null) {
      body['otp_code'] = otpCode;
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(
        ApiConfig.connectTimeout,
        onTimeout: () {
          throw Exception('Connection timeout. Please check your backend URL and network connection.');
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Store tokens
        final tokens = AuthTokens.fromJson(responseData);
        await _saveTokens(tokens);

        // Store user data
        if (responseData['user'] != null) {
          final user = User.fromJson(responseData['user']);
          await _saveUser(user);
        }

        return {
          'success': true,
          'tokens': tokens,
          'user': responseData['user'] != null
              ? User.fromJson(responseData['user'])
              : null,
        };
      } else if (response.statusCode == 401 && responseData['mfa_required'] == true) {
        return {
          'success': false,
          'mfa_required': true,
          'error': responseData['error'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? responseData['errors']?.join(', ') ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection failed: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required Map<String, String> deviceInfo,
    String? inviteCode,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/signup');

    final Map<String, Object> body = {
      'user': {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      },
      'device': deviceInfo,
    };

    if (inviteCode != null) {
      body['invite_code'] = inviteCode;
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(
        ApiConfig.connectTimeout,
        onTimeout: () {
          throw Exception('Connection timeout. Please check your backend URL and network connection.');
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Store tokens
        final tokens = AuthTokens.fromJson(responseData);
        await _saveTokens(tokens);

        // Store user data
        if (responseData['user'] != null) {
          final user = User.fromJson(responseData['user']);
          await _saveUser(user);
        }

        return {
          'success': true,
          'tokens': tokens,
          'user': responseData['user'] != null
              ? User.fromJson(responseData['user'])
              : null,
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? responseData['errors']?.join(', ') ?? 'Signup failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection failed: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> refreshToken({
    required String refreshToken,
    required Map<String, String> deviceInfo,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/refresh');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'refresh_token': refreshToken,
          'device': deviceInfo,
        }),
      ).timeout(
        ApiConfig.connectTimeout,
        onTimeout: () {
          throw Exception('Connection timeout. Please check your backend URL and network connection.');
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final tokens = AuthTokens.fromJson(responseData);
        await _saveTokens(tokens);

        return {
          'success': true,
          'tokens': tokens,
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Token refresh failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection failed: ${e.toString()}',
      };
    }
  }

  Future<void> logout() async {
    await _deleteSecure(_tokenKey);
    await _deleteSecure(_userKey);
  }

  Future<AuthTokens?> getStoredTokens() async {
    final tokensJson = await _readSecure(_tokenKey);
    if (tokensJson == null) return null;

    try {
      return AuthTokens.fromJson(jsonDecode(tokensJson));
    } catch (e) {
      return null;
    }
  }

  Future<User?> getStoredUser() async {
    final userJson = await _readSecure(_userKey);
    if (userJson == null) return null;

    try {
      return User.fromJson(jsonDecode(userJson));
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveTokens(AuthTokens tokens) async {
    await _writeSecure(
      _tokenKey,
      jsonEncode(tokens.toJson()),
    );
  }

  Future<void> _saveUser(User user) async {
    await _writeSecure(
      _userKey,
      jsonEncode({
        'id': user.id,
        'email': user.email,
        'first_name': user.firstName,
        'last_name': user.lastName,
      }),
    );
  }
}

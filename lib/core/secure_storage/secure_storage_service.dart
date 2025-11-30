import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/models/auth_models.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Keys
  static const String _accessTokenKey = 'access_token';
  static const String _userKey = 'user_data';

  // Token operations
  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  static Future<void> deleteAccessToken() async {
    await _storage.delete(key: _accessTokenKey);
  }

  // User operations
  static Future<void> saveUser(User user) async {
    final userJson = jsonEncode(user.toJson());
    await _storage.write(key: _userKey, value: userJson);
  }

  static Future<User?> getUser() async {
    final userJson = await _storage.read(key: _userKey);
    if (userJson == null) return null;
    
    try {
      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      return User.fromJson(userMap);
    } catch (e) {
      // If there's an error parsing, delete the corrupted data
      await deleteUser();
      return null;
    }
  }

  static Future<void> deleteUser() async {
    await _storage.delete(key: _userKey);
  }

  // Clear all auth data
  static Future<void> clearAll() async {
    await Future.wait([
      deleteAccessToken(),
      deleteUser(),
    ]);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    final user = await getUser();
    return token != null && user != null;
  }

  // Get stored auth state
  static Future<AuthState> getStoredAuthState() async {
    final token = await getAccessToken();
    final user = await getUser();
    
    if (token != null && user != null) {
      return AuthState(
        accessToken: token,
        user: user,
        isAuthenticated: true,
      );
    }
    
    return AuthState.initial;
  }
}

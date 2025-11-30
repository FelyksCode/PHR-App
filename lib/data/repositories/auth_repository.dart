import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../../core/secure_storage/secure_storage_service.dart';

class AuthRepository {
  final AuthService _authService;

  AuthRepository(this._authService);

  // Login and store credentials
  Future<AuthState> login(String email, String password) async {
    try {
      final loginRequest = LoginRequest(email: email, password: password);
      
      final loginResponse = await _authService.login(loginRequest);
      
      // Store token securely
      await SecureStorageService.saveAccessToken(loginResponse.accessToken);
      
      // Fetch user data using the token
      final user = await _authService.getMe(loginResponse.accessToken);
      
      // Store user data securely
      await SecureStorageService.saveUser(user);
      
      return AuthState(
        user: user,
        accessToken: loginResponse.accessToken,
        isAuthenticated: true,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Login failed: $e');
    }
  }

  // Get current user from server (validate token)
  Future<User> getCurrentUser() async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null) {
      throw AuthException('No access token found');
    }
    
    try {
      return await _authService.getMe(token);
    } on AuthException catch (e) {
      // If token is invalid, clear stored data
      if (e.message.contains('Token expired') || e.message.contains('invalid')) {
        await logout();
      }
      rethrow;
    }
  }

  // Auto-login using stored credentials
  Future<AuthState> autoLogin() async {
    try {
      final storedState = await SecureStorageService.getStoredAuthState();
      
      if (!storedState.isAuthenticated || storedState.accessToken == null) {
        return AuthState.initial;
      }
      
      // Validate token by fetching user data
      final user = await getCurrentUser();
      
      return AuthState(
        user: user,
        accessToken: storedState.accessToken,
        isAuthenticated: true,
      );
    } on AuthException {
      // Token is invalid, clear storage and return unauthenticated state
      await SecureStorageService.clearAll();
      return AuthState.initial;
    } catch (e) {
      // Other errors, clear storage to be safe
      await SecureStorageService.clearAll();
      return AuthState.initial;
    }
  }

  // Logout and clear all stored data
  Future<void> logout() async {
    await SecureStorageService.clearAll();
  }

  // Check if user is currently logged in
  Future<bool> isLoggedIn() async {
    return await SecureStorageService.isLoggedIn();
  }

  // Get stored auth state without server validation
  Future<AuthState> getStoredAuthState() async {
    return await SecureStorageService.getStoredAuthState();
  }
}

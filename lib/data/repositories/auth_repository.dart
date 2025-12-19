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
  Future<AuthState> autoLogin({bool skipNetworkValidation = false}) async {
    try {
      final storedState = await SecureStorageService.getStoredAuthState();
      
      if (!storedState.isAuthenticated || storedState.accessToken == null) {
        return AuthState.initial;
      }

      // If offline or explicitly skipping validation, trust stored state
      if (skipNetworkValidation) {
        return storedState.copyWith(
          isAuthenticated: true,
          isLoading: false,
          error: 'offline',
        );
      }

      // Validate token by fetching user data
      final user = await getCurrentUser();
      
      return storedState.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      );
    } on AuthException catch (e) {
      // If we're offline but have a stored token+user, allow offline auth
      final storedState = await SecureStorageService.getStoredAuthState();
      final isOffline = _isOfflineMessage(e.message);
      final isInvalid = e.message.contains('Token expired') || e.message.contains('invalid');

      if (isOffline && storedState.isAuthenticated && storedState.user != null) {
        return storedState.copyWith(
          isAuthenticated: true,
          isLoading: false,
          error: 'offline',
        );
      }

      if (isInvalid) {
        await SecureStorageService.clearAll();
        return AuthState.initial;
      }

      // Unknown error: keep stored token to avoid logging user out unexpectedly
      return storedState.copyWith(
        isAuthenticated: storedState.isAuthenticated,
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      // On unexpected errors, fall back to stored auth state without clearing it
      final storedState = await SecureStorageService.getStoredAuthState();
      return storedState.copyWith(
        isAuthenticated: storedState.isAuthenticated,
        isLoading: false,
        error: e.toString(),
      );
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

  bool _isOfflineMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('network error') ||
        lower.contains('connection timeout') ||
        lower.contains('receive timeout') ||
        lower.contains('offline') ||
        lower.contains('socketexception');
  }
}

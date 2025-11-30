import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/auth_models.dart';
import '../data/repositories/auth_repository.dart';
import '../data/services/auth_service.dart';

// Service providers
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthRepository(authService);
});

// Auth state provider
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  
  AuthNotifier(this._authRepository) : super(AuthState.initial) {
    _checkAuthStatus();
  }
  
  // Check if user is already authenticated on app start
  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final authState = await _authRepository.autoLogin();
      state = authState;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
  
  // Login method
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final authState = await _authRepository.login(email, password);
      state = authState;
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        error: 'An unexpected error occurred: $e',
      );
    }
  }
  
  // Logout method
  Future<void> logout() async {
    await _authRepository.logout();
    state = AuthState.initial;
  }
  
  // Clear error
  void clearError() {
    state = state.clearError();
  }
  
  // Refresh user data
  Future<void> refreshUser() async {
    if (!state.isAuthenticated) return;
    
    try {
      final user = await _authRepository.getCurrentUser();
      state = state.copyWith(user: user);
    } on AuthException catch (e) {
      // If refresh fails, likely token expired
      if (e.message.contains('Token expired') || e.message.contains('invalid')) {
        await logout();
      }
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});

// Login form providers
final emailProvider = StateProvider<String>((ref) => '');
final passwordProvider = StateProvider<String>((ref) => '');
final obscurePasswordProvider = StateProvider<bool>((ref) => true);

// Login form validation
final isLoginFormValidProvider = Provider<bool>((ref) {
  final email = ref.watch(emailProvider);
  final password = ref.watch(passwordProvider);
  
  return email.isNotEmpty && 
         password.isNotEmpty && 
         email.contains('@') && 
         password.length >= 6;
});

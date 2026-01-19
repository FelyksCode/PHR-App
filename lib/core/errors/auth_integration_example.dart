/// Integration Example: Error Handling in Auth Flow
///
/// This example shows how to use the error handling system in a login flow.
/// It demonstrates all key patterns: repository → state notifier → UI.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_error.dart';
import 'api_error_mapper.dart';
import 'app_error_logger.dart';
import 'error_message_resolver.dart';

// ============================================================================
// Repository Layer: Handles API calls and error conversion
// ============================================================================

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  /// Logs in user and throws AppError on failure
  Future<User> login(String email, String password) async {
    try {
      _validateCredentials(email, password);

      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final result = LoginResponse.fromJson(response.data);
      return result.user;
    } on LocalValidationError {
      rethrow; // Client validation - let UI handle field errors
    } on DioException catch (e, st) {
      final appError = ApiErrorMapper.fromException(e, stackTrace: st);
      AppErrorLogger.logError(
        appError,
        source: 'AuthRepository.login',
        severity: ErrorSeverity.medium,
      );
      throw appError;
    } catch (e, st) {
      final error = UnknownError(
        'Login failed unexpectedly',
        code: 'LOGIN_UNEXPECTED',
        stackTrace: st,
        originalException: e,
      );
      AppErrorLogger.logError(
        error,
        source: 'AuthRepository.login',
        severity: ErrorSeverity.high,
      );
      throw error;
    }
  }

  void _validateCredentials(String email, String password) {
    final errors = <String, List<String>>{};

    if (email.isEmpty) {
      errors['email'] = ['Email is required'];
    } else if (!_isValidEmail(email)) {
      errors['email'] = ['Invalid email format'];
    }

    if (password.isEmpty) {
      errors['password'] = ['Password is required'];
    } else if (password.length < 6) {
      errors['password'] = ['Password must be at least 6 characters'];
    }

    if (errors.isNotEmpty) {
      throw LocalValidationError(
        'Please check your input',
        code: 'LOGIN_VALIDATION',
        fieldErrors: errors,
      );
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }
}

// ============================================================================
// State Management: Auth state and notifier
// ============================================================================

class AuthState {
  final bool isLoading;
  final User? user;
  final AppError? error;
  final LocalValidationError? validationError;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.error,
    this.validationError,
  });

  AuthState copyWith({
    bool? isLoading,
    User? user,
    AppError? error,
    LocalValidationError? validationError,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error,
      validationError: validationError,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AuthState());

  /// Attempts login and updates state with result
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null, validationError: null);

    try {
      final user = await _authRepository.login(email, password);
      state = state.copyWith(user: user, isLoading: false);
    } on LocalValidationError catch (e) {
      state = state.copyWith(isLoading: false, validationError: e, error: null);
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: e, validationError: null);
    }
  }
}

// ============================================================================
// UI Layer: Login screen
// ============================================================================

class LoginScreenExample extends ConsumerWidget {
  const LoginScreenExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Show API/network errors
              if (authState.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ErrorMessageResolver.resolve(authState.error!, context),
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),

              const SizedBox(height: 16),

              // Email field with validation error
              TextField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText:
                      authState.validationError?.fieldErrors?['email']?.first,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Password field with validation error
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: authState
                      .validationError
                      ?.fieldErrors?['password']
                      ?.first,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Login button
              ElevatedButton(
                onPressed: authState.isLoading
                    ? null
                    : () => _login(context, ref),
                child: authState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _login(BuildContext context, WidgetRef ref) {
    ref
        .read(authNotifierProvider.notifier)
        .login('user@example.com', 'password123');
  }
}

// ============================================================================
// Providers: Riverpod configuration
// ============================================================================

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Dio());
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});

// ============================================================================
// Models: Data classes
// ============================================================================

class User {
  final String id;
  final String email;
  final String name;

  User({required this.id, required this.email, required this.name});
}

class LoginResponse {
  final User user;
  final String accessToken;

  LoginResponse({required this.user, required this.accessToken});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      user: User(
        id: json['user']['id'] ?? '',
        email: json['user']['email'] ?? '',
        name: json['user']['name'] ?? '',
      ),
      accessToken: json['access_token'] ?? '',
    );
  }
}

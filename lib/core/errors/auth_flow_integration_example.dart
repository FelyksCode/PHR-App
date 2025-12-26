// Integration Example: Error Handling in Auth Flow
//
// This example shows how to use the error handling system in a login flow.
// It demonstrates key patterns: repository → state notifier → UI.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// (imports moved to top of file)
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
    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
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

  // (no repository-level refreshUser here; handled by notifier in app code)
}

// Step 3: UI Layer - Login Screen Implementation
// ============================================================================

// (imports already at file top)

// (removed verbose LoginScreenImplementation; see LoginScreenExample below)

// ============================================================================
// State Management: Auth state and notifier
// ============================================================================

class AuthStateModel {
  final bool isLoading;
  final User? user;
  final AppError? error;
  final LocalValidationError? validationError;

  const AuthStateModel({
    this.isLoading = false,
    this.user,
    this.error,
    this.validationError,
  });

  AuthStateModel copyWith({
    bool? isLoading,
    User? user,
    AppError? error,
    LocalValidationError? validationError,
  }) {
    return AuthStateModel(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error,
      validationError: validationError,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthStateModel> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AuthStateModel());

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null, validationError: null);

    try {
      final user = await _authRepository.login(email, password);
      state = state.copyWith(user: user, isLoading: false);
    } on LocalValidationError catch (e) {
      state = state.copyWith(
        isLoading: false,
        validationError: e,
        error: null,
      );
    } on AppError catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e,
        validationError: null,
      );
    }
  }
}

// ============================================================================
// UI Layer: Minimal login screen using resolver
// ============================================================================

class LoginScreenExample extends ConsumerWidget {
  const LoginScreenExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            ElevatedButton(
              onPressed: authState.isLoading
                  ? null
                  : () =>
                      ref.read(authNotifierProvider.notifier).login('user@example.com', 'password123'),
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
    );
  }
}

// ============================================================================
// Providers
// ============================================================================

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Dio());
});

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthStateModel>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});

// ============================================================================
// Models
// ============================================================================

class User {
  final String id;
  final String email;
  final String name;

  User({
    required this.id,
    required this.email,
    required this.name,
  });
}

class LoginResponse {
  final User user;
  final String accessToken;

  LoginResponse({
    required this.user,
    required this.accessToken,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      user: User(
        id: json['user']?['id'] ?? '',
        email: json['user']?['email'] ?? '',
        name: json['user']?['name'] ?? '',
      ),
      accessToken: json['access_token'] ?? '',
    );
  }
}

// (removed duplicate state model and model classes to avoid redefinitions)


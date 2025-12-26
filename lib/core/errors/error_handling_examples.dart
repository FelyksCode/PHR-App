/// Example: Error Handling in Auth Flow
/// 
/// This demonstrates how to use the centralized error handling system
/// in a login/authentication flow.

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/api_error_mapper.dart';
import '../../core/errors/app_error_logger.dart';
import '../../core/errors/result.dart';
import '../../core/errors/error_message_resolver.dart';

// Example 1: Repository-level error handling

class AuthRepositoryExample {
  final Dio _dio;

  AuthRepositoryExample(this._dio);

  /// Login with proper error handling
  /// 
  /// Key points:
  /// 1. All exceptions are converted to AppError
  /// 2. Errors are logged centrally
  /// 3. Repository throws only AppError or returns Result
  Future<LoginResponse> login(String email, String password) async {
    try {
      // Validation errors are caught early
      _validateCredentials(email, password);

      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      // Status code 200-299 flows through
      return LoginResponse.fromJson(response.data);
    } on ValidationError catch (e) {
      // Local validation errors are logged and re-thrown
      AppErrorLogger.logError(
        e,
        source: 'AuthRepository.login',
        severity: ErrorSeverity.low,
      );
      rethrow;
    } on DioException catch (e) {
      // Convert Dio errors to domain errors
      final appError = ApiErrorMapper.fromException(e);
      
      // Log with appropriate severity
      final severity = _getLoginErrorSeverity(appError);
      AppErrorLogger.logError(
        appError,
        source: 'AuthRepository.login',
        severity: severity,
      );
      
      throw appError;
    } catch (e, st) {
      // Unexpected errors are wrapped as UnknownError
      final error = UnknownError(
        'Login failed unexpectedly',
        code: 'LOGIN_UNKNOWN_ERROR',
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

  /// Validates credentials locally
  void _validateCredentials(String email, String password) {
    final errors = <String, List<String>>{};

    if (email.isEmpty) {
      errors['email'] = ['Email is required'];
    } else if (!_isValidEmail(email)) {
      errors['email'] = ['Email format is invalid'];
    }

    if (password.isEmpty) {
      errors['password'] = ['Password is required'];
    } else if (password.length < 6) {
      errors['password'] = ['Password must be at least 6 characters'];
    }

    if (errors.isNotEmpty) {
      throw LocalValidationError(
        'Please check your input',
        code: 'CREDENTIALS_VALIDATION_ERROR',
        fieldErrors: errors,
      );
    }
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return regex.hasMatch(email);
  }

  ErrorSeverity _getLoginErrorSeverity(AppError error) {
    return switch (error) {
      UnauthorizedError _ => ErrorSeverity.medium, // Expected on wrong password
      ValidationError _ => ErrorSeverity.low, // Expected on bad input
      NetworkError _ => ErrorSeverity.medium, // User should retry
      ServerError _ => ErrorSeverity.high, // Server issues
      _ => ErrorSeverity.medium,
    };
  }
}

// ============================================================================
// Example 2: UI Layer - Screen/Provider handling errors
// ============================================================================


class LoginScreenExample extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the login provider
    // Note: Implementation depends on your actual state management setup
    
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Email field
              TextField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  // Show field-level validation errors
                  // error: _getFieldError('email'),
                ),
              ),
              const SizedBox(height: 16),

              // Password field
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  // Show field-level validation errors
                  // error: _getFieldError('password'),
                ),
              ),
              const SizedBox(height: 24),

              // Login button
              ElevatedButton(
                onPressed: () => _handleLogin(context, ref),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handles login and shows appropriate error UI
  Future<void> _handleLogin(BuildContext context, WidgetRef ref) async {
    try {
      // Call your login method that throws AppError
      // final result = await ref.read(authRepositoryProvider).login(email, password);
      
      // Handle based on error type
    } on LocalValidationError catch (e) {
      // Show inline field errors for local validation
      _showValidationErrors(context, e);
    } on UnauthorizedError catch (e) {
      // Show snackbar for invalid credentials
      _showErrorSnackbar(context, e);
      // The error logger has already logged this
    } on NetworkError catch (e) {
      // Show snackbar with retry option
      _showNetworkErrorSnackbar(context, e);
    } on ServerError catch (e) {
      // Show error dialog for server errors
      _showErrorDialog(context, 'Server Error', e);
    } on AppError catch (e) {
      // Catch-all for any other AppError
      _showErrorSnackbar(context, e);
    }
  }

  /// Shows field-level validation errors
  void _showValidationErrors(
    BuildContext context,
    LocalValidationError error,
  ) {
    // Implementation: Update UI to show field errors
    if (error.fieldErrors != null) {
      for (final entry in error.fieldErrors!.entries) {
        print('${entry.key}: ${entry.value.join(', ')}');
        // Update form field to show error
      }
    }
  }

  /// Shows a simple error snackbar
  void _showErrorSnackbar(BuildContext context, AppError error) {
    final message = ErrorMessageResolver.resolve(error, context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Shows network error with retry option
  void _showNetworkErrorSnackbar(BuildContext context, NetworkError error) {
    final message = ErrorMessageResolver.resolve(error, context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
        action: error.isRetryable
            ? SnackBarAction(
                label: 'Retry',
                onPressed: () {
                  // Retry login
                },
              )
            : null,
      ),
    );
  }

  /// Shows error dialog for critical errors
  void _showErrorDialog(
    BuildContext context,
    String title,
    AppError error,
  ) {
    final message = ErrorMessageResolver.resolve(error, context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Example 3: Observation Sync with Error Recovery
// ============================================================================

class ObservationSyncExample {
  /// Syncs observations with retry logic
  /// 
  /// Demonstrates:
  /// - Type-specific error handling
  /// - Retry logic for retryable errors
  /// - Graceful degradation
  Future<void> syncObservations(
    List<ObservationEntity> observations,
  ) async {
    const maxRetries = 3;
    var retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        // Attempt sync
        await _performSync(observations);
        return; // Success
      } on NetworkError catch (e) {
        retryCount++;
        if (!e.isRetryable || retryCount >= maxRetries) {
          AppErrorLogger.logError(
            e,
            source: 'ObservationSync.syncObservations',
            severity: ErrorSeverity.high,
            additionalData: {'retryCount': retryCount},
          );
          rethrow;
        }
        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(seconds: 2 * retryCount));
      } on TimeoutError catch (e) {
        retryCount++;
        if (!e.isRetryable || retryCount >= maxRetries) {
          AppErrorLogger.logError(
            e,
            source: 'ObservationSync.syncObservations',
            severity: ErrorSeverity.high,
          );
          rethrow;
        }
        // Wait before retrying
        await Future.delayed(Duration(seconds: 2 * retryCount));
      } on UnauthorizedError catch (e) {
        // Don't retry auth errors, they require user intervention
        AppErrorLogger.logCritical(
          e,
          source: 'ObservationSync.syncObservations',
        );
        rethrow;
      } on AppError catch (e) {
        // Log and propagate non-retryable errors
        AppErrorLogger.logError(
          e,
          source: 'ObservationSync.syncObservations',
          severity: ErrorSeverity.high,
        );
        rethrow;
      }
    }
  }

  Future<void> _performSync(List<ObservationEntity> observations) async {
    // Implementation
  }
}

// ============================================================================
// Example 4: Fitbit Integration with Vendor Errors
// ============================================================================

class FitbitVendorIntegrationExample {
  /// Handles Fitbit authorization flow with error handling
  Future<void> authenticateFitbit() async {
    try {
      // Attempt Fitbit authorization
      // If 401: UnauthorizedError (user declined or invalid credentials)
      // If 403: ForbiddenError (scope issues)
      // If 4xx: ValidationError
      // If 5xx: ServerError
      // If timeout: TimeoutError
      // If no connection: NetworkError
    } on UnauthorizedError catch (e) {
      // User cancelled or invalid credentials
      AppErrorLogger.logError(
        e,
        source: 'FitbitIntegration.authenticate',
      );
      // Show user-friendly message: "Please try connecting again"
    } on NetworkError catch (e) {
      // No internet - user can retry when online
      AppErrorLogger.logError(
        e,
        source: 'FitbitIntegration.authenticate',
      );
      // Show retry prompt
    } on ServerError catch (e) {
      // Fitbit service down
      AppErrorLogger.logCritical(
        e,
        source: 'FitbitIntegration.authenticate',
      );
      // Show message: "Fitbit service is temporarily unavailable"
    }
  }
}

// ============================================================================
// Example 5: Form Validation with Field Errors
// ============================================================================

class FormValidationExample {
  /// Validates a form and returns structured field errors
  Result<FormData> validateForm(Map<String, dynamic> input) {
    final errors = <String, List<String>>{};

    // Email validation
    if ((input['email'] as String?)?.isEmpty ?? true) {
      errors['email'] = ['Email is required'];
    } else if (!_isValidEmail(input['email'])) {
      errors['email'] = ['Invalid email format'];
    }

    // Password validation
    if ((input['password'] as String?)?.isEmpty ?? true) {
      errors['password'] = ['Password is required'];
    } else if ((input['password'] as String).length < 8) {
      errors['password'] = ['Password must be at least 8 characters'];
    }

    if (errors.isNotEmpty) {
      return Failure(
        LocalValidationError(
          'Please fix the errors below',
          code: 'FORM_VALIDATION_ERROR',
          fieldErrors: errors,
        ),
      );
    }

    return Success(FormData.fromMap(input));
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return regex.hasMatch(email);
  }
}

class FormData {
  final String email;
  final String password;

  FormData({required this.email, required this.password});

  factory FormData.fromMap(Map<String, dynamic> map) {
    return FormData(
      email: map['email'] as String,
      password: map['password'] as String,
    );
  }
}

// Import Result type from your errors package
class LoginResponse {
  final String token;
  final String userId;

  LoginResponse({required this.token, required this.userId});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['access_token'] ?? '',
      userId: json['user_id'] ?? '',
    );
  }
}

class ObservationEntity {
  final String id;
  final DateTime timestamp;

  ObservationEntity({required this.id, required this.timestamp});
}

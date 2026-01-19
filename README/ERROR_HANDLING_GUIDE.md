# Enterprise-Grade Error Handling Architecture

## Overview

This document describes the centralized, type-safe error handling system implemented across the PHR application. This system ensures consistent error handling, prevents raw exceptions from leaking to the UI, and provides centralized logging for observability.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interface (Widgets)                  │
│  - Shows ErrorMessageResolver messages                       │
│  - Never parses HTTP codes                                   │
│  - Handles errors based on type, not code                    │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                  UI Layer (Providers/BLoC)                   │
│  - Catches AppError                                          │
│  - Triggers UI updates (snackbars, dialogs)                  │
│  - Decides navigation (retry, logout, etc)                   │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│              Repository Layer (Domain Boundary)              │
│  - Converts exceptions to AppError                           │
│  - Logs errors via AppErrorLogger                            │
│  - Returns Result<T> or throws AppError only                │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│          API/Service Layer (HTTP, Hardware, etc)             │
│  - ApiService (Dio)                                          │
│  - Health Connect Service                                    │
│  - Local Storage Service                                     │
│                                                               │
│  ┌─────────────────────────────────────────────────┐       │
│  │         ApiErrorMapper (Single Conversion Point) │       │
│  │  - DioException → AppError                       │       │
│  │  - HTTP 4xx/5xx → Specific Error Types           │       │
│  │  - SocketException → NetworkError                │       │
│  │  - TimeoutException → TimeoutError               │       │
│  └─────────────────────────────────────────────────┘       │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                   Centralized Logging                        │
│  - AppErrorLogger (all errors logged here)                   │
│  - Stack traces (internal only)                              │
│  - Integration with: Firebase, Sentry, etc                   │
└──────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. AppError Sealed Class Hierarchy

All errors in the application extend the `AppError` sealed class. This provides type safety and ensures all errors have consistent structure.

```dart
sealed class AppError {
  final String message;
  final String? code;
  final StackTrace? stackTrace;
}
```

**Concrete Error Types:**

| Type | When Used | Properties | UI Action |
|------|-----------|-----------|-----------|
| **NetworkError** | No connectivity, socket errors | `isRetryable` | Show retry CTA |
| **UnauthorizedError** | Invalid token, 401 | `shouldLogout` | Force logout |
| **ForbiddenError** | Insufficient permissions, 403 | `requiredPermissions` | Show permission request |
| **NotFoundError** | Resource missing, 404 | `resourceType`, `resourceId` | Show not found message |
| **ValidationError** | Bad input, 400 | `fieldErrors` | Show inline field errors |
| **LocalValidationError** | Client-side validation | `fieldErrors` | Show inline field errors |
| **ServerError** | Server errors, 5xx | `statusCode`, `isRetryable` | Show retry option |
| **TimeoutError** | Request timeout | `timeout`, `isRetryable` | Show retry option |
| **UnknownError** | Unexpected errors | `originalException` | Show fallback message |

### 2. ApiErrorMapper

Single point of conversion from HTTP responses and exceptions to domain errors.

```dart
// Converts HTTP response
ApiErrorMapper.fromResponse(response)

// Converts exceptions
ApiErrorMapper.fromException(error)
```

**HTTP Mapping Rules:**

```
400 → ValidationError
401 → UnauthorizedError
403 → ForbiddenError
404 → NotFoundError
408 → TimeoutError
5xx → ServerError
```

### 3. ErrorMessageResolver

Converts AppError instances to human-readable, localized messages suitable for UI display.

```dart
// Get user-facing message
String message = ErrorMessageResolver.resolve(error, context);

// Get title for dialogs
String title = ErrorMessageResolver.getErrorTitle(error, context);

// Get brief message for snackbars
String brief = ErrorMessageResolver.getBriefMessage(error, context);
```

**Features:**
- Non-technical language
- Localization-ready (uses `AppLocalizations`)
- Stack traces never shown to user
- Backend error messages normalized

### 4. AppErrorLogger

Centralized logging for all errors. Handles severity levels and integration with logging backends.

```dart
// Log with default severity
AppErrorLogger.logError(
  error,
  source: 'LoginRepository.login',
  severity: ErrorSeverity.medium,
  additionalData: {'retryCount': 3},
);

// Log critical error
AppErrorLogger.logCritical(
  error,
  source: 'AuthService.refresh',
);
```

**Severity Levels:**
- `low`: Debug information
- `medium`: Non-critical business logic failures
- `high`: Critical errors requiring user action
- `critical`: System failures, should not happen

**Logged Information:**
- Error type, code, and message
- Type-specific metadata
- Stack traces (internal only)
- Source location
- Timestamp
- Custom metadata

**Integration Points:**
- Firebase Crashlytics
- Sentry
- Custom analytics
- Local console (development)

### 5. Result<T> Type

Optional value wrapper for functions that can fail:

```dart
sealed class Result<T> {
  // Success case
  Success(T value)
  
  // Failure case
  Failure(AppError error)
}

// Usage
final result = _validateForm(data);
result.fold(
  onSuccess: (data) => saveData(data),
  onFailure: (error) => showError(error),
);
```

## Implementation Guidelines

### Repository Layer

Repositories are the boundary between low-level exceptions and domain errors.

**Rules:**
1. **Catch all exceptions** at repository methods
2. **Convert to AppError** using ApiErrorMapper or creating directly
3. **Log errors** via AppErrorLogger
4. **Throw only AppError** (never raw DioException, SocketException, etc)

**Example:**

```dart
class ObservationRepository {
  Future<List<Observation>> getObservations() async {
    try {
      final response = await _dio.get('/observations');
      return _parseObservations(response.data);
    } on DioException catch (e, st) {
      // Convert to domain error
      final error = ApiErrorMapper.fromException(e, stackTrace: st);
      
      // Log for observability
      AppErrorLogger.logError(error, source: 'ObservationRepository.get');
      
      // Throw domain error (no raw exceptions escape)
      throw error;
    } catch (e, st) {
      // Unexpected error
      final error = UnknownError(
        'Failed to fetch observations',
        code: 'FETCH_ERROR',
        stackTrace: st,
      );
      AppErrorLogger.logError(error, source: 'ObservationRepository.get');
      throw error;
    }
  }
}
```

### Service Layer

Services use the same pattern. Wrap low-level errors immediately.

```dart
class HealthSyncService {
  Future<SyncResult> sync(List<Observation> obs) async {
    try {
      // Sync logic
      return SyncResult.success();
    } on NetworkException catch (e, st) {
      throw ApiErrorMapper.fromException(e, stackTrace: st);
    } on TimeoutException catch (e, st) {
      throw TimeoutError(
        'Sync took too long',
        timeout: Duration(seconds: 30),
        stackTrace: st,
      );
    }
  }
}
```

### UI Layer

UI never interprets error codes directly. Always use ErrorMessageResolver.

**Pattern:**

```dart
void _handleLogin() async {
  try {
    await _authRepository.login(email, password);
    // Navigate on success
  } on LocalValidationError catch (e) {
    // Show field errors
    _showFieldErrors(e.fieldErrors);
  } on UnauthorizedError catch (e) {
    // Show snackbar
    _showSnackbar(ErrorMessageResolver.resolve(e, context));
  } on NetworkError catch (e) {
    // Show snackbar with retry
    _showSnackbarWithRetry(
      ErrorMessageResolver.resolve(e, context),
      onRetry: _handleLogin,
    );
  } on AppError catch (e) {
    // Generic error dialog
    _showErrorDialog(ErrorMessageResolver.resolve(e, context));
  }
}
```

### State Management (Riverpod)

When using state notifiers:

```dart
class AuthNotifier extends StateNotifier<AuthState> {
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _repository.login(email, password);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: result,
      );
    } on AppError catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e, // Store AppError in state
      );
      // UI reads state.error and shows it
    }
  }
}

// In widget:
class LoginScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    
    // Handle error stored in state
    if (auth.error != null) {
      _showError(context, auth.error);
    }
    
    return ...;
  }
}
```

## Usage Examples

### Login Flow

```dart
class LoginRepositoryExample {
  Future<LoginResult> login(String email, String password) async {
    try {
      // Validate locally first
      _validateCredentials(email, password);
      
      // API call
      final response = await _dio.post('/auth/login', data: {...});
      return LoginResult.fromJson(response.data);
      
    } on LocalValidationError {
      // Re-throw for UI to show field errors
      rethrow;
    } on DioException catch (e, st) {
      // Convert to domain error
      final error = ApiErrorMapper.fromException(e, stackTrace: st);
      AppErrorLogger.logError(
        error,
        source: 'LoginRepository.login',
        severity: ErrorSeverity.medium,
      );
      throw error;
    }
  }
  
  void _validateCredentials(String email, String password) {
    final errors = <String, List<String>>{};
    
    if (!_isValidEmail(email)) {
      errors['email'] = ['Invalid email format'];
    }
    if (password.length < 6) {
      errors['password'] = ['Minimum 6 characters'];
    }
    
    if (errors.isNotEmpty) {
      throw LocalValidationError(
        'Please fix errors',
        code: 'LOGIN_VALIDATION',
        fieldErrors: errors,
      );
    }
  }
}
```

### Observation Sync with Retry

```dart
Future<void> syncObservations() async {
  const maxRetries = 3;
  var attempts = 0;
  
  while (attempts < maxRetries) {
    try {
      await _repository.submitObservations(observations);
      return; // Success
      
    } on NetworkError catch (e) {
      attempts++;
      if (!e.isRetryable || attempts >= maxRetries) {
        AppErrorLogger.logError(
          e,
          source: 'ObservationSync',
          severity: ErrorSeverity.high,
          additionalData: {'attempts': attempts},
        );
        rethrow;
      }
      // Exponential backoff
      await Future.delayed(Duration(seconds: pow(2, attempts).toInt() as int));
      
    } on UnauthorizedError catch (e) {
      // Don't retry - force logout
      AppErrorLogger.logCritical(e, source: 'ObservationSync');
      await _logoutUser();
      rethrow;
      
    } on AppError catch (e) {
      AppErrorLogger.logError(e, source: 'ObservationSync');
      rethrow;
    }
  }
}
```

### Form Validation

```dart
// Local validation during form interaction
LocalValidationError? validateEmail(String email) {
  if (email.isEmpty) {
    return LocalValidationError(
      'Email is required',
      code: 'EMAIL_REQUIRED',
      fieldErrors: {'email': ['Email is required']},
    );
  }
  if (!_isValidEmail(email)) {
    return LocalValidationError(
      'Invalid email format',
      code: 'EMAIL_INVALID',
      fieldErrors: {'email': ['Invalid email format']},
    );
  }
  return null;
}

// In UI
final error = validateEmail(_emailController.text);
if (error != null) {
  setState(() => _emailError = error.getFieldError('email'));
} else {
  setState(() => _emailError = null);
}
```

## Error Handling Checklist

Use this checklist when implementing error handling in new features:

- [ ] **Repository**: All exceptions caught and converted to AppError
- [ ] **Repository**: All errors logged via AppErrorLogger
- [ ] **Repository**: No raw exceptions reach UI layer
- [ ] **Validation**: Local validation throws LocalValidationError with fieldErrors
- [ ] **Validation**: API validation throws ValidationError with fieldErrors
- [ ] **Auth**: UnauthorizedError triggers logout
- [ ] **Network**: NetworkError has isRetryable flag
- [ ] **UI**: Uses ErrorMessageResolver for messages
- [ ] **UI**: Shows field errors for ValidationError
- [ ] **UI**: Shows retry CTA for NetworkError
- [ ] **UI**: Never parses HTTP status codes
- [ ] **UI**: Never accesses stack traces
- [ ] **Logging**: Critical errors logged with ErrorSeverity.critical
- [ ] **Logging**: Source location always provided
- [ ] **Testing**: Each error type tested independently

## Testing Error Handling

### Unit Test Example

```dart
void main() {
  group('ObservationRepository', () {
    test('converts DioException to NetworkError', () async {
      // Arrange
      final dio = MockDio();
      dio.onError = DioException(
        error: SocketException('Connection refused'),
        type: DioExceptionType.connectionError,
      );
      
      // Act & Assert
      expect(
        () => ObservationRepository(dio).getObservations(),
        throwsA(isA<NetworkError>()),
      );
    });
    
    test('validation errors include field errors', () async {
      // Arrange
      final repository = ObservationRepository();
      
      // Act & Assert
      expect(
        () => repository.login('invalid@', '123'),
        throwsA(
          isA<LocalValidationError>().having(
            (e) => e.hasFieldError('email'),
            'has email error',
            true,
          ),
        ),
      );
    });
  });
}
```

## Best Practices

### ✅ DO

- Convert exceptions at repository boundary
- Log all errors centrally
- Use specific error types (not just UnknownError)
- Include field errors in ValidationError
- Provide source location in logs
- Use ErrorMessageResolver for UI messages
- Implement retry logic for NetworkError
- Test error paths thoroughly

### ❌ DON'T

- Let raw exceptions escape repositories
- Parse HTTP status codes in UI
- Show stack traces to users
- Use generic "Error" messages
- Swallow errors silently
- Log in multiple places
- Create custom exception types
- Assume error types without checking

## Integration with Logging Services

### Firebase Crashlytics

```dart
// In _sendToLogger
if (severity.index >= ErrorSeverity.high.index) {
  FirebaseCrashlytics.instance.recordError(
    logEntry['errorMessage'],
    StackTrace.fromString(logEntry['stackTrace'] ?? ''),
    reason: logEntry['errorType'],
    fatal: severity == ErrorSeverity.critical,
  );
}
```

### Sentry

```dart
// In _sendToLogger
Sentry.captureException(
  Exception(logEntry['errorMessage']),
  stackTrace: logEntry['stackTrace'] != null 
    ? StackTrace.fromString(logEntry['stackTrace'])
    : null,
  withScope: (scope) {
    scope.setTag('errorType', logEntry['errorType']);
    scope.setTag('source', logEntry['source']);
  },
);
```

## Migration Path

Migrating existing code to new error handling:

1. **Phase 1**: Define error types (AppError hierarchy)
2. **Phase 2**: Create ApiErrorMapper and ErrorMessageResolver
3. **Phase 3**: Update repositories one by one
4. **Phase 4**: Update UI screens
5. **Phase 5**: Setup centralized logging
6. **Phase 6**: Remove old error handling code

## Troubleshooting

### "Raw DioException reaches UI"

**Problem**: DioException thrown from repository

**Solution**: Wrap in try-catch at repository:
```dart
try {
  await _dio.post(...);
} on DioException catch (e, st) {
  throw ApiErrorMapper.fromException(e, stackTrace: st);
}
```

### "Error message is too technical"

**Problem**: Backend error message shown directly

**Solution**: Use ErrorMessageResolver:
```dart
// Instead of:
ScaffoldMessenger.showSnackBar(SnackBar(text: error.message));

// Do:
ScaffoldMessenger.showSnackBar(
  SnackBar(text: ErrorMessageResolver.resolve(error, context)),
);
```

### "Retry logic too complex"

**Problem**: Manual retry handling in UI

**Solution**: Implement in repository:
```dart
Future<T> _retryable<T>(Future<T> Function() fn) async {
  for (int i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } on NetworkError catch (e) {
      if (i == maxRetries - 1) rethrow;
      await Future.delayed(Duration(seconds: 2 * (i + 1)));
    }
  }
}
```

## References

- **Dart sealed classes**: https://dart.dev/language/class-modifiers#sealed
- **Riverpod state management**: https://riverpod.dev
- **Error handling patterns**: https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html

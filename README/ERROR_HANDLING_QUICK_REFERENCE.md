# Error Handling Quick Reference

## Quick Start

### 1. Import error handling
```dart
import 'package:phr_app/core/errors/errors.dart';
```

### 2. In Repository
```dart
Future<Data> fetchData() async {
  try {
    final response = await _dio.get('/data');
    return Data.fromJson(response.data);
  } on DioException catch (e, st) {
    // Convert to domain error
    final error = ApiErrorMapper.fromException(e, stackTrace: st);
    // Log it
    AppErrorLogger.logError(error, source: 'Repository.fetchData');
    // Throw (never raw exceptions)
    throw error;
  }
}
```

### 3. In UI
```dart
try {
  final data = await _repository.fetchData();
} on ValidationError catch (e) {
  _showFieldErrors(e.fieldErrors);
} on NetworkError catch (e) {
  _showSnackbar(ErrorMessageResolver.resolve(e, context));
} on AppError catch (e) {
  _showDialog(ErrorMessageResolver.resolve(e, context));
}
```

## Error Types Reference

| Error | Use When | Metadata | UI Action |
|-------|----------|----------|-----------|
| `NetworkError` | No internet, socket exception | `isRetryable` | Retry button |
| `UnauthorizedError` | 401, token expired | `shouldLogout` | Force logout |
| `ForbiddenError` | 403, permissions denied | `requiredPermissions` | Request permission |
| `NotFoundError` | 404, resource missing | `resourceType`, `resourceId` | Show not found |
| `ValidationError` | 400, API validation | `fieldErrors` | Show field errors |
| `LocalValidationError` | Client-side validation | `fieldErrors` | Show field errors |
| `ServerError` | 5xx, backend error | `statusCode`, `isRetryable` | Retry button |
| `TimeoutError` | Request timeout | `timeout`, `isRetryable` | Retry button |
| `UnknownError` | Unexpected error | `originalException` | Fallback dialog |

## Common Patterns

### Validation with Field Errors
```dart
Future<void> register(String email, String password) async {
  try {
    _validateInput(email, password); // Can throw LocalValidationError
    await _apiService.register(email, password); // Can throw ValidationError
  } on LocalValidationError catch (e) {
    // Client-side validation failed
    showFieldErrors(e.fieldErrors);
  } on ValidationError catch (e) {
    // Server-side validation failed
    showFieldErrors(e.fieldErrors);
  }
}

void _validateInput(String email, String password) {
  final errors = <String, List<String>>{};
  
  if (email.isEmpty) {
    errors['email'] = ['Email is required'];
  }
  if (password.length < 8) {
    errors['password'] = ['Minimum 8 characters'];
  }
  
  if (errors.isNotEmpty) {
    throw LocalValidationError(
      'Please fix the errors',
      code: 'VALIDATION_ERROR',
      fieldErrors: errors,
    );
  }
}
```

### Retry with Exponential Backoff
```dart
Future<T> retryWithBackoff<T>(
  Future<T> Function() operation,
  {int maxRetries = 3}
) async {
  for (int attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await operation();
    } on NetworkError catch (e) {
      if (!e.isRetryable || attempt == maxRetries - 1) rethrow;
      
      final delaySeconds = pow(2, attempt).toInt();
      await Future.delayed(Duration(seconds: delaySeconds));
    }
  }
}
```

### Handling Auth Errors
```dart
Future<void> someAuthOperation() async {
  try {
    await _repository.sensitiveOperation();
  } on UnauthorizedError catch (e) {
    // Token expired, force logout
    if (e.shouldLogout) {
      await _logout();
      navigateToLogin();
    }
  }
}
```

### Show Error Messages in UI
```dart
void _showError(BuildContext context, AppError error) {
  final message = ErrorMessageResolver.resolve(error, context);
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
```

### Log Errors Centrally
```dart
// Automatic (already done in repositories)
AppErrorLogger.logError(
  error,
  source: 'SomeRepository.method',
  severity: ErrorSeverity.medium,
);

// Critical errors
AppErrorLogger.logCritical(
  criticalError,
  source: 'AuthService.refresh',
);
```

## Do's and Don'ts

✅ **DO**
- Use `AppError` subclasses
- Log at repository boundary
- Convert exceptions immediately
- Use `ErrorMessageResolver` in UI
- Handle specific error types
- Include stack traces in logs only

❌ **DON'T**
- Throw raw `DioException`
- Let exceptions escape repositories
- Parse HTTP codes in UI
- Show stack traces to users
- Create custom exception types
- Swallow errors silently

## Type Safety

```dart
// Type-safe error handling with Result
Result<UserData> getUser() {
  // Returns either Success(userData) or Failure(appError)
}

// Usage
final result = getUser();
result.fold(
  onSuccess: (user) => print('User: $user'),
  onFailure: (error) => print('Error: $error'),
);
```

## Logging Severity

```dart
ErrorSeverity.low       // Debug info
ErrorSeverity.medium    // Non-critical failures
ErrorSeverity.high      // Critical errors
ErrorSeverity.critical  // System failures
```

## Field Error Helpers

```dart
ValidationError error = ...;

// Get specific field error
String? emailError = error.getFieldError('email');

// Check if field has error
bool hasError = error.hasFieldError('password');

// Access all errors
Map<String, List<String>>? allErrors = error.fieldErrors;
```

## Integration Checklist

When implementing error handling in a new feature:

- [ ] Repository catches all exceptions
- [ ] Repository throws only AppError
- [ ] Repository logs errors
- [ ] UI uses ErrorMessageResolver
- [ ] UI shows field errors for validation
- [ ] UI shows retry for network errors
- [ ] No HTTP codes in UI logic
- [ ] UnauthorizedError triggers logout
- [ ] Tests verify error types

## Common Mistakes

### ❌ Showing raw exceptions
```dart
// WRONG
ScaffoldMessenger.showSnackBar(
  SnackBar(text: error.toString())
);

// RIGHT
ScaffoldMessenger.showSnackBar(
  SnackBar(text: ErrorMessageResolver.resolve(error, context))
);
```

### ❌ Parsing HTTP codes in UI
```dart
// WRONG
if (error is DioException && error.response?.statusCode == 401) {
  logout();
}

// RIGHT
if (error is UnauthorizedError) {
  logout();
}
```

### ❌ Multiple logging
```dart
// WRONG
print('Error: $e');
debugPrint('Error: $e');
_analytics.logError(e);

// RIGHT
AppErrorLogger.logError(e, source: 'MyRepository.method');
// Logging backend receives the error
```

### ❌ Losing stack traces
```dart
// WRONG
try {
  await operation();
} catch (e) {
  throw UnknownError(e.toString()); // No stack trace
}

// RIGHT
try {
  await operation();
} catch (e, st) {
  throw UnknownError(
    e.toString(),
    stackTrace: st, // Preserve stack trace
  );
}
```

## Useful Imports

```dart
// Main error handling
import 'core/errors/errors.dart';

// If you need specific components
import 'core/errors/app_error.dart';
import 'core/errors/api_error_mapper.dart';
import 'core/errors/error_message_resolver.dart';
import 'core/errors/app_error_logger.dart';
import 'core/errors/result.dart';
```

## Next Steps

1. Read [ERROR_HANDLING_GUIDE.md](ERROR_HANDLING_GUIDE.md) for complete documentation
2. Review examples in `core/errors/error_handling_examples.dart`
3. Migrate existing repositories one by one
4. Setup logging backend integration
5. Add tests for error paths

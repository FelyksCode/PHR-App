# 🛡️ Error Handling System - One-Page Summary

## The 4-Layer Architecture

```
┌────────────────────────────────┐
│   UI LAYER                     │
│   Show user-friendly messages  │
│   via ErrorMessageResolver     │
└────────────────┬───────────────┘
                 │
         ┌───────▼────────┐
         │ State Mgmt     │
         │ (Riverpod)     │
         └───────┬────────┘
                 │
    ┌────────────▼────────────┐
    │  Repository Layer       │
    │  Convert → Log → Throw  │
    └────────────┬────────────┘
                 │
      ┌──────────▼──────────┐
      │ API Layer (Dio)     │
      │ Throws raw          │
      │ exceptions          │
      └─────────────────────┘
```

## The 5-Step Error Flow

```
1. Exception Occurs
   ↓
2. Repository catches it
   ↓
3. ApiErrorMapper converts to AppError
   ↓
4. AppErrorLogger logs it
   ↓
5. UI shows user-friendly message
```

## 9 Error Types

```
🌐 NetworkError      ← No internet, socket error
🔐 UnauthorizedError ← 401, token expired (→ logout)
🚫 ForbiddenError    ← 403, no permission
❓ NotFoundError     ← 404, resource missing
⚠️ ValidationError    ← 400, API validation
📝 LocalValidation   ← Client-side validation
💥 ServerError       ← 5xx, backend error
⏰ TimeoutError      ← 408, request timeout
❌ UnknownError      ← Unexpected error
```

## HTTP Status Code Mapping

```
400 → ValidationError
401 → UnauthorizedError (triggers logout!)
403 → ForbiddenError
404 → NotFoundError
408 → TimeoutError
5xx → ServerError
N/A → NetworkError or UnknownError
```

## Import Everything With One Line

```dart
import 'core/errors/errors.dart';
```

## 3-Step Implementation Pattern

### Step 1: Repository
```dart
try {
  final response = await _dio.get('/api/data');
  return Data.fromJson(response.data);
} on DioException catch (e, st) {
  final error = ApiErrorMapper.fromException(e, stackTrace: st);
  AppErrorLogger.logError(error, source: 'MyRepository.getData');
  throw error; // Only AppError escapes!
}
```

### Step 2: State Management
```dart
Future<void> getData() async {
  try {
    final data = await _repository.getData();
    state = state.copyWith(data: data);
  } on AppError catch (e) {
    state = state.copyWith(error: e); // Store in state
  }
}
```

### Step 3: UI
```dart
if (state.error != null) {
  showSnackBar(
    ErrorMessageResolver.resolve(state.error!, context)
  );
}
```

## Error Handling Checklist

- [ ] Catch exceptions in repository
- [ ] Convert with ApiErrorMapper
- [ ] Log with AppErrorLogger
- [ ] Throw only AppError
- [ ] Catch in state management
- [ ] Store error in state
- [ ] Show with ErrorMessageResolver
- [ ] Never show stack traces
- [ ] Never parse HTTP codes in UI
- [ ] Test error paths

## What NOT to Do ❌

```dart
// ❌ DON'T: Show raw exception
ScaffoldMessenger.showSnackBar(SnackBar(text: e.toString()));

// ✅ DO: Use ErrorMessageResolver
ScaffoldMessenger.showSnackBar(
  SnackBar(text: ErrorMessageResolver.resolve(error, context))
);

// ❌ DON'T: Let DioException escape repository
throw error; // if error is DioException

// ✅ DO: Convert to AppError
throw ApiErrorMapper.fromException(error);

// ❌ DON'T: Parse HTTP codes in UI
if (error is DioException && error.response?.statusCode == 401)

// ✅ DO: Check error type
if (error is UnauthorizedError)

// ❌ DON'T: Multiple error logging
print('Error: $e');
logError(e);
analytics.logError(e);

// ✅ DO: Single point
AppErrorLogger.logError(error, source: 'Repository.method');
```

## Field Validation Errors

```dart
// Create with field errors
throw LocalValidationError(
  'Please fix the errors',
  fieldErrors: {
    'email': ['Invalid format'],
    'password': ['Too short'],
  }
);

// Use in UI
if (error is ValidationError) {
  final emailError = error.getFieldError('email');
  final hasPasswordError = error.hasFieldError('password');
}
```

## Retry Logic

```dart
Future<void> syncWithRetry() async {
  for (int i = 0; i < 3; i++) {
    try {
      await _sync();
      return; // Success!
    } on NetworkError catch (e) {
      if (!e.isRetryable) rethrow;
      if (i == 2) rethrow; // Last attempt
      await Future.delayed(Duration(seconds: pow(2, i).toInt()));
    }
  }
}
```

## Logging Levels

```
ErrorSeverity.low       → Debug info
ErrorSeverity.medium    → Non-critical failures
ErrorSeverity.high      → Critical errors
ErrorSeverity.critical  → System failures
```

## Files Created

```
lib/core/errors/
├── app_error.dart                    (9 error types)
├── api_error_mapper.dart             (Conversion)
├── error_message_resolver.dart       (Messaging)
├── app_error_logger.dart             (Logging)
├── result.dart                       (Wrapper type)
├── errors.dart                       (Exports)
├── error_handling_examples.dart      (Examples)
└── auth_flow_integration_example.dart (Full example)

Documentation/
├── README_ERROR_HANDLING.md          (This system)
├── ERROR_HANDLING_GUIDE.md           (900+ line guide)
├── ERROR_HANDLING_QUICK_REFERENCE.md (Quick patterns)
├── ERROR_HANDLING_FLOW_DIAGRAMS.md   (8 flowcharts)
└── IMPLEMENTATION_CHECKLIST.md       (Step-by-step)
```

## One-Minute Quick Start

```dart
// 1. Import
import 'core/errors/errors.dart';

// 2. In repository: convert exceptions
try {
  return await api.call();
} on DioException catch (e, st) {
  throw ApiErrorMapper.fromException(e, stackTrace: st);
}

// 3. In state: catch and store
try {
  final data = await repo.getData();
  state = state.copyWith(data: data);
} on AppError catch (e) {
  state = state.copyWith(error: e);
}

// 4. In UI: show message
Text(ErrorMessageResolver.resolve(state.error!, context))
```

## Common Errors and Fixes

| Problem | Fix |
|---------|-----|
| DioException reaches UI | Catch in repository, convert with ApiErrorMapper |
| Raw error message shown | Use ErrorMessageResolver |
| Field errors not visible | Check error type: is ValidationError |
| Retry button not shown | Check: error is NetworkError && error.isRetryable |
| User stays logged in after 401 | UnauthorizedError should auto-logout in state |
| Error not logged | Add AppErrorLogger.logError() call |
| Wrong message shown | Verify ErrorMessageResolver has case for error type |

## Ask These Questions

When implementing error handling:

1. What exceptions can this method throw?
2. Am I converting all of them to AppError?
3. Am I logging the error?
4. Is the error type specific enough?
5. Do I have metadata (field errors, retry flag)?
6. Is the UI catching AppError?
7. Am I using ErrorMessageResolver?
8. Does the message make sense to users?

## Success Metrics ✅

- [ ] 0 raw exceptions reach UI
- [ ] All errors logged
- [ ] User-friendly messages
- [ ] Field errors shown inline
- [ ] Retry for retryable errors
- [ ] Auto-logout on 401
- [ ] No HTTP codes in UI
- [ ] Tests pass

## Pro Tips 💡

1. **Field Errors First**: Check hasFieldError() before showing general message
2. **Retry Backoff**: Use 2^n seconds (2, 4, 8, 16...)
3. **User Messages**: Plain language, no "DioException" or "SocketException"
4. **Logging Source**: Always include source: 'Repository.methodName'
5. **Stack Traces**: Keep them in logs, never show to users
6. **Testing**: Mock service to throw DioException, verify AppError
7. **Gradual Migration**: Do one repository at a time
8. **Documentation**: Update docstrings about what AppErrors can be thrown

## Related Files

- `ERROR_HANDLING_GUIDE.md` - Complete reference (read this!)
- `ERROR_HANDLING_QUICK_REFERENCE.md` - Common patterns
- `ERROR_HANDLING_FLOW_DIAGRAMS.md` - Visual explanations
- `IMPLEMENTATION_CHECKLIST.md` - Step-by-step guide
- `error_handling_examples.dart` - 5 full examples
- `auth_flow_integration_example.dart` - Auth implementation

---

**Remember**: ✨ *One conversion point, one log point, one message source* ✨

**Keep errors structured. Keep users informed. Keep logs clean.**

---

Print this page and keep it handy! 📌

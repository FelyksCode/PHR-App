# Implementation Checklist for Error Handling

## Phase 1: Review & Understanding (Day 1)

### Documentation Review
- [ ] Read `ERROR_HANDLING_IMPLEMENTATION_SUMMARY.md`
- [ ] Review `ERROR_HANDLING_GUIDE.md` (full reference)
- [ ] Skim `ERROR_HANDLING_QUICK_REFERENCE.md`
- [ ] Study `ERROR_HANDLING_FLOW_DIAGRAMS.md`
- [ ] Review example code in `lib/core/errors/error_handling_examples.dart`

### Code Review
- [ ] Examine `lib/core/errors/app_error.dart` (error types)
- [ ] Review `lib/core/errors/api_error_mapper.dart` (conversion logic)
- [ ] Check `lib/core/errors/error_message_resolver.dart` (messaging)
- [ ] Understand `lib/core/errors/app_error_logger.dart` (logging)
- [ ] Look at `lib/core/errors/result.dart` (optional wrapper type)

### Understanding Goals
- [ ] Can explain what AppError is (sealed class)
- [ ] Understand 9 error types and when to use each
- [ ] Know HTTP status code mappings
- [ ] Understand error flow: Exception → AppError → Message → UI
- [ ] Can draw the architecture diagram from memory

## Phase 2: Preparation (Day 2)

### Environment Setup
- [ ] Import error handling in build (already done)
- [ ] Verify all error files compile without errors
- [ ] Check that `errors.dart` exports work
- [ ] Verify ApiService has error handling methods
- [ ] Verify HealthSyncRepository has error handling

### Testing Preparation
- [ ] Setup mock Dio for testing
- [ ] Create test fixtures for different error scenarios
- [ ] Plan test coverage for each error type

### Documentation in Code
- [ ] Add comments explaining error handling pattern
- [ ] Document repository error contract
- [ ] Mark fields to show field errors

## Phase 3: Migrate Repositories One by One (Days 3-5)

For each repository, follow this pattern:

### Step 1: Add Imports
```dart
import 'core/errors/app_error.dart';
import 'core/errors/api_error_mapper.dart';
import 'core/errors/app_error_logger.dart';
```
- [ ] Imports added
- [ ] No IDE errors

### Step 2: Identify All Methods
```dart
// List all methods that can throw exceptions
- [ ] Method 1: description
- [ ] Method 2: description
- [ ] Method 3: description
```

### Step 3: Update Method by Method
For each method:

- [ ] Identify what exceptions it can throw
  - [ ] DioException
  - [ ] SocketException
  - [ ] Custom exceptions
  - [ ] Other

- [ ] Add try-catch block around low-level calls
  - [ ] Catch DioException
  - [ ] Catch local validation errors
  - [ ] Catch other exceptions

- [ ] Convert exceptions to AppError
  ```dart
  on DioException catch (e, st) {
    final error = ApiErrorMapper.fromException(e, stackTrace: st);
    AppErrorLogger.logError(error, source: 'RepositoryName.method');
    throw error;
  }
  ```
  - [ ] ApiErrorMapper used
  - [ ] AppErrorLogger called
  - [ ] Converted error thrown

- [ ] Update documentation comment
  ```dart
  /// Fetches data
  /// 
  /// Throws:
  ///   - NetworkError: No internet connection
  ///   - UnauthorizedError: Token expired (401)
  ///   - ServerError: Backend error (5xx)
  ///   - UnknownError: Unexpected error
  ```
  - [ ] Documented what AppError types can be thrown

- [ ] Run tests to verify
  - [ ] No runtime errors
  - [ ] Method still returns correct type
  - [ ] Error types are correct

### Step 4: After Each Repository
- [ ] All methods updated
- [ ] Code compiles
- [ ] No warnings
- [ ] Documentation complete
- [ ] Tests written for error paths

**Repositories to Update:**
- [ ] `AuthRepository`
- [ ] `HealthSyncRepository` (partially done)
- [ ] `ObservationRepository`
- [ ] Any other repositories with API calls

## Phase 4: Update UI Screens (Days 6-7)

For each screen that handles errors:

### Step 1: Identify Error Points
```dart
// List all places where errors occur
- [ ] Login button: can throw UnauthorizedError, ValidationError
- [ ] Data fetch: can throw NetworkError, ServerError
- [ ] Form validation: LocalValidationError
```

### Step 2: Update Error Handling
```dart
try {
  await _repository.method();
} on LocalValidationError catch (e) {
  _showFieldErrors(e.fieldErrors);
} on NetworkError catch (e) {
  _showSnackbarWithRetry(ErrorMessageResolver.resolve(e, context));
} on AppError catch (e) {
  _showErrorDialog(ErrorMessageResolver.resolve(e, context));
}
```

### Step 3: Update State Management
```dart
// If using Riverpod/StateNotifier
class MyNotifier extends StateNotifier<MyState> {
  Future<void> method() async {
    try {
      final result = await _repository.method();
      state = state.copyWith(data: result);
    } on AppError catch (e) {
      state = state.copyWith(error: e);
    }
  }
}
```

### Step 4: Update UI Display
```dart
// Show errors from state
if (state.error != null) {
  _showError(state.error!);
}

// Never show raw exception messages
// WRONG: Text(error.toString())
// RIGHT: Text(ErrorMessageResolver.resolve(error, context))
```

- [ ] Catches AppError (not specific exceptions)
- [ ] Uses ErrorMessageResolver for messages
- [ ] Shows field errors for ValidationError
- [ ] Shows retry for NetworkError
- [ ] Never parses HTTP codes
- [ ] No stack traces shown

**Screens to Update:**
- [ ] Login screen
- [ ] Registration screen
- [ ] Data fetch screens
- [ ] Form screens
- [ ] Any screen with API calls

## Phase 5: Setup Logging Integration (Day 8)

### Firebase Crashlytics Setup
- [ ] Firebase initialized
- [ ] Crashlytics dependency added
- [ ] Update `AppErrorLogger._sendToLogger()`
  ```dart
  if (severity.index >= ErrorSeverity.high.index) {
    FirebaseCrashlytics.instance.recordError(...);
  }
  ```
- [ ] Test with a critical error
- [ ] Verify error appears in Firebase console

### Alternative: Sentry Setup
- [ ] Sentry project created
- [ ] Sentry dependency added
- [ ] Update `AppErrorLogger._sendToLogger()`
  ```dart
  Sentry.captureException(...);
  ```
- [ ] Test with an error
- [ ] Verify error appears in Sentry dashboard

### Local Testing
- [ ] Run app and trigger different error types
- [ ] Check console output matches expected format
- [ ] Verify all error metadata is logged
- [ ] Check timestamp and source information

## Phase 6: Testing (Day 9)

### Unit Tests for Error Conversion
```dart
test('DioException with 401 → UnauthorizedError', () {
  // Arrange
  final dio = MockDio();
  dio.onError = DioException(response: Response(statusCode: 401));
  
  // Act & Assert
  expect(
    () => repository.login('', ''),
    throwsA(isA<UnauthorizedError>()),
  );
});
```

- [ ] Test 400 → ValidationError
- [ ] Test 401 → UnauthorizedError
- [ ] Test 403 → ForbiddenError
- [ ] Test 404 → NotFoundError
- [ ] Test 408 → TimeoutError
- [ ] Test 5xx → ServerError
- [ ] Test socket exception → NetworkError
- [ ] Test unexpected exception → UnknownError

### Field Error Tests
```dart
test('ValidationError includes field errors', () {
  // Verify fieldErrors map populated correctly
});
```

- [ ] Field errors extracted correctly
- [ ] Field error format correct
- [ ] getFieldError() works
- [ ] hasFieldError() works

### UI Tests
```dart
test('Shows field errors for ValidationError', () {
  // Verify UI shows field-level errors
});

test('Shows retry button for NetworkError', () {
  // Verify retry button only for retryable
});
```

- [ ] Validation errors show fields
- [ ] Network errors show retry
- [ ] Unauthorized triggers logout
- [ ] Error messages are user-friendly

### Integration Tests
- [ ] Full login flow with error
- [ ] Data sync with network error and retry
- [ ] Form submission with validation error
- [ ] Session expiration (UnauthorizedError)

## Phase 7: Documentation & Knowledge Transfer (Day 10)

### Internal Documentation
- [ ] Add team notes to ERROR_HANDLING_GUIDE.md
- [ ] Document any customizations
- [ ] Add examples specific to your app
- [ ] Document logging backend setup

### Team Communication
- [ ] Brief team on error handling system
- [ ] Share quick reference document
- [ ] Answer questions
- [ ] Get feedback

### Feedback Loop
- [ ] Collect issues/questions from team
- [ ] Update documentation based on feedback
- [ ] Create FAQ section if needed
- [ ] Share learnings with team

## Acceptance Criteria Verification

### Architecture
- [ ] No raw DioException escapes repository ✓
- [ ] All exceptions logged ✓
- [ ] Single conversion point (ApiErrorMapper) ✓
- [ ] Single logging point (AppErrorLogger) ✓
- [ ] Single messaging point (ErrorMessageResolver) ✓

### Error Types
- [ ] 8+ specific error types defined ✓
- [ ] Each has appropriate metadata ✓
- [ ] HTTP codes mapped correctly ✓
- [ ] Retryable flags set ✓

### Logging
- [ ] All errors logged with source ✓
- [ ] Severity levels used correctly ✓
- [ ] Stack traces preserved internally ✓
- [ ] Integration point ready for Firebase/Sentry ✓

### UI
- [ ] No HTTP codes in UI logic ✓
- [ ] No raw error messages shown ✓
- [ ] Field errors displayed inline ✓
- [ ] Retry options for retryable errors ✓
- [ ] Auto-logout on UnauthorizedError ✓

### Validation
- [ ] Local validation errors for client-side ✓
- [ ] API validation errors with field errors ✓
- [ ] Field error helpers work ✓
- [ ] Both error types tested ✓

### Testing
- [ ] Each error type tested ✓
- [ ] Error conversions tested ✓
- [ ] UI error handling tested ✓
- [ ] End-to-end flows tested ✓

## Maintenance Checklist

### Monthly
- [ ] Review error logs for patterns
- [ ] Check for unhandled error types
- [ ] Update messages if needed
- [ ] Update severity levels if needed

### Per Feature
- [ ] New endpoints have error handling
- [ ] New error types documented
- [ ] Tests added for error paths
- [ ] UI handles specific error types

### Quarterly
- [ ] Review error handling across codebase
- [ ] Update documentation
- [ ] Share learnings with team
- [ ] Consider improvements

## Troubleshooting During Implementation

### Issue: "Type 'DioException' is not a subtype of 'AppError'"
**Solution**: Make sure you're catching DioException before throwing AppError
```dart
try {
  await operation();
} on DioException catch (e, st) {
  throw ApiErrorMapper.fromException(e, stackTrace: st);
}
```

### Issue: "User sees raw exception message"
**Solution**: Check that ErrorMessageResolver is used in UI
```dart
// WRONG
ScaffoldMessenger.showSnackBar(SnackBar(text: error.message));

// RIGHT  
ScaffoldMessenger.showSnackBar(SnackBar(
  text: ErrorMessageResolver.resolve(error, context)
));
```

### Issue: "AppErrorLogger not logging anything"
**Solution**: Verify it's being called in repository
```dart
AppErrorLogger.logError(error, source: 'Repository.method');
```

### Issue: "Field errors not showing"
**Solution**: Check that error is LocalValidationError or ValidationError
```dart
if (error is ValidationError) {
  print(error.fieldErrors); // Should not be null
}
```

### Issue: "Logs don't reach Firebase"
**Solution**: Verify Firebase setup and update _sendToLogger
```dart
// In app_error_logger.dart, update _sendToLogger method
if (severity.index >= ErrorSeverity.high.index) {
  FirebaseCrashlytics.instance.recordError(...);
}
```

## Sign-Off Checklist

Complete this when done:

- [ ] All core error files created and compile
- [ ] ApiService updated with error handling
- [ ] At least 2 repositories migrated
- [ ] At least 2 screens updated to use new errors
- [ ] Tests written for error paths
- [ ] Documentation reviewed and understood
- [ ] Team briefed on system
- [ ] Ready for production use

**Estimated Timeline**: 10 working days for full implementation

**Quick Implementation** (errors only, no tests): 2-3 days
**Complete Implementation** (with tests and docs): 10 days
**Maintenance**: ~1 hour per week

## Next Steps After Completion

1. **Monitor**: Watch error logs for patterns
2. **Improve**: Add more specific error types as needed
3. **Expand**: Apply pattern to all repositories
4. **Optimize**: Fine-tune message text based on feedback
5. **Document**: Keep docs updated with learnings

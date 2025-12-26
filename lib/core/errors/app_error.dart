/// Base class for all application errors.
/// 
/// This sealed class ensures type-safe error handling throughout the app.
/// All errors in the application should extend this class.
sealed class AppError implements Exception {
  final String message;
  final String? code;
  final StackTrace? stackTrace;

  const AppError(
    this.message, {
    this.code,
    this.stackTrace,
  });

  /// Returns a copy of this error with updated fields
  AppError copyWith({
    String? message,
    String? code,
    StackTrace? stackTrace,
  });

  @override
  String toString() => 'AppError($code): $message';
}

/// Network-related errors (no connectivity, socket exceptions, etc.)
final class NetworkError extends AppError {
  final bool isRetryable;

  const NetworkError(
    String message, {
    String? code,
    StackTrace? stackTrace,
    this.isRetryable = true,
  }) : super(message, code: code, stackTrace: stackTrace);

  @override
  NetworkError copyWith({
    String? message,
    String? code,
    StackTrace? stackTrace,
    bool? isRetryable,
  }) {
    return NetworkError(
      message ?? this.message,
      code: code ?? this.code,
      stackTrace: stackTrace ?? this.stackTrace,
      isRetryable: isRetryable ?? this.isRetryable,
    );
  }
}

/// Authentication errors (invalid credentials, token expired, etc.)
final class UnauthorizedError extends AppError {
  final bool shouldLogout;

  const UnauthorizedError(
    String message, {
    String? code,
    StackTrace? stackTrace,
    this.shouldLogout = true,
  }) : super(message, code: code, stackTrace: stackTrace);

  @override
  UnauthorizedError copyWith({
    String? message,
    String? code,
    StackTrace? stackTrace,
    bool? shouldLogout,
  }) {
    return UnauthorizedError(
      message ?? this.message,
      code: code ?? this.code,
      stackTrace: stackTrace ?? this.stackTrace,
      shouldLogout: shouldLogout ?? this.shouldLogout,
    );
  }
}

/// Authorization errors (insufficient permissions)
final class ForbiddenError extends AppError {
  final List<String>? requiredPermissions;

  const ForbiddenError(
    String message, {
    String? code,
    StackTrace? stackTrace,
    this.requiredPermissions,
  }) : super(message, code: code, stackTrace: stackTrace);

  @override
  ForbiddenError copyWith({
    String? message,
    String? code,
    StackTrace? stackTrace,
    List<String>? requiredPermissions,
  }) {
    return ForbiddenError(
      message ?? this.message,
      code: code ?? this.code,
      stackTrace: stackTrace ?? this.stackTrace,
      requiredPermissions: requiredPermissions ?? this.requiredPermissions,
    );
  }
}

/// 404 Resource not found errors
final class NotFoundError extends AppError {
  final String? resourceType;
  final String? resourceId;

  const NotFoundError(
    String message, {
    String? code,
    StackTrace? stackTrace,
    this.resourceType,
    this.resourceId,
  }) : super(message, code: code, stackTrace: stackTrace);

  @override
  NotFoundError copyWith({
    String? message,
    String? code,
    StackTrace? stackTrace,
    String? resourceType,
    String? resourceId,
  }) {
    return NotFoundError(
      message ?? this.message,
      code: code ?? this.code,
      stackTrace: stackTrace ?? this.stackTrace,
      resourceType: resourceType ?? this.resourceType,
      resourceId: resourceId ?? this.resourceId,
    );
  }
}

/// Validation errors (400 Bad Request, form validation, etc.)
final class ValidationError extends AppError {
  final Map<String, List<String>>? fieldErrors;

  const ValidationError(
    String message, {
    String? code,
    StackTrace? stackTrace,
    this.fieldErrors,
  }) : super(message, code: code, stackTrace: stackTrace);

  /// Get error message for a specific field
  String? getFieldError(String fieldName) {
    return fieldErrors?[fieldName]?.first;
  }

  /// Check if a field has errors
  bool hasFieldError(String fieldName) {
    return fieldErrors?.containsKey(fieldName) ?? false;
  }

  @override
  ValidationError copyWith({
    String? message,
    String? code,
    StackTrace? stackTrace,
    Map<String, List<String>>? fieldErrors,
  }) {
    return ValidationError(
      message ?? this.message,
      code: code ?? this.code,
      stackTrace: stackTrace ?? this.stackTrace,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }
}

/// Server errors (5xx status codes)
final class ServerError extends AppError {
  final int? statusCode;
  final bool isRetryable;

  const ServerError(
    String message, {
    String? code,
    StackTrace? stackTrace,
    this.statusCode,
    this.isRetryable = true,
  }) : super(message, code: code, stackTrace: stackTrace);

  @override
  ServerError copyWith({
    String? message,
    String? code,
    StackTrace? stackTrace,
    int? statusCode,
    bool? isRetryable,
  }) {
    return ServerError(
      message ?? this.message,
      code: code ?? this.code,
      stackTrace: stackTrace ?? this.stackTrace,
      statusCode: statusCode ?? this.statusCode,
      isRetryable: isRetryable ?? this.isRetryable,
    );
  }
}

/// Request timeout errors
final class TimeoutError extends AppError {
  final Duration? timeout;
  final bool isRetryable;

  const TimeoutError(
    String message, {
    String? code,
    StackTrace? stackTrace,
    this.timeout,
    this.isRetryable = true,
  }) : super(message, code: code, stackTrace: stackTrace);

  @override
  TimeoutError copyWith({
    String? message,
    String? code,
    StackTrace? stackTrace,
    Duration? timeout,
    bool? isRetryable,
  }) {
    return TimeoutError(
      message ?? this.message,
      code: code ?? this.code,
      stackTrace: stackTrace ?? this.stackTrace,
      timeout: timeout ?? this.timeout,
      isRetryable: isRetryable ?? this.isRetryable,
    );
  }
}

/// Unknown or unexpected errors
final class UnknownError extends AppError {
  final dynamic originalException;

  const UnknownError(
    String message, {
    String? code,
    StackTrace? stackTrace,
    this.originalException,
  }) : super(message, code: code, stackTrace: stackTrace);

  @override
  UnknownError copyWith({
    String? message,
    String? code,
    StackTrace? stackTrace,
    dynamic originalException,
  }) {
    return UnknownError(
      message ?? this.message,
      code: code ?? this.code,
      stackTrace: stackTrace ?? this.stackTrace,
      originalException: originalException ?? this.originalException,
    );
  }
}

/// Local validation errors (form validation, business logic validation)
final class LocalValidationError extends AppError {
  final Map<String, List<String>>? fieldErrors;

  const LocalValidationError(
    String message, {
    String? code,
    StackTrace? stackTrace,
    this.fieldErrors,
  }) : super(message, code: code, stackTrace: stackTrace);

  /// Get error message for a specific field
  String? getFieldError(String fieldName) {
    return fieldErrors?[fieldName]?.first;
  }

  /// Check if a field has errors
  bool hasFieldError(String fieldName) {
    return fieldErrors?.containsKey(fieldName) ?? false;
  }

  @override
  LocalValidationError copyWith({
    String? message,
    String? code,
    StackTrace? stackTrace,
    Map<String, List<String>>? fieldErrors,
  }) {
    return LocalValidationError(
      message ?? this.message,
      code: code ?? this.code,
      stackTrace: stackTrace ?? this.stackTrace,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }
}

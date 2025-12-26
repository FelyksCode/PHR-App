import 'app_error.dart';

/// Severity levels for error logging
enum ErrorSeverity {
  low,
  medium,
  high,
  critical,
}

/// Centralized error logging system
/// 
/// This handles all error logging and reporting without UI involvement.
/// Logs include error type, code, and stack traces (internal only).
abstract class AppErrorLogger {
  /// Logs an error with appropriate severity
  static void logError(
    AppError error, {
    required String source,
    ErrorSeverity severity = ErrorSeverity.medium,
    Map<String, dynamic>? additionalData,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = _buildLogEntry(
      error: error,
      source: source,
      severity: severity,
      timestamp: timestamp,
      additionalData: additionalData,
    );

    _sendToLogger(logEntry, severity);
  }

  /// Logs a critical error that requires immediate attention
  static void logCritical(
    AppError error, {
    required String source,
    Map<String, dynamic>? additionalData,
  }) {
    logError(
      error,
      source: source,
      severity: ErrorSeverity.critical,
      additionalData: additionalData,
    );
  }

  /// Builds a structured log entry
  static Map<String, dynamic> _buildLogEntry({
    required AppError error,
    required String source,
    required ErrorSeverity severity,
    required String timestamp,
    Map<String, dynamic>? additionalData,
  }) {
    final baseEntry = {
      'timestamp': timestamp,
      'source': source,
      'severity': severity.name,
      'errorType': _getErrorTypeName(error),
      'errorCode': error.code,
      'errorMessage': error.message,
    };

    // Add type-specific metadata
    final typeSpecificData = _extractTypeSpecificData(error);

    // Add stack trace if available (internal logging only)
    if (error.stackTrace != null) {
      baseEntry['stackTrace'] = error.stackTrace.toString();
    }

    return {
      ...baseEntry,
      ...typeSpecificData,
      if (additionalData != null) ...additionalData,
    };
  }

  /// Extracts type-specific metadata from each error type
  static Map<String, dynamic> _extractTypeSpecificData(AppError error) {
    return switch (error) {
      NetworkError e => {
        'isRetryable': e.isRetryable,
      },
      UnauthorizedError e => {
        'shouldLogout': e.shouldLogout,
      },
      ForbiddenError e => {
        if (e.requiredPermissions != null)
          'requiredPermissions': e.requiredPermissions,
      },
      NotFoundError e => {
        if (e.resourceType != null) 'resourceType': e.resourceType,
        if (e.resourceId != null) 'resourceId': e.resourceId,
      },
      ValidationError e => {
        if (e.fieldErrors != null)
          'fieldErrorCount': e.fieldErrors!.length,
      },
      LocalValidationError e => {
        if (e.fieldErrors != null)
          'fieldErrorCount': e.fieldErrors!.length,
      },
      ServerError e => {
        'statusCode': e.statusCode,
        'isRetryable': e.isRetryable,
      },
      TimeoutError e => {
        'timeoutMs': e.timeout?.inMilliseconds,
        'isRetryable': e.isRetryable,
      },
      UnknownError e => {
        if (e.originalException != null)
          'originalExceptionType': e.originalException.runtimeType.toString(),
      },
    };
  }

  /// Gets a human-readable error type name
  static String _getErrorTypeName(AppError error) {
    return switch (error) {
      NetworkError _ => 'NetworkError',
      UnauthorizedError _ => 'UnauthorizedError',
      ForbiddenError _ => 'ForbiddenError',
      NotFoundError _ => 'NotFoundError',
      ValidationError _ => 'ValidationError',
      LocalValidationError _ => 'LocalValidationError',
      ServerError _ => 'ServerError',
      TimeoutError _ => 'TimeoutError',
      UnknownError _ => 'UnknownError',
    };
  }

  /// Sends the log entry to the actual logging backend
  /// 
  /// This is where you'd integrate with:
  /// - Firebase Crashlytics
  /// - Sentry
  /// - Custom analytics
  /// - Local logging
  static void _sendToLogger(
    Map<String, dynamic> logEntry,
    ErrorSeverity severity,
  ) {
    // TODO: Integrate with your preferred logging backend
    // Example implementations:
    
    // Firebase Crashlytics:
    // if (severity.index >= ErrorSeverity.high.index) {
    //   FirebaseCrashlytics.instance.recordError(
    //     logEntry['errorMessage'],
    //     logEntry['stackTrace'] != null ? StackTrace.fromString(logEntry['stackTrace']) : null,
    //   );
    // }

    // Sentry:
    // Sentry.captureException(
    //   logEntry['errorMessage'],
    //   stackTrace: logEntry['stackTrace'],
    // );

    // Local logging (development):
    _logToConsole(logEntry, severity);
  }

  /// Local console logging for development
  static void _logToConsole(
    Map<String, dynamic> logEntry,
    ErrorSeverity severity,
  ) {
    final prefix = _getSeverityPrefix(severity);
    print('$prefix [${logEntry['timestamp']}] ${logEntry['errorType']} '
        '(${logEntry['errorCode']}): ${logEntry['errorMessage']}');
    
    if (logEntry.containsKey('stackTrace')) {
      print('Stack trace:\n${logEntry['stackTrace']}');
    }
  }

  static String _getSeverityPrefix(ErrorSeverity severity) {
    return switch (severity) {
      ErrorSeverity.low => '📋',
      ErrorSeverity.medium => '⚠️',
      ErrorSeverity.high => '❌',
      ErrorSeverity.critical => '🚨',
    };
  }
}

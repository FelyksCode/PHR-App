import 'dart:io';
import 'package:dio/dio.dart';
import 'app_error.dart';

/// Maps low-level exceptions (Dio, Socket, etc.) to domain-level AppError.
/// 
/// This is the single point of conversion for all API and network errors.
/// No raw exceptions should leak past this mapper.
abstract class ApiErrorMapper {
  /// Converts a Dio response (successful or error) to AppError
  static AppError fromResponse(Response response) {
    final statusCode = response.statusCode ?? 0;
    final data = response.data;

    // Extract backend error message if available
    String? backendMessage;
    String? errorCode;

    if (data is Map<String, dynamic>) {
      backendMessage = data['message'] ??
          data['error'] ??
          data['errorMessage'] ??
          data['detail'];
      errorCode = data['code'] ?? data['errorCode'];
    }

    switch (statusCode) {
      case 400:
        return _handleValidationError(data, backendMessage, errorCode);
      case 401:
        return UnauthorizedError(
          backendMessage ?? 'Authentication failed. Please login again.',
          code: errorCode ?? 'UNAUTHORIZED',
        );
      case 403:
        return ForbiddenError(
          backendMessage ?? 'You do not have permission to access this resource.',
          code: errorCode ?? 'FORBIDDEN',
        );
      case 404:
        return NotFoundError(
          backendMessage ?? 'The requested resource was not found.',
          code: errorCode ?? 'NOT_FOUND',
        );
      case 408:
        return TimeoutError(
          backendMessage ?? 'The request timed out. Please try again.',
          code: errorCode ?? 'TIMEOUT',
        );
      case >= 500:
        return ServerError(
          backendMessage ?? 'Server error. Please try again later.',
          code: errorCode ?? 'SERVER_ERROR',
          statusCode: statusCode,
        );
      default:
        return UnknownError(
          backendMessage ?? 'An unexpected error occurred.',
          code: errorCode ?? 'UNKNOWN_ERROR',
        );
    }
  }

  /// Converts an exception (Dio error, Socket exception, etc.) to AppError
  static AppError fromException(
    Object error, {
    StackTrace? stackTrace,
  }) {
    // DioException wraps various network-related errors
    if (error is DioException) {
      return _handleDioException(error, stackTrace);
    }

    // Socket exceptions (no connectivity, connection refused, etc.)
    if (error is SocketException) {
      return NetworkError(
        'No internet connection. Please check your network.',
        code: 'SOCKET_ERROR',
        stackTrace: stackTrace,
        isRetryable: true,
      );
    }

    // Fallback for any other exception
    return UnknownError(
      'An unexpected error occurred: ${error.toString()}',
      code: 'UNKNOWN',
      stackTrace: stackTrace,
      originalException: error,
    );
  }

  /// Handles DioException specifically
  static AppError _handleDioException(
    DioException error,
    StackTrace? stackTrace,
  ) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return TimeoutError(
          'Connection timed out. Please check your internet and try again.',
          code: 'CONNECTION_TIMEOUT',
          stackTrace: stackTrace,
          isRetryable: true,
        );

      case DioExceptionType.sendTimeout:
        return TimeoutError(
          'Request timed out while sending. Please try again.',
          code: 'SEND_TIMEOUT',
          stackTrace: stackTrace,
          isRetryable: true,
        );

      case DioExceptionType.receiveTimeout:
        return TimeoutError(
          'Server did not respond in time. Please try again.',
          code: 'RECEIVE_TIMEOUT',
          stackTrace: stackTrace,
          isRetryable: true,
        );

      case DioExceptionType.badCertificate:
        return NetworkError(
          'SSL certificate error. Please contact support.',
          code: 'BAD_CERTIFICATE',
          stackTrace: stackTrace,
          isRetryable: false,
        );

      case DioExceptionType.badResponse:
        // Has a response with status code
        final response = error.response;
        if (response != null) {
          return fromResponse(response);
        }
        return ServerError(
          'Server returned an invalid response.',
          code: 'BAD_RESPONSE',
          stackTrace: stackTrace,
        );

      case DioExceptionType.cancel:
        return UnknownError(
          'Request was cancelled.',
          code: 'REQUEST_CANCELLED',
          stackTrace: stackTrace,
        );

      case DioExceptionType.connectionError:
        // No internet connection or connection refused
        return NetworkError(
          'Connection failed. Please check your internet connection.',
          code: 'CONNECTION_ERROR',
          stackTrace: stackTrace,
          isRetryable: true,
        );

      case DioExceptionType.unknown:
        return UnknownError(
          error.message ?? 'An unknown error occurred.',
          code: 'UNKNOWN_DIO_ERROR',
          stackTrace: stackTrace,
          originalException: error,
        );
    }
  }

  /// Handles validation errors from 400 responses
  static ValidationError _handleValidationError(
    dynamic data,
    String? message,
    String? code,
  ) {
    Map<String, List<String>>? fieldErrors;

    // Try to extract field-level errors from response
    if (data is Map<String, dynamic>) {
      // Common formats for field errors:
      // 1. { "fieldName": ["error message"] }
      // 2. { "errors": { "fieldName": ["error message"] } }
      // 3. { "fieldErrors": { "fieldName": ["error message"] } }

      if (data.containsKey('errors') && data['errors'] is Map) {
        fieldErrors = _normalizeFieldErrors(data['errors']);
      } else if (data.containsKey('fieldErrors') && data['fieldErrors'] is Map) {
        fieldErrors = _normalizeFieldErrors(data['fieldErrors']);
      } else {
        // Try direct field errors
        fieldErrors = _normalizeFieldErrors(data);
      }
    }

    return ValidationError(
      message ?? 'Please check your input and try again.',
      code: code ?? 'VALIDATION_ERROR',
      fieldErrors: fieldErrors,
    );
  }

  // / Normalizes field errors to Map<String, List<String>> format
  static Map<String, List<String>>? _normalizeFieldErrors(
    Map<String, dynamic> data,
  ) {
    final normalized = <String, List<String>>{};

    data.forEach((key, value) {
      if (value is List) {
        // Convert list items to strings
        normalized[key] = value.map((e) => e.toString()).toList();
      } else if (value is String) {
        // Single error message
        normalized[key] = [value];
      } else if (value is Map && value.containsKey('message')) {
        // Object with message property
        normalized[key] = [value['message'].toString()];
      }
    });

    return normalized.isEmpty ? null : normalized;
  }
}

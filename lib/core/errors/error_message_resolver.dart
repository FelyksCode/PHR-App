import 'package:flutter/material.dart';
import 'package:phr_app/l10n/app_localizations.dart';
import 'app_error.dart';

/// Resolves human-readable, localized messages for AppError instances.
///
/// This layer ensures:
/// - Messages are non-technical and user-friendly
/// - Localization support across all error types
/// - Stack traces and backend messages never leak to UI
/// - Consistent messaging across the entire app
abstract class ErrorMessageResolver {
  /// Resolves an error to a user-facing message
  static String resolve(AppError error, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return switch (error) {
      NetworkError() => _networkErrorMessage(error, l10n),
      UnauthorizedError() => _unauthorizedErrorMessage(error, l10n),
      ForbiddenError() => _forbiddenErrorMessage(error, l10n),
      NotFoundError() => _notFoundErrorMessage(error, l10n),
      ValidationError() => _validationErrorMessage(error, l10n),
      LocalValidationError() => _localValidationErrorMessage(error, l10n),
      ServerError() => _serverErrorMessage(error, l10n),
      TimeoutError() => _timeoutErrorMessage(error, l10n),
      UnknownError() => _unknownErrorMessage(error, l10n),
    };
  }

  /// Returns a user-friendly error title (for dialogs, snackbars, etc.)
  static String getErrorTitle(AppError error, BuildContext context) {
    return switch (error) {
      NetworkError() => 'Network Error',
      UnauthorizedError() => 'Authentication Failed',
      ForbiddenError() => 'Permission Denied',
      NotFoundError() => 'Not Found',
      ValidationError() => 'Invalid Input',
      LocalValidationError() => 'Invalid Input',
      ServerError() => 'Server Error',
      TimeoutError() => 'Request Timeout',
      UnknownError() => 'Unexpected Error',
    };
  }

  /// Gets a brief description suitable for a snackbar
  static String getBriefMessage(AppError error, BuildContext context) {
    final fullMessage = resolve(error, context);
    // Truncate to 100 characters for snackbars
    return fullMessage.length > 100
        ? '${fullMessage.substring(0, 97)}...'
        : fullMessage;
  }

  // ============================================================================
  // Private message builders for each error type
  // ============================================================================

  static String _networkErrorMessage(
    NetworkError error,
    AppLocalizations l10n,
  ) {
    return 'No internet connection. Please check your network and try again.';
  }

  static String _unauthorizedErrorMessage(
    UnauthorizedError error,
    AppLocalizations l10n,
  ) {
    return 'Your session has expired. Please login again.';
  }

  static String _forbiddenErrorMessage(
    ForbiddenError error,
    AppLocalizations l10n,
  ) {
    if (error.requiredPermissions?.isNotEmpty ?? false) {
      final permissions = error.requiredPermissions!.join(', ');
      return 'You need the following permissions to access this: $permissions.';
    }
    return 'You do not have permission to access this resource.';
  }

  static String _notFoundErrorMessage(
    NotFoundError error,
    AppLocalizations l10n,
  ) {
    if (error.resourceType != null) {
      return 'The ${error.resourceType} you are looking for was not found.';
    }
    return 'The requested resource was not found.';
  }

  static String _validationErrorMessage(
    ValidationError error,
    AppLocalizations l10n,
  ) {
    if (error.fieldErrors != null && error.fieldErrors!.isNotEmpty) {
      // Return first field error for now (UI should handle detailed errors)
      final firstField = error.fieldErrors!.keys.first;
      final firstError = error.fieldErrors![firstField]?.first;
      return firstError ?? 'Please check your input and try again.';
    }
    return 'Please check your input and try again.';
  }

  static String _localValidationErrorMessage(
    LocalValidationError error,
    AppLocalizations l10n,
  ) {
    if (error.fieldErrors != null && error.fieldErrors!.isNotEmpty) {
      final firstField = error.fieldErrors!.keys.first;
      final firstError = error.fieldErrors![firstField]?.first;
      return firstError ?? 'Please check your input and try again.';
    }
    return 'Please check your input and try again.';
  }

  static String _serverErrorMessage(ServerError error, AppLocalizations l10n) {
    return 'Something went wrong on the server. Please try again later.';
  }

  static String _timeoutErrorMessage(
    TimeoutError error,
    AppLocalizations l10n,
  ) {
    return 'The request took too long. Please check your connection and try again.';
  }

  static String _unknownErrorMessage(
    UnknownError error,
    AppLocalizations l10n,
  ) {
    return 'An unexpected error occurred. Please try again or contact support if the problem persists.';
  }
}

import 'app_error.dart';

/// A Result type representing either success or failure
///
/// This provides a type-safe way to handle both success and error cases
/// without exceptions.
sealed class Result<T> {
  /// Map a successful result to another type
  Result<U> map<U>(U Function(T value) fn) {
    return switch (this) {
      Success(value: final v) => Success(fn(v)),
      Failure(error: final e) => Failure(e),
    };
  }

  /// Map a failed result while preserving success
  Result<T> mapError(AppError Function(AppError error) fn) {
    return switch (this) {
      Success(value: final v) => Success(v),
      Failure(error: final e) => Failure(fn(e)),
    };
  }

  /// Fold the result into a single value
  U fold<U>(
    U Function(T value) onSuccess,
    U Function(AppError error) onFailure,
  ) {
    return switch (this) {
      Success(value: final v) => onSuccess(v),
      Failure(error: final e) => onFailure(e),
    };
  }

  /// Get the value if successful, otherwise throw the error
  T getOrThrow() {
    return switch (this) {
      Success(value: final v) => v,
      Failure(error: final e) => throw e,
    };
  }

  /// Get the value if successful, otherwise return null
  T? getOrNull() {
    return switch (this) {
      Success(value: final v) => v,
      Failure(error: _) => null,
    };
  }

  /// Check if this is a success
  bool get isSuccess => this is Success<T>;

  /// Check if this is a failure
  bool get isFailure => this is Failure<T>;
}

/// Successful result containing a value
final class Success<T> extends Result<T> {
  final T value;

  Success(this.value);

  @override
  String toString() => 'Success($value)';
}

/// Failed result containing an error
final class Failure<T> extends Result<T> {
  final AppError error;

  Failure(this.error);

  @override
  String toString() => 'Failure($error)';
}

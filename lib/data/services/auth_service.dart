import 'package:dio/dio.dart';
import 'package:phr_app/core/errors/api_error_mapper.dart';
import '../models/auth_models.dart';
import '../../core/network/api_client.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/app_error_logger.dart';

class AuthService {
  final Dio _dio;

  AuthService() : _dio = ApiClient.dio {
    _setupInterceptors();
  }

  AppError _mapLoginErrorResponse(Response response) {
    final status = response.statusCode;
    if (status == 401) {
      return UnauthorizedError(
        'Invalid email or password',
        code: 'AUTH_INVALID_CREDENTIALS',
        shouldLogout: false,
      );
    }
    if (status == 422) {
      return ValidationError(
        'Invalid input format',
        code: 'AUTH_INPUT_INVALID',
        fieldErrors: {},
      );
    }
    if (status != null && status >= 500) {
      return ServerError(
        'Server error during login',
        code: 'AUTH_SERVER_ERROR',
        statusCode: status,
      );
    }
    return UnknownError(
      'Login failed (status: ${status ?? 'unknown'}): ${response.statusMessage ?? 'unknown error'}',
      code: 'AUTH_LOGIN_FAILED',
    );
  }

  AppError _mapMeErrorResponse(Response response) {
    final status = response.statusCode;
    if (status == 401) {
      return UnauthorizedError(
        'Token expired or invalid',
        code: 'AUTH_TOKEN_INVALID',
        shouldLogout: true,
      );
    }
    if (status != null && status >= 500) {
      return ServerError(
        'Server error while fetching user',
        code: 'AUTH_ME_SERVER_ERROR',
        statusCode: status,
      );
    }
    return UnknownError(
      'Failed to get user info (status: ${status ?? 'unknown'}): ${response.statusMessage ?? 'unknown error'}',
      code: 'AUTH_ME_FAILED',
    );
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.next(options);
        },
        onError: (error, handler) {
          // Handle common HTTP errors
          if (error.response?.statusCode == 401) {
            AppErrorLogger.logError(
              UnauthorizedError(
                'Auth service unauthorized',
                code: 'AUTH_SERVICE_401',
                shouldLogout: true,
              ),
              source: 'AuthService.onError',
              severity: ErrorSeverity.medium,
            );
          }
          // Pass through for higher-level handling
          handler.next(error);
        },
      ),
    );
  }

  // Test connectivity to the backend
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/');
      return response.statusCode == 200;
    } catch (e, st) {
      AppErrorLogger.logError(
        UnknownError(
          'Auth service connectivity check failed',
          code: 'AUTH_CONNECTIVITY_FAILED',
          stackTrace: st,
          originalException: e,
        ),
        source: 'AuthService.testConnection',
        severity: ErrorSeverity.medium,
      );
      return false;
    }
  }

  Future<LoginResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return LoginResponse.fromJson(response.data);
      }

      final appError = _mapLoginErrorResponse(response);
      AppErrorLogger.logError(
        appError,
        source: 'AuthService.login',
        severity: ErrorSeverity.medium,
      );
      throw appError;
    } on DioException catch (e, st) {
      final appError = ApiErrorMapper.fromException(e, stackTrace: st);
      AppErrorLogger.logError(
        appError,
        source: 'AuthService.login',
        severity: ErrorSeverity.medium,
      );
      throw appError;
    } catch (e, st) {
      final appError = UnknownError(
        'Unexpected login error',
        code: 'LOGIN_UNEXPECTED',
        stackTrace: st,
        originalException: e,
      );
      AppErrorLogger.logError(
        appError,
        source: 'AuthService.login',
        severity: ErrorSeverity.high,
      );
      throw appError;
    }
  }

  Future<User> getMe(String token) async {
    try {
      final response = await _dio.get(
        '/auth/me',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        try {
          return User.fromJson(response.data as Map<String, dynamic>);
        } catch (e, st) {
          final appError = UnknownError(
            'Failed to parse user data',
            code: 'USER_PARSE_ERROR',
            stackTrace: st,
            originalException: e,
          );
          AppErrorLogger.logError(
            appError,
            source: 'AuthService.getMe',
            severity: ErrorSeverity.medium,
          );
          throw appError;
        }
      }

      final appError = _mapMeErrorResponse(response);
      AppErrorLogger.logError(
        appError,
        source: 'AuthService.getMe',
        severity: ErrorSeverity.medium,
      );
      throw appError;
    } on DioException catch (e, st) {
      final appError = ApiErrorMapper.fromException(e, stackTrace: st);
      AppErrorLogger.logError(
        appError,
        source: 'AuthService.getMe',
        severity: ErrorSeverity.medium,
      );
      throw appError;
    } catch (e, st) {
      final appError = UnknownError(
        'Unexpected getMe error',
        code: 'GET_ME_UNEXPECTED',
        stackTrace: st,
        originalException: e,
      );
      AppErrorLogger.logError(
        appError,
        source: 'AuthService.getMe',
        severity: ErrorSeverity.high,
      );
      throw appError;
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  
  @override
  String toString() => 'AuthException: $message';
}

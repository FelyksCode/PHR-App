import 'package:dio/dio.dart';
import '../models/auth_models.dart';
import '../../core/network/api_client.dart';

class AuthService {
  final Dio _dio;

  AuthService() : _dio = ApiClient.dio {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print('🔗 Auth Service Request: ${options.method} ${options.path}');
          handler.next(options);
        },
        onError: (error, handler) {
          // Handle common HTTP errors
          if (error.response?.statusCode == 401) {
            print('🔒 Auth Service: 401 Unauthorized');
            // Token expired or invalid - this will be handled by AuthRepository
          }
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
    } catch (e) {
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
      } else {
        throw AuthException('Login failed: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw AuthException('Invalid email or password');
      } else if (e.response?.statusCode == 422) {
        throw AuthException('Invalid input format');
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        throw AuthException('Connection timeout. Please try again.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw AuthException('Network error. Please check your internet connection.');
      } else {
        throw AuthException('Login failed: ${e.message}');
      }
    } catch (e) {
      throw AuthException('Unexpected error: $e');
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
        } catch (e) {
          throw AuthException('Failed to parse user data: $e');
        }
      } else {
        throw AuthException('Failed to get user info: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw AuthException('Token expired or invalid');
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        throw AuthException('Connection timeout. Please try again.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw AuthException('Network error. Please check your internet connection.');
      } else {
        throw AuthException('Failed to get user info: ${e.message}');
      }
    } catch (e) {
      throw AuthException('Unexpected error: $e');
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  
  @override
  String toString() => 'AuthException: $message';
}

import 'package:dio/dio.dart';

class ApiClient {
  static late Dio _dio;
  
  static Dio get dio => _dio;
  
  static void initialize({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? 'http://10.0.2.2:8000',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );
  }
}

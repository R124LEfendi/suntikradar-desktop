import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(tokenStorageProvider));
});

class ApiClient {
  ApiClient(this._tokenStorage) {
    dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokenStorage.readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final path = error.requestOptions.path;
        final shouldClearSession = path == '/auth/me' || path == '/auth/logout';
        if (error.response?.statusCode == 401 && shouldClearSession) {
          await _tokenStorage.clear();
        }
        handler.next(error);
      },
    ));

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
      ));
    }
  }

  final TokenStorage _tokenStorage;
  late final Dio dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    return _unwrap(await dio.get(path, queryParameters: query));
  }

  Future<dynamic> post(String path,
      {dynamic data, Map<String, dynamic>? query}) async {
    return _unwrap(await dio.post(path, data: data, queryParameters: query));
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    return _unwrap(await dio.put(path, data: data));
  }

  Future<dynamic> delete(String path) async {
    return _unwrap(await dio.delete(path));
  }

  dynamic _unwrap(Response response) {
    final body = response.data;
    if (body is Map<String, dynamic>) {
      if (body['success'] == false) {
        throw ApiException(
          body['message']?.toString() ?? 'Request gagal',
          statusCode: response.statusCode,
          errors:
              body['errors'] is Map<String, dynamic> ? body['errors'] : null,
        );
      }
      return body['data'] ?? body;
    }
    return body;
  }

  static ApiException mapError(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        return ApiException(
          data['message']?.toString() ?? error.message ?? 'Request gagal',
          statusCode: error.response?.statusCode,
          errors:
              data['errors'] is Map<String, dynamic> ? data['errors'] : null,
        );
      }
      return ApiException(error.message ?? 'Request gagal',
          statusCode: error.response?.statusCode);
    }
    return ApiException(error.toString());
  }
}

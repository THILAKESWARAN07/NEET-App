import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/app_storage.dart';

const String _defaultBackendBaseUrl = 'https://neet-backend-g2d8.onrender.com';
const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: _defaultBackendBaseUrl,
);
const String apiBaseUrl = '$backendBaseUrl/api';

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(appStorageProvider);

  const baseUrl = apiBaseUrl;

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 120),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.readToken();
        if (kDebugMode) {
          debugPrint(
            '[API] ${options.method} ${options.path} | tokenPresent=${token != null && token.isNotEmpty}',
          );
        }
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        } else {
          options.headers.remove('Authorization');
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (kDebugMode && error.response?.statusCode == 401) {
          debugPrint(
            '[API] 401 Unauthorized for ${error.requestOptions.method} ${error.requestOptions.path}',
          );
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

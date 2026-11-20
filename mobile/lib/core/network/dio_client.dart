import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/core/config/env_config.dart';

/// Riverpod provider delivering a configured Dio HTTP client.
final dioClientProvider = Provider<Dio>((ref) {
  final config = ref.watch(envConfigProvider);

  final options = BaseOptions(
    baseUrl: config.apiBaseUrl,
    connectTimeout: Duration(milliseconds: config.connectTimeoutMs),
    receiveTimeout: Duration(milliseconds: config.receiveTimeoutMs),
    headers: const {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  );

  final dio = Dio(options);

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
      ),
    );
  }

  return dio;
});


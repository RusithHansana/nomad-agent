import 'package:dio/dio.dart';

import 'api_interceptor.dart';

/// Environment constants supplied via `--dart-define`.
///
/// Local run example:
/// ```
/// flutter run --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=API_KEY=change-me
/// ```
class EnvConfig {
  EnvConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );
}

/// Singleton Dio client pre‑configured with the NomadAgent backend
/// base URL, 35 s timeout, and the API‑key interceptor.
class ApiClient {
  ApiClient._();

  static final Dio instance = _create();

  static Dio _create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(ApiKeyInterceptor(EnvConfig.apiKey));

    return dio;
  }
}

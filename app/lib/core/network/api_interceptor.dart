import 'package:dio/dio.dart';

/// Interceptor that adds `X-API-Key` to every outgoing request.
class ApiKeyInterceptor extends Interceptor {
  ApiKeyInterceptor(this._apiKey);

  final String _apiKey;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_apiKey.isNotEmpty) {
      options.headers['X-API-Key'] = _apiKey;
    }
    super.onRequest(options, handler);
  }
}

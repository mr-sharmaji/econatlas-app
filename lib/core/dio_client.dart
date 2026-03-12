import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connectivity.dart';
import 'constants.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();
  dio.interceptors.add(BaseUrlInterceptor());
  dio.interceptors.add(OfflineInterceptor());
  dio.interceptors.add(RetryInterceptor(dio: dio));
  dio.interceptors.add(LogInterceptor(
    requestBody: false,
    responseBody: false,
    logPrint: (o) {},
  ));
  return dio;
});

class BaseUrlInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    options.baseUrl = prefs.getString(AppConstants.prefBaseUrl) ??
        AppConstants.defaultBaseUrl;
    options.connectTimeout = const Duration(seconds: 6);
    options.sendTimeout = const Duration(seconds: 6);
    options.receiveTimeout = const Duration(seconds: 8);
    handler.next(options);
  }
}

/// Fails fast when offline so we don't send pointless requests.
class OfflineInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (await isOffline()) {
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'No internet connection',
        ),
      );
    }
    handler.next(options);
  }
}

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;

  RetryInterceptor({required this.dio, this.maxRetries = 1});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = (err.requestOptions.extra['retry_count'] as int?) ?? 0;
    if (!_shouldRetry(err) || retryCount >= maxRetries) {
      handler.next(err);
      return;
    }
    if (await isOffline()) {
      handler.next(err);
      return;
    }
    final nextCount = retryCount + 1;
    err.requestOptions.extra['retry_count'] = nextCount;
    await Future.delayed(Duration(milliseconds: 400 * nextCount));
    try {
      final response = await dio.fetch(err.requestOptions);
      handler.resolve(response);
      return;
    } on DioException catch (retryErr) {
      handler.next(retryErr);
      return;
    }
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode != null && err.response!.statusCode! >= 500);
  }
}

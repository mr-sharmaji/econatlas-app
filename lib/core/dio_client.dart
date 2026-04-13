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
    // Don't override receiveTimeout for streaming requests (SSE)
    if (options.responseType != ResponseType.stream) {
      options.receiveTimeout = const Duration(seconds: 8);
    }
    handler.next(options);
  }
}

/// Soft offline guard — no-op pass-through.
///
/// The old implementation rejected ALL requests when `isOffline()`
/// returned true.  This broke pull-to-refresh on many Android devices
/// because `connectivity_plus` briefly reports `ConnectivityResult.none`
/// during WiFi→mobile handoffs or after doze mode wakeup.  The reject
/// completed RefreshIndicator's Future with an error that was caught
/// silently → spinner disappeared, data unchanged → "pull to refresh
/// not working".
///
/// Now: let every request through.  If genuinely offline, the TCP
/// connect will fail with a proper timeout and the RetryInterceptor
/// handles retry.  The `isOffline()` check is still available for the
/// UI (offline banners) but no longer gates outgoing requests.
class OfflineInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
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
    // Never retry streaming (SSE) requests
    if (err.requestOptions.responseType == ResponseType.stream) return false;
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode != null && err.response!.statusCode! >= 500);
  }
}

import 'package:dio/dio.dart';

/// Returns a short, user-friendly message for API/network errors.
/// Avoids showing raw exception text to the user.
String friendlyErrorMessage(dynamic err, {String? fallback}) {
  final defaultFallback =
      fallback ?? 'Couldn\'t load data. Pull to refresh or tap Retry.';

  if (err is DioException) {
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'No internet or server unreachable. Check your connection and try again.';
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode;
        if (status != null) {
          if (status == 404) return 'Not found.';
          if (status >= 500) return 'Server error. Please try again later.';
          if (status == 401 || status == 403) return 'Access denied.';
        }
        return defaultFallback;
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.unknown:
        final msg = err.message?.toString().toLowerCase() ?? '';
        if (msg.contains('socket') ||
            msg.contains('network') ||
            msg.contains('connection') ||
            msg.contains('failed host lookup')) {
          return 'No internet or server unreachable. Check your connection and try again.';
        }
        return defaultFallback;
      case DioExceptionType.badCertificate:
        return 'Connection not secure. Check your backend URL in Settings.';
    }
  }

  final str = err?.toString() ?? '';
  if (str.isEmpty) return defaultFallback;
  // Avoid leaking technical details
  if (str.contains('SocketException') ||
      str.contains('Connection refused') ||
      str.contains('Failed host lookup')) {
    return 'No internet or server unreachable. Check your connection and try again.';
  }
  return defaultFallback;
}

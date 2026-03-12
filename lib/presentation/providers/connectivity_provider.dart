import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream of connectivity results (wifi, mobile, none, etc.). Use to show offline banner.
final connectivityStreamProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// True when device has no connectivity. Use for UI (e.g. offline banner).
bool isOfflineFromResults(List<ConnectivityResult> list) {
  if (list.isEmpty) return true;
  return list.length == 1 && list.first == ConnectivityResult.none;
}

import 'package:connectivity_plus/connectivity_plus.dart';

/// Returns true when the device has no connectivity (avoids pointless API requests).
Future<bool> isOffline() async {
  final list = await Connectivity().checkConnectivity();
  if (list.isEmpty) return true;
  return list.length == 1 && list.first == ConnectivityResult.none;
}

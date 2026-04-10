import 'package:flutter_riverpod/flutter_riverpod.dart';

// Tick counters for bottom-nav reselect actions.
// Index mapping:
// 0 Overview, 1 Market, 2 Watchlist, 3 Discover, 4 Economy, 5 Artha
final bottomTabReselectProvider =
    StateProvider<List<int>>((ref) => List<int>.filled(6, 0));

final bottomTabReselectTickProvider = Provider.family<int, int>((ref, index) {
  final ticks = ref.watch(bottomTabReselectProvider);
  if (index < 0 || index >= ticks.length) return 0;
  return ticks[index];
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/brief.dart';
import 'repository_providers.dart';

final briefMarketProvider = StateProvider<String>((ref) => 'IN');

final briefPostMarketProvider =
    FutureProvider.autoDispose.family<PostMarketOverview, String>((ref, market) {
  final repo = ref.watch(briefRepositoryProvider);
  return repo.getPostMarketOverview(market: market);
});

final briefTopGainersProvider =
    FutureProvider.autoDispose.family<List<BriefStockItem>, String>((ref, market) async {
  final repo = ref.watch(briefRepositoryProvider);
  final res = await repo.getMovers(market: market, type: 'gainers', limit: 10);
  return res.items;
});

final briefTopLosersProvider =
    FutureProvider.autoDispose.family<List<BriefStockItem>, String>((ref, market) async {
  final repo = ref.watch(briefRepositoryProvider);
  final res = await repo.getMovers(market: market, type: 'losers', limit: 10);
  return res.items;
});

final briefMostActiveProvider =
    FutureProvider.autoDispose.family<List<BriefStockItem>, String>((ref, market) async {
  final repo = ref.watch(briefRepositoryProvider);
  final res = await repo.getMostActive(market: market, limit: 10);
  return res.items;
});

final briefSectorPulseProvider =
    FutureProvider.autoDispose.family<List<BriefSectorItem>, String>((ref, market) async {
  final repo = ref.watch(briefRepositoryProvider);
  final res = await repo.getSectors(market: market, limit: 8);
  return res.sectors;
});

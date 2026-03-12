import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/dio_client.dart';
import '../../data/datasources/remote_data_source.dart';
import '../../data/repositories/market_repository_impl.dart';
import '../../data/repositories/commodity_repository_impl.dart';
import '../../data/repositories/news_repository_impl.dart';
import '../../data/repositories/macro_repository_impl.dart';
import '../../data/repositories/brief_repository_impl.dart';
import '../../data/repositories/discover_repository_impl.dart';
import '../../domain/repositories/market_repository.dart';
import '../../domain/repositories/commodity_repository.dart';
import '../../domain/repositories/news_repository.dart';
import '../../domain/repositories/macro_repository.dart';
import '../../domain/repositories/brief_repository.dart';
import '../../domain/repositories/discover_repository.dart';

final remoteDataSourceProvider = Provider<RemoteDataSource>((ref) {
  return RemoteDataSource(ref.watch(dioProvider));
});

final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  return MarketRepositoryImpl(ref.watch(remoteDataSourceProvider));
});

final commodityRepositoryProvider = Provider<CommodityRepository>((ref) {
  return CommodityRepositoryImpl(ref.watch(remoteDataSourceProvider));
});

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepositoryImpl(ref.watch(remoteDataSourceProvider));
});

final macroRepositoryProvider = Provider<MacroRepository>((ref) {
  return MacroRepositoryImpl(ref.watch(remoteDataSourceProvider));
});

final briefRepositoryProvider = Provider<BriefRepository>((ref) {
  return BriefRepositoryImpl(ref.watch(remoteDataSourceProvider));
});

final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  return DiscoverRepositoryImpl(ref.watch(remoteDataSourceProvider));
});

import '../../domain/repositories/brief_repository.dart';
import '../datasources/remote_data_source.dart';
import '../models/brief.dart';

class BriefRepositoryImpl implements BriefRepository {
  final RemoteDataSource _remote;

  BriefRepositoryImpl(this._remote);

  @override
  Future<PostMarketOverview> getPostMarketOverview({required String market}) {
    return _remote.getBriefPostMarket(market: market);
  }

  @override
  Future<BriefStockListResponse> getMovers({
    required String market,
    required String type,
    int limit = 10,
  }) {
    return _remote.getBriefMovers(market: market, type: type, limit: limit);
  }

  @override
  Future<BriefStockListResponse> getMostActive({
    required String market,
    int limit = 10,
  }) {
    return _remote.getBriefMostActive(market: market, limit: limit);
  }

  @override
  Future<BriefSectorPulseResponse> getSectors({
    required String market,
    int limit = 8,
  }) {
    return _remote.getBriefSectors(market: market, limit: limit);
  }
}

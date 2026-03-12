import '../../domain/repositories/commodity_repository.dart';
import '../datasources/remote_data_source.dart';
import '../models/market_price.dart';

class CommodityRepositoryImpl implements CommodityRepository {
  final RemoteDataSource _remote;

  CommodityRepositoryImpl(this._remote);

  @override
  Future<MarketPriceResponse> getCommodities({
    String? asset,
    int limit = 50,
    int offset = 0,
  }) {
    return _remote.getCommodities(
      asset: asset,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<MarketPriceResponse> getLatestCommodities() {
    return _remote.getLatestCommodities();
  }
}

import '../../domain/repositories/market_repository.dart';
import '../datasources/remote_data_source.dart';
import '../models/intraday_response.dart';
import '../models/market_price.dart';
import '../models/market_status.dart';

class MarketRepositoryImpl implements MarketRepository {
  final RemoteDataSource _remote;

  MarketRepositoryImpl(this._remote);

  @override
  Future<MarketStatus> getMarketStatus() => _remote.getMarketStatus();

  @override
  Future<IntradayResponse> getMarketIntraday({
    required String asset,
    required String instrumentType,
  }) =>
      _remote.getMarketIntraday(asset: asset, instrumentType: instrumentType);

  @override
  Future<IntradayResponse> getCommodityIntraday({required String asset}) =>
      _remote.getCommodityIntraday(asset: asset);

  @override
  Future<MarketPriceResponse> getMarketPrices({
    String? instrumentType,
    String? asset,
    int limit = 50,
    int offset = 0,
  }) {
    return _remote.getMarketPrices(
      instrumentType: instrumentType,
      asset: asset,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<MarketPriceResponse> getLatestMarketPrices({
    String? instrumentType,
  }) {
    return _remote.getLatestMarketPrices(instrumentType: instrumentType);
  }
}

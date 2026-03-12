import '../../data/models/market_price.dart';

abstract class CommodityRepository {
  Future<MarketPriceResponse> getCommodities({
    String? asset,
    int limit = 50,
    int offset = 0,
  });

  Future<MarketPriceResponse> getLatestCommodities();
}

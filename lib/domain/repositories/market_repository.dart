import '../../data/models/intraday_response.dart';
import '../../data/models/market_price.dart';
import '../../data/models/market_status.dart';

abstract class MarketRepository {
  Future<MarketStatus> getMarketStatus();

  Future<IntradayResponse> getMarketIntraday({
    required String asset,
    required String instrumentType,
  });

  Future<IntradayResponse> getCommodityIntraday({required String asset});

  Future<IntradayResponse> getCryptoIntraday({required String asset});

  Future<MarketPriceResponse> getMarketPrices({
    String? instrumentType,
    String? asset,
    int limit = 50,
    int offset = 0,
  });

  Future<MarketPriceResponse> getLatestMarketPrices({
    String? instrumentType,
  });

  Future<MarketStory> getMarketStory({
    required String asset,
    required String instrumentType,
  });
}

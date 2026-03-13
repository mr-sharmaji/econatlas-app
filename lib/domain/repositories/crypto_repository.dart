import '../../data/models/market_price.dart';

abstract class CryptoRepository {
  Future<MarketPriceResponse> getCrypto({
    String? asset,
    int limit = 50,
    int offset = 0,
  });

  Future<MarketPriceResponse> getLatestCrypto();
}

import '../../domain/repositories/crypto_repository.dart';
import '../datasources/remote_data_source.dart';
import '../models/market_price.dart';

class CryptoRepositoryImpl implements CryptoRepository {
  final RemoteDataSource _remote;

  CryptoRepositoryImpl(this._remote);

  @override
  Future<MarketPriceResponse> getCrypto({
    String? asset,
    int limit = 50,
    int offset = 0,
  }) {
    return _remote.getCrypto(
      asset: asset,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<MarketPriceResponse> getLatestCrypto() {
    return _remote.getLatestCrypto();
  }
}

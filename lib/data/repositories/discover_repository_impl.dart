import '../../domain/repositories/discover_repository.dart';
import '../datasources/remote_data_source.dart';
import '../models/discover.dart';

class DiscoverRepositoryImpl implements DiscoverRepository {
  final RemoteDataSource _remote;

  DiscoverRepositoryImpl(this._remote);

  @override
  Future<DiscoverOverview> getOverview({required String segment}) {
    return _remote.getDiscoverOverview(segment: segment);
  }

  @override
  Future<DiscoverStockListResponse> getStocks({
    required String preset,
    String? search,
    String? sector,
    double? minScore,
    double? maxScore,
    double? minPrice,
    double? maxPrice,
    double? minPe,
    double? maxPe,
    double? minRoe,
    double? minRoce,
    double? maxDebtToEquity,
    int? minVolume,
    double? minTradedValue,
    double? minMarketCap,
    double? maxMarketCap,
    double? minDividendYield,
    double? minPb,
    double? maxPb,
    String? sourceStatus,
    String sortBy = 'score',
    String sortOrder = 'desc',
    int limit = 25,
    int offset = 0,
  }) {
    return _remote.getDiscoverStocks(
      preset: preset,
      search: search,
      sector: sector,
      minScore: minScore,
      maxScore: maxScore,
      minPrice: minPrice,
      maxPrice: maxPrice,
      minPe: minPe,
      maxPe: maxPe,
      minRoe: minRoe,
      minRoce: minRoce,
      maxDebtToEquity: maxDebtToEquity,
      minVolume: minVolume,
      minTradedValue: minTradedValue,
      minMarketCap: minMarketCap,
      maxMarketCap: maxMarketCap,
      minDividendYield: minDividendYield,
      minPb: minPb,
      maxPb: maxPb,
      sourceStatus: sourceStatus,
      sortBy: sortBy,
      sortOrder: sortOrder,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<DiscoverMutualFundListResponse> getMutualFunds({
    required String preset,
    String? search,
    String? category,
    String? riskLevel,
    bool directOnly = true,
    double? minScore,
    double? minAumCr,
    double? maxExpenseRatio,
    double? minReturn1y,
    double? minReturn3y,
    double? minReturn5y,
    double? minFundAge,
    String? sourceStatus,
    String sortBy = 'score',
    String sortOrder = 'desc',
    int limit = 25,
    int offset = 0,
  }) {
    return _remote.getDiscoverMutualFunds(
      preset: preset,
      search: search,
      category: category,
      riskLevel: riskLevel,
      directOnly: directOnly,
      minScore: minScore,
      minAumCr: minAumCr,
      maxExpenseRatio: maxExpenseRatio,
      minReturn1y: minReturn1y,
      minReturn3y: minReturn3y,
      minReturn5y: minReturn5y,
      minFundAge: minFundAge,
      sourceStatus: sourceStatus,
      sortBy: sortBy,
      sortOrder: sortOrder,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<UnifiedSearchResponse> search({
    required String query,
    int limit = 10,
  }) {
    return _remote.discoverSearch(query: query, limit: limit);
  }

  @override
  Future<DiscoverHomeData> getHomeData() {
    return _remote.getDiscoverHome();
  }

  @override
  Future<PriceHistoryResponse> getStockHistory({
    required String symbol,
    int days = 365,
  }) {
    return _remote.getDiscoverStockHistory(symbol: symbol, days: days);
  }

  @override
  Future<PriceHistoryResponse> getMfNavHistory({
    required String schemeCode,
    int days = 365,
  }) {
    return _remote.getDiscoverMfNavHistory(
        schemeCode: schemeCode, days: days);
  }

  @override
  Future<DiscoverStockItem> getStockBySymbol({required String symbol}) =>
      _remote.getDiscoverStockBySymbol(symbol);

  @override
  Future<DiscoverMutualFundItem> getMfBySchemeCode({required String schemeCode}) =>
      _remote.getDiscoverMfBySchemeCode(schemeCode);

  @override
  Future<List<DiscoverStockItem>> getStockPeers({
    required String symbol,
    int limit = 5,
  }) {
    return _remote.getDiscoverStockPeers(symbol: symbol, limit: limit);
  }

  @override
  Future<List<DiscoverMutualFundItem>> getMfPeers({
    required String schemeCode,
    int limit = 5,
  }) {
    return _remote.getDiscoverMfPeers(schemeCode: schemeCode, limit: limit);
  }
}

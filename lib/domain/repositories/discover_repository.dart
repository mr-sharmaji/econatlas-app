import '../../data/models/discover.dart';

abstract class DiscoverRepository {
  Future<DiscoverOverview> getOverview({required String segment});

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
    String sortBy,
    String sortOrder,
    int limit,
    int offset,
  });

  Future<DiscoverMutualFundListResponse> getMutualFunds({
    required String preset,
    String? search,
    String? category,
    String? riskLevel,
    required bool directOnly,
    double? minScore,
    double? minAumCr,
    double? maxExpenseRatio,
    double? minReturn1y,
    double? minReturn3y,
    double? minReturn5y,
    double? minFundAge,
    String? sourceStatus,
    String sortBy,
    String sortOrder,
    int limit,
    int offset,
  });

  Future<UnifiedSearchResponse> search({
    required String query,
    int limit,
  });

  Future<DiscoverHomeData> getHomeData();

  Future<PriceHistoryResponse> getStockHistory({
    required String symbol,
    int days,
  });

  Future<PriceHistoryResponse> getMfNavHistory({
    required String schemeCode,
    int days,
  });

  Future<DiscoverStockItem> getStockBySymbol({required String symbol});

  Future<DiscoverMutualFundItem> getMfBySchemeCode({required String schemeCode});

  Future<List<DiscoverStockItem>> getStockPeers({
    required String symbol,
    int limit,
  });

  Future<List<DiscoverMutualFundItem>> getMfPeers({
    required String schemeCode,
    int limit,
  });

  Future<Map<String, List<PriceHistoryPoint>>> getStockSparklines({
    required List<String> symbols,
    int days,
  });

  Future<Map<String, List<PriceHistoryPoint>>> getMfSparklines({
    required List<String> schemeCodes,
    int days,
  });
}

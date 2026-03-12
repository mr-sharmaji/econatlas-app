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
    double? minReturn3y,
    String? sourceStatus,
    String sortBy,
    String sortOrder,
    int limit,
    int offset,
  });

  Future<DiscoverCompareResponse> getCompare({
    required String segment,
    required List<String> ids,
  });
}

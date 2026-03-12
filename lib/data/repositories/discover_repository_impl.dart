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
    double? minReturn3y,
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
      minReturn3y: minReturn3y,
      sourceStatus: sourceStatus,
      sortBy: sortBy,
      sortOrder: sortOrder,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<DiscoverCompareResponse> getCompare({
    required String segment,
    required List<String> ids,
  }) {
    return _remote.getDiscoverCompare(segment: segment, ids: ids);
  }
}

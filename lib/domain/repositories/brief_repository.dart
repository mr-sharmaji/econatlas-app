import '../../data/models/brief.dart';

abstract class BriefRepository {
  Future<PostMarketOverview> getPostMarketOverview({required String market});

  Future<BriefStockListResponse> getMovers({
    required String market,
    required String type,
    int limit = 10,
  });

  Future<BriefStockListResponse> getMostActive({
    required String market,
    int limit = 10,
  });

  Future<BriefSectorPulseResponse> getSectors({
    required String market,
    int limit = 8,
  });
}

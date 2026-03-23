import 'package:dio/dio.dart';
import '../models/models.dart';

class RemoteDataSource {
  final Dio _dio;

  RemoteDataSource(this._dio);

  Future<MarketPriceResponse> getMarketPrices({
    String? instrumentType,
    String? asset,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (instrumentType != null) params['instrument_type'] = instrumentType;
    if (asset != null) params['asset'] = asset;

    final response = await _dio.get('/market', queryParameters: params);
    return MarketPriceResponse.fromJson(response.data);
  }

  Future<MarketPriceResponse> getLatestMarketPrices({
    String? instrumentType,
  }) async {
    final params = <String, dynamic>{};
    if (instrumentType != null) params['instrument_type'] = instrumentType;

    final response = await _dio.get(
      '/market/latest',
      queryParameters: params,
    );
    return MarketPriceResponse.fromJson(response.data);
  }

  Future<MarketStatus> getMarketStatus() async {
    final response = await _dio.get('/market/status');
    return MarketStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<IntradayResponse> getMarketIntraday({
    required String asset,
    required String instrumentType,
  }) async {
    final response = await _dio.get(
      '/market/intraday',
      queryParameters: {
        'asset': asset,
        'instrument_type': instrumentType,
      },
    );
    return IntradayResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MarketStory> getMarketStory({
    required String asset,
    required String instrumentType,
  }) async {
    final response = await _dio.get(
      '/market/story',
      queryParameters: {'asset': asset, 'instrument_type': instrumentType},
    );
    return MarketStory.fromJson(response.data as Map<String, dynamic>);
  }

  Future<IntradayResponse> getCommodityIntraday({required String asset}) async {
    final response = await _dio.get(
      '/commodities/intraday',
      queryParameters: {'asset': asset},
    );
    return IntradayResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MarketPriceResponse> getCommodities({
    String? asset,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (asset != null) params['asset'] = asset;

    final response = await _dio.get('/commodities', queryParameters: params);
    return MarketPriceResponse.fromJson(response.data);
  }

  Future<MarketPriceResponse> getLatestCommodities() async {
    final response = await _dio.get('/commodities/latest');
    return MarketPriceResponse.fromJson(response.data);
  }

  Future<IntradayResponse> getCryptoIntraday({required String asset}) async {
    final response = await _dio.get(
      '/crypto/intraday',
      queryParameters: {'asset': asset},
    );
    return IntradayResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MarketPriceResponse> getCrypto({
    String? asset,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (asset != null) params['asset'] = asset;

    final response = await _dio.get('/crypto', queryParameters: params);
    return MarketPriceResponse.fromJson(response.data);
  }

  Future<MarketPriceResponse> getLatestCrypto() async {
    final response = await _dio.get('/crypto/latest');
    return MarketPriceResponse.fromJson(response.data);
  }

  Future<NewsResponse> getNews({
    String? entity,
    String? impact,
    String? source,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (entity != null) params['entity'] = entity;
    if (impact != null) params['impact'] = impact;
    if (source != null) params['source'] = source;

    final response = await _dio.get('/news', queryParameters: params);
    return NewsResponse.fromJson(response.data);
  }

  Future<MacroResponse> getMacroIndicators({
    String? country,
    int limit = 50,
    int offset = 0,
    bool latestOnly = false,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (country != null) params['country'] = country;
    if (latestOnly) params['latest_only'] = true;

    final response = await _dio.get('/macro', queryParameters: params);
    return MacroResponse.fromJson(response.data);
  }

  Future<InstitutionalFlowsOverview> getInstitutionalFlowsOverview({
    int sessions = 7,
  }) async {
    final response = await _dio.get(
      '/macro/flows/overview',
      queryParameters: {'sessions': sessions},
    );
    return InstitutionalFlowsOverview.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<MacroForecastResponse> getMacroForecasts({
    String? country,
    String? indicator,
  }) async {
    final params = <String, dynamic>{};
    if (country != null) params['country'] = country;
    if (indicator != null) params['indicator'] = indicator;
    final response =
        await _dio.get('/macro/forecasts', queryParameters: params);
    return MacroForecastResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<EconCalendarResponse> getEconCalendar({
    int daysAhead = 90,
    String? country,
    bool includePast = false,
  }) async {
    final params = <String, dynamic>{
      'days_ahead': daysAhead,
      'include_past': includePast,
    };
    if (country != null) params['country'] = country;
    final response = await _dio.get('/macro/calendar', queryParameters: params);
    return EconCalendarResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MacroMetadataResponse> getMacroMetadata() async {
    final response = await _dio.get('/macro/metadata');
    return MacroMetadataResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<MacroRegimeResponse> getMacroRegime({String? country}) async {
    final params = <String, dynamic>{};
    if (country != null && country.trim().isNotEmpty) {
      params['country'] = country;
    }
    final response = await _dio.get('/macro/regime', queryParameters: params);
    return MacroRegimeResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MacroSummaryResponse> getMacroSummary({String? country}) async {
    final params = <String, dynamic>{};
    if (country != null && country.trim().isNotEmpty) {
      params['country'] = country;
    }
    final response = await _dio.get('/macro/summary', queryParameters: params);
    return MacroSummaryResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MacroLinkagesResponse> getMacroLinkages({
    required String country,
    required String indicator,
    int windowDays = 365,
  }) async {
    final response = await _dio.get(
      '/macro/linkages',
      queryParameters: {
        'country': country,
        'indicator': indicator,
        'window_days': windowDays,
      },
    );
    return MacroLinkagesResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<EconomicEventListResponse> getEvents({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      '/events',
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );
    return EconomicEventListResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.data['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<AssetCatalogResponse> getAssetCatalog({
    String? region,
    String? instrumentType,
  }) async {
    final params = <String, dynamic>{};
    if (region != null && region.trim().isNotEmpty && region != 'All') {
      params['region'] = region;
    }
    if (instrumentType != null && instrumentType.trim().isNotEmpty) {
      params['instrument_type'] = instrumentType;
    }
    final response = await _dio.get('/assets/catalog', queryParameters: params);
    return AssetCatalogResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WatchlistResponse> getWatchlist({required String deviceId}) async {
    final response = await _dio.get(
      '/watchlist',
      queryParameters: {'device_id': deviceId},
    );
    return WatchlistResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WatchlistResponse> putWatchlist({
    required String deviceId,
    required List<String> assets,
  }) async {
    final response = await _dio.put(
      '/watchlist',
      queryParameters: {'device_id': deviceId},
      data: {'assets': assets},
    );
    return WatchlistResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ScreenerResponse> getScreener({
    required String preset,
    String? region,
    String? instrumentType,
    int limit = 25,
    double minQuality = 0.0,
  }) async {
    final params = <String, dynamic>{
      'preset': preset,
      'limit': limit,
      'min_quality': minQuality,
    };
    if (region != null && region.trim().isNotEmpty && region != 'All') {
      params['region'] = region;
    }
    if (instrumentType != null && instrumentType.trim().isNotEmpty) {
      params['instrument_type'] = instrumentType;
    }
    final response = await _dio.get('/screener', queryParameters: params);
    return ScreenerResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DataHealthResponse> getDataHealth() async {
    final response = await _dio.get('/ops/data-health');
    return DataHealthResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PostMarketOverview> getBriefPostMarket({
    required String market,
  }) async {
    final response = await _dio.get(
      '/brief/post-market',
      queryParameters: {'market': market},
    );
    return PostMarketOverview.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BriefStockListResponse> getBriefMovers({
    required String market,
    required String type,
    int limit = 10,
  }) async {
    final response = await _dio.get(
      '/brief/movers',
      queryParameters: {
        'market': market,
        'type': type,
        'limit': limit,
      },
    );
    return BriefStockListResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<BriefStockListResponse> getBriefMostActive({
    required String market,
    int limit = 10,
  }) async {
    final response = await _dio.get(
      '/brief/most-active',
      queryParameters: {
        'market': market,
        'limit': limit,
      },
    );
    return BriefStockListResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<BriefSectorPulseResponse> getBriefSectors({
    required String market,
    int limit = 8,
  }) async {
    final response = await _dio.get(
      '/brief/sectors',
      queryParameters: {
        'market': market,
        'limit': limit,
      },
    );
    return BriefSectorPulseResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<DiscoverOverview> getDiscoverOverview({
    required String segment,
  }) async {
    final response = await _dio.get(
      '/screener/overview',
      queryParameters: {'segment': segment},
    );
    return DiscoverOverview.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DiscoverStockListResponse> getDiscoverStocks({
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
  }) async {
    final params = <String, dynamic>{
      'preset': preset,
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'limit': limit,
      'offset': offset,
    };
    if (search != null && search.trim().isNotEmpty) params['search'] = search;
    if (sector != null && sector.trim().isNotEmpty) params['sector'] = sector;
    if (minScore != null) params['min_score'] = minScore;
    if (maxScore != null) params['max_score'] = maxScore;
    if (minPrice != null) params['min_price'] = minPrice;
    if (maxPrice != null) params['max_price'] = maxPrice;
    if (minPe != null) params['min_pe'] = minPe;
    if (maxPe != null) params['max_pe'] = maxPe;
    if (minRoe != null) params['min_roe'] = minRoe;
    if (minRoce != null) params['min_roce'] = minRoce;
    if (maxDebtToEquity != null) {
      params['max_debt_to_equity'] = maxDebtToEquity;
    }
    if (minVolume != null) params['min_volume'] = minVolume;
    if (minTradedValue != null) params['min_traded_value'] = minTradedValue;
    if (minMarketCap != null) params['min_market_cap'] = minMarketCap;
    if (maxMarketCap != null) params['max_market_cap'] = maxMarketCap;
    if (minDividendYield != null) {
      params['min_dividend_yield'] = minDividendYield;
    }
    if (minPb != null) params['min_pb'] = minPb;
    if (maxPb != null) params['max_pb'] = maxPb;
    if (sourceStatus != null && sourceStatus.trim().isNotEmpty) {
      params['source_status'] = sourceStatus;
    }
    final response =
        await _dio.get('/screener/stocks', queryParameters: params);
    return DiscoverStockListResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<DiscoverMutualFundListResponse> getDiscoverMutualFunds({
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
  }) async {
    final params = <String, dynamic>{
      'preset': preset,
      'direct_only': directOnly,
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'limit': limit,
      'offset': offset,
    };
    if (search != null && search.trim().isNotEmpty) params['search'] = search;
    if (category != null && category.trim().isNotEmpty) {
      params['category'] = category;
    }
    if (riskLevel != null && riskLevel.trim().isNotEmpty) {
      params['risk_level'] = riskLevel;
    }
    if (minScore != null) params['min_score'] = minScore;
    if (minAumCr != null) params['min_aum_cr'] = minAumCr;
    if (maxExpenseRatio != null) {
      params['max_expense_ratio'] = maxExpenseRatio;
    }
    if (minReturn1y != null) params['min_return_1y'] = minReturn1y;
    if (minReturn3y != null) params['min_return_3y'] = minReturn3y;
    if (minReturn5y != null) params['min_return_5y'] = minReturn5y;
    if (minFundAge != null) params['min_fund_age'] = minFundAge;
    if (sourceStatus != null && sourceStatus.trim().isNotEmpty) {
      params['source_status'] = sourceStatus;
    }
    final response = await _dio.get(
      '/screener/mutual-funds',
      queryParameters: params,
    );
    return DiscoverMutualFundListResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<UnifiedSearchResponse> discoverSearch({
    required String query,
    int limit = 10,
  }) async {
    final response = await _dio.get(
      '/screener/search',
      queryParameters: {'q': query, 'limit': limit},
    );
    return UnifiedSearchResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<DiscoverHomeData> getDiscoverHome() async {
    final response = await _dio.get('/screener/home');
    return DiscoverHomeData.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<PriceHistoryResponse> getDiscoverStockHistory({
    required String symbol,
    int days = 365,
  }) async {
    final response = await _dio.get(
      '/screener/stocks/${Uri.encodeComponent(symbol)}/history',
      queryParameters: {'days': days},
    );
    return PriceHistoryResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<PriceHistoryResponse> getDiscoverMfNavHistory({
    required String schemeCode,
    int days = 365,
  }) async {
    final response = await _dio.get(
      '/screener/mutual-funds/${Uri.encodeComponent(schemeCode)}/history',
      queryParameters: {'days': days},
    );
    return PriceHistoryResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<DiscoverStockItem> getDiscoverStockBySymbol(String symbol) async {
    final response = await _dio
        .get('/screener/stocks/${Uri.encodeComponent(symbol)}/detail');
    return DiscoverStockItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DiscoverMutualFundItem> getDiscoverMfBySchemeCode(
      String schemeCode) async {
    final response = await _dio.get(
        '/screener/mutual-funds/${Uri.encodeComponent(schemeCode)}/detail');
    return DiscoverMutualFundItem.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<List<DiscoverStockItem>> getDiscoverStockPeers({
    required String symbol,
    int limit = 5,
  }) async {
    final response = await _dio.get(
      '/screener/stocks/${Uri.encodeComponent(symbol)}/peers',
      queryParameters: {'limit': limit},
    );
    final raw = response.data;
    final list = raw is List<dynamic>
        ? raw
        : (raw is Map<String, dynamic>
            ? (raw['items'] as List<dynamic>? ?? const [])
            : const <dynamic>[]);
    return list
        .map((e) => DiscoverStockItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DiscoverMutualFundItem>> getDiscoverMfPeers({
    required String schemeCode,
    int limit = 5,
  }) async {
    final response = await _dio.get(
      '/screener/mutual-funds/${Uri.encodeComponent(schemeCode)}/peers',
      queryParameters: {'limit': limit},
    );
    final raw = response.data;
    final list = raw is List<dynamic>
        ? raw
        : (raw is Map<String, dynamic>
            ? (raw['items'] as List<dynamic>? ?? const [])
            : const <dynamic>[]);
    return list
        .map((e) => DiscoverMutualFundItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, List<PriceHistoryPoint>>> getStockSparklines({
    required List<String> symbols,
    int days = 7,
  }) async {
    final response = await _dio.get(
      '/screener/stocks/sparklines',
      queryParameters: {
        'symbols': symbols.join(','),
        'days': days,
        'max_points': 30,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return data.map((key, value) {
      final points = (value as List<dynamic>)
          .map((e) => PriceHistoryPoint.fromJson(e as Map<String, dynamic>))
          .toList();
      return MapEntry(key, points);
    });
  }

  Future<Map<String, List<PriceHistoryPoint>>> getMfSparklines({
    required List<String> schemeCodes,
    int days = 7,
  }) async {
    final response = await _dio.get(
      '/screener/mutual-funds/sparklines',
      queryParameters: {
        'scheme_codes': schemeCodes.join(','),
        'days': days,
        'max_points': 30,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return data.map((key, value) {
      final points = (value as List<dynamic>)
          .map((e) => PriceHistoryPoint.fromJson(e as Map<String, dynamic>))
          .toList();
      return MapEntry(key, points);
    });
  }

  Future<ScoreHistoryResponse> getStockScoreHistory({
    required String symbol,
    int days = 30,
  }) async {
    final response = await _dio.get(
      '/screener/stocks/${Uri.encodeComponent(symbol)}/score-history',
      queryParameters: {'days': days},
    );
    return ScoreHistoryResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<StockStory> getStockStory(String symbol) async {
    final response = await _dio.get(
      '/screener/stocks/${Uri.encodeComponent(symbol)}/story',
    );
    return StockStory.fromJson(response.data as Map<String, dynamic>);
  }

  Future<StockCompareResponse> compareStocks(List<String> symbols) async {
    final response = await _dio.get(
      '/screener/stocks/compare',
      queryParameters: {'symbols': symbols.join(',')},
    );
    return StockCompareResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MarketMood> getMarketMood() async {
    final response = await _dio.get('/screener/market-mood');
    return MarketMood.fromJson(response.data as Map<String, dynamic>);
  }

  Future<IpoListResponse> getIpos({
    required String status,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '/ipos',
      queryParameters: {
        'status': status,
        'limit': limit,
      },
    );
    return IpoListResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<IpoAlertsResponse> getIpoAlerts({required String deviceId}) async {
    final response = await _dio.get(
      '/ipos/alerts',
      queryParameters: {'device_id': deviceId},
    );
    return IpoAlertsResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<IpoAlertsResponse> putIpoAlerts({
    required String deviceId,
    required List<String> symbols,
  }) async {
    final response = await _dio.put(
      '/ipos/alerts',
      queryParameters: {'device_id': deviceId},
      data: {'symbols': symbols},
    );
    return IpoAlertsResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<OpsLogListResponse> getOpsLogs({
    int limit = 120,
    int? afterId,
    String? minLevel,
    String? contains,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
    };
    if (afterId != null && afterId > 0) params['after_id'] = afterId;
    if (minLevel != null && minLevel.trim().isNotEmpty) {
      params['min_level'] = minLevel.trim().toUpperCase();
    }
    if (contains != null && contains.trim().isNotEmpty) {
      params['contains'] = contains.trim();
    }
    final response = await _dio.get('/ops/logs', queryParameters: params);
    return OpsLogListResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<FeedbackSubmitResponse> submitFeedback({
    required String deviceId,
    required String category,
    required String message,
    String? appVersion,
    String? platform,
  }) async {
    final response = await _dio.post(
      '/feedback',
      data: {
        'device_id': deviceId,
        'category': category,
        'message': message,
        'app_version': appVersion,
        'platform': platform,
      },
    );
    return FeedbackSubmitResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<FeedbackListResponse> getFeedbackSubmissions({
    int limit = 80,
  }) async {
    final response = await _dio.get(
      '/feedback',
      queryParameters: {'limit': limit},
    );
    return FeedbackListResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> triggerJob(String jobName) async {
    final response = await _dio.post(
      '/ops/jobs/trigger/$jobName',
      options: Options(
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<String>> listJobs() async {
    final response = await _dio.get('/ops/jobs');
    final data = response.data as Map<String, dynamic>;
    return (data['jobs'] as List<dynamic>).map((e) => '$e').toList();
  }

  Future<TaxConfig> getTaxConfig() async {
    final response = await _dio.get('/tax/config');
    return TaxConfig.fromJson(response.data as Map<String, dynamic>);
  }
}

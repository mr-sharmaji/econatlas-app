import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/connectivity.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../data/datasources/remote_data_source.dart';
import '../../data/models/discover.dart';
import '../../data/models/market_price.dart';
import '../../data/services/starred_stocks_service.dart';
import '../../domain/repositories/commodity_repository.dart';
import '../../domain/repositories/crypto_repository.dart';
import '../../domain/repositories/discover_repository.dart';
import '../../domain/repositories/market_repository.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

final dashboardHomeWidgetServiceProvider =
    Provider<DashboardHomeWidgetService>((ref) {
  return DashboardHomeWidgetService(
    prefs: ref.read(sharedPreferencesProvider),
    remoteDataSource: ref.read(remoteDataSourceProvider),
    marketRepository: ref.read(marketRepositoryProvider),
    commodityRepository: ref.read(commodityRepositoryProvider),
    cryptoRepository: ref.read(cryptoRepositoryProvider),
    discoverRepository: ref.read(discoverRepositoryProvider),
    unitSystem: ref.read(unitSystemProvider),
    deviceId: ref.read(deviceIdProvider),
  );
});

class DashboardHomeWidgetService {
  DashboardHomeWidgetService({
    required SharedPreferences prefs,
    required RemoteDataSource remoteDataSource,
    required MarketRepository marketRepository,
    required CommodityRepository commodityRepository,
    required CryptoRepository cryptoRepository,
    required DiscoverRepository discoverRepository,
    required UnitSystem unitSystem,
    required String deviceId,
  })  : _prefs = prefs,
        _remoteDataSource = remoteDataSource,
        _marketRepository = marketRepository,
        _commodityRepository = commodityRepository,
        _cryptoRepository = cryptoRepository,
        _discoverRepository = discoverRepository,
        _unitSystem = unitSystem,
        _deviceId = deviceId;

  final SharedPreferences _prefs;
  final RemoteDataSource _remoteDataSource;
  final MarketRepository _marketRepository;
  final CommodityRepository _commodityRepository;
  final CryptoRepository _cryptoRepository;
  final DiscoverRepository _discoverRepository;
  final UnitSystem _unitSystem;
  final String _deviceId;

  static const _widgetUriScheme = 'econatlas';

  Future<void> publish({bool preferNetwork = true}) async {
    if (!Platform.isAndroid) return;

    final existingSnapshot = _prefs.getString(
      AppConstants.prefDashboardWidgetSnapshot,
    );

    try {
      final snapshot = await _buildSnapshot(preferNetwork: preferNetwork);
      final encoded = jsonEncode(snapshot.toJson());

      await _prefs.setString(AppConstants.prefDashboardWidgetSnapshot, encoded);
      await _prefs.setString(
        AppConstants.prefDashboardWidgetSnapshotTs,
        snapshot.generatedAt.toIso8601String(),
      );
      await HomeWidget.saveWidgetData(
        AppConstants.prefDashboardWidgetSnapshot,
        encoded,
      );
      await HomeWidget.saveWidgetData(
        AppConstants.prefDashboardWidgetSnapshotTs,
        snapshot.generatedAt.toIso8601String(),
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: AppConstants.dashboardWidgetProviderQualifiedName,
      );
    } catch (error, stackTrace) {
      debugPrint('Dashboard widget publish failed: $error\n$stackTrace');
      if (existingSnapshot != null && existingSnapshot.isNotEmpty) {
        await HomeWidget.updateWidget(
          qualifiedAndroidName:
              AppConstants.dashboardWidgetProviderQualifiedName,
        );
      }
    }
  }

  Future<DashboardWidgetSnapshot> _buildSnapshot({
    required bool preferNetwork,
  }) async {
    final generatedAt = DateTime.now();
    final offline = await isOffline();
    final shouldUseNetwork = preferNetwork && !offline;
    final previousItemsByRoute = _loadPreviousItemsByRoute();

    final watchlist = await _resolveWatchlist(useNetwork: shouldUseNetwork);
    final latestMarket = await _resolveLatestMarketPrices(
      useNetwork: shouldUseNetwork,
    );
    final latestCommodities = await _resolveLatestCommodities(
      useNetwork: shouldUseNetwork,
    );
    final latestCrypto = await _resolveLatestCrypto(
      useNetwork: shouldUseNetwork,
    );
    final combined = [...latestMarket, ...latestCommodities, ...latestCrypto];
    final byAsset = <String, MarketPrice>{};
    for (final price in combined) {
      byAsset.putIfAbsent(price.asset, () => price);
    }

    final usdInrRate = byAsset['USD/INR']?.price ??
        _prefs.getDouble(AppConstants.prefCacheUsdInrRate) ??
        83.0;
    if (byAsset['USD/INR']?.price != null) {
      await _prefs.setDouble(
        AppConstants.prefCacheUsdInrRate,
        byAsset['USD/INR']!.price,
      );
      await _prefs.setString(
        AppConstants.prefCacheUsdInrRateTs,
        generatedAt.toUtc().millisecondsSinceEpoch.toString(),
      );
    }

    final starredItems = StarredStocksService(_prefs).load();
    final starredStocks = starredItems
        .where((item) => item.type == 'stock')
        .toList(growable: false);
    final starredMfs =
        starredItems.where((item) => item.type == 'mf').toList(growable: false);

    final stockDetails = await _resolveStockDetails(
      symbols: starredStocks.map((item) => item.id).toList(growable: false),
      useNetwork: shouldUseNetwork,
    );
    final mfDetails = await _resolveMfDetails(
      schemeCodes: starredMfs.map((item) => item.id).toList(growable: false),
      useNetwork: shouldUseNetwork,
    );

    // Widget default sort: keep the Markets tab in the user's own
    // watchlist order (indices / commodities follow a deliberate
    // layout in-app), but sort Stocks and Mutual Funds alphabetically
    // by display_name so the widget's ListView always reads top-down
    // in a predictable order. Matches what the user expects from a
    // home-screen watchlist and avoids "why is XYZ at the bottom"
    // confusion.
    final sortedStocks = [...starredStocks]
      ..sort((a, b) {
        // Prefer live display_name when available, fall back to the
        // saved StarredItem name.
        final na = stockDetails[a.id]?.displayName ?? a.name;
        final nb = stockDetails[b.id]?.displayName ?? b.name;
        return na.toLowerCase().compareTo(nb.toLowerCase());
      });
    final sortedMfs = [...starredMfs]
      ..sort((a, b) {
        final na = mfDetails[a.id]?.displayName ??
            mfDetails[a.id]?.schemeName ??
            a.name;
        final nb = mfDetails[b.id]?.displayName ??
            mfDetails[b.id]?.schemeName ??
            b.name;
        return na.toLowerCase().compareTo(nb.toLowerCase());
      });

    final items = <DashboardWidgetListItem>[];
    _appendSection(
      items,
      title: 'Markets',
      count: watchlist.length,
      content: [
        if (watchlist.isEmpty)
          const DashboardWidgetListItem.empty(
            title: 'Add markets in Watchlist to see them here.',
          )
        else
          for (final asset in watchlist)
            _buildMarketItem(
              asset: asset,
              price: byAsset[asset],
              usdInrRate: usdInrRate,
              previous: _findPreviousMarketItem(
                asset: asset,
                previousItemsByRoute: previousItemsByRoute,
              ),
            ),
      ],
    );
    _appendSection(
      items,
      title: 'Stocks',
      count: sortedStocks.length,
      content: [
        if (sortedStocks.isEmpty)
          const DashboardWidgetListItem.empty(
            title: 'Star stocks from Discover to see them here.',
          )
        else
          for (final item in sortedStocks)
            _buildStockItem(
              item: item,
              live: stockDetails[item.id],
              previous: previousItemsByRoute[_widgetRoute(
                '/discover/stock/${Uri.encodeComponent(item.id)}',
              )],
            ),
      ],
    );
    _appendSection(
      items,
      title: 'Mutual Funds',
      count: sortedMfs.length,
      content: [
        if (sortedMfs.isEmpty)
          const DashboardWidgetListItem.empty(
            title: 'Star mutual funds from Discover to see them here.',
          )
        else
          for (final item in sortedMfs)
            _buildMfItem(
              item: item,
              live: mfDetails[item.id],
              previous: previousItemsByRoute[_widgetRoute(
                '/discover/mf/${Uri.encodeComponent(item.id)}',
              )],
            ),
      ],
    );

    return DashboardWidgetSnapshot(
      generatedAt: generatedAt,
      title: 'EconAtlas Watchlist',
      subtitle:
          'Last refreshed ${DateFormat('d MMM, h:mm a').format(generatedAt)}',
      launchRoute: _widgetRoute('/dashboard'),
      items: items,
    );
  }

  Future<List<String>> _resolveWatchlist({required bool useNetwork}) async {
    final cached = _loadCachedWatchlist();
    if (!useNetwork) return cached;

    try {
      final fresh = await _remoteDataSource
          .getWatchlist(deviceId: _deviceId)
          .then((response) => response.assets);
      await _prefs.setString(
        AppConstants.prefCacheWatchlist,
        jsonEncode(fresh),
      );
      return fresh;
    } catch (_) {
      return cached;
    }
  }

  List<String> _loadCachedWatchlist() {
    final raw = _prefs.getString(AppConstants.prefCacheWatchlist);
    if (raw == null || raw.trim().isEmpty) return const <String>[];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<List<MarketPrice>> _resolveLatestMarketPrices({
    required bool useNetwork,
  }) {
    return _resolveMarketLikeList(
      useNetwork: useNetwork,
      cacheKey: AppConstants.prefCacheLatestMarketAll,
      tsKey: AppConstants.prefCacheLatestMarketAllTs,
      fetcher: () async =>
          (await _marketRepository.getLatestMarketPrices()).prices,
    );
  }

  Future<List<MarketPrice>> _resolveLatestCommodities({
    required bool useNetwork,
  }) {
    return _resolveMarketLikeList(
      useNetwork: useNetwork,
      cacheKey: AppConstants.prefCacheLatestCommodities,
      tsKey: AppConstants.prefCacheLatestCommoditiesTs,
      fetcher: () async =>
          (await _commodityRepository.getLatestCommodities()).prices,
    );
  }

  Future<List<MarketPrice>> _resolveLatestCrypto({
    required bool useNetwork,
  }) {
    return _resolveMarketLikeList(
      useNetwork: useNetwork,
      cacheKey: AppConstants.prefCacheLatestCrypto,
      tsKey: AppConstants.prefCacheLatestCryptoTs,
      fetcher: () async => (await _cryptoRepository.getLatestCrypto()).prices,
    );
  }

  Future<List<MarketPrice>> _resolveMarketLikeList({
    required bool useNetwork,
    required String cacheKey,
    required String tsKey,
    required Future<List<MarketPrice>> Function() fetcher,
  }) async {
    final cached = _loadCachedMarketList(cacheKey);
    if (!useNetwork) return cached;

    try {
      final fresh = await fetcher();
      if (fresh.isNotEmpty) {
        await _prefs.setString(
          cacheKey,
          jsonEncode(fresh.map((item) => item.toJson()).toList()),
        );
        await _prefs.setString(
          tsKey,
          DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
        );
      }
      return fresh.isNotEmpty ? fresh : cached;
    } catch (_) {
      return cached;
    }
  }

  List<MarketPrice> _loadCachedMarketList(String cacheKey) {
    final raw = _prefs.getString(cacheKey);
    if (raw == null || raw.trim().isEmpty) return const <MarketPrice>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => MarketPrice.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const <MarketPrice>[];
    }
  }

  Map<String, DashboardWidgetListItem> _loadPreviousItemsByRoute() {
    final raw = _prefs.getString(AppConstants.prefDashboardWidgetSnapshot);
    if (raw == null || raw.trim().isEmpty) {
      return const <String, DashboardWidgetListItem>{};
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items = (decoded['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DashboardWidgetListItem.fromJson)
          .where((item) => item.route != null)
          .toList(growable: false);
      return {for (final item in items) item.route!: item};
    } catch (_) {
      return const <String, DashboardWidgetListItem>{};
    }
  }

  DashboardWidgetListItem? _findPreviousMarketItem({
    required String asset,
    required Map<String, DashboardWidgetListItem> previousItemsByRoute,
  }) {
    final encodedAsset = Uri.encodeComponent(asset);
    return previousItemsByRoute[_widgetRoute('/market/detail/$encodedAsset')] ??
        previousItemsByRoute[
            _widgetRoute('/commodities/detail/$encodedAsset')] ??
        previousItemsByRoute[_widgetRoute('/crypto/detail/$encodedAsset')];
  }

  Future<Map<String, DiscoverStockItem>> _resolveStockDetails({
    required List<String> symbols,
    required bool useNetwork,
  }) async {
    if (!useNetwork || symbols.isEmpty) {
      return const <String, DiscoverStockItem>{};
    }
    final futures = symbols.map(
      (symbol) => _discoverRepository
          .getStockBySymbol(symbol: symbol)
          .then<MapEntry<String, DiscoverStockItem>?>(
            (item) => MapEntry(symbol, item),
            onError: (_) => null,
          ),
    );
    final results = await Future.wait(futures);
    return {
      for (final entry
          in results.whereType<MapEntry<String, DiscoverStockItem>>())
        entry.key: entry.value,
    };
  }

  Future<Map<String, DiscoverMutualFundItem>> _resolveMfDetails({
    required List<String> schemeCodes,
    required bool useNetwork,
  }) async {
    if (!useNetwork || schemeCodes.isEmpty) {
      return const <String, DiscoverMutualFundItem>{};
    }
    final futures = schemeCodes.map(
      (schemeCode) => _discoverRepository
          .getMfBySchemeCode(schemeCode: schemeCode)
          .then<MapEntry<String, DiscoverMutualFundItem>?>(
            (item) => MapEntry(schemeCode, item),
            onError: (_) => null,
          ),
    );
    final results = await Future.wait(futures);
    return {
      for (final entry
          in results.whereType<MapEntry<String, DiscoverMutualFundItem>>())
        entry.key: entry.value,
    };
  }

  DashboardWidgetListItem _buildMarketItem({
    required String asset,
    required MarketPrice? price,
    required double usdInrRate,
    DashboardWidgetListItem? previous,
  }) {
    final instrumentType = price?.instrumentType ?? 'index';
    final route = switch (instrumentType) {
      'commodity' => '/commodities/detail/${Uri.encodeComponent(asset)}',
      'crypto' => '/crypto/detail/${Uri.encodeComponent(asset)}',
      _ => '/market/detail/${Uri.encodeComponent(asset)}',
    };

    if (price == null) {
      if (previous != null) {
        return previous.copyWith(
          title: displayName(asset),
          route: _widgetRoute(route),
        );
      }
      return DashboardWidgetListItem.market(
        title: displayName(asset),
        subtitle: 'No cached quote yet',
        footer: 'Tap to open details',
        value: '—',
        change: '',
        changeTone: WidgetChangeTone.neutral,
        route: _widgetRoute(route),
      );
    }

    final useIndianUnits = _unitSystem == UnitSystem.indian &&
        (price.instrumentType == 'commodity' ||
            price.instrumentType == 'crypto');
    final display = assetDisplayPriceAndUnit(
      asset: price.asset,
      rawPrice: price.price,
      useIndianUnits: useIndianUnits,
      usdInrRate: usdInrRate,
      instrumentType: price.instrumentType,
      sourceUnit: price.unit,
    );
    final freshness = Formatters.marketFreshnessSubtitle(
      tickTime: price.lastTickTimestamp ?? price.timestamp,
      isPredictive: price.isPredictive ?? false,
    );

    return DashboardWidgetListItem.market(
      title: displayName(price.asset),
      subtitle: freshness,
      footer: '',
      value: '${display.$1}${display.$2}',
      change: _formatPercent(price.changePercent, digits: 2),
      changeTone: _toneFor(price.changePercent),
      route: _widgetRoute(route),
    );
  }

  DashboardWidgetListItem _buildStockItem({
    required StarredItem item,
    required DiscoverStockItem? live,
    DashboardWidgetListItem? previous,
  }) {
    // Compact footer: sector • Score N • action_tag. Deliberately
    // omit the "Saved / updated" freshness stamp — the widget
    // header already shows the global last-refreshed time, so
    // per-row staleness text is noise.
    final footerParts = <String>[
      if ((live?.sector ?? '').trim().isNotEmpty) live!.sector!.trim(),
      if (live != null) 'Score ${live.score.toStringAsFixed(0)}',
      if ((live?.actionTag ?? '').trim().isNotEmpty) live!.actionTag!.trim(),
    ];

    return DashboardWidgetListItem.stock(
      title: item.id,
      subtitle: live?.displayName ?? item.name,
      footer: footerParts.join(' • ').ifEmpty(previous?.footer ?? ''),
      value: live != null
          ? '₹ ${Formatters.fullPrice(live.lastPrice)}'
          : (previous?.value ?? ''),
      change: _formatPercent(live?.percentChange ?? item.percentChange).ifEmpty(
        previous?.change ?? '',
      ),
      changeTone: _toneFor(live?.percentChange ?? item.percentChange),
      route: _widgetRoute('/discover/stock/${Uri.encodeComponent(item.id)}'),
    );
  }

  DashboardWidgetListItem _buildMfItem({
    required StarredItem item,
    required DiscoverMutualFundItem? live,
    DashboardWidgetListItem? previous,
  }) {
    final subtitleParts = <String>[
      if ((live?.category ?? '').trim().isNotEmpty) live!.category!.trim(),
      if ((live?.fundClassification ?? '').trim().isNotEmpty)
        live!.fundClassification!.trim(),
    ];
    // Compact footer: Score • risk • expense • AUM. No "Saved / NAV
    // from" freshness — the header last-refreshed stamp covers it.
    final footerParts = <String>[
      if (live != null) 'Score ${live.score.toStringAsFixed(0)}',
      if ((live?.riskLevel ?? '').trim().isNotEmpty) live!.riskLevel!.trim(),
      if (live?.expenseRatio != null)
        'Exp ${live!.expenseRatio!.toStringAsFixed(2)}%',
      if (live?.aumCr != null) 'AUM ₹${Formatters.fullPrice(live!.aumCr!)} Cr',
    ];

    return DashboardWidgetListItem.mutualFund(
      title: live?.displayName ?? live?.schemeName ?? item.name,
      subtitle: subtitleParts.join(' • ').ifEmpty(previous?.subtitle ?? ''),
      footer: footerParts.join(' • ').ifEmpty(previous?.footer ?? ''),
      value: live != null
          ? '₹ ${Formatters.fullPrice(live.nav)}'
          : (previous?.value ?? ''),
      change: _formatReturn1y(live?.returns1y ?? item.percentChange).ifEmpty(
        previous?.change ?? '',
      ),
      changeTone: _toneFor(live?.returns1y ?? item.percentChange),
      // Pass the display name as a fallback query so the detail
      // screen can reconcile stale scheme codes (e.g. a starred
      // Regular plan code that no longer exists in the backend's
      // Direct-only snapshots table) by searching the name and
      // redirecting to the matching scheme_code.
      route: _widgetRoute(
        '/discover/mf/${Uri.encodeComponent(item.id)}'
        '?name=${Uri.encodeQueryComponent(item.name)}',
      ),
    );
  }

  void _appendSection(
    List<DashboardWidgetListItem> items, {
    required String title,
    required int count,
    required List<DashboardWidgetListItem> content,
  }) {
    items.add(DashboardWidgetListItem.section(title: title, count: count));
    items.addAll(content);
  }

  String _widgetRoute(String path) => '$_widgetUriScheme:///$path'.replaceAll(
        '////',
        '///',
      );

  WidgetChangeTone _toneFor(double? value) {
    if (value == null) return WidgetChangeTone.neutral;
    if (value > 0) return WidgetChangeTone.positive;
    if (value < 0) return WidgetChangeTone.negative;
    return WidgetChangeTone.neutral;
  }

  String _formatPercent(double? value, {int digits = 1}) {
    if (value == null) return '';
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(digits)}%';
  }

  String _formatReturn1y(double? value) {
    final formatted = _formatPercent(value);
    if (formatted.isEmpty) return '';
    return '$formatted 1Y';
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

enum DashboardWidgetItemType { section, market, stock, mutualFund, empty }

enum WidgetChangeTone { positive, negative, neutral }

@immutable
class DashboardWidgetSnapshot {
  const DashboardWidgetSnapshot({
    required this.generatedAt,
    required this.title,
    required this.subtitle,
    required this.launchRoute,
    required this.items,
  });

  final DateTime generatedAt;
  final String title;
  final String subtitle;
  final String launchRoute;
  final List<DashboardWidgetListItem> items;

  Map<String, dynamic> toJson() => {
        'generatedAt': generatedAt.toIso8601String(),
        'title': title,
        'subtitle': subtitle,
        'launchRoute': launchRoute,
        'items': items.map((item) => item.toJson()).toList(),
      };
}

@immutable
class DashboardWidgetListItem {
  const DashboardWidgetListItem({
    required this.type,
    required this.title,
    this.subtitle = '',
    this.footer = '',
    this.value = '',
    this.change = '',
    this.changeTone = WidgetChangeTone.neutral,
    this.count,
    this.route,
  });

  const DashboardWidgetListItem.section({
    required String title,
    required int count,
  }) : this(
          type: DashboardWidgetItemType.section,
          title: title,
          count: count,
        );

  const DashboardWidgetListItem.market({
    required String title,
    required String subtitle,
    required String footer,
    required String value,
    required String change,
    required WidgetChangeTone changeTone,
    required String route,
  }) : this(
          type: DashboardWidgetItemType.market,
          title: title,
          subtitle: subtitle,
          footer: footer,
          value: value,
          change: change,
          changeTone: changeTone,
          route: route,
        );

  const DashboardWidgetListItem.stock({
    required String title,
    required String subtitle,
    required String footer,
    required String value,
    required String change,
    required WidgetChangeTone changeTone,
    required String route,
  }) : this(
          type: DashboardWidgetItemType.stock,
          title: title,
          subtitle: subtitle,
          footer: footer,
          value: value,
          change: change,
          changeTone: changeTone,
          route: route,
        );

  const DashboardWidgetListItem.mutualFund({
    required String title,
    required String subtitle,
    required String footer,
    required String value,
    required String change,
    required WidgetChangeTone changeTone,
    required String route,
  }) : this(
          type: DashboardWidgetItemType.mutualFund,
          title: title,
          subtitle: subtitle,
          footer: footer,
          value: value,
          change: change,
          changeTone: changeTone,
          route: route,
        );

  const DashboardWidgetListItem.empty({
    required String title,
  }) : this(
          type: DashboardWidgetItemType.empty,
          title: title,
        );

  final DashboardWidgetItemType type;
  final String title;
  final String subtitle;
  final String footer;
  final String value;
  final String change;
  final WidgetChangeTone changeTone;
  final int? count;
  final String? route;

  Map<String, dynamic> toJson() => {
        'type': switch (type) {
          DashboardWidgetItemType.section => 'section',
          DashboardWidgetItemType.market => 'market',
          DashboardWidgetItemType.stock => 'stock',
          DashboardWidgetItemType.mutualFund => 'mutual_fund',
          DashboardWidgetItemType.empty => 'empty',
        },
        'title': title,
        'subtitle': subtitle,
        'footer': footer,
        'value': value,
        'change': change,
        'changeTone': switch (changeTone) {
          WidgetChangeTone.positive => 'positive',
          WidgetChangeTone.negative => 'negative',
          WidgetChangeTone.neutral => 'neutral',
        },
        if (count != null) 'count': count,
        if (route != null) 'route': route,
      };

  factory DashboardWidgetListItem.fromJson(Map<String, dynamic> json) {
    return DashboardWidgetListItem(
      type: switch (json['type']) {
        'section' => DashboardWidgetItemType.section,
        'market' => DashboardWidgetItemType.market,
        'stock' => DashboardWidgetItemType.stock,
        'mutual_fund' => DashboardWidgetItemType.mutualFund,
        _ => DashboardWidgetItemType.empty,
      },
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      footer: json['footer'] as String? ?? '',
      value: json['value'] as String? ?? '',
      change: json['change'] as String? ?? '',
      changeTone: switch (json['changeTone']) {
        'positive' => WidgetChangeTone.positive,
        'negative' => WidgetChangeTone.negative,
        _ => WidgetChangeTone.neutral,
      },
      count: (json['count'] as num?)?.toInt(),
      route: json['route'] as String?,
    );
  }

  DashboardWidgetListItem copyWith({
    DashboardWidgetItemType? type,
    String? title,
    String? subtitle,
    String? footer,
    String? value,
    String? change,
    WidgetChangeTone? changeTone,
    int? count,
    String? route,
  }) {
    return DashboardWidgetListItem(
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      footer: footer ?? this.footer,
      value: value ?? this.value,
      change: change ?? this.change,
      changeTone: changeTone ?? this.changeTone,
      count: count ?? this.count,
      route: route ?? this.route,
    );
  }
}

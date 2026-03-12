import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../core/error_utils.dart';
import '../../../core/market_status_helper.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/intraday_response.dart';
import '../../../data/models/market_price.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final ScrollController _indicesScrollController;
  late final ScrollController _currenciesScrollController;
  late final ScrollController _commoditiesScrollController;
  late final ScrollController _bondsScrollController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _indicesScrollController = ScrollController();
    _currenciesScrollController = ScrollController();
    _commoditiesScrollController = ScrollController();
    _bondsScrollController = ScrollController();
  }

  @override
  void dispose() {
    _indicesScrollController.dispose();
    _currenciesScrollController.dispose();
    _commoditiesScrollController.dispose();
    _bondsScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _scrollCurrentTabToTop() {
    final controller = switch (_tabController.index) {
      0 => _indicesScrollController,
      1 => _commoditiesScrollController,
      2 => _currenciesScrollController,
      _ => _bondsScrollController,
    };
    if (!controller.hasClients) return;
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(bottomTabReselectTickProvider(1), (prev, next) {
      if (prev == null || prev == next) return;
      _scrollCurrentTabToTop();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Markets'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Indices'),
            Tab(text: 'Commodities'),
            Tab(text: 'Currencies'),
            Tab(text: 'Bond'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _IndicesTab(scrollController: _indicesScrollController),
          _CommoditiesTab(scrollController: _commoditiesScrollController),
          _CurrenciesTab(scrollController: _currenciesScrollController),
          _BondsTab(scrollController: _bondsScrollController),
        ],
      ),
    );
  }
}

class _IndicesTab extends ConsumerWidget {
  const _IndicesTab({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricesAsync = ref.watch(latestMarketPricesProvider);
    final statusAsync = ref.watch(marketStatusProvider);
    final status = statusAsync.valueOrNull;
    bool isLiveFor(MarketPrice p) =>
        status != null &&
        isLiveForAsset(
          p.asset,
          p.instrumentType,
          status,
          lastUpdate: p.lastTickTimestamp ?? p.timestamp,
        );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(marketStatusProvider);
        ref.invalidate(latestMarketPricesProvider);
      },
      child: pricesAsync.when(
        loading: () => const ShimmerList(itemCount: 6),
        error: (err, _) => ErrorView(
          message: friendlyErrorMessage(err),
          onRetry: () => ref.invalidate(latestMarketPricesProvider),
        ),
        data: (prices) {
          final indices =
              prices.where((p) => p.instrumentType == 'index').toList();

          final inIndices = <MarketPrice>[];
          for (final name in Entities.indicesIndia) {
            final match = indices.where((p) => p.asset == name).toList();
            if (match.isNotEmpty) inIndices.add(match.first);
          }
          final usIndices = <MarketPrice>[];
          for (final name in Entities.indicesUS) {
            final match = indices.where((p) => p.asset == name).toList();
            if (match.isNotEmpty) usIndices.add(match.first);
          }
          final europeIndices = <MarketPrice>[];
          for (final name in Entities.indicesEurope) {
            final match = indices.where((p) => p.asset == name).toList();
            if (match.isNotEmpty) europeIndices.add(match.first);
          }
          final japanIndices = <MarketPrice>[];
          for (final name in Entities.indicesJapan) {
            final match = indices.where((p) => p.asset == name).toList();
            if (match.isNotEmpty) japanIndices.add(match.first);
          }

          if (indices.isEmpty) {
            return const EmptyView(
                message: 'No index data available', icon: Icons.show_chart);
          }

          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 112),
            children: [
              if (inIndices.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.india,
                  title: 'India',
                  subtitle: 'Key indices',
                ),
                ...inIndices
                    .map((p) => _MarketTile(price: p, isLive: isLiveFor(p))),
              ],
              if (usIndices.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.us,
                  title: 'United States',
                  subtitle: 'Key indices',
                ),
                ...usIndices
                    .map((p) => _MarketTile(price: p, isLive: isLiveFor(p))),
              ],
              if (europeIndices.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.europe,
                  title: 'Europe',
                  subtitle: 'Key indices',
                ),
                ...europeIndices
                    .map((p) => _MarketTile(price: p, isLive: isLiveFor(p))),
              ],
              if (japanIndices.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.japan,
                  title: 'Japan',
                  subtitle: 'Key indices',
                ),
                ...japanIndices
                    .map((p) => _MarketTile(price: p, isLive: isLiveFor(p))),
              ],
              ...indices
                  .where((p) =>
                      !Entities.indicesUS.contains(p.asset) &&
                      !Entities.indicesIndia.contains(p.asset) &&
                      !Entities.indicesEurope.contains(p.asset) &&
                      !Entities.indicesJapan.contains(p.asset))
                  .map((p) => _MarketTile(price: p, isLive: isLiveFor(p))),
            ],
          );
        },
      ),
    );
  }
}

class _CurrenciesTab extends ConsumerWidget {
  const _CurrenciesTab({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricesAsync = ref.watch(latestCurrenciesProvider);
    final statusAsync = ref.watch(marketStatusProvider);
    final status = statusAsync.valueOrNull;
    bool isLiveFor(MarketPrice p) =>
        status != null &&
        isLiveForAsset(
          p.asset,
          p.instrumentType,
          status,
          lastUpdate: p.lastTickTimestamp ?? p.timestamp,
        );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(marketStatusProvider);
        ref.invalidate(latestCurrenciesProvider);
      },
      child: pricesAsync.when(
        loading: () => const ShimmerList(itemCount: 4),
        error: (err, _) => ErrorView(
          message: friendlyErrorMessage(err),
          onRetry: () => ref.invalidate(latestCurrenciesProvider),
        ),
        data: (prices) {
          final filtered = <MarketPrice>[];
          for (final name in Entities.fx) {
            final match = prices.where((p) => p.asset == name).toList();
            if (match.isNotEmpty) filtered.add(match.first);
          }
          if (filtered.isEmpty) {
            return const EmptyView(
                message: 'No currency data', icon: Icons.currency_exchange);
          }
          final byAsset = {for (final p in filtered) p.asset: p};
          List<MarketPrice> group(List<String> names) {
            final out = <MarketPrice>[];
            for (final name in names) {
              final row = byAsset[name];
              if (row != null) out.add(row);
            }
            return out;
          }

          final majors = group(Entities.fxMajor);
          final asiaPacific = group(Entities.fxAsiaPacific);
          final middleEast = group(Entities.fxMiddleEast);
          final europe = group(Entities.fxEurope);
          final americas = group(Entities.fxAmericas);
          final africa = group(Entities.fxAfrica);
          final groupedAssets = <String>{
            ...Entities.fxMajor,
            ...Entities.fxAsiaPacific,
            ...Entities.fxMiddleEast,
            ...Entities.fxEurope,
            ...Entities.fxAmericas,
            ...Entities.fxAfrica,
          };
          final others =
              filtered.where((p) => !groupedAssets.contains(p.asset)).toList();
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 112),
            children: [
              if (majors.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.global,
                  title: 'Global Majors',
                  subtitle: 'High-volume INR pairs',
                ),
                ...majors.map((p) => _MarketTile(
                      price: p,
                      isLive: isLiveFor(p),
                      pricePrefix: '₹ ',
                    )),
              ],
              if (asiaPacific.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.asia,
                  title: 'Asia Pacific',
                  subtitle: 'Asia-Pacific INR pairs',
                ),
                ...asiaPacific.map((p) => _MarketTile(
                      price: p,
                      isLive: isLiveFor(p),
                      pricePrefix: '₹ ',
                    )),
              ],
              if (middleEast.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.middleEast,
                  title: 'Middle East',
                  subtitle: 'Middle East INR pairs',
                ),
                ...middleEast.map((p) => _MarketTile(
                      price: p,
                      isLive: isLiveFor(p),
                      pricePrefix: '₹ ',
                    )),
              ],
              if (europe.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.europe,
                  title: 'Europe',
                  subtitle: 'Europe INR pairs',
                ),
                ...europe.map((p) => _MarketTile(
                      price: p,
                      isLive: isLiveFor(p),
                      pricePrefix: '₹ ',
                    )),
              ],
              if (americas.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.americas,
                  title: 'Americas',
                  subtitle: 'Americas INR pairs',
                ),
                ...americas.map((p) => _MarketTile(
                      price: p,
                      isLive: isLiveFor(p),
                      pricePrefix: '₹ ',
                    )),
              ],
              if (africa.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.africa,
                  title: 'Africa',
                  subtitle: 'Africa INR pairs',
                ),
                ...africa.map((p) => _MarketTile(
                      price: p,
                      isLive: isLiveFor(p),
                      pricePrefix: '₹ ',
                    )),
              ],
              if (others.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.currenciesOther,
                  title: 'Other',
                  subtitle: 'Less-tracked INR pairs',
                ),
                ...others.map((p) => _MarketTile(
                      price: p,
                      isLive: isLiveFor(p),
                      pricePrefix: '₹ ',
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CommoditiesTab extends ConsumerWidget {
  const _CommoditiesTab({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricesAsync = ref.watch(latestCommoditiesProvider);
    final unitSystem = ref.watch(unitSystemProvider);
    final marketAsync = ref.watch(latestMarketPricesProvider);
    final statusAsync = ref.watch(marketStatusProvider);
    final status = statusAsync.valueOrNull;
    final usdInrRate = marketAsync.whenOrNull(
          data: (prices) {
            final usdInr = prices.where((p) => p.asset == 'USD/INR').toList();
            return usdInr.isNotEmpty ? usdInr.first.price : null;
          },
        ) ??
        84.0;
    bool isLiveFor(MarketPrice p) =>
        status != null &&
        isLiveForAsset(
          p.asset,
          p.instrumentType,
          status,
          lastUpdate: p.lastTickTimestamp ?? p.timestamp,
        );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(marketStatusProvider);
        ref.invalidate(latestCommoditiesProvider);
      },
      child: pricesAsync.when(
        loading: () => const ShimmerList(itemCount: 5),
        error: (err, _) => ErrorView(
          message: friendlyErrorMessage(err),
          onRetry: () => ref.invalidate(latestCommoditiesProvider),
        ),
        data: (prices) {
          if (prices.isEmpty) {
            return const EmptyView(
                message: 'No commodity data', icon: Icons.diamond_outlined);
          }

          final ordered = <MarketPrice>[];
          for (final name in Entities.commodities) {
            final match = prices.where((p) => p.asset == name).toList();
            if (match.isNotEmpty) ordered.add(match.first);
          }
          for (final p in prices) {
            if (!ordered.any((o) => o.asset == p.asset)) ordered.add(p);
          }

          final precious = ordered
              .where((p) =>
                  {'gold', 'silver', 'platinum', 'palladium'}.contains(p.asset))
              .toList();
          final industrial =
              ordered.where((p) => {'copper'}.contains(p.asset)).toList();
          final energy = ordered
              .where((p) => {'crude oil', 'natural gas'}.contains(p.asset))
              .toList();
          final others = ordered
              .where((p) => !{
                    'gold',
                    'silver',
                    'platinum',
                    'palladium',
                    'copper',
                    'crude oil',
                    'natural gas',
                  }.contains(p.asset))
              .toList();

          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 112),
            children: [
              if (precious.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.metals,
                  title: 'Precious Metals',
                  subtitle: 'Gold, silver, and other precious metals',
                ),
                ...precious.map((p) => _CommodityTile(
                      price: p,
                      usdInrRate: usdInrRate,
                      unitSystem: unitSystem,
                      isLive: isLiveFor(p),
                    )),
              ],
              if (industrial.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.metals,
                  title: 'Industrial Metals',
                  subtitle: 'Key industrial metal benchmarks',
                ),
                ...industrial.map((p) => _CommodityTile(
                      price: p,
                      usdInrRate: usdInrRate,
                      unitSystem: unitSystem,
                      isLive: isLiveFor(p),
                    )),
              ],
              if (energy.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.energy,
                  title: 'Energy',
                  subtitle: 'Oil and natural gas benchmarks',
                ),
                ...energy.map((p) => _CommodityTile(
                      price: p,
                      usdInrRate: usdInrRate,
                      unitSystem: unitSystem,
                      isLive: isLiveFor(p),
                    )),
              ],
              ...others.map((p) => _CommodityTile(
                    price: p,
                    usdInrRate: usdInrRate,
                    unitSystem: unitSystem,
                    isLive: isLiveFor(p),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _BondsTab extends ConsumerWidget {
  const _BondsTab({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricesAsync = ref.watch(latestBondsProvider);
    final statusAsync = ref.watch(marketStatusProvider);
    final status = statusAsync.valueOrNull;
    bool isLiveFor(MarketPrice p) =>
        status != null &&
        isLiveForAsset(
          p.asset,
          p.instrumentType,
          status,
          lastUpdate: p.lastTickTimestamp ?? p.timestamp,
        );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(marketStatusProvider);
        ref.invalidate(latestBondsProvider);
      },
      child: pricesAsync.when(
        loading: () => const ShimmerList(itemCount: 3),
        error: (err, _) => ErrorView(
          message: friendlyErrorMessage(err),
          onRetry: () => ref.invalidate(latestBondsProvider),
        ),
        data: (prices) {
          if (prices.isEmpty) {
            return const EmptyView(
                message: 'No bond data', icon: Icons.account_balance);
          }
          final ordered = <MarketPrice>[];
          for (final name in Entities.bonds) {
            final match = prices.where((p) => p.asset == name).toList();
            if (match.isNotEmpty) ordered.add(match.first);
          }
          for (final p in prices) {
            if (!ordered.any((o) => o.asset == p.asset)) ordered.add(p);
          }

          final inBonds =
              ordered.where((p) => p.asset.contains('India')).toList();
          final usBonds = ordered.where((p) => p.asset.contains('US')).toList();
          final euBonds =
              ordered.where((p) => p.asset.contains('Germany')).toList();
          final jpBonds =
              ordered.where((p) => p.asset.contains('Japan')).toList();
          final others = ordered
              .where((p) =>
                  !p.asset.contains('India') &&
                  !p.asset.contains('US') &&
                  !p.asset.contains('Germany') &&
                  !p.asset.contains('Japan'))
              .toList();

          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 112),
            children: [
              if (inBonds.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.india,
                  title: 'India',
                  subtitle: 'Government yields',
                ),
                ...inBonds.map((p) => _MarketTile(
                      price: p,
                      suffix: '%',
                      isLive: isLiveFor(p),
                      showChange: false,
                    )),
              ],
              if (usBonds.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.us,
                  title: 'United States',
                  subtitle: 'Treasury yields',
                ),
                ...usBonds.map((p) => _MarketTile(
                      price: p,
                      suffix: '%',
                      isLive: isLiveFor(p),
                      showChange: false,
                    )),
              ],
              if (euBonds.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.europe,
                  title: 'Europe',
                  subtitle: 'Sovereign yields',
                ),
                ...euBonds.map((p) => _MarketTile(
                      price: p,
                      suffix: '%',
                      isLive: isLiveFor(p),
                      showChange: false,
                    )),
              ],
              if (jpBonds.isNotEmpty) ...[
                const _RegionBanner(
                  badgeStyle: AssetBadgeStyle.japan,
                  title: 'Japan',
                  subtitle: 'Government yields',
                ),
                ...jpBonds.map((p) => _MarketTile(
                      price: p,
                      suffix: '%',
                      isLive: isLiveFor(p),
                      showChange: false,
                    )),
              ],
              ...others.map((p) => _MarketTile(
                    price: p,
                    suffix: '%',
                    isLive: isLiveFor(p),
                    showChange: false,
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _RegionBanner extends StatelessWidget {
  const _RegionBanner({
    required this.badgeStyle,
    required this.title,
    required this.subtitle,
  });

  final AssetBadgeStyle badgeStyle;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white10,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            AssetBadgeChip(
              style: badgeStyle,
              mode: AssetBadgeMode.category,
              size: 28,
              borderRadius: 8,
              showBorder: false,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketTile extends StatelessWidget {
  final MarketPrice price;
  final String pricePrefix;
  final String suffix;
  final bool isLive;
  final bool showChange;

  const _MarketTile({
    required this.price,
    this.pricePrefix = '',
    this.suffix = '',
    this.isLive = false,
    this.showChange = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasApiPhase = (price.marketPhase ?? '').trim().isNotEmpty;
    final apiPhase = normalizeMarketPhase(price.marketPhase);
    final phase = hasApiPhase ? apiPhase : (isLive ? 'live' : 'closed');
    final tickTs = price.lastTickTimestamp ?? price.timestamp;
    final isPredictive = price.isPredictive ?? false;
    final changeTag = Formatters.changeWithDiff(
      current: price.price,
      previous: price.previousClose,
      pct: price.changePercent,
    );
    final priceLabel = price.instrumentType == 'currency'
        ? Formatters.fxInrPrice(price.price)
        : Formatters.fullPrice(price.price);
    final pctColor = (price.changePercent ?? 0) >= 0
        ? AppTheme.accentGreen
        : AppTheme.accentRed;
    final subtitle = Formatters.marketFreshnessSubtitle(
      tickTime: tickTs,
      isPredictive: isPredictive,
    );

    return Card(
      child: InkWell(
        onTap: () {
          final encoded = Uri.encodeComponent(price.asset);
          context.push('/market/detail/$encoded', extra: price);
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              AssetLogoBadge(
                asset: price.asset,
                instrumentType: price.instrumentType,
                size: 20,
                borderRadius: 6,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayName(price.asset),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        MarketStatusPill(phase: phase),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white30,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$pricePrefix$priceLabel$suffix',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (showChange && changeTag.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      changeTag,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pctColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommodityTile extends StatelessWidget {
  final MarketPrice price;
  final double usdInrRate;
  final UnitSystem unitSystem;
  final bool isLive;

  const _CommodityTile({
    required this.price,
    required this.usdInrRate,
    required this.unitSystem,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasApiPhase = (price.marketPhase ?? '').trim().isNotEmpty;
    final apiPhase = normalizeMarketPhase(price.marketPhase);
    final phase = hasApiPhase ? apiPhase : (isLive ? 'live' : 'closed');
    final tickTs = price.lastTickTimestamp ?? price.timestamp;

    final useIndianCommodity = unitSystem == UnitSystem.indian;
    final display = assetDisplayPriceAndUnit(
      asset: price.asset,
      rawPrice: price.price,
      useIndianUnits: useIndianCommodity,
      usdInrRate: usdInrRate,
      instrumentType: 'commodity',
      sourceUnit: price.unit,
    );
    final displayPrice = display.$1;
    final unit = display.$2;
    final displayValue = assetDisplayValue(
      asset: price.asset,
      rawPrice: price.price,
      useIndianUnits: useIndianCommodity,
      usdInrRate: usdInrRate,
      instrumentType: 'commodity',
    );

    final previousDisplayValue = price.previousClose == null
        ? null
        : assetDisplayValue(
            asset: price.asset,
            rawPrice: price.previousClose!,
            useIndianUnits: useIndianCommodity,
            usdInrRate: usdInrRate,
            instrumentType: 'commodity',
          );
    final changeTag = Formatters.changeWithDiff(
      current: displayValue,
      previous: previousDisplayValue,
      pct: price.changePercent,
    );
    final pctColor = (price.changePercent ?? 0) >= 0
        ? AppTheme.accentGreen
        : AppTheme.accentRed;
    final subtitle = phase == 'live'
        ? Formatters.updatedFreshness(
            tickTs,
            allowJustNow: true,
          )
        : Formatters.updatedFreshness(tickTs);

    return Card(
      child: InkWell(
        onTap: () {
          final encoded = Uri.encodeComponent(price.asset);
          context.push('/commodities/detail/$encoded', extra: price);
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              AssetLogoBadge(
                asset: price.asset,
                instrumentType: 'commodity',
                size: 20,
                borderRadius: 6,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayName(price.asset),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        MarketStatusPill(phase: phase),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white30,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$displayPrice$unit',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (changeTag.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      changeTag,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pctColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}

class MarketDetailScreen extends ConsumerStatefulWidget {
  final String asset;
  final MarketPrice? initialPrice;

  const MarketDetailScreen({super.key, required this.asset, this.initialPrice});

  @override
  ConsumerState<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends ConsumerState<MarketDetailScreen> {
  ChartRange _chartRange = ChartRange.oneDay;
  final ScrollController _rangeScrollController = ScrollController();
  bool _showRangeScrollHint = true;

  @override
  void initState() {
    super.initState();
    _rangeScrollController.addListener(_onRangeScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRangeScroll());
  }

  @override
  void dispose() {
    _rangeScrollController.removeListener(_onRangeScroll);
    _rangeScrollController.dispose();
    super.dispose();
  }

  void _onRangeScroll() {
    if (!_rangeScrollController.hasClients) return;
    final atEnd = _rangeScrollController.offset >=
        _rangeScrollController.position.maxScrollExtent - 4;
    if (_showRangeScrollHint == atEnd) {
      setState(() => _showRangeScrollHint = !atEnd);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initialInstType = widget.initialPrice?.instrumentType ?? 'index';
    final isCommodity = initialInstType == 'commodity';
    final historyAsync = isCommodity
        ? ref.watch(commodityHistoryProvider(widget.asset))
        : ref.watch(marketHistoryProvider(widget.asset));
    final unitSystem = ref.watch(unitSystemProvider);
    final latestMarketAsync = ref.watch(latestMarketPricesProvider);
    final latestCommodityAsync = ref.watch(latestCommoditiesProvider);
    final latestResolvedPrice = isCommodity
        ? latestCommodityAsync.valueOrNull
            ?.where((p) => p.asset == widget.asset)
            .firstOrNull
        : latestMarketAsync.valueOrNull
            ?.where((p) => p.asset == widget.asset)
            .firstOrNull;
    final currentPrice = latestResolvedPrice ?? widget.initialPrice;
    final usdInrRate = latestMarketAsync.valueOrNull
            ?.where((p) => p.asset == 'USD/INR')
            .map((p) => p.price)
            .firstOrNull ??
        84.0;
    final useIndian = unitSystem == UnitSystem.indian;
    final instType = currentPrice?.instrumentType ?? initialInstType;
    final display = currentPrice != null
        ? assetDisplayPriceAndUnit(
            asset: widget.asset,
            rawPrice: currentPrice.price,
            useIndianUnits: useIndian && isCommodity,
            usdInrRate: usdInrRate,
            instrumentType: instType,
            sourceUnit: currentPrice.unit,
          )
        : null;

    final is1D = _chartRange == ChartRange.oneDay;
    final intradayAsync = isCommodity
        ? ref.watch(commodityIntradayProvider(widget.asset))
        : ref.watch(marketIntradayProvider(
            (asset: widget.asset, instrumentType: instType)));
    final intradayPayload = intradayAsync.valueOrNull;
    final intradayListRaw = intradayPayload?.prices ?? const [];
    final intradayChartList = isCommodity
        ? intradayListRaw
        : _prependSessionAnchor(
            intradayListRaw,
            instType: instType,
            previousClose: currentPrice?.previousClose,
          );
    final intradayStatsList =
        intradayListRaw.isNotEmpty ? intradayListRaw : intradayChartList;
    final status = ref.watch(marketStatusProvider).valueOrNull;
    final hasApiPhase = (currentPrice?.marketPhase ?? '').trim().isNotEmpty;
    final fallbackLive = status != null &&
        isLiveForAsset(
          widget.asset,
          instType,
          status,
          lastUpdate:
              currentPrice?.lastTickTimestamp ?? currentPrice?.timestamp,
        );
    final phase = hasApiPhase
        ? normalizeMarketPhase(currentPrice?.marketPhase)
        : (fallbackLive ? 'live' : 'closed');
    final chartTzId = ref.watch(chartTimezoneProvider).id;
    final displayUnit = display?.$2;
    final isCurrency = instType == 'currency';
    final oneDayLabel = (isCommodity || isCurrency) ? '24H' : '1D';
    final hasAuthoritativeTick =
        latestResolvedPrice != null || intradayChartList.isNotEmpty;
    final watchlistAssets =
        ref.watch(watchlistProvider).valueOrNull ?? const <String>[];
    final inWatchlist = watchlistAssets.contains(widget.asset);

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName(widget.asset)),
        actions: [
          IconButton(
            tooltip: inWatchlist ? 'Remove from watchlist' : 'Add to watchlist',
            icon: Icon(
              inWatchlist ? Icons.star_rounded : Icons.star_border_rounded,
              color: inWatchlist ? Colors.amber : null,
            ),
            onPressed: () =>
                ref.read(watchlistProvider.notifier).toggle(widget.asset),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: MarketStatusPill(phase: phase, showLabel: true),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(latestMarketPricesProvider);
          ref.invalidate(latestCommoditiesProvider);
          if (isCommodity) {
            ref.invalidate(commodityHistoryProvider(widget.asset));
            ref.invalidate(commodityIntradayProvider(widget.asset));
          } else {
            ref.invalidate(marketHistoryProvider(widget.asset));
            ref.invalidate(marketIntradayProvider(
                (asset: widget.asset, instrumentType: instType)));
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _chartRangeChips(context, oneDayLabel: oneDayLabel),
            const SizedBox(height: 16),
            if (currentPrice != null && display != null) ...[
              _buildTopCard(
                theme,
                display.$1,
                display.$2,
                historyAsync.valueOrNull,
                priceForTop: currentPrice,
                intradayFor1D: intradayChartList,
                asset: widget.asset,
                useIndianCommodityUnits: useIndian && isCommodity,
                usdInrRate: usdInrRate,
                phase: phase,
                showTickAge: hasAuthoritativeTick,
              ),
              const SizedBox(height: 16),
            ],
            historyAsync.when(
              loading: () => const ShimmerCard(height: 200),
              error: (err, _) => ErrorView(
                message: friendlyErrorMessage(err),
                onRetry: () {
                  if (isCommodity) {
                    ref.invalidate(commodityHistoryProvider(widget.asset));
                  } else {
                    ref.invalidate(marketHistoryProvider(widget.asset));
                  }
                },
              ),
              data: (prices) {
                final useIntraday = is1D && intradayChartList.isNotEmpty;
                final List<double> chartPrices;
                final List<DateTime> chartTimestamps;
                final bool isIntradayChart;
                final String? chartUnit;
                final String? prefix;
                final String? chartUnitHint;
                List<double> statsPrices;

                if (useIntraday) {
                  chartPrices = isCommodity && useIndian
                      ? intradayChartList
                          .map((p) => assetDisplayValue(
                                asset: widget.asset,
                                rawPrice: p.price,
                                useIndianUnits: true,
                                usdInrRate: usdInrRate,
                                instrumentType: 'commodity',
                              ))
                          .toList()
                      : intradayChartList.map((p) => p.price).toList();
                  chartTimestamps =
                      intradayChartList.map((p) => p.timestamp).toList();
                  final intradayStatsSource = intradayStatsList.isNotEmpty
                      ? intradayStatsList
                      : intradayChartList;
                  statsPrices = isCommodity && useIndian
                      ? intradayStatsSource
                          .map((p) => assetDisplayValue(
                                asset: widget.asset,
                                rawPrice: p.price,
                                useIndianUnits: true,
                                usdInrRate: usdInrRate,
                                instrumentType: 'commodity',
                              ))
                          .toList()
                      : intradayStatsSource.map((p) => p.price).toList();
                  isIntradayChart = true;
                  chartUnit = isCommodity && useIndian
                      ? null
                      : (isCurrency ? 'inr' : displayUnit);
                  prefix =
                      (isCommodity && useIndian) || isCurrency ? '₹ ' : null;
                  chartUnitHint =
                      (isCommodity && useIndian && displayUnit != null)
                          ? '₹$displayUnit'
                          : null;
                } else {
                  if (prices.isEmpty) {
                    return const EmptyView(
                        message:
                            'No historical data yet.\nData builds up as the scraper runs.');
                  }
                  final sorted = List.of(prices)
                    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
                  final filtered = _filterByRange(sorted);
                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Center(
                        child: Text(
                          'No data in this range',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    );
                  }
                  chartPrices = isCommodity && useIndian
                      ? filtered
                          .map((p) => assetDisplayValue(
                                asset: widget.asset,
                                rawPrice: p.price,
                                useIndianUnits: true,
                                usdInrRate: usdInrRate,
                                instrumentType: 'commodity',
                              ))
                          .toList()
                      : filtered.map((p) => p.price).toList();
                  chartTimestamps = filtered.map((p) => p.timestamp).toList();
                  statsPrices = chartPrices;
                  isIntradayChart = false;
                  chartUnit = isCommodity && useIndian
                      ? null
                      : (isCurrency ? 'inr' : filtered.first.unit);
                  prefix =
                      (isCommodity && useIndian) || isCurrency ? '₹ ' : null;
                  chartUnitHint =
                      (isCommodity && useIndian && displayUnit != null)
                          ? '₹$displayUnit'
                          : (chartUnit == 'percent' ? 'Yield %' : chartUnit);
                }

                if (chartPrices.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(
                      child: Text(
                        is1D
                            ? 'No intraday data (market closed or no data yet)'
                            : 'No data in this range',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  );
                }
                final isShortRange = _chartRange == ChartRange.oneMonth ||
                    _chartRange == ChartRange.threeMonths;
                final open = statsPrices.first;
                final close = statsPrices.last;
                final high = statsPrices.reduce((a, b) => a > b ? a : b);
                final low = statsPrices.reduce((a, b) => a < b ? a : b);
                final avg = statsPrices.fold<double>(0, (s, p) => s + p) /
                    statsPrices.length;
                final spreadPct =
                    open != 0 ? ((high - low) / open) * 100 : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MarketRangeStatsCard(
                      open: open,
                      high: high,
                      low: low,
                      close: close,
                      avg: avg,
                      spreadPct: spreadPct,
                      pricePrefix: prefix,
                      unit: chartUnit,
                    ),
                    const SizedBox(height: 12),
                    PriceLineChart(
                      prices: chartPrices,
                      timestamps: chartTimestamps,
                      unit: chartUnit,
                      isShortRange: isShortRange,
                      isIntraday: isIntradayChart,
                      chartTimeZoneId: chartTzId,
                      pricePrefix: prefix,
                      chartUnitHint: chartUnitHint,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCard(
    ThemeData theme,
    String displayPrice,
    String unitLabel,
    List<MarketPrice>? history, {
    required MarketPrice priceForTop,
    List<IntradayPoint>? intradayFor1D,
    required String asset,
    required bool useIndianCommodityUnits,
    required double usdInrRate,
    String phase = 'closed',
    bool showTickAge = true,
  }) {
    double toDisplayValue(double raw) => assetDisplayValue(
          asset: asset,
          rawPrice: raw,
          useIndianUnits: useIndianCommodityUnits,
          usdInrRate: usdInrRate,
          instrumentType: priceForTop.instrumentType,
        );

    double? rangePct;
    double? rangeCurrentDisplay;
    double? rangeBaseDisplay;
    if (_chartRange == ChartRange.oneDay) {
      // Backend session/24H change should already align with the active intraday window.
      rangePct = priceForTop.changePercent;
      rangeCurrentDisplay = toDisplayValue(priceForTop.price);
      if (rangePct == null) {
        final prevClose = priceForTop.previousClose;
        final last = priceForTop.price;
        if (prevClose != null && prevClose != 0) {
          rangePct = ((last - prevClose) / prevClose) * 100;
        }
      }
      if (priceForTop.previousClose != null) {
        rangeBaseDisplay = toDisplayValue(priceForTop.previousClose!);
      }
      if (rangePct == null &&
          intradayFor1D != null &&
          intradayFor1D.length >= 2) {
        final first = intradayFor1D.first.price;
        final last = intradayFor1D.last.price;
        if (first != 0) rangePct = ((last - first) / first) * 100;
        rangeBaseDisplay = toDisplayValue(first);
        rangeCurrentDisplay = toDisplayValue(last);
      }
    } else if (history != null && history.isNotEmpty) {
      final sorted = List.of(history)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final filtered = _filterByRange(sorted);
      if (filtered.length >= 2) {
        final first = filtered.first.price;
        final last = filtered.last.price;
        if (first != 0) rangePct = ((last - first) / first) * 100;
        rangeBaseDisplay = toDisplayValue(first);
        rangeCurrentDisplay = toDisplayValue(last);
      }
    }
    String rangeChangeTag = '';
    if (rangeCurrentDisplay != null) {
      rangeChangeTag = Formatters.changeWithDiff(
        current: rangeCurrentDisplay,
        previous: rangeBaseDisplay,
        pct: rangePct,
      );
    }
    if (rangeChangeTag.isEmpty && rangePct != null) {
      rangeChangeTag = Formatters.changeTag(rangePct);
    }
    final changeIsPositive =
        (rangeCurrentDisplay != null && rangeBaseDisplay != null)
            ? (rangeCurrentDisplay - rangeBaseDisplay) >= 0
            : ((rangePct ?? 0) >= 0);

    final lastTick = (intradayFor1D != null && intradayFor1D.isNotEmpty)
        ? intradayFor1D.last.timestamp
        : priceForTop.lastTickTimestamp ?? priceForTop.timestamp;
    final rangeLabel = (_chartRange == ChartRange.oneDay &&
            ((priceForTop.instrumentType == 'commodity') ||
                (priceForTop.instrumentType == 'currency')))
        ? '24H'
        : _chartRange.label;
    final subtitle = phase == 'live'
        ? Formatters.updatedFreshness(
            lastTick,
            allowJustNow: true,
          )
        : (priceForTop.isPredictive ?? false)
            ? 'Indicative · last quoted ${Formatters.relativeTime(lastTick)}'
            : Formatters.updatedFreshness(lastTick);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$displayPrice$unitLabel',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (rangeChangeTag.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '$rangeLabel change  $rangeChangeTag',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: changeIsPositive
                      ? AppTheme.accentGreen
                      : AppTheme.accentRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  List<IntradayPoint> _prependSessionAnchor(
    List<IntradayPoint> points, {
    required String instType,
    required double? previousClose,
  }) {
    if (points.isEmpty || previousClose == null) return points;
    final isSessionAsset = instType == 'index' || instType == 'bond_yield';
    if (!isSessionAsset) return points;

    final firstUtc = points.first.timestamp.toUtc();
    if ((points.first.price - previousClose).abs() < 1e-9) {
      return points;
    }

    final sessionAnchorUtc = firstUtc.subtract(const Duration(minutes: 1));
    return [
      IntradayPoint(timestamp: sessionAnchorUtc, price: previousClose),
      ...points,
    ];
  }

  List<MarketPrice> _filterByRange(List<MarketPrice> sorted) {
    if (_chartRange == ChartRange.all) return sorted;
    final cutoff = DateTime.now().subtract(_chartRange.duration);
    return sorted.where((p) => !p.timestamp.isBefore(cutoff)).toList();
  }

  Widget _chartRangeChips(BuildContext context, {String oneDayLabel = '1D'}) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          SingleChildScrollView(
            controller: _rangeScrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...ChartRange.values.map((r) {
                  final selected = r == _chartRange;
                  final label = r == ChartRange.oneDay ? oneDayLabel : r.label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => setState(() => _chartRange = r),
                      selectedColor: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.4),
                      checkmarkColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                }),
                const SizedBox(width: 24),
              ],
            ),
          ),
          if (_showRangeScrollHint)
            IgnorePointer(
              child: Container(
                width: 32,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      theme.scaffoldBackgroundColor.withValues(alpha: 0),
                      theme.scaffoldBackgroundColor,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MarketRangeStatsCard extends StatelessWidget {
  final double open;
  final double high;
  final double low;
  final double close;
  final double? avg;
  final double? spreadPct;
  final String? pricePrefix;
  final String? unit;

  const _MarketRangeStatsCard({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.avg,
    this.spreadPct,
    this.pricePrefix,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefix = pricePrefix ?? '';
    String fmt(double v) {
      if (unit == 'percent') {
        return Formatters.price(v, unit: unit);
      }
      if (unit == 'inr') {
        return '$prefix${Formatters.fxInrPrice(v)}';
      }
      return '$prefix${Formatters.fullPrice(v)}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _stat(theme, 'Open', fmt(open))),
                const SizedBox(width: 12),
                Expanded(child: _stat(theme, 'High', fmt(high))),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _stat(theme, 'Low', fmt(low))),
                const SizedBox(width: 12),
                Expanded(child: _stat(theme, 'Close', fmt(close))),
              ],
            ),
            if (avg != null || spreadPct != null) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (avg != null)
                    Expanded(child: _stat(theme, 'Avg', fmt(avg!))),
                  if (spreadPct != null) ...[
                    if (avg != null) const SizedBox(width: 12),
                    Expanded(
                        child: _stat(theme, 'High–Low',
                            Formatters.price(spreadPct!, unit: 'percent'))),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(ThemeData theme, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}

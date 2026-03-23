import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../core/error_utils.dart';
import '../../../core/market_status_helper.dart' show normalizeMarketPhase;
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/intraday_response.dart';
import '../../../data/models/market_price.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../discover/widgets/position_bar.dart';

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
  late final ScrollController _cryptoScrollController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _indicesScrollController = ScrollController();
    _currenciesScrollController = ScrollController();
    _commoditiesScrollController = ScrollController();
    _bondsScrollController = ScrollController();
    _cryptoScrollController = ScrollController();
  }

  @override
  void dispose() {
    _indicesScrollController.dispose();
    _currenciesScrollController.dispose();
    _commoditiesScrollController.dispose();
    _bondsScrollController.dispose();
    _cryptoScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _scrollCurrentTabToTop() {
    final controller = switch (_tabController.index) {
      0 => _indicesScrollController,
      1 => _commoditiesScrollController,
      2 => _cryptoScrollController,
      3 => _currenciesScrollController,
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
            Tab(text: 'Crypto'),
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
          _CryptoTab(scrollController: _cryptoScrollController),
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

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(latestMarketPricesProvider);
      },
      child: pricesAsync.when(
        loading: () => const ShimmerList(itemCount: 6),
        error: (err, _) => ErrorView(
          message: friendlyErrorMessage(err),
          onRetry: () => ref.invalidate(latestMarketPricesProvider),
        ),
        data: (prices) {
          // VIX indices are shown on the Overview page, not here.
          const vixAssets = {'CBOE VIX', 'India VIX'};
          final indices = prices
              .where((p) =>
                  p.instrumentType == 'index' && !vixAssets.contains(p.asset))
              .toList();

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
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.india,
                  title: 'India',
                  prices: inIndices,
                ),
                ...inIndices.map((p) => _MarketTile(price: p)),
              ],
              if (usIndices.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.us,
                  title: 'United States',
                  prices: usIndices,
                ),
                ...usIndices.map((p) => _MarketTile(price: p)),
              ],
              if (europeIndices.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.europe,
                  title: 'Europe',
                  prices: europeIndices,
                ),
                ...europeIndices.map((p) => _MarketTile(price: p)),
              ],
              if (japanIndices.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.japan,
                  title: 'Japan',
                  prices: japanIndices,
                ),
                ...japanIndices.map((p) => _MarketTile(price: p)),
              ],
              ...indices
                  .where((p) =>
                      !Entities.indicesUS.contains(p.asset) &&
                      !Entities.indicesIndia.contains(p.asset) &&
                      !Entities.indicesEurope.contains(p.asset) &&
                      !Entities.indicesJapan.contains(p.asset))
                  .map((p) => _MarketTile(price: p)),
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

    return RefreshIndicator(
      onRefresh: () async {
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
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.global,
                  title: 'Global Majors',
                  prices: majors,
                ),
                ...majors.map((p) => _MarketTile(
                      price: p,
                      pricePrefix: '₹ ',
                    )),
              ],
              if (asiaPacific.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.asia,
                  title: 'Asia Pacific',
                  prices: asiaPacific,
                ),
                ...asiaPacific.map((p) => _MarketTile(
                      price: p,
                      pricePrefix: '₹ ',
                    )),
              ],
              if (middleEast.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.middleEast,
                  title: 'Middle East',
                  prices: middleEast,
                ),
                ...middleEast.map((p) => _MarketTile(
                      price: p,
                      pricePrefix: '₹ ',
                    )),
              ],
              if (europe.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.europe,
                  title: 'Europe',
                  prices: europe,
                ),
                ...europe.map((p) => _MarketTile(
                      price: p,
                      pricePrefix: '₹ ',
                    )),
              ],
              if (americas.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.americas,
                  title: 'Americas',
                  prices: americas,
                ),
                ...americas.map((p) => _MarketTile(
                      price: p,
                      pricePrefix: '₹ ',
                    )),
              ],
              if (africa.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.africa,
                  title: 'Africa',
                  prices: africa,
                ),
                ...africa.map((p) => _MarketTile(
                      price: p,
                      pricePrefix: '₹ ',
                    )),
              ],
              if (others.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.currenciesOther,
                  title: 'Other',
                  prices: others,
                ),
                ...others.map((p) => _MarketTile(
                      price: p,
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
    final usdInrRate = marketAsync.whenOrNull(
      data: (prices) {
        final usdInr = prices.where((p) => p.asset == 'USD/INR').toList();
        return usdInr.isNotEmpty ? usdInr.first.price : null;
      },
    );
    final effectiveUsdInrRate = usdInrRate ?? 1.0;
    final useIndianCommodityUnits =
        unitSystem == UnitSystem.indian && usdInrRate != null && usdInrRate > 0;

    return RefreshIndicator(
      onRefresh: () async {
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
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.metals,
                  title: 'Precious Metals',
                  prices: precious,
                ),
                ...precious.map((p) => _CommodityTile(
                      price: p,
                      usdInrRate: effectiveUsdInrRate,
                      useIndianCommodityUnits: useIndianCommodityUnits,
                    )),
              ],
              if (industrial.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.metals,
                  title: 'Industrial Metals',
                  prices: industrial,
                ),
                ...industrial.map((p) => _CommodityTile(
                      price: p,
                      usdInrRate: effectiveUsdInrRate,
                      useIndianCommodityUnits: useIndianCommodityUnits,
                    )),
              ],
              if (energy.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.energy,
                  title: 'Energy',
                  prices: energy,
                ),
                ...energy.map((p) => _CommodityTile(
                      price: p,
                      usdInrRate: effectiveUsdInrRate,
                      useIndianCommodityUnits: useIndianCommodityUnits,
                    )),
              ],
              ...others.map((p) => _CommodityTile(
                    price: p,
                    usdInrRate: effectiveUsdInrRate,
                    useIndianCommodityUnits: useIndianCommodityUnits,
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

    return RefreshIndicator(
      onRefresh: () async {
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
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.india,
                  title: 'India',
                  prices: inBonds,
                ),
                ...inBonds.map((p) => _MarketTile(
                      price: p,
                      suffix: '%',
                      showChange: false,
                    )),
              ],
              if (usBonds.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.us,
                  title: 'United States',
                  prices: usBonds,
                ),
                ...usBonds.map((p) => _MarketTile(
                      price: p,
                      suffix: '%',
                      showChange: false,
                    )),
              ],
              if (euBonds.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.europe,
                  title: 'Europe',
                  prices: euBonds,
                ),
                ...euBonds.map((p) => _MarketTile(
                      price: p,
                      suffix: '%',
                      showChange: false,
                    )),
              ],
              if (jpBonds.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.japan,
                  title: 'Japan',
                  prices: jpBonds,
                ),
                ...jpBonds.map((p) => _MarketTile(
                      price: p,
                      suffix: '%',
                      showChange: false,
                    )),
              ],
              ...others.map((p) => _MarketTile(
                    price: p,
                    suffix: '%',
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
    required this.prices,
  });

  final AssetBadgeStyle badgeStyle;
  final String title;
  final List<MarketPrice> prices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Compute trend summary from changePercent
    final changes =
        prices.map((p) => p.changePercent).whereType<double>().toList();
    final upCount = changes.where((c) => c >= 0).length;
    final downCount = changes.where((c) => c < 0).length;
    final avgChange = changes.isNotEmpty
        ? changes.fold<double>(0, (s, c) => s + c) / changes.length
        : null;
    final avgPositive = (avgChange ?? 0) >= 0;
    final avgColor = avgPositive ? AppTheme.accentGreen : AppTheme.accentRed;

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
                  const SizedBox(height: 2),
                  if (changes.isNotEmpty)
                    Row(
                      children: [
                        if (upCount > 0)
                          Text(
                            '▲$upCount',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.accentGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        if (upCount > 0 && downCount > 0)
                          const SizedBox(width: 6),
                        if (downCount > 0)
                          Text(
                            '▼$downCount',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.accentRed,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        if (avgChange != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: avgColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${avgPositive ? "+" : ""}${avgChange.toStringAsFixed(2)}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: avgColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  else
                    Text(
                      '—',
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
  final bool showChange;

  const _MarketTile({
    required this.price,
    this.pricePrefix = '',
    this.suffix = '',
    this.showChange = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = normalizeMarketPhase(price.marketPhase);
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

class _CryptoTab extends ConsumerWidget {
  const _CryptoTab({required this.scrollController});

  final ScrollController scrollController;

  static const _layer1 = {
    'bitcoin',
    'ethereum',
    'bnb',
    'solana',
    'cardano',
    'avalanche'
  };
  static const _defi = {'chainlink', 'polkadot'};
  static const _meme = {'dogecoin', 'xrp'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricesAsync = ref.watch(latestCryptoProvider);
    final unitSystem = ref.watch(unitSystemProvider);
    final useIndian = unitSystem == UnitSystem.indian;
    final marketAsync = ref.watch(latestMarketPricesProvider);
    final usdInrRate = marketAsync.valueOrNull
            ?.where((p) => p.asset == 'USD/INR')
            .map((p) => p.price)
            .firstOrNull ??
        84.0;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(latestCryptoProvider);
      },
      child: pricesAsync.when(
        loading: () => const ShimmerList(itemCount: 6),
        error: (err, _) => ErrorView(
          message: friendlyErrorMessage(err),
          onRetry: () => ref.invalidate(latestCryptoProvider),
        ),
        data: (prices) {
          if (prices.isEmpty) {
            return const EmptyView(
                message: 'No crypto data', icon: Icons.currency_bitcoin);
          }

          final ordered = <MarketPrice>[];
          for (final name in Entities.crypto) {
            final match = prices.where((p) => p.asset == name).toList();
            if (match.isNotEmpty) ordered.add(match.first);
          }
          for (final p in prices) {
            if (!ordered.any((o) => o.asset == p.asset)) ordered.add(p);
          }

          final layer1 =
              ordered.where((p) => _layer1.contains(p.asset)).toList();
          final defi = ordered.where((p) => _defi.contains(p.asset)).toList();
          final meme = ordered.where((p) => _meme.contains(p.asset)).toList();
          final others = ordered
              .where((p) =>
                  !_layer1.contains(p.asset) &&
                  !_defi.contains(p.asset) &&
                  !_meme.contains(p.asset))
              .toList();

          Widget tile(MarketPrice p) => _CryptoTile(
                price: p,
                useIndian: useIndian,
                usdInrRate: usdInrRate,
              );

          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 112),
            children: [
              if (layer1.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.crypto,
                  title: 'Layer 1',
                  prices: layer1,
                ),
                ...layer1.map(tile),
              ],
              if (defi.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.crypto,
                  title: 'Infrastructure',
                  prices: defi,
                ),
                ...defi.map(tile),
              ],
              if (meme.isNotEmpty) ...[
                _RegionBanner(
                  badgeStyle: AssetBadgeStyle.crypto,
                  title: 'Payments & Meme',
                  prices: meme,
                ),
                ...meme.map(tile),
              ],
              ...others.map(tile),
            ],
          );
        },
      ),
    );
  }
}

class _CryptoTile extends StatelessWidget {
  final MarketPrice price;
  final bool useIndian;
  final double usdInrRate;

  const _CryptoTile({
    required this.price,
    this.useIndian = false,
    this.usdInrRate = 84.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = normalizeMarketPhase(price.marketPhase);
    final tickTs = price.lastTickTimestamp ?? price.timestamp;

    final display = assetDisplayPriceAndUnit(
      asset: price.asset,
      rawPrice: price.price,
      useIndianUnits: useIndian,
      usdInrRate: usdInrRate,
      instrumentType: 'crypto',
    );
    final displayPrice = display.$1;
    final changeTag = Formatters.changeWithDiff(
      current: price.price,
      previous: price.previousClose,
      pct: price.changePercent,
    );
    final pctColor = (price.changePercent ?? 0) >= 0
        ? AppTheme.accentGreen
        : AppTheme.accentRed;
    final subtitle = Formatters.marketFreshnessSubtitle(
      tickTime: tickTs,
    );

    return Card(
      child: InkWell(
        onTap: () {
          final encoded = Uri.encodeComponent(price.asset);
          context.push('/crypto/detail/$encoded', extra: price);
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              AssetLogoBadge(
                asset: price.asset,
                instrumentType: 'crypto',
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
                    displayPrice,
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

class _CommodityTile extends StatelessWidget {
  final MarketPrice price;
  final double usdInrRate;
  final bool useIndianCommodityUnits;

  const _CommodityTile({
    required this.price,
    required this.usdInrRate,
    required this.useIndianCommodityUnits,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = normalizeMarketPhase(price.marketPhase);
    final tickTs = price.lastTickTimestamp ?? price.timestamp;

    final display = assetDisplayPriceAndUnit(
      asset: price.asset,
      rawPrice: price.price,
      useIndianUnits: useIndianCommodityUnits,
      usdInrRate: usdInrRate,
      instrumentType: 'commodity',
      sourceUnit: price.unit,
    );
    final displayPrice = display.$1;
    final unit = display.$2;
    final displayValue = assetDisplayValue(
      asset: price.asset,
      rawPrice: price.price,
      useIndianUnits: useIndianCommodityUnits,
      usdInrRate: usdInrRate,
      instrumentType: 'commodity',
    );

    final previousDisplayValue = price.previousClose == null
        ? null
        : assetDisplayValue(
            asset: price.asset,
            rawPrice: price.previousClose!,
            useIndianUnits: useIndianCommodityUnits,
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

  // Context metadata for header line
  static String _contextForAsset(String asset, String instType) {
    if (instType == 'bond_yield') return 'Government';
    if (instType == 'currency') {
      final base = asset.split('/').first;
      return '$base vs INR';
    }
    if (instType == 'commodity') {
      const exchanges = <String, String>{
        'gold': 'COMEX',
        'silver': 'COMEX',
        'platinum': 'NYMEX',
        'palladium': 'NYMEX',
        'copper': 'COMEX',
        'crude oil': 'NYMEX',
        'natural gas': 'NYMEX',
      };
      return exchanges[asset.toLowerCase()] ?? 'Exchange';
    }
    if (instType == 'crypto') return 'Decentralized';
    // index
    if (Entities.indicesUS.contains(asset)) return 'United States';
    if (Entities.indicesEurope.contains(asset)) return 'Europe';
    if (Entities.indicesJapan.contains(asset)) return 'Japan';
    if (Entities.indicesIndia.contains(asset)) return 'India';
    return '';
  }

  static String _typeBadge(String instType) {
    switch (instType) {
      case 'bond_yield':
        return 'Bond';
      case 'currency':
        return 'FX';
      case 'commodity':
        return 'Commodity';
      case 'crypto':
        return 'Crypto';
      default:
        return 'Index';
    }
  }

  // ── Market action tag color mapping ──
  static Color _marketTagColor(String tag) {
    switch (tag) {
      case 'Bullish':
        return AppTheme.accentGreen;
      case 'Moderately Bullish':
        return AppTheme.accentTeal;
      case 'Neutral':
        return AppTheme.accentGray;
      case 'Moderately Bearish':
        return AppTheme.accentOrange;
      case 'Bearish':
        return AppTheme.accentRed;
      default:
        return AppTheme.accentTeal;
    }
  }

  // ── Market action tag icon mapping ──
  static IconData _marketTagIcon(String tag) {
    switch (tag) {
      case 'Bullish':
        return Icons.trending_up_rounded;
      case 'Moderately Bullish':
        return Icons.north_east_rounded;
      case 'Neutral':
        return Icons.pause_circle_outline_rounded;
      case 'Moderately Bearish':
        return Icons.south_east_rounded;
      case 'Bearish':
        return Icons.trending_down_rounded;
      default:
        return Icons.trending_flat_rounded;
    }
  }

  static String _formatTag(String tag) {
    return tag
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static Color _driverTagColor(String tag) {
    final lower = tag.toLowerCase();
    if (lower.contains('uptrend') || lower.contains('rally') ||
        lower.contains('strengthening') || lower.contains('high momentum') ||
        lower.contains('rising')) {
      return AppTheme.accentGreen;
    }
    if (lower.contains('downtrend') || lower.contains('slump') ||
        lower.contains('weakening') || lower.contains('weak momentum') ||
        lower.contains('falling')) {
      return AppTheme.accentRed;
    }
    if (lower.contains('high volatility')) return AppTheme.accentOrange;
    if (lower.contains('low volatility')) return AppTheme.accentTeal;
    return AppTheme.accentBlue;
  }

  static Color _scoreColor(double score) {
    if (score >= 60) return AppTheme.accentGreen;
    if (score >= 40) return Colors.white;
    return AppTheme.accentRed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initialInstType = widget.initialPrice?.instrumentType ?? 'index';
    final isCommodity = initialInstType == 'commodity';
    final isCrypto = initialInstType == 'crypto';
    final isRolling = isCommodity || isCrypto;
    // Only fetch history when not on 1D — avoids 6s blocking call on initial load
    final needsHistory = _chartRange != ChartRange.oneDay;
    final historyAsync = needsHistory
        ? (isCommodity
            ? ref.watch(commodityHistoryProvider(widget.asset))
            : isCrypto
                ? ref.watch(cryptoHistoryProvider(widget.asset))
                : ref.watch(marketHistoryProvider(widget.asset)))
        : const AsyncValue<List<MarketPrice>>.data([]);
    final unitSystem = ref.watch(unitSystemProvider);
    final latestMarketAsync = ref.watch(latestMarketPricesProvider);
    final latestCommodityAsync = ref.watch(latestCommoditiesProvider);
    final latestCryptoAsync = ref.watch(latestCryptoProvider);
    final latestResolvedPrice = isCommodity
        ? latestCommodityAsync.valueOrNull
            ?.where((p) => p.asset == widget.asset)
            .firstOrNull
        : isCrypto
            ? latestCryptoAsync.valueOrNull
                ?.where((p) => p.asset == widget.asset)
                .firstOrNull
            : latestMarketAsync.valueOrNull
                ?.where((p) => p.asset == widget.asset)
                .firstOrNull;
    final currentPrice = latestResolvedPrice ?? widget.initialPrice;
    final usdInrRate = latestMarketAsync.valueOrNull
        ?.where((p) => p.asset == 'USD/INR')
        .map((p) => p.price)
        .firstOrNull;
    final effectiveUsdInrRate = usdInrRate ?? 1.0;
    final useIndian = unitSystem == UnitSystem.indian;
    final useIndianCommodityUnits =
        useIndian && isCommodity && usdInrRate != null && usdInrRate > 0;
    final instType = currentPrice?.instrumentType ?? initialInstType;
    final display = currentPrice != null
        ? assetDisplayPriceAndUnit(
            asset: widget.asset,
            rawPrice: currentPrice.price,
            useIndianUnits: useIndianCommodityUnits,
            usdInrRate: effectiveUsdInrRate,
            instrumentType: instType,
            sourceUnit: currentPrice.unit,
          )
        : null;

    final is1D = _chartRange == ChartRange.oneDay;
    final intradayAsync = isCommodity
        ? ref.watch(commodityIntradayProvider(widget.asset))
        : isCrypto
            ? ref.watch(cryptoIntradayProvider(widget.asset))
            : ref.watch(marketIntradayProvider(
                (asset: widget.asset, instrumentType: instType)));
    final intradayPayload = intradayAsync.valueOrNull;
    final intradayListRaw = intradayPayload?.prices ?? const [];
    final intradayChartList = isRolling
        ? intradayListRaw
        : _prependSessionAnchor(
            intradayListRaw,
            instType: instType,
            previousClose: currentPrice?.previousClose,
          );
    final intradayStatsList =
        intradayListRaw.isNotEmpty ? intradayListRaw : intradayChartList;
    final phase = normalizeMarketPhase(currentPrice?.marketPhase);
    final chartTzId = ref.watch(chartTimezoneProvider).id;
    final displayUnit = display?.$2;
    final isCurrency = instType == 'currency';
    final oneDayLabel = (isRolling || isCurrency) ? '24H' : '1D';
    final hasAuthoritativeTick =
        latestResolvedPrice != null || intradayChartList.isNotEmpty;
    final watchlistAssets =
        ref.watch(watchlistProvider).valueOrNull ?? const <String>[];
    final inWatchlist = watchlistAssets.contains(widget.asset);

    // Story data for verdict / driver tags / scores
    final storyAsync = ref.watch(marketStoryProvider(
        (asset: widget.asset, instrumentType: instType)));

    return Scaffold(
      // ── 1. AppBar — simplified ──
      appBar: AppBar(
        title: Text(
          displayName(widget.asset),
          overflow: TextOverflow.ellipsis,
        ),
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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(latestMarketPricesProvider);
          ref.invalidate(latestCommoditiesProvider);
          ref.invalidate(latestCryptoProvider);
          ref.invalidate(marketStoryProvider(
              (asset: widget.asset, instrumentType: instType)));
          if (isCommodity) {
            ref.invalidate(commodityHistoryProvider(widget.asset));
            ref.invalidate(commodityIntradayProvider(widget.asset));
          } else if (isCrypto) {
            ref.invalidate(cryptoHistoryProvider(widget.asset));
            ref.invalidate(cryptoIntradayProvider(widget.asset));
          } else {
            ref.invalidate(marketHistoryProvider(widget.asset));
            ref.invalidate(marketIntradayProvider(
                (asset: widget.asset, instrumentType: instType)));
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 1. Header: Name + Chips + Status ──
            Text(
              displayName(widget.asset),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChipLabel(theme, _typeBadge(instType)),
                  if (_contextForAsset(widget.asset, instType).isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _buildChipLabel(
                        theme, _contextForAsset(widget.asset, instType)),
                  ],
                  const SizedBox(width: 8),
                  MarketStatusPill(phase: phase, showLabel: true),
                ],
              ),
            ),

            // ── Driver Tags (below header) ──
            storyAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (story) {
                if (story.driverTags.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: story.driverTags.map((tag) {
                      final tagColor = _driverTagColor(tag);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tagColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: tagColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // ── 2. Price + Change Badge ──
            if (currentPrice != null && display != null) ...[
              _buildPriceRow(
                theme,
                display.$1,
                display.$2,
                historyAsync.valueOrNull,
                priceForTop: currentPrice,
                intradayFor1D: intradayChartList,
                asset: widget.asset,
                useIndianCommodityUnits: useIndianCommodityUnits,
                usdInrRate: effectiveUsdInrRate,
                phase: phase,
                showTickAge: hasAuthoritativeTick,
              ),
              const SizedBox(height: 16),
            ],

            // ── 3. Period Selector ──
            _buildPeriodSelector(theme, oneDayLabel: oneDayLabel),
            const SizedBox(height: 12),

            // ── 4. Chart + 5. Range card ──
            // On 1D: if intraday is still loading, show shimmer
            if (is1D && intradayChartList.isEmpty && intradayAsync.isLoading)
              const ShimmerCard(height: 200)
            else
            historyAsync.when(
              loading: () => const ShimmerCard(height: 200),
              error: (err, _) => ErrorView(
                message: friendlyErrorMessage(err),
                onRetry: () {
                  if (isCommodity) {
                    ref.invalidate(commodityHistoryProvider(widget.asset));
                  } else if (isCrypto) {
                    ref.invalidate(cryptoHistoryProvider(widget.asset));
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
                  chartPrices = useIndianCommodityUnits
                      ? intradayChartList
                          .map((p) => assetDisplayValue(
                                asset: widget.asset,
                                rawPrice: p.price,
                                useIndianUnits: true,
                                usdInrRate: effectiveUsdInrRate,
                                instrumentType: 'commodity',
                              ))
                          .toList()
                      : intradayChartList.map((p) => p.price).toList();
                  chartTimestamps =
                      intradayChartList.map((p) => p.timestamp).toList();
                  final intradayStatsSource = intradayStatsList.isNotEmpty
                      ? intradayStatsList
                      : intradayChartList;
                  statsPrices = useIndianCommodityUnits
                      ? intradayStatsSource
                          .map((p) => assetDisplayValue(
                                asset: widget.asset,
                                rawPrice: p.price,
                                useIndianUnits: true,
                                usdInrRate: effectiveUsdInrRate,
                                instrumentType: 'commodity',
                              ))
                          .toList()
                      : intradayStatsSource.map((p) => p.price).toList();
                  isIntradayChart = true;
                  chartUnit = useIndianCommodityUnits
                      ? null
                      : (isCurrency ? 'inr' : displayUnit);
                  prefix = useIndianCommodityUnits || isCurrency ? '₹ ' : null;
                  chartUnitHint =
                      (useIndianCommodityUnits && displayUnit != null)
                          ? '₹$displayUnit'
                          : null;
                } else {
                  if (prices.isEmpty) {
                    if (is1D) {
                      // 1D selected but no intraday data and no history loaded
                      return Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Center(
                          child: Text(
                            'No intraday data available\nMarket may be closed',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      );
                    }
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
                  chartPrices = useIndianCommodityUnits
                      ? filtered
                          .map((p) => assetDisplayValue(
                                asset: widget.asset,
                                rawPrice: p.price,
                                useIndianUnits: true,
                                usdInrRate: effectiveUsdInrRate,
                                instrumentType: 'commodity',
                              ))
                          .toList()
                      : filtered.map((p) => p.price).toList();
                  chartTimestamps = filtered.map((p) => p.timestamp).toList();
                  statsPrices = chartPrices;
                  isIntradayChart = false;
                  chartUnit = useIndianCommodityUnits
                      ? null
                      : (isCurrency ? 'inr' : filtered.first.unit);
                  prefix = useIndianCommodityUnits || isCurrency ? '₹ ' : null;
                  chartUnitHint =
                      (useIndianCommodityUnits && displayUnit != null)
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
                final currentVal = currentPrice != null && display != null
                    ? statsPrices.last
                    : close;

                final rangeLabel = is1D
                    ? ((isCommodity || isCurrency)
                        ? '24H Range'
                        : 'Session Range')
                    : 'Period Range';

                String fmt(double v) {
                  final u = chartUnit;
                  final p = prefix ?? '';
                  if (u == 'percent') return Formatters.price(v, unit: u);
                  if (u == 'inr') return '$p${Formatters.fxInrPrice(v)}';
                  return '$p${Formatters.fullPrice(v)}';
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const SizedBox(height: 16),
                    // ── Range Card ──
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rangeLabel,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            PositionBar(
                              min: low,
                              max: high,
                              current: currentVal,
                              minLabel: fmt(low),
                              maxLabel: fmt(high),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _miniStat(theme, 'Open', fmt(open)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _miniStat(theme, 'Close', fmt(close)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // ── 6. Verdict Card ──
            _buildVerdictCard(theme, storyAsync),

            // ── 7. Score Stats (Trend + Momentum only) ──
            storyAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (story) {
                final hasTrend = story.scoreTrend != null;
                final hasMom = story.scoreMomentum != null;
                if (!hasTrend && !hasMom) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      if (hasTrend)
                        Expanded(
                          child: _buildScoreCard(
                              theme, 'Trend', story.scoreTrend!),
                        ),
                      if (hasTrend && hasMom) const SizedBox(width: 8),
                      if (hasMom)
                        Expanded(
                          child: _buildScoreCard(
                              theme, 'Momentum', story.scoreMomentum!),
                        ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Verdict Card ───────────────────────────────────────────────────

  Widget _buildVerdictCard(ThemeData theme, AsyncValue<MarketStory> storyAsync) {
    return storyAsync.when(
      loading: () => const ShimmerCard(height: 72),
      error: (_, __) => const SizedBox.shrink(),
      data: (story) {
        final actionTag = story.actionTag;
        final verdict = story.verdict;
        final reasoning = story.actionTagReasoning;
        if (actionTag == null && verdict == null) {
          return const SizedBox.shrink();
        }

        final color =
            actionTag != null ? _marketTagColor(actionTag) : Colors.white54;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.12),
                color.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (actionTag != null)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_marketTagIcon(actionTag),
                          size: 16, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _formatTag(actionTag),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              if (verdict != null) ...[
                const SizedBox(height: 10),
                Text(
                  verdict,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (reasoning != null) ...[
                const SizedBox(height: 6),
                Text(
                  reasoning,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Chip label (matching stock detail) ─────────────────────────────

  Widget _buildChipLabel(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── Score card helper ──────────────────────────────────────────────

  Widget _buildScoreCard(ThemeData theme, String label, double score) {
    final color = _scoreColor(score);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style:
                  theme.textTheme.labelSmall?.copyWith(color: Colors.white38),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  score.toStringAsFixed(0),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  '/100',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white24,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Mini stat row helper ───────────────────────────────────────────

  Widget _miniStat(ThemeData theme, String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // ── Price row (no Card wrapper) ─────────────────────────────────────

  Widget _buildPriceRow(
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

    final isPositive = (rangeCurrentDisplay != null && rangeBaseDisplay != null)
        ? (rangeCurrentDisplay - rangeBaseDisplay) >= 0
        : ((rangePct ?? 0) >= 0);
    final changeColor = isPositive ? AppTheme.accentGreen : AppTheme.accentRed;

    final lastTick = (intradayFor1D != null && intradayFor1D.isNotEmpty)
        ? intradayFor1D.last.timestamp
        : priceForTop.lastTickTimestamp ?? priceForTop.timestamp;
    final subtitle = phase == 'live'
        ? Formatters.updatedFreshness(lastTick, allowJustNow: true)
        : (priceForTop.isPredictive ?? false)
            ? 'Indicative · last quoted ${Formatters.relativeTime(lastTick)}'
            : Formatters.updatedFreshness(lastTick);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$displayPrice$unitLabel',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (rangePct != null) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: changeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${isPositive ? "+" : ""}${rangePct.toStringAsFixed(2)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: changeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
        ),
      ],
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

  // ── Period selector (ChoiceChip, matching stock detail) ──────────────

  Widget _buildPeriodSelector(ThemeData theme, {String oneDayLabel = '1D'}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ChartRange.values
            .where((r) => r != ChartRange.all)
            .map((r) {
          final isSelected = r == _chartRange;
          final label = r == ChartRange.oneDay ? oneDayLabel : r.label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => setState(() => _chartRange = r),
              showCheckmark: false,
              selectedColor: AppTheme.accentBlue.withValues(alpha: 0.25),
              side: BorderSide(
                color: isSelected
                    ? AppTheme.accentBlue.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
              ),
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? AppTheme.accentBlue : Colors.white60,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          );
        }).toList(),
      ),
    );
  }
}

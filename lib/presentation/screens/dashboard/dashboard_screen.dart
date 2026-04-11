import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/error_utils.dart';
import '../../../core/market_status_helper.dart' show normalizeMarketPhase;
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/discover.dart';
import '../../../data/models/market_price.dart';
import '../../../data/services/starred_stocks_service.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(bottomTabReselectTickProvider(2), (prev, next) {
      if (prev == null || prev == next) return;
      _scrollToTop();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check_rounded),
            tooltip: 'Manage Watchlist',
            onPressed: () => context.push('/watchlist'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentBlue,
          labelColor: AppTheme.accentBlue,
          unselectedLabelColor: Colors.white54,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Markets'),
            Tab(text: 'Stocks'),
            Tab(text: 'Mutual Funds'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Markets tab — watchlist with health card
          RefreshIndicator(
            onRefresh: () async {
              await ref.read(watchlistProvider.notifier).load(silent: true);
              await Future.wait([
                ref.refresh(latestMarketPricesProvider.future),
                ref.refresh(latestCommoditiesProvider.future),
              ]);
            },
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 112),
              children: [
                _MarketOverviewGrid(),
                const SizedBox(height: 24),
              ],
            ),
          ),
          // Stocks tab — starred discover stocks
          const _StarredFavoritesTab(type: 'stock'),
          const _StarredFavoritesTab(type: 'mf'),
        ],
      ),
    );
  }
}

// =============================================================================
// Starred Favorites Tabs
// =============================================================================

class _StarredFavoritesTab extends ConsumerWidget {
  final String type;

  const _StarredFavoritesTab({required this.type});

  bool get _isStockTab => type == 'stock';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starred = (ref
        .watch(starredStocksProvider)
        .where((item) => item.type == type)
        .toList(growable: false)
      ..sort((a, b) {
        final primaryCompare =
            a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (primaryCompare != 0) return primaryCompare;
        return a.id.toLowerCase().compareTo(b.id.toLowerCase());
      }));

    if (starred.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          _FavoritesEmptyState(type: type),
        ],
      );
    }

    // Live batch fetch replaces the old frozen `StarredItem.percentChange`
    // that was captured at star-time and never refreshed. MFs still use
    // the legacy path until a mfLiveQuotesProvider is added.
    final liveQuotes = _isStockTab
        ? ref.watch(starredStockLiveQuotesProvider).maybeWhen(
              data: (q) => q,
              orElse: () => const <String, DiscoverStockItem>{},
            )
        : const <String, DiscoverStockItem>{};

    double? effectivePct(StarredItem s) =>
        liveQuotes[s.id]?.percentChange ?? s.percentChange;

    final withChange = starred
        .where((e) => effectivePct(e) != null)
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async {
        if (_isStockTab) {
          ref.invalidate(starredStockLiveQuotesProvider);
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 112),
        children: [
          if (_isStockTab && withChange.isNotEmpty) ...[
            _StocksHealthCard(items: withChange, overrides: liveQuotes),
            const SizedBox(height: 8),
          ],
          if (!_isStockTab && withChange.isNotEmpty) ...[
            _MfHealthCard(items: withChange),
            const SizedBox(height: 8),
          ],
          for (final item in starred)
            _StarredItemTile(
              item: item,
              liveQuote: liveQuotes[item.id],
            ),
        ],
      ),
    );
  }
}

class _StocksHealthCard extends StatelessWidget {
  final List<StarredItem> items;
  final Map<String, DiscoverStockItem> overrides;

  const _StocksHealthCard({
    required this.items,
    this.overrides = const {},
  });

  double _pct(StarredItem s) =>
      overrides[s.id]?.percentChange ?? s.percentChange ?? 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = items.length;
    final gainers = items.where((p) => _pct(p) > 0).length;
    final losers = items.where((p) => _pct(p) < 0).length;
    final unchanged = total - gainers - losers;
    final avgChange =
        items.fold<double>(0, (sum, p) => sum + _pct(p)) / total;
    final avgColor = avgChange >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
    final avgSign = avgChange >= 0 ? '+' : '';

    final sorted = [...items]..sort((a, b) => _pct(b).compareTo(_pct(a)));
    final best = sorted.first;
    final worst = sorted.last;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_heart_outlined,
                    size: 18, color: AppTheme.accentBlue),
                const SizedBox(width: 8),
                Text(
                  'Stocks Health',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: avgColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Avg $avgSign${avgChange.toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: avgColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _HealthStat(
                  label: 'Total',
                  value: '$total',
                  color: AppTheme.accentBlue,
                ),
                const SizedBox(width: 16),
                _HealthStat(
                  label: 'Gainers',
                  value: '$gainers',
                  color: AppTheme.accentGreen,
                ),
                const SizedBox(width: 16),
                _HealthStat(
                  label: 'Losers',
                  value: '$losers',
                  color: AppTheme.accentRed,
                ),
                if (unchanged > 0) ...[
                  const SizedBox(width: 16),
                  _HealthStat(
                    label: 'Flat',
                    value: '$unchanged',
                    color: Colors.white38,
                  ),
                ],
              ],
            ),
            if (items.length >= 2) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PerformerChip(
                      label: 'Best',
                      symbol: best.id,
                      pct: _pct(best),
                      color: AppTheme.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PerformerChip(
                      label: 'Worst',
                      symbol: worst.id,
                      pct: _pct(worst),
                      color: AppTheme.accentRed,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MfHealthCard extends StatelessWidget {
  final List<StarredItem> items;

  const _MfHealthCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = items.length;
    final gainers = items.where((p) => (p.percentChange ?? 0) > 0).length;
    final losers = items.where((p) => (p.percentChange ?? 0) < 0).length;
    final unchanged = total - gainers - losers;
    final avgChange = items.fold<double>(
          0,
          (sum, p) => sum + (p.percentChange ?? 0),
        ) /
        total;
    final avgColor = avgChange >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
    final avgSign = avgChange >= 0 ? '+' : '';

    final sorted = [...items]
      ..sort((a, b) => (b.percentChange ?? 0).compareTo(a.percentChange ?? 0));
    final best = sorted.first;
    final worst = sorted.last;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 18, color: AppTheme.accentBlue),
                const SizedBox(width: 8),
                Text(
                  'MFs Health',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: avgColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Avg $avgSign${avgChange.toStringAsFixed(1)}% 1Y',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: avgColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _HealthStat(
                  label: 'Total',
                  value: '$total',
                  color: AppTheme.accentBlue,
                ),
                const SizedBox(width: 16),
                _HealthStat(
                  label: 'Positive',
                  value: '$gainers',
                  color: AppTheme.accentGreen,
                ),
                const SizedBox(width: 16),
                _HealthStat(
                  label: 'Negative',
                  value: '$losers',
                  color: AppTheme.accentRed,
                ),
                if (unchanged > 0) ...[
                  const SizedBox(width: 16),
                  _HealthStat(
                    label: 'Flat',
                    value: '$unchanged',
                    color: Colors.white38,
                  ),
                ],
              ],
            ),
            if (items.length >= 2) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PerformerChip(
                      label: 'Best',
                      symbol: best.name,
                      pct: best.percentChange ?? 0,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PerformerChip(
                      label: 'Worst',
                      symbol: worst.name,
                      pct: worst.percentChange ?? 0,
                      color: AppTheme.accentRed,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PerformerChip extends StatelessWidget {
  final String label;
  final String symbol;
  final double pct;
  final Color color;

  const _PerformerChip({
    required this.label,
    required this.symbol,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sign = pct >= 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white38,
              fontSize: 10,
            ),
          ),
          Expanded(
            child: Text(
              symbol,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$sign${pct.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarredItemTile extends StatelessWidget {
  final StarredItem item;
  final DiscoverStockItem? liveQuote;

  const _StarredItemTile({required this.item, this.liveQuote});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = liveQuote?.percentChange ?? item.percentChange;
    final pctColor =
        (pct ?? 0) >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
    final isStock = item.type == 'stock';
    final title = isStock ? item.id : item.name;
    final subtitle = isStock ? item.name : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: InkWell(
        onTap: () => context.push(
          isStock ? '/discover/stock/${item.id}' : '/discover/mf/${item.id}',
        ),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isStock
                      ? Icons.bar_chart_rounded
                      : Icons.account_balance_rounded,
                  size: 16,
                  color: AppTheme.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (pct != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: pctColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: pctColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesEmptyState extends StatelessWidget {
  final String type;

  const _FavoritesEmptyState({required this.type});

  bool get _isStock => type == 'stock';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title =
        _isStock ? 'No starred stocks yet' : 'No starred mutual funds yet';
    final body = _isStock
        ? 'Star stocks from Discover to track them here.'
        : 'Star mutual funds from Discover to track them here.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(
                _isStock
                    ? Icons.star_border_rounded
                    : Icons.account_balance_wallet_outlined,
                size: 44,
                color: Colors.white.withValues(alpha: 0.16),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white38,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white24,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.go('/discover'),
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Open Discover'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Market Overview Grid (existing)
// =============================================================================

class _MarketOverviewGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketAsync = ref.watch(latestMarketPricesProvider);
    final commodityAsync = ref.watch(latestCommoditiesProvider);
    final cryptoAsync = ref.watch(latestCryptoProvider);
    final unitSystem = ref.watch(unitSystemProvider);
    final watchlistAsync = ref.watch(watchlistProvider);
    String phaseFor(MarketPrice p) => normalizeMarketPhase(p.marketPhase);

    return marketAsync.when(
      loading: () => const ShimmerList(itemCount: 4, itemHeight: 70),
      error: (err, _) => ErrorView(
        message: friendlyErrorMessage(err),
        onRetry: () => ref.invalidate(latestMarketPricesProvider),
      ),
      data: (marketPrices) {
        final commodities = commodityAsync.valueOrNull ?? [];
        final cryptos = cryptoAsync.valueOrNull ?? [];
        final allPrices = [...marketPrices, ...commodities, ...cryptos];

        final usdInrPrice =
            allPrices.where((p) => p.asset == 'USD/INR').toList();
        final usdInrRate =
            usdInrPrice.isNotEmpty ? usdInrPrice.first.price : null;

        final watchlistAssets = watchlistAsync.valueOrNull;
        if (watchlistAssets == null) {
          if (watchlistAsync.isLoading) {
            return const ShimmerList(itemCount: 4, itemHeight: 70);
          }
          // Error state — show retry
          return ErrorView(
            message: 'Failed to load watchlist',
            onRetry: () => ref.read(watchlistProvider.notifier).load(),
          );
        }
        final byAsset = <String, MarketPrice>{};
        for (final price in allPrices) {
          byAsset.putIfAbsent(price.asset, () => price);
        }
        final rows = watchlistAssets
            .map(
              (asset) => _DashboardWatchlistRow(
                asset: asset,
                price: byAsset[asset],
              ),
            )
            .toList();

        if (watchlistAssets.isEmpty) {
          return const EmptyView(message: 'Your watchlist is empty');
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (final row in rows)
                row.price != null
                    ? _DashboardTile(
                        price: row.price!,
                        usdInrRate: usdInrRate,
                        unitSystem: unitSystem,
                        phase: phaseFor(row.price!),
                      )
                    : _DashboardFallbackTile(asset: row.asset),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardWatchlistRow {
  final String asset;
  final MarketPrice? price;

  const _DashboardWatchlistRow({
    required this.asset,
    required this.price,
  });
}

class _DashboardTile extends StatelessWidget {
  final MarketPrice price;
  final double? usdInrRate;
  final UnitSystem unitSystem;
  final String phase;

  const _DashboardTile({
    required this.price,
    required this.usdInrRate,
    required this.unitSystem,
    this.phase = 'closed',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCommodity = price.instrumentType == 'commodity';
    final isCrypto = price.instrumentType == 'crypto';
    final useIndianCommodity = unitSystem == UnitSystem.indian &&
        usdInrRate != null &&
        (isCommodity || isCrypto);
    final fx = usdInrRate ?? 1.0;
    final displayValue = assetDisplayValue(
      asset: price.asset,
      rawPrice: price.price,
      useIndianUnits: useIndianCommodity,
      usdInrRate: fx,
      instrumentType: price.instrumentType,
    );
    final display = assetDisplayPriceAndUnit(
      asset: price.asset,
      rawPrice: price.price,
      useIndianUnits: useIndianCommodity,
      usdInrRate: fx,
      instrumentType: price.instrumentType,
      sourceUnit: price.unit,
    );
    final displayPrice = display.$1;
    final unitLabel = display.$2;

    final previousDisplayValue = price.previousClose == null
        ? null
        : assetDisplayValue(
            asset: price.asset,
            rawPrice: price.previousClose!,
            useIndianUnits: useIndianCommodity,
            usdInrRate: fx,
            instrumentType: price.instrumentType,
          );
    final changeTag = Formatters.changeWithDiff(
      current: displayValue,
      previous: previousDisplayValue,
      pct: price.changePercent,
    );
    final pctColor = (price.changePercent ?? 0) >= 0
        ? AppTheme.accentGreen
        : AppTheme.accentRed;
    final tickTs = price.lastTickTimestamp ?? price.timestamp;
    final freshness = Formatters.marketFreshnessSubtitle(
      tickTime: tickTs,
      isPredictive: price.isPredictive ?? false,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: InkWell(
        onTap: () {
          final encoded = Uri.encodeComponent(price.asset);
          if (price.instrumentType == 'crypto') {
            context.push('/crypto/detail/$encoded', extra: price);
          } else {
            context.push('/market/detail/$encoded', extra: price);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayName(price.asset),
                            style: theme.textTheme.bodyMedium?.copyWith(
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
                      freshness,
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
                    '$displayPrice$unitLabel',
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
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HealthStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white30,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _DashboardFallbackTile extends StatelessWidget {
  final String asset;

  const _DashboardFallbackTile({required this.asset});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            AssetLogoBadge(
              asset: asset,
              size: 20,
              borderRadius: 6,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName(asset),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Syncing latest quote',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white30,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '--',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white54,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/error_utils.dart';
import '../../../core/market_status_helper.dart' show normalizeMarketPhase;
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/market_price.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
      ),
      body: RefreshIndicator(
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
    );
  }
}

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
          return const ShimmerList(itemCount: 4, itemHeight: 70);
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

        final pricesWithData = rows
            .where((r) => r.price != null)
            .map((r) => r.price!)
            .toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              if (pricesWithData.isNotEmpty)
                _WatchlistHealthCard(prices: pricesWithData),
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

class _WatchlistHealthCard extends StatelessWidget {
  final List<MarketPrice> prices;

  const _WatchlistHealthCard({required this.prices});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = prices.length;
    final gainers =
        prices.where((p) => (p.changePercent ?? 0) > 0).length;
    final losers =
        prices.where((p) => (p.changePercent ?? 0) < 0).length;
    final unchanged = total - gainers - losers;
    final avgChange = prices.fold<double>(
          0,
          (sum, p) => sum + (p.changePercent ?? 0),
        ) /
        total;
    final avgColor = avgChange >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
    final avgSign = avgChange >= 0 ? '+' : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_heart_outlined,
                    size: 18, color: AppTheme.accentBlue),
                const SizedBox(width: 8),
                Text(
                  'Watchlist Health',
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
                    color: avgColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Avg $avgSign${avgChange.toStringAsFixed(2)}%',
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
          ],
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

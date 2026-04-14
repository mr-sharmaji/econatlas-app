import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../core/error_utils.dart';
import '../../../core/market_status_helper.dart' show normalizeMarketPhase;
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/intraday_response.dart';
import '../../../data/models/market_price.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class CommodityDetailScreen extends ConsumerStatefulWidget {
  final String asset;
  final MarketPrice? initialPrice;

  const CommodityDetailScreen({
    super.key,
    required this.asset,
    this.initialPrice,
  });

  @override
  ConsumerState<CommodityDetailScreen> createState() =>
      _CommodityDetailScreenState();
}

class _CommodityDetailScreenState extends ConsumerState<CommodityDetailScreen> {
  ChartRange _chartRange = ChartRange.oneDay;

  // Commodity category labels for the context line
  static const _categories = <String, String>{
    'gold': 'Precious Metal',
    'silver': 'Precious Metal',
    'platinum': 'Precious Metal',
    'palladium': 'Precious Metal',
    'copper': 'Industrial Metal',
    'crude oil': 'Energy',
    'natural gas': 'Energy',
  };

  static const _exchanges = <String, String>{
    'gold': 'COMEX',
    'silver': 'COMEX',
    'platinum': 'NYMEX',
    'palladium': 'NYMEX',
    'copper': 'COMEX',
    'crude oil': 'NYMEX',
    'natural gas': 'NYMEX',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(commodityHistoryProvider(widget.asset));
    final unitSystem = ref.watch(unitSystemProvider);
    final latestCommoditiesAsync = ref.watch(latestCommoditiesProvider);
    final latestResolvedPrice = latestCommoditiesAsync.valueOrNull
        ?.where((p) => p.asset == widget.asset)
        .firstOrNull;
    final currentPrice = latestResolvedPrice ?? widget.initialPrice;
    final is1D = _chartRange == ChartRange.oneDay;
    final intradayAsync = ref.watch(commodityIntradayProvider(widget.asset));
    final intradayPayload = intradayAsync.valueOrNull;
    final intradayList = intradayPayload?.prices ?? const [];
    final hasAuthoritativeTick =
        latestResolvedPrice != null || intradayList.isNotEmpty;
    final phase = normalizeMarketPhase(currentPrice?.marketPhase);
    final chartTzId = ref.watch(chartTimezoneProvider).id;
    // Dedicated USD/INR provider — hydrates from SharedPreferences so
    // the first frame always has a non-null rate when the user has
    // chosen Indian units. See usdInrRateProvider for rationale.
    final usdInrRate = ref.watch(usdInrRateProvider);
    final effectiveUsdInrRate = usdInrRate ?? 83.0;
    final useIndian =
        unitSystem == UnitSystem.indian && effectiveUsdInrRate > 0;
    final display = currentPrice != null
        ? assetDisplayPriceAndUnit(
            asset: widget.asset,
            rawPrice: currentPrice.price,
            useIndianUnits: useIndian,
            usdInrRate: effectiveUsdInrRate,
            instrumentType: 'commodity',
            sourceUnit: currentPrice.unit,
          )
        : null;
    final displayUnit = display?.$2;
    final watchlistAssets =
        ref.watch(watchlistProvider).valueOrNull ?? const <String>[];
    final inWatchlist = watchlistAssets.contains(widget.asset);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AssetLogoBadge(
              asset: widget.asset,
              instrumentType: 'commodity',
              size: 22,
              borderRadius: 6,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                displayName(widget.asset),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            MarketStatusPill(phase: phase, showLabel: true),
          ],
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
          ref.invalidate(commodityHistoryProvider(widget.asset));
          ref.invalidate(commodityIntradayProvider(widget.asset));
          // forceRefreshLatestCommodities bypasses the cached-return
          // path so the indicator actually waits for the network
          // fetch instead of dismissing on the cached return.
          try {
            await Future.wait([
              forceRefreshLatestCommodities(ref),
              ref.read(commodityHistoryProvider(widget.asset).future),
            ]);
          } catch (_) {}
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 1. Header ──
            _buildHeader(theme),
            const SizedBox(height: 12),

            // ── 2. Price row ──
            if (currentPrice != null && display != null) ...[
              _buildPriceRow(
                theme,
                display.$1,
                display.$2,
                historyAsync.valueOrNull,
                priceForTop: currentPrice,
                intradayFor1D: intradayList,
                phase: phase,
                showTickAge: hasAuthoritativeTick,
              ),
              const SizedBox(height: 20),
            ],

            // ── 3. Period selector ──
            _buildPeriodSelector(theme, oneDayLabel: '24H'),
            const SizedBox(height: 10),

            // ── 4. Chart + 5. Range card ──
            historyAsync.when(
              loading: () => const ShimmerCard(height: 200),
              error: (err, _) => ErrorView(
                message: friendlyErrorMessage(err),
                onRetry: () =>
                    ref.invalidate(commodityHistoryProvider(widget.asset)),
              ),
              data: (prices) {
                final useIntraday = is1D && intradayList.isNotEmpty;
                final List<double> chartPrices;
                final List<DateTime> chartTimestamps;
                final bool isIntradayChart;

                if (useIntraday) {
                  chartPrices = useIndian
                      ? intradayList
                          .map((p) => assetDisplayValue(
                                asset: widget.asset,
                                rawPrice: p.price,
                                useIndianUnits: true,
                                usdInrRate: effectiveUsdInrRate,
                                instrumentType: 'commodity',
                              ))
                          .toList()
                      : intradayList.map((p) => p.price).toList();
                  chartTimestamps =
                      intradayList.map((p) => p.timestamp).toList();
                  isIntradayChart = true;
                } else {
                  if (prices.isEmpty) {
                    return const EmptyView(message: 'No historical data');
                  }
                  final sorted = List.of(prices)
                    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
                  final filtered = _filterByRange(sorted);
                  if (filtered.isEmpty) {
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
                  chartPrices = useIndian
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
                  isIntradayChart = false;
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
                final open = chartPrices.first;
                final close = chartPrices.last;
                final high = chartPrices.reduce((a, b) => a > b ? a : b);
                final low = chartPrices.reduce((a, b) => a < b ? a : b);
                final prefix = useIndian ? '₹ ' : '';
                final chartUnitHint =
                    useIndian && displayUnit != null ? '₹$displayUnit' : null;
                final dCurrent = currentPrice != null
                    ? (useIndian
                        ? assetDisplayValue(
                            asset: widget.asset,
                            rawPrice: currentPrice.price,
                            useIndianUnits: true,
                            usdInrRate: effectiveUsdInrRate,
                            instrumentType: 'commodity',
                          )
                        : currentPrice.price)
                    : close;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PriceLineChart(
                      prices: chartPrices,
                      timestamps: chartTimestamps,
                      unit: null,
                      isShortRange: isShortRange,
                      isIntraday: isIntradayChart,
                      chartTimeZoneId: chartTzId,
                      pricePrefix: prefix.isEmpty ? null : prefix,
                      chartUnitHint: chartUnitHint,
                    ),
                    const SizedBox(height: 14),
                    _SessionRangeCard(
                      label: is1D ? '24H Range' : 'Period Range',
                      low: low,
                      high: high,
                      current: dCurrent,
                      open: open,
                      close: close,
                      pricePrefix: prefix.isEmpty ? '' : prefix,
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

  // ── Header ──────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeData theme) {
    final category = _categories[widget.asset] ?? 'Commodity';
    final exchange = _exchanges[widget.asset] ?? 'COMEX';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            category,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          exchange,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
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
    String phase = 'closed',
    bool showTickAge = true,
  }) {
    double? rangePct;
    if (_chartRange == ChartRange.oneDay) {
      rangePct = priceForTop.changePercent;
      if (rangePct == null) {
        final prevClose = priceForTop.previousClose;
        final last = priceForTop.price;
        if (prevClose != null && prevClose != 0) {
          rangePct = ((last - prevClose) / prevClose) * 100;
        }
      }
      if (rangePct == null &&
          intradayFor1D != null &&
          intradayFor1D.length >= 2) {
        final first = intradayFor1D.first.price;
        final last = intradayFor1D.last.price;
        if (first != 0) rangePct = ((last - first) / first) * 100;
      }
    } else if (history != null && history.isNotEmpty) {
      final sorted = List.of(history)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final filtered = _filterByRange(sorted);
      if (filtered.length >= 2) {
        final first = filtered.first.price;
        final last = filtered.last.price;
        if (first != 0) rangePct = ((last - first) / first) * 100;
      }
    }
    final lastTick = (intradayFor1D != null && intradayFor1D.isNotEmpty)
        ? intradayFor1D.last.timestamp
        : priceForTop.lastTickTimestamp ?? priceForTop.timestamp;
    final subtitle = phase == 'live'
        ? Formatters.updatedFreshness(lastTick, allowJustNow: true)
        : Formatters.updatedFreshness(lastTick);
    final isPositive = (rangePct ?? 0) >= 0;
    final changeColor = isPositive ? AppTheme.accentGreen : AppTheme.accentRed;

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

  // ── Period selector (ChoiceChip, matching stock detail) ──────────────

  Widget _buildPeriodSelector(ThemeData theme, {String oneDayLabel = '1D'}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ChartRange.values.map((r) {
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

  // ── Helpers ─────────────────────────────────────────────────────────

  List<MarketPrice> _filterByRange(List<MarketPrice> sorted) {
    if (_chartRange == ChartRange.all) return sorted;
    final cutoff = DateTime.now().subtract(_chartRange.duration);
    return sorted.where((p) => !p.timestamp.isBefore(cutoff)).toList();
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Session Range Card
// ═══════════════════════════════════════════════════════════════════════

class _SessionRangeCard extends StatelessWidget {
  final String label;
  final double low;
  final double high;
  final double current;
  final double open;
  final double close;
  final String pricePrefix;

  const _SessionRangeCard({
    required this.label,
    required this.low,
    required this.high,
    required this.current,
    required this.open,
    required this.close,
    this.pricePrefix = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = high - low;
    final fraction =
        range > 0 ? ((current - low) / range).clamp(0.0, 1.0) : 0.5;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '$pricePrefix${Formatters.fullPrice(low)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final barWidth = constraints.maxWidth;
                      final markerPos = barWidth * fraction;
                      return SizedBox(
                        height: 24,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 10,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.accentRed.withValues(alpha: 0.4),
                                      AppTheme.accentOrange
                                          .withValues(alpha: 0.4),
                                      AppTheme.accentGreen
                                          .withValues(alpha: 0.4),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: markerPos - 6,
                              top: 2,
                              child: Container(
                                width: 12,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentBlue,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentBlue
                                          .withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$pricePrefix${Formatters.fullPrice(high)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _miniStat(theme, 'Open',
                      '$pricePrefix${Formatters.fullPrice(open)}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _miniStat(theme, 'Close',
                      '$pricePrefix${Formatters.fullPrice(close)}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../core/error_utils.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/intraday_response.dart';
import '../../../data/models/market_price.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class CryptoDetailScreen extends ConsumerStatefulWidget {
  final String asset;
  final MarketPrice? initialPrice;

  const CryptoDetailScreen({
    super.key,
    required this.asset,
    this.initialPrice,
  });

  @override
  ConsumerState<CryptoDetailScreen> createState() =>
      _CryptoDetailScreenState();
}

class _CryptoDetailScreenState extends ConsumerState<CryptoDetailScreen> {
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
    final historyAsync = ref.watch(cryptoHistoryProvider(widget.asset));
    final latestCryptoAsync = ref.watch(latestCryptoProvider);
    final unitSystem = ref.watch(unitSystemProvider);
    final useIndian = unitSystem == UnitSystem.indian;
    final marketAsync = ref.watch(latestMarketPricesProvider);
    final usdInrRate = marketAsync.valueOrNull
            ?.where((p) => p.asset == 'USD/INR')
            .map((p) => p.price)
            .firstOrNull ??
        84.0;
    final latestResolvedPrice = latestCryptoAsync.valueOrNull
        ?.where((p) => p.asset == widget.asset)
        .firstOrNull;
    final currentPrice = latestResolvedPrice ?? widget.initialPrice;
    final is1D = _chartRange == ChartRange.oneDay;
    final intradayAsync = ref.watch(cryptoIntradayProvider(widget.asset));
    final intradayPayload = intradayAsync.valueOrNull;
    final intradayList = intradayPayload?.prices ?? const [];
    final hasAuthoritativeTick =
        latestResolvedPrice != null || intradayList.isNotEmpty;
    // Crypto is 24/7 — always show as "live" when we have recent data.
    final phase = hasAuthoritativeTick ? 'live' : 'closed';
    final chartTzId = ref.watch(chartTimezoneProvider).id;
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
          ref.invalidate(latestCryptoProvider);
          ref.invalidate(cryptoHistoryProvider(widget.asset));
          ref.invalidate(cryptoIntradayProvider(widget.asset));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _chartRangeChips(context, oneDayLabel: '24H'),
            const SizedBox(height: 16),
            if (currentPrice != null) ...[
              _buildTopCard(
                theme,
                currentPrice,
                historyAsync.valueOrNull,
                intradayFor1D: intradayList,
                phase: phase,
                showTickAge: hasAuthoritativeTick,
                useIndian: useIndian,
                usdInrRate: usdInrRate,
              ),
              const SizedBox(height: 16),
            ],
            historyAsync.when(
              loading: () => const ShimmerCard(height: 200),
              error: (err, _) => ErrorView(
                message: friendlyErrorMessage(err),
                onRetry: () =>
                    ref.invalidate(cryptoHistoryProvider(widget.asset)),
              ),
              data: (prices) {
                final useIntraday = is1D && intradayList.isNotEmpty;
                final List<double> chartPrices;
                final List<DateTime> chartTimestamps;
                final bool isIntradayChart;

                if (useIntraday) {
                  chartPrices = intradayList.map((p) => p.price).toList();
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
                              ? 'No intraday data yet'
                              : 'No data in this range',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    );
                  }
                  chartPrices = filtered.map((p) => p.price).toList();
                  chartTimestamps = filtered.map((p) => p.timestamp).toList();
                  isIntradayChart = false;
                }

                if (chartPrices.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(
                      child: Text(
                        is1D
                            ? 'No intraday data yet'
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
                final avg = chartPrices.fold<double>(0, (s, p) => s + p) /
                    chartPrices.length;
                final spreadPct =
                    open != 0 ? ((high - low) / open) * 100 : null;
                final pricePrefix = useIndian ? '₹ ' : '\$ ';
                final displayPrices = useIndian
                    ? chartPrices.map((p) => p * usdInrRate).toList()
                    : chartPrices;
                final dOpen = useIndian ? open * usdInrRate : open;
                final dHigh = useIndian ? high * usdInrRate : high;
                final dLow = useIndian ? low * usdInrRate : low;
                final dClose = useIndian ? close * usdInrRate : close;
                final dAvg = useIndian ? avg * usdInrRate : avg;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RangeStatsCard(
                      open: dOpen,
                      high: dHigh,
                      low: dLow,
                      close: dClose,
                      avg: dAvg,
                      spreadPct: spreadPct,
                      pricePrefix: pricePrefix,
                    ),
                    const SizedBox(height: 12),
                    PriceLineChart(
                      prices: displayPrices,
                      timestamps: chartTimestamps,
                      unit: null,
                      isShortRange: isShortRange,
                      isIntraday: isIntradayChart,
                      chartTimeZoneId: chartTzId,
                      pricePrefix: pricePrefix,
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
    MarketPrice priceForTop,
    List<MarketPrice>? history, {
    List<IntradayPoint>? intradayFor1D,
    String phase = 'closed',
    bool showTickAge = true,
    required bool useIndian,
    required double usdInrRate,
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
    final rangeLabel =
        _chartRange == ChartRange.oneDay ? '24H' : _chartRange.label;
    final lastTick = (intradayFor1D != null && intradayFor1D.isNotEmpty)
        ? intradayFor1D.last.timestamp
        : priceForTop.lastTickTimestamp ?? priceForTop.timestamp;
    final subtitle = phase == 'live'
        ? Formatters.updatedFreshness(
            lastTick,
            allowJustNow: true,
          )
        : Formatters.updatedFreshness(lastTick);
    final display = assetDisplayPriceAndUnit(
      asset: widget.asset,
      rawPrice: priceForTop.price,
      useIndianUnits: useIndian,
      usdInrRate: usdInrRate,
      instrumentType: 'crypto',
    );
    final displayPrice = display.$1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayPrice,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (rangePct != null) ...[
              const SizedBox(height: 6),
              Text(
                '$rangeLabel change  ${Formatters.changeTag(rangePct)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: (rangePct >= 0)
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

class _RangeStatsCard extends StatelessWidget {
  final double open;
  final double high;
  final double low;
  final double close;
  final double? avg;
  final double? spreadPct;
  final String pricePrefix;

  const _RangeStatsCard({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.avg,
    this.spreadPct,
    this.pricePrefix = '\$ ',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefix = pricePrefix;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: _stat(
                        theme, 'Open', '$prefix${Formatters.fullPrice(open)}')),
                const SizedBox(width: 12),
                Expanded(
                    child: _stat(
                        theme, 'High', '$prefix${Formatters.fullPrice(high)}')),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: _stat(
                        theme, 'Low', '$prefix${Formatters.fullPrice(low)}')),
                const SizedBox(width: 12),
                Expanded(
                    child: _stat(theme, 'Close',
                        '$prefix${Formatters.fullPrice(close)}')),
              ],
            ),
            if (avg != null || spreadPct != null) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (avg != null)
                    Expanded(
                        child: _stat(theme, 'Avg',
                            '$prefix${Formatters.fullPrice(avg!)}')),
                  if (spreadPct != null) ...[
                    if (avg != null) const SizedBox(width: 12),
                    Expanded(
                        child: _stat(theme, 'High\u2013Low',
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

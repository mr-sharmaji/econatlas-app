import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_utils.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/institutional_flow_overview.dart';
import '../../../data/models/ipo.dart';
import '../../../data/models/market_price.dart';
import '../../../data/models/news_article.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class OverviewScreen extends ConsumerStatefulWidget {
  const OverviewScreen({super.key});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen> {
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
    ref.listen<int>(bottomTabReselectTickProvider(0), (prev, next) {
      if (prev == null || prev == next) return;
      _scrollToTop();
    });

    final marketAsync = ref.watch(latestMarketPricesProvider);
    final flowAsync = ref.watch(institutionalFlowsOverviewProvider);
    final newsAsync = ref.watch(newsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(latestMarketPricesProvider);
          ref.invalidate(institutionalFlowsOverviewProvider);
          ref.invalidate(allMacroIndicatorsProvider);
          ref.invalidate(newsProvider);
          ref.invalidate(ipoListProvider('open'));
          ref.invalidate(ipoListProvider('upcoming'));
          ref.invalidate(ipoListProvider('closed'));
          ref.invalidate(ipoAlertsProvider);
          await ref.read(latestMarketPricesProvider.future).catchError((_) => <MarketPrice>[]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 112),
          children: [
            _TopHeadlinesSection(newsAsync: newsAsync),
            const SizedBox(height: 10),
            _MarketSentimentSection(marketAsync: marketAsync),
            const SizedBox(height: 10),
            _MarketVolatilitySection(marketAsync: marketAsync),
            const SizedBox(height: 10),
            _InstitutionalFlowSection(flowAsync: flowAsync),
            const SizedBox(height: 10),
            const _IpoSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TopHeadlinesSection extends StatelessWidget {
  const _TopHeadlinesSection({required this.newsAsync});

  final AsyncValue<List<NewsArticle>> newsAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: newsAsync.when(
          loading: () => const ShimmerList(itemCount: 3, itemHeight: 42),
          error: (err, _) => Text(
            friendlyErrorMessage(err),
            style: theme.textTheme.bodySmall,
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Text('No relevant headlines right now');
            }
            final rows = [...items]
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
            final top = rows.take(3).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Relevant Headlines',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...top.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4C8DFF),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${item.source} · ${Formatters.relativeTime(item.timestamp)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MarketSentimentSection extends StatelessWidget {
  const _MarketSentimentSection({required this.marketAsync});

  final AsyncValue<List<MarketPrice>> marketAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: marketAsync.when(
          loading: () => const ShimmerCard(height: 120),
          error: (err, _) => Text(
            friendlyErrorMessage(err),
            style: theme.textTheme.bodySmall,
          ),
          data: (prices) {
            final indiaAssets = ['Nifty 50', 'Sensex', 'Nifty Bank'];
            final usAssets = ['S&P500', 'NASDAQ', 'Dow Jones', 'Nasdaq 100'];
            final indiaScore = _score(prices, indiaAssets);
            final usScore = _score(prices, usAssets);
            final lastTs =
                _latestTimestamp(prices, [...indiaAssets, ...usAssets]);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Market Sentiment',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (lastTs != null)
                      Text(
                        Formatters.relativeTime(lastTs),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.white54),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _sentimentRow(context, 'India', indiaScore),
                const SizedBox(height: 10),
                _sentimentRow(context, 'US', usScore),
              ],
            );
          },
        ),
      ),
    );
  }

  double _score(List<MarketPrice> prices, List<String> assets) {
    final values = <double>[];
    for (final a in assets) {
      final p = prices.where((e) => e.asset == a).toList();
      if (p.isEmpty) continue;
      final change = p.first.changePercent;
      if (change != null) values.add(change);
    }
    if (values.isEmpty) return 0;
    final avg = values.reduce((x, y) => x + y) / values.length;
    return avg.clamp(-2, 2).toDouble();
  }

  DateTime? _latestTimestamp(List<MarketPrice> prices, List<String> assets) {
    final set = assets.map((e) => e.toLowerCase()).toSet();
    DateTime? latest;
    for (final row in prices) {
      if (!set.contains(row.asset.toLowerCase())) continue;
      final ts = row.lastTickTimestamp ?? row.timestamp;
      if (latest == null || ts.isAfter(latest)) {
        latest = ts;
      }
    }
    return latest;
  }

  Widget _sentimentRow(BuildContext context, String label, double score) {
    final theme = Theme.of(context);
    final t = ((score + 2) / 4).clamp(0.0, 1.0);
    final sentiment = _sentimentMeta(score);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              sentiment.$1,
              style: theme.textTheme.bodySmall?.copyWith(
                color: sentiment.$2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFD24E5A),
                    Color(0xFFC9A538),
                    Color(0xFF2FB864)
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment(-1 + (2 * t), 0),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Text('Bearish',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: Colors.white54)),
            const Spacer(),
            Text('Neutral',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: Colors.white54)),
            const Spacer(),
            Text('Bullish',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: Colors.white54)),
          ],
        ),
      ],
    );
  }

  (String, Color) _sentimentMeta(double score) {
    if (score <= -1.2) return ('Strongly Bearish', AppTheme.accentRed);
    if (score <= -0.55) return ('Bearish', const Color(0xFFFF7A7A));
    if (score <= -0.2) return ('Slightly Bearish', const Color(0xFFFFB3B3));
    if (score < 0.2) return ('Neutral', const Color(0xFFFFC107));
    if (score < 0.55) return ('Slightly Bullish', const Color(0xFF8DE9B0));
    if (score < 1.2) return ('Bullish', AppTheme.accentGreen);
    return ('Strongly Bullish', const Color(0xFF22E07A));
  }
}

class _InstitutionalFlowSection extends StatelessWidget {
  const _InstitutionalFlowSection({required this.flowAsync});

  final AsyncValue<InstitutionalFlowsOverview> flowAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: flowAsync.when(
          loading: () => const ShimmerCard(height: 140),
          error: (err, _) => Text(
            friendlyErrorMessage(err),
            style: theme.textTheme.bodySmall,
          ),
          data: (overview) {
            final fiiValue = overview.fiiValue;
            final diiValue = overview.diiValue;
            if (fiiValue == null && diiValue == null) {
              return const Text('FII/DII flow data unavailable');
            }

            final netFlow =
                overview.combinedValue ?? ((fiiValue ?? 0) + (diiValue ?? 0));
            final lastTs = overview.asOf;
            final trend = overview.trend;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Text(
                      'Institutional Flows',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (lastTs != null)
                      Text(
                        Formatters.asOfDate(lastTs),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.white54),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // Summary chips
                Row(
                  children: [
                    _flowChip(context, 'FII', fiiValue),
                    const SizedBox(width: 8),
                    _flowChip(context, 'DII', diiValue),
                    const SizedBox(width: 8),
                    _flowChip(context, 'Net', netFlow),
                  ],
                ),
                const SizedBox(height: 10),
                // 30-day bar chart
                if (trend.length >= 2)
                  SizedBox(
                    height: 100,
                    child: _flowBarChart(context, trend),
                  ),
                // Legend
                if (trend.length >= 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legendDot(const Color(0xFFFF9800), 'FII'),
                        const SizedBox(width: 12),
                        _legendDot(Colors.blueAccent, 'DII'),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _flowChip(BuildContext context, String label, double? value) {
    final theme = Theme.of(context);
    final color = (value ?? 0) >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
    final formatted = value != null
        ? '₹${Formatters.fullPrice(value)} Cr'
        : 'N/A';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white54,
                fontSize: 10,
              ),
            ),
            Text(
              formatted,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _flowBarChart(
    BuildContext context,
    List<InstitutionalFlowTrendPoint> trend,
  ) {
    // Build bar groups — each day has FII and DII side by side
    final barGroups = <BarChartGroupData>[];
    double maxAbs = 0;

    for (int i = 0; i < trend.length; i++) {
      final fii = trend[i].fiiValue ?? 0;
      final dii = trend[i].diiValue ?? 0;
      if (fii.abs() > maxAbs) maxAbs = fii.abs();
      if (dii.abs() > maxAbs) maxAbs = dii.abs();

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: fii,
              color: const Color(0xFFFF9800).withValues(alpha: 0.9),
              width: trend.length > 20 ? 3 : 5,
              borderRadius: BorderRadius.vertical(
                top: fii >= 0 ? const Radius.circular(1.5) : Radius.zero,
                bottom: fii < 0 ? const Radius.circular(1.5) : Radius.zero,
              ),
            ),
            BarChartRodData(
              toY: dii,
              color: Colors.blueAccent.withValues(alpha: 0.85),
              width: trend.length > 20 ? 3 : 5,
              borderRadius: BorderRadius.vertical(
                top: dii >= 0 ? const Radius.circular(1.5) : Radius.zero,
                bottom: dii < 0 ? const Radius.circular(1.5) : Radius.zero,
              ),
            ),
          ],
          barsSpace: 1,
        ),
      );
    }

    if (maxAbs == 0) maxAbs = 1;
    final yPad = maxAbs * 0.15;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: maxAbs + yPad,
        minY: -(maxAbs + yPad),
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxAbs,
          getDrawingHorizontalLine: (value) {
            if (value == 0) {
              return FlLine(
                color: Colors.white24,
                strokeWidth: 0.8,
              );
            }
            return FlLine(color: Colors.transparent);
          },
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 16,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= trend.length) {
                  return const SizedBox.shrink();
                }
                // Show labels at start, middle, end only
                if (idx != 0 &&
                    idx != trend.length - 1 &&
                    idx != trend.length ~/ 2) {
                  return const SizedBox.shrink();
                }
                final d = trend[idx].sessionDate;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${d.day}/${d.month}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tooltipMargin: 4,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = rodIndex == 0 ? 'FII' : 'DII';
              final val = rod.toY;
              final sign = val >= 0 ? '+' : '';
              return BarTooltipItem(
                '$label: $sign₹${Formatters.fullPrice(val)} Cr',
                TextStyle(
                  color: rod.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MarketVolatilitySection extends StatelessWidget {
  const _MarketVolatilitySection({required this.marketAsync});

  final AsyncValue<List<MarketPrice>> marketAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: marketAsync.when(
          loading: () => const ShimmerCard(height: 80),
          error: (err, _) => Text(
            friendlyErrorMessage(err),
            style: theme.textTheme.bodySmall,
          ),
          data: (prices) {
            final india = _latest(prices, const ['India VIX']);
            final us = _latest(prices, const ['CBOE VIX', 'US VIX']);
            if (india == null && us == null) {
              return const Text('Volatility data unavailable');
            }
            final lastTs = [india, us]
                .whereType<MarketPrice>()
                .map((e) => e.lastTickTimestamp ?? e.timestamp)
                .fold<DateTime?>(
                    null, (a, b) => a == null || b.isAfter(a) ? b : a);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Market Volatility',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (lastTs != null)
                      Text(
                        Formatters.relativeTime(lastTs),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.white54),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (india != null) _volRow(context, india),
                if (india != null && us != null) const SizedBox(height: 6),
                if (us != null) _volRow(context, us),
              ],
            );
          },
        ),
      ),
    );
  }

  MarketPrice? _latest(List<MarketPrice> rows, List<String> assets) {
    final matched = rows
        .where((e) =>
            assets.any((name) => e.asset.toLowerCase() == name.toLowerCase()))
        .toList();
    if (matched.isEmpty) return null;
    matched.sort((a, b) {
      final aTs = a.lastTickTimestamp ?? a.timestamp;
      final bTs = b.lastTickTimestamp ?? b.timestamp;
      return bTs.compareTo(aTs);
    });
    return matched.first;
  }

  Widget _volRow(BuildContext context, MarketPrice item) {
    final theme = Theme.of(context);
    final phase = (item.marketPhase ?? 'closed').trim().toLowerCase();
    final phaseColor = switch (phase) {
      'live' => AppTheme.accentGreen,
      'stale' => const Color(0xFFFFC107),
      _ => Colors.white54,
    };
    final delta = item.previousClose == null
        ? null
        : (item.price - (item.previousClose ?? 0));
    final pct = item.changePercent;
    final changeLabel = Formatters.changeWithDiff(
      current: item.price,
      previous: item.previousClose,
      pct: pct,
    );
    final tone =
        _volatilityTone(pct: pct, delta: delta, previous: item.previousClose);
    final riskUp = ((delta ?? pct ?? 0) >= 0);
    final changeColor = riskUp ? AppTheme.accentRed : AppTheme.accentGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName(item.asset),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: phaseColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                Formatters.fullPrice(item.price),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tone.$2.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tone.$1,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tone.$2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (changeLabel.isNotEmpty)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      changeLabel,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: changeColor,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  (String, Color) _volatilityTone({
    required double? pct,
    required double? delta,
    required double? previous,
  }) {
    double? movePct = pct;
    if (movePct == null && previous != null && previous != 0 && delta != null) {
      movePct = (delta / previous) * 100;
    }

    if (movePct == null) {
      return ('Watch', const Color(0xFFFFC107));
    }
    if (movePct >= 20) {
      return ('Spike', AppTheme.accentRed);
    }
    if (movePct >= 5) {
      return ('Rising', const Color(0xFFFFB74D));
    }
    if (movePct <= -20) {
      return ('Calm', AppTheme.accentGreen);
    }
    if (movePct <= -5) {
      return ('Cooling', const Color(0xFF7DD3FC));
    }
    return ('Steady', Colors.white70);
  }
}

class _IpoSection extends ConsumerWidget {
  const _IpoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tab = ref.watch(ipoTabProvider);
    final ipoResponseAsync = ref.watch(ipoListProvider(tab));
    final alertsAsync = ref.watch(ipoAlertsProvider);
    final selectedAlerts = alertsAsync.valueOrNull ?? <String>{};

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'IPOs',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _statusButton(
                    context: context,
                    selected: tab == 'open',
                    label: 'Open',
                    onTap: () =>
                        ref.read(ipoTabProvider.notifier).state = 'open',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statusButton(
                    context: context,
                    selected: tab == 'upcoming',
                    label: 'Upcoming',
                    onTap: () =>
                        ref.read(ipoTabProvider.notifier).state = 'upcoming',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statusButton(
                    context: context,
                    selected: tab == 'closed',
                    label: 'Closed',
                    onTap: () =>
                        ref.read(ipoTabProvider.notifier).state = 'closed',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ipoResponseAsync.when(
              loading: () => const ShimmerList(itemCount: 3, itemHeight: 96),
              error: (err, _) => Text(
                friendlyErrorMessage(err),
                style: theme.textTheme.bodySmall,
              ),
              data: (response) {
                final items = response.items;
                if (items.isEmpty) {
                  return _emptyState(
                    context: context,
                    tab: tab,
                    asOf: response.asOf,
                  );
                }
                return Column(
                  children: items.take(8).map((item) {
                    final isClosed = item.status.toLowerCase() == 'closed';
                    final isUpcoming = item.status.toLowerCase() == 'upcoming';
                    final rec = item.recommendation.toLowerCase();
                    final recColor = rec == 'apply'
                        ? AppTheme.accentGreen
                        : rec == 'avoid'
                            ? AppTheme.accentRed
                            : const Color(0xFFFFC107);
                    final recText = rec == 'apply'
                        ? 'Apply'
                        : rec == 'avoid'
                            ? 'Avoid'
                            : 'Watch';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.companyName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      _ipoTypeLabel(item.ipoType),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.white60),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!isClosed)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: recColor.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    recText,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: recColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Price band: ${_priceBandText(item.priceBand)}',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: Colors.white54),
                          ),
                          const SizedBox(height: 6),
                          if (isClosed)
                            Text(
                              _closedOutcomeText(item),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _closedOutcomeColor(item),
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _metric(
                                  context, 'GMP', _gmpText(item.gmpPercent)),
                              if (!isUpcoming) ...[
                                const SizedBox(width: 10),
                                _metric(
                                    context,
                                    'Subscription',
                                    item.subscriptionMultiple == null
                                        ? '—'
                                        : '${item.subscriptionMultiple!.toStringAsFixed(1)}x'),
                              ],
                              const SizedBox(width: 10),
                              _metric(
                                context,
                                'Issue size',
                                item.issueSizeCr == null
                                    ? '—'
                                    : '₹ ${Formatters.fullPrice(item.issueSizeCr!)} Cr',
                              ),
                            ],
                          ),
                          if (!isClosed &&
                              item.recommendationReason.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.recommendationReason,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (isClosed) const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _dateLine(item),
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(color: Colors.white54),
                                ),
                              ),
                              if (!isClosed)
                                _alertButton(
                                  context: context,
                                  enabled: selectedAlerts.contains(item.symbol),
                                  onTap: () => ref
                                      .read(ipoAlertsProvider.notifier)
                                      .toggle(item.symbol),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusButton({
    required BuildContext context,
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? baseColor.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? baseColor.withValues(alpha: 0.8) : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertButton({
    required BuildContext context,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final tint = enabled ? AppTheme.accentGreen : Colors.white54;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled
              ? AppTheme.accentGreen.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          enabled
              ? Icons.notifications_active_rounded
              : Icons.notifications_off_outlined,
          color: tint,
          size: 18,
        ),
      ),
    );
  }

  Widget _emptyState({
    required BuildContext context,
    required String tab,
    required DateTime? asOf,
  }) {
    final theme = Theme.of(context);
    final normalizedTab = tab.toLowerCase();
    IconData icon = Icons.inbox_outlined;
    String title = 'No IPO entries right now';
    String subtitle = 'Pull down to refresh and check again.';

    if (normalizedTab == 'open') {
      icon = Icons.hourglass_top_rounded;
      title = 'No open IPOs now';
      subtitle = 'Live subscription window issues will appear here.';
    } else if (normalizedTab == 'upcoming') {
      icon = Icons.calendar_month_rounded;
      title = 'No upcoming IPOs queued';
      subtitle = 'New issue announcements will show up here.';
    } else if (normalizedTab == 'closed') {
      icon = Icons.task_alt_rounded;
      title = 'No recently closed IPOs';
      subtitle = 'Closed issues with listing outcomes will appear here.';
    }

    final asOfLine = asOf == null ? null : 'As of ${Formatters.asOfDate(asOf)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: Colors.white70),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                if (asOfLine != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    asOfLine,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.white54),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String _gmpText(double? gmp) {
    if (gmp == null) return '—';
    return '${gmp >= 0 ? '+' : ''}${gmp.toStringAsFixed(1)}%';
  }

  String _priceBandText(String? priceBand) {
    if (priceBand == null || priceBand.trim().isEmpty) return '—';
    return priceBand.trim();
  }

  String _ipoTypeLabel(String ipoType) {
    return ipoType.toLowerCase() == 'sme' ? 'SME' : 'Mainboard';
  }

  String _closedOutcomeText(IpoItem item) {
    if (item.listingPrice == null) return 'Awaiting listing data';
    final listed = 'Listed at ₹ ${Formatters.fullPrice(item.listingPrice!)}';
    if (item.listingGainPct == null) return listed;
    final gain = item.listingGainPct!;
    final gainText = '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)}%';
    return '$listed ($gainText)';
  }

  Color _closedOutcomeColor(IpoItem item) {
    if (item.listingGainPct == null) return Colors.white70;
    return item.listingGainPct! >= 0
        ? AppTheme.accentGreen
        : AppTheme.accentRed;
  }

  String _dateLine(IpoItem item) {
    if (item.status.toLowerCase() == 'closed') {
      final close =
          item.closeDate == null ? '—' : Formatters.date(item.closeDate!);
      final listing =
          item.listingDate == null ? '—' : Formatters.date(item.listingDate!);
      return 'Closed $close · Listing $listing';
    }
    final open = item.openDate == null ? '—' : Formatters.date(item.openDate!);
    final close =
        item.closeDate == null ? '—' : Formatters.date(item.closeDate!);
    return 'Open $open · Close $close';
  }
}

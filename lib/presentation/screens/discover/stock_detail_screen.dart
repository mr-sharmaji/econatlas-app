import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/discover.dart';
import '../../providers/discover_providers.dart';
import '../../widgets/chart_widget.dart';
import 'widgets/score_bar.dart';
import 'widgets/metric_grid.dart';

class StockDetailScreen extends ConsumerStatefulWidget {
  final String symbol;
  final DiscoverStockItem? initialItem;

  const StockDetailScreen({super.key, required this.symbol, this.initialItem});

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen> {
  int _selectedDays = 90; // default 3M

  static const _periods = [
    (label: '1M', days: 30),
    (label: '3M', days: 90),
    (label: '6M', days: 180),
    (label: '1Y', days: 365),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.initialItem != null) {
      return _buildContent(theme, widget.initialItem!);
    }

    final detailAsync = ref.watch(discoverStockDetailProvider(widget.symbol));
    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(widget.symbol)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: Text(widget.symbol)),
        body: const Center(child: Text('Error loading stock details')),
      ),
      data: (item) => _buildContent(theme, item),
    );
  }

  Widget _buildContent(ThemeData theme, DiscoverStockItem item) {
    final isPositive = (item.percentChange ?? 0) >= 0;
    final changeColor =
        isPositive ? AppTheme.accentGreen : AppTheme.accentRed;

    final historyAsync = ref.watch(
      discoverStockHistoryProvider((symbol: item.symbol, days: _selectedDays)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(item.symbol)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Quality Verdict Banner --------------------------
            _buildQualityBanner(theme, item),
            const SizedBox(height: 14),

            // -- Header ------------------------------------------
            Text(
              item.displayName,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  item.symbol,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white54),
                ),
                if (item.sector != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.sector!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white54),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  Formatters.fullPrice(item.lastPrice),
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: changeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    Formatters.changeTag(item.percentChange),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: changeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // -- Price Chart -------------------------------------
            _buildPeriodSelector(theme),
            const SizedBox(height: 10),
            historyAsync.when(
              data: (history) {
                if (history.points.isEmpty) {
                  return const SizedBox(
                    height: 180,
                    child: Center(child: Text('No chart data')),
                  );
                }
                return PriceLineChart(
                  prices: history.points.map((p) => p.value).toList(),
                  timestamps: history.points.map((p) => p.date).toList(),
                  isShortRange: _selectedDays <= 90,
                  pricePrefix: '\u20B9 ',
                );
              },
              loading: () => const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox(
                height: 180,
                child: Center(child: Text('Failed to load chart')),
              ),
            ),
            const SizedBox(height: 20),

            // -- 52-Week Range -----------------------------------
            if (item.high52w != null && item.low52w != null) ...[
              _build52WeekRange(theme, item),
              const SizedBox(height: 14),
            ],

            // -- Score -------------------------------------------
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Score',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          item.score.toStringAsFixed(0),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: ScoreBar.scoreColor(item.score),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ScoreBreakdownBar(
                      segments: [
                        ScoreSegment(
                          label: 'Momentum',
                          value: item.scoreMomentum,
                          color: AppTheme.accentBlue,
                        ),
                        ScoreSegment(
                          label: 'Liquidity',
                          value: item.scoreLiquidity,
                          color: AppTheme.accentTeal,
                        ),
                        ScoreSegment(
                          label: 'Fundamentals',
                          value: item.scoreFundamentals,
                          color: AppTheme.accentOrange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // -- Valuation Metrics -------------------------------
            _buildMetricSection(theme, 'Valuation', [
              MetricItem(
                label: 'P/E',
                value: item.peRatio?.toStringAsFixed(1) ?? '\u2014',
                valueColor: _peColor(item.peRatio),
              ),
              MetricItem(
                label: 'P/B',
                value: item.priceToBook?.toStringAsFixed(2) ?? '\u2014',
                valueColor: item.priceToBook == null ? Colors.white38 : null,
              ),
              MetricItem(
                label: 'EPS',
                value: item.eps?.toStringAsFixed(2) ?? '\u2014',
                valueColor: item.eps == null ? Colors.white38 : null,
              ),
            ]),
            const SizedBox(height: 14),

            // -- Quality Metrics ---------------------------------
            _buildMetricSection(theme, 'Quality', [
              MetricItem(
                label: 'ROE',
                value: item.roe != null
                    ? '${item.roe!.toStringAsFixed(1)}%'
                    : '\u2014',
                valueColor: _roeColor(item.roe),
              ),
              MetricItem(
                label: 'ROCE',
                value: item.roce != null
                    ? '${item.roce!.toStringAsFixed(1)}%'
                    : '\u2014',
                valueColor: _roeColor(item.roce),
              ),
              MetricItem(
                label: 'D/E',
                value: item.debtToEquity?.toStringAsFixed(2) ?? '\u2014',
                valueColor: _deColor(item.debtToEquity),
              ),
            ]),
            const SizedBox(height: 14),

            // -- Activity Metrics --------------------------------
            _buildMetricSection(theme, 'Activity', [
              MetricItem(
                label: 'Volume',
                value: item.volume != null
                    ? _formatLargeNumber(item.volume!.toDouble())
                    : '\u2014',
                valueColor: item.volume == null ? Colors.white38 : null,
              ),
              MetricItem(
                label: 'Traded Value',
                value: item.tradedValue != null
                    ? '\u20B9${_formatCrores(item.tradedValue!)}'
                    : '\u2014',
                valueColor: item.tradedValue == null ? Colors.white38 : null,
              ),
              MetricItem(
                label: 'Market Cap',
                value: item.marketCap != null
                    ? '\u20B9${_formatCrores(item.marketCap!)} Cr'
                    : '\u2014',
                valueColor: item.marketCap == null ? Colors.white38 : null,
              ),
              MetricItem(
                label: 'Dividend Yield',
                value: item.dividendYield != null
                    ? '${item.dividendYield!.toStringAsFixed(2)}%'
                    : '\u2014',
                valueColor: item.dividendYield == null ? Colors.white38 : null,
              ),
            ]),
            const SizedBox(height: 14),

            // -- Tags --------------------------------------------
            if (item.tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: item.tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag, style: theme.textTheme.labelSmall),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Quality Verdict Banner ──────────────────────────────────────

  Widget _buildQualityBanner(ThemeData theme, DiscoverStockItem item) {
    final tier = item.qualityTier?.toLowerCase() ?? '';
    final score = item.score;

    final Color bgColor;
    final String tierLabel;
    final String explanation;
    final IconData icon;

    if (score >= 80 || tier == 'strong') {
      bgColor = AppTheme.accentGreen;
      tierLabel = 'Strong';
      explanation = 'This stock has strong fundamentals across all metrics';
      icon = Icons.verified_rounded;
    } else if (score >= 60 || tier == 'good') {
      bgColor = AppTheme.accentBlue;
      tierLabel = 'Good';
      explanation = 'This stock shows good fundamentals with minor gaps';
      icon = Icons.thumb_up_alt_rounded;
    } else if (score >= 40 || tier == 'average') {
      bgColor = AppTheme.accentOrange;
      tierLabel = 'Average';
      explanation = 'This stock has mixed fundamentals worth monitoring';
      icon = Icons.info_outline_rounded;
    } else {
      bgColor = AppTheme.accentRed;
      tierLabel = 'Weak';
      explanation = 'This stock has weak fundamentals and higher risk';
      icon = Icons.warning_amber_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bgColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: bgColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tierLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: bgColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  explanation,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Period Selector Pills ───────────────────────────────────────

  Widget _buildPeriodSelector(ThemeData theme) {
    return Row(
      children: _periods.map((p) {
        final isSelected = p.days == _selectedDays;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(p.label),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedDays = p.days),
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
    );
  }

  // ── 52-Week Range Bar ───────────────────────────────────────────

  Widget _build52WeekRange(ThemeData theme, DiscoverStockItem item) {
    final low = item.low52w!;
    final high = item.high52w!;
    final current = item.lastPrice;
    final range = high - low;
    final fraction = range > 0 ? ((current - low) / range).clamp(0.0, 1.0) : 0.5;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '52-Week Range',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  Formatters.fullPrice(low),
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
                            // Background bar
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
                            // Current price marker
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
                                      color:
                                          AppTheme.accentBlue.withValues(alpha: 0.4),
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
                  Formatters.fullPrice(high),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Metric Section Helper ───────────────────────────────────────

  Widget _buildMetricSection(
      ThemeData theme, String title, List<MetricItem> items) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            MetricGrid(items: items),
          ],
        ),
      ),
    );
  }

  // ── Metric Color Helpers ────────────────────────────────────────

  static Color? _peColor(double? pe) {
    if (pe == null) return Colors.white38;
    if (pe < 25) return AppTheme.accentGreen;
    if (pe > 40) return AppTheme.accentRed;
    return null; // default text color
  }

  static Color? _roeColor(double? roe) {
    if (roe == null) return Colors.white38;
    if (roe > 15) return AppTheme.accentGreen;
    if (roe < 10) return AppTheme.accentRed;
    return null;
  }

  static Color? _deColor(double? de) {
    if (de == null) return Colors.white38;
    if (de < 0.5) return AppTheme.accentGreen;
    if (de > 1.0) return AppTheme.accentRed;
    return null;
  }

  // ── Number Formatting Helpers ───────────────────────────────────

  /// Format large numbers in crore notation (e.g. "12,450").
  static String _formatCrores(double value) {
    final crores = value / 10000000;
    if (crores >= 100) {
      return Formatters.fullPrice(crores.roundToDouble());
    }
    return crores.toStringAsFixed(2);
  }

  /// Format large numbers with K/L/Cr suffixes.
  static String _formatLargeNumber(double value) {
    if (value >= 10000000) {
      return '${(value / 10000000).toStringAsFixed(2)} Cr';
    }
    if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(2)} L';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}

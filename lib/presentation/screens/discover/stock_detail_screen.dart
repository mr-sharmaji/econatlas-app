import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/discover.dart';
import '../../providers/discover_providers.dart';
import 'widgets/score_bar.dart';
import 'widgets/metric_grid.dart';

class StockDetailScreen extends ConsumerWidget {
  final DiscoverStockItem item;

  const StockDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPositive = (item.percentChange ?? 0) >= 0;
    final changeColor =
        isPositive ? AppTheme.accentGreen : AppTheme.accentRed;
    final compareList = ref.watch(discoverStockCompareProvider);
    final isInCompare = compareList.contains(item.symbol);

    return Scaffold(
      appBar: AppBar(title: Text(item.symbol)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────
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

            // ── Score ───────────────────────────────────────
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

            // ── Key Metrics ─────────────────────────────────
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Key Metrics',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    MetricGrid(
                      items: [
                        MetricItem(
                          label: 'P/E',
                          value:
                              item.peRatio?.toStringAsFixed(1) ?? 'N/A',
                        ),
                        MetricItem(
                          label: 'ROE',
                          value: item.roe != null
                              ? '${item.roe!.toStringAsFixed(1)}%'
                              : 'N/A',
                        ),
                        MetricItem(
                          label: 'ROCE',
                          value: item.roce != null
                              ? '${item.roce!.toStringAsFixed(1)}%'
                              : 'N/A',
                        ),
                        MetricItem(
                          label: 'D/E',
                          value: item.debtToEquity?.toStringAsFixed(2) ??
                              'N/A',
                        ),
                        MetricItem(
                          label: 'P/B',
                          value: item.priceToBook?.toStringAsFixed(2) ??
                              'N/A',
                        ),
                        MetricItem(
                          label: 'EPS',
                          value:
                              item.eps?.toStringAsFixed(2) ?? 'N/A',
                        ),
                        MetricItem(
                          label: 'Volume',
                          value: item.volume?.toString() ?? 'N/A',
                        ),
                        MetricItem(
                          label: 'Traded Value',
                          value: item.tradedValue != null
                              ? Formatters.fullPrice(item.tradedValue!)
                              : 'N/A',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Tags ────────────────────────────────────────
            if (item.tags.isNotEmpty) ...[
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tags',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: item.tags
                            .map(
                              (tag) => Chip(
                                label: Text(tag),
                                visualDensity: VisualDensity.compact,
                                side: BorderSide(
                                  color:
                                      Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Why Ranked ──────────────────────────────────
            if (item.whyRanked.isNotEmpty) ...[
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why Ranked',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      ...item.whyRanked.map(
                        (reason) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\u2022  ',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: Colors.white54),
                              ),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Compare Button ──────────────────────────────
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () {
                  ref
                      .read(discoverStockCompareProvider.notifier)
                      .toggle(item.symbol);
                },
                child: Text(
                  isInCompare ? 'Remove from Compare' : 'Add to Compare',
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

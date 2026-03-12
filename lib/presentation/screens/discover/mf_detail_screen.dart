import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/discover.dart';
import '../../providers/discover_providers.dart';
import 'widgets/score_bar.dart';
import 'widgets/metric_grid.dart';

class MfDetailScreen extends ConsumerWidget {
  final DiscoverMutualFundItem item;

  const MfDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final compareList = ref.watch(discoverMutualFundCompareProvider);
    final isInCompare = compareList.contains(item.schemeCode);

    return Scaffold(
      appBar: AppBar(title: const Text('Fund Detail')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            _buildHeader(theme),
            const SizedBox(height: 16),

            // ── Score ──
            _buildScoreCard(theme),
            const SizedBox(height: 12),

            // ── Returns ──
            _buildReturnsCard(theme),
            const SizedBox(height: 12),

            // ── Key Metrics ──
            _buildMetricsCard(theme),
            const SizedBox(height: 12),

            // ── Tags ──
            if (item.tags.isNotEmpty) ...[
              _buildTagsSection(theme),
              const SizedBox(height: 12),
            ],

            // ── Why Ranked ──
            if (item.whyRanked.isNotEmpty) ...[
              _buildWhyRankedSection(theme),
              const SizedBox(height: 16),
            ],

            // ── Compare Button ──
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () {
                  ref
                      .read(discoverMutualFundCompareProvider.notifier)
                      .toggle(item.schemeCode);
                },
                child: Text(
                  isInCompare ? 'Remove from Compare' : 'Add to Compare',
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.schemeName,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (item.category != null) ...[
              Flexible(
                child: Text(
                  item.category!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white54),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (item.riskLevel != null) _buildRiskBadge(theme),
          ],
        ),
        if (item.amc != null) ...[
          const SizedBox(height: 4),
          Text(
            item.amc!,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
        ],
      ],
    );
  }

  Widget _buildRiskBadge(ThemeData theme) {
    final risk = item.riskLevel!.toLowerCase();
    final Color color;
    if (risk.contains('low')) {
      color = AppTheme.accentGreen;
    } else if (risk.contains('moderate') || risk.contains('medium')) {
      color = AppTheme.accentOrange;
    } else if (risk.contains('high') || risk.contains('very high')) {
      color = AppTheme.accentRed;
    } else {
      color = AppTheme.accentGray;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        item.riskLevel!,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Score Card ──────────────────────────────────────────────────────────

  Widget _buildScoreCard(ThemeData theme) {
    return Card(
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
                  style: theme.textTheme.titleSmall,
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
                  label: 'Return',
                  value: item.scoreReturn,
                  color: AppTheme.accentGreen,
                ),
                ScoreSegment(
                  label: 'Risk',
                  value: item.scoreRisk,
                  color: AppTheme.accentBlue,
                ),
                ScoreSegment(
                  label: 'Cost',
                  value: item.scoreCost,
                  color: AppTheme.accentTeal,
                ),
                ScoreSegment(
                  label: 'Consistency',
                  value: item.scoreConsistency,
                  color: AppTheme.accentOrange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Returns Card ────────────────────────────────────────────────────────

  Widget _buildReturnsCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Returns', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _returnColumn(theme, '1Y', item.returns1y)),
                Expanded(child: _returnColumn(theme, '3Y', item.returns3y)),
                Expanded(child: _returnColumn(theme, '5Y', item.returns5y)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _returnColumn(ThemeData theme, String label, double? value) {
    final String display;
    final Color color;
    if (value != null) {
      display = '${value.toStringAsFixed(1)}%';
      color = value >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
    } else {
      display = 'N/A';
      color = Colors.white54;
    }

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: Colors.white54),
        ),
        const SizedBox(height: 4),
        Text(
          display,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ── Key Metrics Card ────────────────────────────────────────────────────

  Widget _buildMetricsCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Key Metrics', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            MetricGrid(
              items: [
                MetricItem(
                  label: 'NAV',
                  value: Formatters.fullPrice(item.nav),
                ),
                MetricItem(
                  label: 'AUM',
                  value: item.aumCr != null
                      ? '${NumberFormat('#,##,###', 'en_IN').format(item.aumCr!.round())} Cr'
                      : 'N/A',
                ),
                MetricItem(
                  label: 'Expense Ratio',
                  value: item.expenseRatio != null
                      ? '${item.expenseRatio!.toStringAsFixed(2)}%'
                      : 'N/A',
                ),
                MetricItem(
                  label: 'Sharpe',
                  value: item.sharpe?.toStringAsFixed(2) ?? 'N/A',
                ),
                MetricItem(
                  label: 'Sortino',
                  value: item.sortino?.toStringAsFixed(2) ?? 'N/A',
                ),
                MetricItem(
                  label: 'Std Dev',
                  value: item.stdDev?.toStringAsFixed(2) ?? 'N/A',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tags ────────────────────────────────────────────────────────────────

  Widget _buildTagsSection(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: item.tags
          .map((tag) => Chip(
                label: Text(tag, style: theme.textTheme.labelSmall),
                visualDensity: VisualDensity.compact,
              ))
          .toList(),
    );
  }

  // ── Why Ranked ──────────────────────────────────────────────────────────

  Widget _buildWhyRankedSection(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Why Ranked', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ...item.whyRanked.map((reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('  \u2022  ', style: TextStyle(color: Colors.white54)),
                      Expanded(
                        child: Text(
                          reason,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

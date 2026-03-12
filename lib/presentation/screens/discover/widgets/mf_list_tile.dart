import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../data/models/discover.dart';
import 'score_bar.dart';

/// A compact mutual fund card for the screener list.
class MfListTile extends StatelessWidget {
  final DiscoverMutualFundItem item;
  final VoidCallback? onTap;

  const MfListTile({super.key, required this.item, this.onTap});

  static Color riskColor(String? risk) {
    final r = (risk ?? '').toLowerCase();
    if (r.contains('low')) return AppTheme.accentGreen;
    if (r.contains('moderate')) return AppTheme.accentOrange;
    if (r.contains('high')) return AppTheme.accentRed;
    return AppTheme.accentGray;
  }

  static Color _badgeColor(String badge) {
    final b = badge.toLowerCase();
    if (b.contains('top performer')) return AppTheme.accentGreen;
    if (b.contains('consistent')) return AppTheme.accentBlue;
    if (b.contains('cost efficient')) return AppTheme.accentTeal;
    if (b.contains('proven') || b.contains('track record')) {
      return AppTheme.accentOrange;
    }
    return AppTheme.accentBlue;
  }

  /// Format AUM with Indian numbering, e.g. "2,450 Cr".
  static String _formatAumCr(double? aumCr) {
    if (aumCr == null) return '';
    // Use Indian formatting via Formatters for the integer part.
    return '\u20b9${Formatters.price(aumCr)} Cr';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scheme name
            Text(
              item.displayName ?? item.schemeName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),

            // Category, risk badge, category rank
            Row(
              children: [
                if (item.category != null)
                  Text(
                    item.category!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white54),
                  ),
                if (item.riskLevel != null) ...[
                  const SizedBox(width: 8),
                  _riskBadge(context, item.riskLevel!),
                ],
                if (item.categoryRank != null &&
                    item.categoryTotal != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '#${item.categoryRank} of ${item.categoryTotal}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: Colors.white38),
                  ),
                ],
              ],
            ),

            // Quality badges
            if (item.qualityBadges.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: item.qualityBadges.take(2).map((badge) {
                  final color = _badgeColor(badge);
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 8),

            // Score bar
            ScoreBar(score: item.score),
            const SizedBox(height: 6),

            // Metrics row: 1Y, 3Y, Expense, AUM
            Row(
              children: [
                if (item.returns1y != null)
                  _inlineMetric(
                    context,
                    '1Y',
                    '${item.returns1y!.toStringAsFixed(1)}%',
                    color: item.returns1y! >= 0
                        ? AppTheme.accentGreen
                        : AppTheme.accentRed,
                  ),
                if (item.returns1y != null && item.returns3y != null)
                  const SizedBox(width: 12),
                if (item.returns3y != null)
                  _inlineMetric(
                    context,
                    '3Y',
                    '${item.returns3y!.toStringAsFixed(1)}%',
                    color: item.returns3y! >= 0
                        ? AppTheme.accentGreen
                        : AppTheme.accentRed,
                  ),
                if (item.returns3y != null && item.returns5y != null)
                  const SizedBox(width: 12),
                if (item.returns5y != null)
                  _inlineMetric(
                    context,
                    '5Y',
                    '${item.returns5y!.toStringAsFixed(1)}%',
                    color: item.returns5y! >= 0
                        ? AppTheme.accentGreen
                        : AppTheme.accentRed,
                  ),
                if ((item.returns1y != null || item.returns3y != null || item.returns5y != null) &&
                    item.expenseRatio != null)
                  const SizedBox(width: 12),
                if (item.expenseRatio != null)
                  _inlineMetric(
                    context,
                    'Exp',
                    '${item.expenseRatio!.toStringAsFixed(2)}%',
                  ),
                if (item.aumCr != null) ...[
                  const Spacer(),
                  Text(
                    _formatAumCr(item.aumCr),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: Colors.white38),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _riskBadge(BuildContext context, String risk) {
    final color = riskColor(risk);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        risk,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
      ),
    );
  }

  Widget _inlineMetric(
    BuildContext context,
    String label,
    String value, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Text(
      '$label: $value',
      style: theme.textTheme.labelSmall?.copyWith(
        color: color ?? Colors.white54,
      ),
    );
  }
}

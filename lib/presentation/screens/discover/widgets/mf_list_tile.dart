import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
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
            Text(
              item.schemeName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
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
              ],
            ),
            const SizedBox(height: 8),
            ScoreBar(score: item.score),
            const SizedBox(height: 6),
            Row(
              children: [
                if (item.returns3y != null)
                  _inlineMetric(
                    context,
                    '3Y',
                    '${item.returns3y!.toStringAsFixed(1)}%',
                    color: item.returns3y! >= 0
                        ? AppTheme.accentGreen
                        : AppTheme.accentRed,
                  ),
                if (item.returns3y != null && item.expenseRatio != null)
                  const SizedBox(width: 12),
                if (item.expenseRatio != null)
                  _inlineMetric(
                    context,
                    'Exp',
                    '${item.expenseRatio!.toStringAsFixed(2)}%',
                  ),
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

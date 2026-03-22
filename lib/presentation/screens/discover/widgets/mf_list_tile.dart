import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../data/models/discover.dart';
import 'sparkline_widget.dart';

/// A compact mutual fund card for the screener list.
///
/// 3-row layout:
/// Row 1: display name + 1Y return badge
/// Row 2: category · risk level
/// Row 3: circular score + "Top X%" category rank
class MfListTile extends StatelessWidget {
  final DiscoverMutualFundItem item;
  final VoidCallback? onTap;

  /// Optional sparkline data points.
  final List<double>? sparklineValues;

  /// Current sort field — determines which return to display.
  final String sortBy;

  const MfListTile({
    super.key,
    required this.item,
    this.onTap,
    this.sparklineValues,
    this.sortBy = 'score',
  });

  /// Format AUM (in Cr) to compact string.
  static String _formatAum(double crores) {
    if (crores >= 100000) return '${(crores / 100000).toStringAsFixed(1)}L Cr';
    if (crores >= 1000) return '${(crores / 1000).toStringAsFixed(1)}K Cr';
    return '${crores.toStringAsFixed(0)} Cr';
  }

  static Color riskColor(String? risk) {
    final r = (risk ?? '').toLowerCase();
    if (r.contains('low')) return AppTheme.accentGreen;
    if (r.contains('moderate')) return AppTheme.accentOrange;
    if (r.contains('high')) return AppTheme.accentRed;
    return AppTheme.accentGray;
  }

  /// Returns the display return value and label based on sort.
  ({double? value, String label}) get _displayReturn {
    switch (sortBy) {
      case 'returns_3y':
        return (value: item.returns3y, label: '3Y');
      case 'returns_5y':
        return (value: item.returns5y, label: '5Y');
      case 'expense':
        return (value: item.expenseRatio, label: 'ER');
      case 'aum':
        return (value: item.aumCr, label: 'AUM');
      default:
        return (value: item.returns1y, label: '1Y');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dr = _displayReturn;
    final retVal = dr.value;
    final retLabel = dr.label;
    final isReturnField = sortBy != 'expense' && sortBy != 'aum';
    final retPositive = isReturnField ? (retVal ?? 0) >= 0 : true;
    final retColor = isReturnField
        ? (retPositive ? AppTheme.accentGreen : AppTheme.accentRed)
        : Colors.white60;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Scheme name + return/metric badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.displayName ?? item.schemeName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (retVal != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: retColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sortBy == 'aum'
                          ? '₹${retVal >= 1000 ? '${(retVal / 1000).toStringAsFixed(1)}K' : retVal.toStringAsFixed(0)} Cr'
                          : '${isReturnField && retVal >= 0 ? '+' : ''}${retVal.toStringAsFixed(sortBy == 'expense' ? 2 : 1)}% $retLabel',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: retColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 6),

            // Row 2: Fund classification · AUM · Risk level · Expense ratio
            Row(
              children: [
                Flexible(
                  child: Text(
                    '${item.fundClassification ?? item.category ?? ''}'
                    '${item.aumCr != null ? ' · ₹${_formatAum(item.aumCr!)}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white54),
                  ),
                ),
                if (item.riskLevel != null) ...[
                  const SizedBox(width: 8),
                  _riskBadge(context, item.riskLevel!),
                ],
                if (item.expenseRatio != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'ER: ${item.expenseRatio!.toStringAsFixed(2)}%',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // Row 3: Circular score + "Top X%" category rank + sparkline
            Row(
              children: [
                _CompactScore(score: item.score),
                const Spacer(),
                if (sparklineValues != null && sparklineValues!.length >= 2)
                  SizedBox(
                    width: 50,
                    child: SparklineWidget(
                      values: sparklineValues!,
                      color: (sparklineValues!.last >= sparklineValues!.first)
                          ? AppTheme.accentGreen
                          : AppTheme.accentRed,
                      height: 24,
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        risk,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
      ),
    );
  }
}

/// Compact circular score indicator showing just the number.
class _CompactScore extends StatelessWidget {
  final double? score;

  const _CompactScore({required this.score});

  @override
  Widget build(BuildContext context) {
    final s = score ?? 0;
    final color = s >= 70
        ? AppTheme.accentGreen
        : s >= 40
            ? AppTheme.accentOrange
            : AppTheme.accentRed;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        s.toInt().toString(),
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

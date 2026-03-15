import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../data/models/discover.dart';

/// A compact mutual fund card for the screener list.
///
/// 3-row layout:
/// Row 1: display name + 1Y return badge
/// Row 2: category · risk level
/// Row 3: circular score + "Top X%" category rank
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
    final ret1y = item.returns1y;
    final retPositive = (ret1y ?? 0) >= 0;
    final retColor = retPositive ? AppTheme.accentGreen : AppTheme.accentRed;

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
            // Row 1: Scheme name + 1Y return badge
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
                if (ret1y != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: retColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${ret1y >= 0 ? '+' : ''}${ret1y.toStringAsFixed(1)}% 1Y',
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

            // Row 2: Category · Risk level
            Row(
              children: [
                if (item.category != null)
                  Flexible(
                    child: Text(
                      item.category!,
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
              ],
            ),

            const SizedBox(height: 8),

            // Row 3: Circular score + "Top X%" category rank
            Row(
              children: [
                _CompactScore(score: item.score),
                const SizedBox(width: 10),
                if (item.categoryRank != null &&
                    item.categoryTotal != null &&
                    item.categoryTotal! > 0)
                  _CategoryRankText(
                    rank: item.categoryRank!,
                    total: item.categoryTotal!,
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

class _CategoryRankText extends StatelessWidget {
  final int rank;
  final int total;

  const _CategoryRankText({required this.rank, required this.total});

  @override
  Widget build(BuildContext context) {
    final percentile = ((rank / total) * 100).clamp(0.0, 100.0);
    final isTopQuartile = percentile <= 25;
    final color = isTopQuartile ? AppTheme.accentGreen : Colors.white60;

    return Text(
      'Top ${percentile.toStringAsFixed(0)}%',
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
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

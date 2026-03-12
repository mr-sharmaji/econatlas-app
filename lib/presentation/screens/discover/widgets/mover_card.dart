import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../data/models/brief.dart';

/// A compact horizontal-scroll card for market movers (gainers/losers).
class MoverCard extends StatelessWidget {
  final BriefStockItem item;

  const MoverCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = (item.percentChange ?? 0) >= 0;
    final color = isPositive ? AppTheme.accentGreen : AppTheme.accentRed;

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.symbol,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            item.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
          const Spacer(),
          Text(
            Formatters.fullPrice(item.lastPrice),
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            Formatters.changeTag(item.percentChange),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

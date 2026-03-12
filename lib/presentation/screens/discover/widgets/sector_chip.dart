import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../data/models/brief.dart';

/// A chip showing sector name + avg change %.
class SectorChip extends StatelessWidget {
  final BriefSectorItem item;

  const SectorChip({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = item.avgChangePercent >= 0;
    final color = isPositive ? AppTheme.accentGreen : AppTheme.accentRed;
    final sign = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              item.sector,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$sign${item.avgChangePercent.toStringAsFixed(2)}%',
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

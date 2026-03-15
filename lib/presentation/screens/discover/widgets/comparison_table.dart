import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../data/models/discover.dart';

class ComparisonTable extends StatelessWidget {
  final List<String> names;
  final List<ComparisonDimension> dimensions;

  const ComparisonTable({
    super.key,
    required this.names,
    required this.dimensions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Head-to-Head',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            // Header row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Metric',
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.white38),
                  ),
                ),
                ...names.map((name) => Expanded(
                  flex: 2,
                  child: Text(
                    name,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.accentBlue,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
              ],
            ),
            const SizedBox(height: 4),
            Divider(color: Colors.white.withValues(alpha: 0.08)),
            // Data rows
            ...List.generate(dimensions.length, (i) {
              final dim = dimensions[i];
              final isEven = i.isEven;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isEven ? Colors.white.withValues(alpha: 0.03) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        dim.label.isNotEmpty ? dim.label : _formatMetric(dim.metric),
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                      ),
                    ),
                    ...List.generate(dim.values.length, (j) {
                      final isWinner = dim.winnerIndex == j;
                      return Expanded(
                        flex: 2,
                        child: Text(
                          dim.values[j]?.toStringAsFixed(1) ?? '—',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isWinner ? AppTheme.accentGreen : Colors.white70,
                            fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  static String _formatMetric(String metric) {
    return metric
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

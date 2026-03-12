import 'package:flutter/material.dart';

/// A 2-column grid displaying key-value metric pairs.
class MetricGrid extends StatelessWidget {
  final List<MetricItem> items;

  const MetricGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 60) / 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Colors.white54),
                ),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: item.valueColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class MetricItem {
  final String label;
  final String value;
  final Color? valueColor;

  const MetricItem({
    required this.label,
    required this.value,
    this.valueColor,
  });
}

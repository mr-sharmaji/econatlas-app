import 'package:flutter/material.dart';

/// Full-width inline key-value metric rows with dividers.
class MetricGrid extends StatelessWidget {
  final List<MetricItem> items;

  const MetricGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: items.asMap().entries.map((entry) {
        final item = entry.value;
        return Column(
          children: [
            if (entry.key > 0)
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white54),
                  ),
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
          ],
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

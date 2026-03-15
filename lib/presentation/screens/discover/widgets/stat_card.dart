import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import 'metric_glossary.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final String? tooltip;

  /// Optional key into [metricExplanations]. If set, tapping the info icon
  /// shows a bottom sheet with the explanation instead of a tooltip.
  final String? metricKey;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.tooltip,
    this.metricKey,
  });

  String? get _explanation {
    if (metricKey != null && metricExplanations.containsKey(metricKey)) {
      return metricExplanations[metricKey];
    }
    return tooltip;
  }

  void _showExplanation(BuildContext context) {
    final explanation = _explanation;
    if (explanation == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              explanation,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasExplanation = _explanation != null;

    return GestureDetector(
      onTap: hasExplanation ? () => _showExplanation(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasExplanation) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.white38,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

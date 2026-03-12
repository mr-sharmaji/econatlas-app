import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';

class ImpactBadge extends StatelessWidget {
  final String? impact;
  final double? confidence;

  const ImpactBadge({
    super.key,
    this.impact,
    this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    if (impact == null) return const SizedBox.shrink();

    final color = AppTheme.impactColor(impact);
    final label = friendlyImpact(impact);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class ConfidenceBar extends StatelessWidget {
  final double confidence;
  final double width;

  const ConfidenceBar({
    super.key,
    required this.confidence,
    this.width = 60,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = confidence > 0.7
        ? AppTheme.accentGreen
        : confidence > 0.4
            ? AppTheme.accentOrange
            : AppTheme.accentRed;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: confidence,
              backgroundColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${(confidence * 100).toInt()}%',
          style: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

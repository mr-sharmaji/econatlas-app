import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

class ActionTagBanner extends StatelessWidget {
  final String actionTag;
  final String? reasoning;

  const ActionTagBanner({
    super.key,
    required this.actionTag,
    this.reasoning,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _tagColor(actionTag);
    final icon = _tagIcon(actionTag);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actionTag,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (reasoning != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    reasoning!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _tagColor(String tag) {
    switch (tag) {
      case 'Strong Outperformer':
        return AppTheme.accentGreen;
      case 'Outperformer':
      case 'Accumulate':
        return AppTheme.accentTeal;
      case 'Watchlist':
      case 'Hold':
      case 'Hold \u2014 Low Data':
      case 'Neutral':
        return AppTheme.accentOrange;
      case 'Momentum Only':
      case 'Caution':
      case 'Avoid':
        return AppTheme.accentRed;
      default:
        return AppTheme.accentBlue;
    }
  }

  static IconData _tagIcon(String tag) {
    switch (tag) {
      case 'Strong Outperformer':
        return Icons.rocket_launch_rounded;
      case 'Outperformer':
        return Icons.trending_up;
      case 'Accumulate':
        return Icons.add_circle_outline;
      case 'Watchlist':
        return Icons.visibility_outlined;
      case 'Hold':
      case 'Hold \u2014 Low Data':
        return Icons.pause_circle_outline;
      case 'Neutral':
        return Icons.remove_circle_outline;
      case 'Momentum Only':
        return Icons.speed;
      case 'Caution':
        return Icons.warning_amber_rounded;
      case 'Avoid':
        return Icons.block;
      default:
        return Icons.info_outline;
    }
  }
}

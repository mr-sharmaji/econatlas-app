import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/market_status.dart';
import '../providers/providers.dart';

/// Shows "Markets live" or "Markets closed" with optional NSE/NYSE detail.
class MarketLiveIndicator extends ConsumerWidget {
  const MarketLiveIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(marketStatusProvider);

    return statusAsync.when(
      data: (status) => _Chip(status: status),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _Chip extends StatelessWidget {
  final MarketStatus status;

  const _Chip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = status.live;
    final color = isLive
        ? (theme.colorScheme.primaryContainer)
        : (theme.colorScheme.surfaceContainerHighest);
    final onColor = isLive
        ? (theme.colorScheme.onPrimaryContainer)
        : (theme.colorScheme.onSurfaceVariant);

    String label;
    if (isLive) {
      if (status.nseOpen && status.nyseOpen) {
        label = 'Markets live (NSE · US)';
      } else if (status.giftNiftyOpen && !status.nseOpen && !status.nyseOpen) {
        label = 'Markets live (Gift Nifty)';
      } else if (status.nseOpen) {
        label = 'Markets live (NSE)';
      } else {
        label = 'Markets live (US)';
      }
    } else {
      label = 'Markets closed';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: onColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

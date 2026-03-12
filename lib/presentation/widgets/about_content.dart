import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';

/// Shared content for the first-time welcome dialog and the About screen.
class AboutContent extends StatelessWidget {
  const AboutContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'About the app',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${AppConstants.appName} helps you make faster daily market decisions with clear, live-ready data across key global assets.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'What you get',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          _bullet(
            theme,
            theme.colorScheme.primary,
            'Overview',
            'Top headlines, market sentiment, volatility pulse, institutional flows, and IPO tracker.',
          ),
          _bullet(
            theme,
            theme.colorScheme.primary,
            'Watchlist',
            'Create your own list of assets and keep high-priority instruments in one place.',
          ),
          _bullet(
            theme,
            theme.colorScheme.primary,
            'Market',
            'Indices, currencies, commodities, and bonds with live/closed status and detailed asset pages.',
          ),
          _bullet(
            theme,
            theme.colorScheme.primary,
            'Economy',
            'Macro indicators for India, US, Europe, and Japan with historical context.',
          ),
          _bullet(
            theme,
            theme.colorScheme.primary,
            'Discover',
            'India-focused discovery hub with Stock and Mutual Fund screeners, compare mode, and guided score explainers.',
          ),
          _bullet(
            theme,
            theme.colorScheme.primary,
            'Quick Tools',
            'Floating quick actions for Currency Converter, Tax Hub, and Trade Charges.',
          ),
          const SizedBox(height: 20),
          Text(
            'How to read status',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          _bullet(
            theme,
            AppTheme.accentGreen,
            'Live',
            'Market/feed is active and updates are coming normally.',
          ),
          _bullet(
            theme,
            Colors.amber,
            'Stale',
            'Market is expected open but latest update is delayed.',
          ),
          _bullet(
            theme,
            theme.colorScheme.onSurfaceVariant,
            'Closed',
            'Market session is closed and values are from the last available tick.',
          ),
        ],
      ),
    );
  }

  Widget _bullet(ThemeData theme, Color dotColor, String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: theme.textTheme.bodyMedium?.fontSize ?? 14,
                  height: 1.4,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

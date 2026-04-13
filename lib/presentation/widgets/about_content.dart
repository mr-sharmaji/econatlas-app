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
            'About ${AppConstants.appName}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${AppConstants.appName} is your personal market intelligence app for Indian and global markets. Track 2,000+ stocks, 1,700+ mutual funds, commodities, crypto, currencies, and macro data \u2014 with AI-powered analysis and smart notifications.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _section(theme, 'Core Features'),
          const SizedBox(height: 6),
          _bullet(theme, theme.colorScheme.primary, 'Overview',
              'Market sentiment, volatility pulse, FII/DII institutional flows, top movers, and IPO tracker.'),
          _bullet(theme, theme.colorScheme.primary, 'Market',
              'Live indices (Nifty 50, Sensex, S&P 500, NASDAQ, etc.), 20+ commodities, 10+ crypto, 35+ currencies, and bond yields with interactive charts.'),
          _bullet(theme, theme.colorScheme.primary, 'Watchlist',
              'Star any stock, mutual fund, index, or commodity. Dashboard shows your picks with sparklines, sorted by sector or performance.'),
          _bullet(theme, theme.colorScheme.primary, 'Discover',
              'Screener for 2,000+ Indian stocks (90+ metrics) and 1,700+ mutual funds. Compare, filter by sector/score/returns, and read AI verdicts.'),
          _bullet(theme, theme.colorScheme.primary, 'Economy',
              'Macro indicators (GDP, inflation, repo rate, trade balance, forex reserves) for India, US, Europe, and Japan.'),
          _bullet(theme, theme.colorScheme.primary, 'Artha AI',
              'Ask anything about markets in English or Hindi. Artha reads your watchlist, queries live data, compares stocks, and gives actionable insights.'),
          const SizedBox(height: 16),
          _section(theme, 'Smart Features'),
          const SizedBox(height: 6),
          _bullet(theme, theme.colorScheme.tertiary, 'Notifications',
              'Market open/close alerts, Gift Nifty pre-market signals, commodity spike alerts, FII/DII activity updates.'),
          _bullet(theme, theme.colorScheme.tertiary, 'Home Widget',
              'Live prices on your home screen with Markets, Stocks, and Funds tabs. Refreshes every 2 minutes.'),
          _bullet(theme, theme.colorScheme.tertiary, 'AI Verdicts',
              'Every asset gets a Bullish/Bearish/Neutral tag with reasoning based on trend, momentum, and volatility scores.'),
          _bullet(theme, theme.colorScheme.tertiary, 'Quick Tools',
              'Trade charges calculator, income tax hub, and currency converter \u2014 always one tap away.'),
          const SizedBox(height: 16),
          _section(theme, 'Data Coverage'),
          const SizedBox(height: 6),
          _bullet(theme, theme.colorScheme.secondary, 'Stocks',
              '2,000+ NSE-listed stocks with fundamentals, technicals, shareholding, financials, and peer comparison.'),
          _bullet(theme, theme.colorScheme.secondary, 'Mutual Funds',
              '1,700+ direct-plan growth funds with expense ratios, holdings, sector allocation, risk levels, and category rankings.'),
          _bullet(theme, theme.colorScheme.secondary, 'Commodities',
              'Gold, silver, crude oil, natural gas, copper, and 15+ more with true 24H rolling prices from futures markets.'),
          _bullet(theme, theme.colorScheme.secondary, 'Global',
              'S&P 500, NASDAQ, Dow Jones, FTSE, DAX, Nikkei, TOPIX, and sector ETFs with intraday charts.'),
          const SizedBox(height: 16),
          _section(theme, 'Status Indicators'),
          const SizedBox(height: 6),
          _bullet(theme, AppTheme.accentGreen, 'Live',
              'Market is active and prices are updating in real time.'),
          _bullet(theme, Colors.amber, 'Stale',
              'Market is expected open but the latest update is delayed.'),
          _bullet(theme, theme.colorScheme.onSurfaceVariant, 'Closed',
              'Market session is closed. Values are from the last available tick.'),
        ],
      ),
    );
  }

  Widget _section(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
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

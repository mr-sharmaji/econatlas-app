import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'data/models/market_price.dart';
import 'data/models/macro_indicator.dart';
import 'presentation/screens/shell_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/market/market_screen.dart';
import 'presentation/screens/commodities/commodities_screen.dart';
import 'presentation/screens/overview/overview_screen.dart';
import 'presentation/screens/macro/macro_screen.dart';
import 'data/models/discover.dart';
import 'presentation/screens/discover/discover_home_screen.dart';
import 'presentation/screens/discover/stock_screener_screen.dart';
import 'presentation/screens/discover/mf_screener_screen.dart';
import 'presentation/screens/discover/stock_detail_screen.dart';
import 'presentation/screens/discover/mf_detail_screen.dart';
import 'presentation/screens/discover/compare_screen.dart';
import 'presentation/screens/tools/currency_converter_screen.dart';
import 'presentation/screens/tools/income_tax_screen.dart';
import 'presentation/screens/tools/trade_charges_screen.dart';
import 'presentation/screens/tools/capital_gains_screen.dart';
import 'presentation/screens/tools/advance_tax_screen.dart';
import 'presentation/screens/tools/tds_screen.dart';
import 'presentation/screens/tools/tax_hub_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/settings/developer_options_screen.dart';
import 'presentation/screens/about_screen.dart';
import 'presentation/screens/watchlist/watchlist_screen.dart';
import 'presentation/widgets/first_launch_welcome.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return FirstLaunchWelcome(
          child: ShellScreen(navigationShell: navigationShell),
        );
      },
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/overview',
            builder: (context, state) => const OverviewScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/market',
            builder: (context, state) => const MarketScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/discover',
            builder: (context, state) => const DiscoverHomeScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/macro',
            builder: (context, state) => const MacroScreen(),
          ),
        ]),
      ],
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/market/detail/:asset',
      builder: (context, state) {
        final asset = Uri.decodeComponent(state.pathParameters['asset']!);
        final price = state.extra as MarketPrice?;
        return MarketDetailScreen(asset: asset, initialPrice: price);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/commodities/detail/:asset',
      builder: (context, state) {
        final asset = Uri.decodeComponent(state.pathParameters['asset']!);
        final price = state.extra as MarketPrice?;
        return CommodityDetailScreen(asset: asset, initialPrice: price);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/macro/detail/:country/:indicator',
      builder: (context, state) {
        final indicatorName = state.pathParameters['indicator']!;
        final country = state.pathParameters['country'];
        final indicator = state.extra as MacroIndicator?;
        return MacroDetailScreen(
          indicatorName: indicatorName,
          countryOverride: country,
          initialIndicator: indicator,
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/macro/detail/:indicator',
      builder: (context, state) {
        final indicatorName = state.pathParameters['indicator']!;
        final indicator = state.extra as MacroIndicator?;
        return MacroDetailScreen(
          indicatorName: indicatorName,
          initialIndicator: indicator,
        );
      },
    ),
    // ── Discover sub-routes ──
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/discover/stocks',
      builder: (context, state) {
        final initialSearch = state.extra as String?;
        return StockScreenerScreen(initialSearch: initialSearch);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/discover/mutual-funds',
      builder: (context, state) {
        final initialSearch = state.extra as String?;
        return MfScreenerScreen(initialSearch: initialSearch);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/discover/stock/:symbol',
      builder: (context, state) {
        final item = state.extra as DiscoverStockItem;
        return StockDetailScreen(item: item);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/discover/mf/:schemeCode',
      builder: (context, state) {
        final item = state.extra as DiscoverMutualFundItem;
        return MfDetailScreen(item: item);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/discover/compare',
      builder: (context, state) => const CompareScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/settings/developer',
      builder: (context, state) => const DeveloperOptionsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/about',
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/watchlist',
      builder: (context, state) => const WatchlistScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tools/converter',
      builder: (context, state) => const CurrencyConverterScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tools/tax',
      builder: (context, state) => const TaxHubScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tools/tax/income',
      builder: (context, state) => const IncomeTaxScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tools/tax/capital-gains',
      builder: (context, state) => const CapitalGainsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tools/tax/advance-tax',
      builder: (context, state) => const AdvanceTaxScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tools/tax/tds',
      builder: (context, state) => const TdsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tools/trade-charges',
      builder: (context, state) => const TradeChargesScreen(),
    ),
  ],
);

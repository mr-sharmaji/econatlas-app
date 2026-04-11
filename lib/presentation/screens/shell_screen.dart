import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/connectivity.dart';
import '../../core/constants.dart';
import '../providers/providers.dart';
import '../widgets/offline_banner.dart';

class ShellScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const ShellScreen({super.key, required this.navigationShell});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _quickExpanded = false;
  DateTime? _lastDiscoverRefreshAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ref.read(dashboardHomeWidgetServiceProvider).publish());
    _refreshTimer = Timer.periodic(AppConstants.marketRefreshInterval, (_) {
      if (!mounted || _lifecycleState != AppLifecycleState.resumed) return;
      unawaited(_refreshAllData());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAllData());
    }
  }

  Future<void> _refreshAllData() async {
    if (await isOffline()) return;
    final now = DateTime.now();
    ref.invalidate(marketStatusProvider);
    ref.invalidate(latestMarketPricesProvider);
    ref.invalidate(latestCryptoProvider);
    ref.invalidate(latestIndicesProvider);
    ref.invalidate(latestCurrenciesProvider);
    ref.invalidate(latestCommoditiesProvider);
    ref.invalidate(latestBondsProvider);
    ref.invalidate(marketIntradayProvider);
    ref.invalidate(commodityIntradayProvider);
    ref.invalidate(allMacroIndicatorsProvider);
    ref.invalidate(macroRegimeProvider);
    ref.invalidate(macroSummaryProvider);
    ref.invalidate(macroMetadataProvider);
    ref.invalidate(econCalendarWithHistoryProvider);
    ref.invalidate(economicEventsProvider);
    ref.invalidate(institutionalFlowsOverviewProvider);
    ref.invalidate(newsProvider);
    final shouldRefreshDiscover = _lastDiscoverRefreshAt == null ||
        now.difference(_lastDiscoverRefreshAt!) >= const Duration(hours: 1);
    if (shouldRefreshDiscover) {
      _lastDiscoverRefreshAt = now;
      ref.invalidate(discoverOverviewProvider(DiscoverSegment.stocks));
      ref.invalidate(discoverOverviewProvider(DiscoverSegment.mutualFunds));
      ref.invalidate(discoverStocksProvider);
      ref.invalidate(discoverMutualFundsProvider);
      ref.invalidate(discoverHomeDataProvider);
    }
    // Brief data (used by discover home)
    final briefMarket = ref.read(briefMarketProvider);
    ref.invalidate(briefPostMarketProvider(briefMarket));
    ref.invalidate(briefTopGainersProvider(briefMarket));
    ref.invalidate(briefTopLosersProvider(briefMarket));
    ref.invalidate(briefSectorPulseProvider(briefMarket));
    ref.invalidate(ipoListProvider('open'));
    ref.invalidate(ipoListProvider('upcoming'));
    ref.invalidate(ipoListProvider('closed'));
    ref.invalidate(ipoAlertsProvider);
    unawaited(ref.read(dashboardHomeWidgetServiceProvider).publish());
  }

  void _openTool(String route) {
    setState(() => _quickExpanded = false);
    context.push(route);
  }

  Widget _quickToolsFab(BuildContext context) {
    final theme = Theme.of(context);
    final actions = [
      (
        label: 'Trade Charges',
        icon: Icons.receipt_long_rounded,
        route: '/tools/trade-charges'
      ),
      (
        label: 'Tax Hub',
        icon: Icons.account_balance_wallet_outlined,
        route: '/tools/tax'
      ),
      (
        label: 'Currency Converter',
        icon: Icons.currency_exchange_rounded,
        route: '/tools/converter'
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_quickExpanded)
          ...actions.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      a.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    heroTag: 'quick-${a.route}',
                    onPressed: () => _openTool(a.route),
                    child: Icon(a.icon),
                  ),
                ],
              ),
            ),
          ),
        FloatingActionButton(
          heroTag: 'quick-main',
          onPressed: () => setState(() => _quickExpanded = !_quickExpanded),
          child: Icon(_quickExpanded ? Icons.close : Icons.flash_on_rounded),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: widget.navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) {
          setState(() => _quickExpanded = false);
          if (index == widget.navigationShell.currentIndex) {
            final current = ref.read(bottomTabReselectProvider);
            if (index >= 0 && index < current.length) {
              final next = [...current];
              next[index] = next[index] + 1;
              ref.read(bottomTabReselectProvider.notifier).state = next;
            }
            unawaited(_refreshAllData());
            return;
          }
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.query_stats_outlined),
            selectedIcon: Icon(Icons.query_stats),
            label: 'Market',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'Watchlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.summarize_outlined),
            selectedIcon: Icon(Icons.summarize),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Economy',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Artha',
          ),
        ],
      ),
      floatingActionButton: widget.navigationShell.currentIndex == 5
          ? null
          : _quickToolsFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

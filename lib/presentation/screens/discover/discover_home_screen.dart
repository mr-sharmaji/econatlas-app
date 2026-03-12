import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_utils.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/discover.dart';
import '../../providers/discover_providers.dart';
import 'widgets/mf_list_tile.dart';
import 'widgets/stock_list_tile.dart';

class DiscoverHomeScreen extends ConsumerStatefulWidget {
  const DiscoverHomeScreen({super.key});

  @override
  ConsumerState<DiscoverHomeScreen> createState() =>
      _DiscoverHomeScreenState();
}

class _DiscoverHomeScreenState extends ConsumerState<DiscoverHomeScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    final isSearchActive = _searchQuery.length >= 2;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Discover'),
          actions: [
            IconButton(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            if (isSearchActive) _clearSearch();
          },
          behavior: HitTestBehavior.translucent,
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: _buildSearchBar(),
              ),
              const SizedBox(height: 8),

              // Quick nav: All Stocks / All MFs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickNavChip(
                        icon: Icons.bar_chart_rounded,
                        label: 'All Stocks',
                        onTap: () => context.push('/discover/stocks'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickNavChip(
                        icon: Icons.account_balance_rounded,
                        label: 'All Mutual Funds',
                        onTap: () =>
                            context.push('/discover/mutual-funds'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Tab bar
              const TabBar(
                tabs: [
                  Tab(text: 'Stocks'),
                  Tab(text: 'Mutual Funds'),
                ],
              ),

              // Tab views
              Expanded(
                child: Stack(
                  children: [
                    TabBarView(
                      children: [
                        _StocksTab(),
                        _MutualFundsTab(),
                      ],
                    ),
                    if (isSearchActive) _buildSearchOverlay(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search bar
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search stocks or mutual funds...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _clearSearch,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppTheme.accentBlue.withValues(alpha: 0.40)),
        ),
        filled: true,
        fillColor:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      textInputAction: TextInputAction.search,
    );
  }

  // ---------------------------------------------------------------------------
  // Search overlay
  // ---------------------------------------------------------------------------

  Widget _buildSearchOverlay() {
    final searchAsync = ref.watch(discoverSearchProvider(_searchQuery));
    final theme = Theme.of(context);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: _clearSearch,
        child: Container(
          color: Colors.black54,
          child: Align(
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () {}, // absorb tap so card doesn't dismiss
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: searchAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      friendlyErrorMessage(err),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  data: (result) {
                    final hasStocks = result.stocks.isNotEmpty;
                    final hasMf = result.mutualFunds.isNotEmpty;

                    if (!hasStocks && !hasMf) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No results found',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: Colors.white54),
                          ),
                        ),
                      );
                    }

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          if (hasStocks) ...[
                            _searchSectionHeader('Stocks'),
                            ...result.stocks.map(_buildStockSearchTile),
                          ],
                          if (hasMf) ...[
                            if (hasStocks) const Divider(height: 1),
                            _searchSectionHeader('Mutual Funds'),
                            ...result.mutualFunds.map(_buildMfSearchTile),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }

  Widget _buildStockSearchTile(SearchStockResult item) {
    final theme = Theme.of(context);
    final changeColor = (item.percentChange ?? 0) >= 0
        ? AppTheme.accentGreen
        : AppTheme.accentRed;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(
        item.symbol,
        style:
            theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        item.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Formatters.price(item.lastPrice),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            Formatters.changeTag(item.percentChange),
            style: theme.textTheme.labelSmall?.copyWith(
              color: changeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      onTap: () {
        _clearSearch();
        FocusScope.of(context).unfocus();
        context.push('/discover/stock/${item.symbol}', extra: item);
      },
    );
  }

  Widget _buildMfSearchTile(SearchMfResult item) {
    final theme = Theme.of(context);

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(
        item.schemeName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        item.category ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
      ),
      trailing: Text(
        'NAV ${Formatters.price(item.nav)}',
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
      ),
      onTap: () {
        _clearSearch();
        FocusScope.of(context).unfocus();
        context.push('/discover/mf/${item.schemeCode}', extra: item);
      },
    );
  }
}

// =============================================================================
// Stocks Tab
// =============================================================================

class _StocksTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stocksAsync = ref.watch(homeTopStocksProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(homeTopStocksProvider);
      },
      child: stocksAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (err, _) => ListView(
          children: [
            const SizedBox(height: 80),
            Center(
              child: Text(
                friendlyErrorMessage(err),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        data: (response) {
          final items = response.items;
          if (items.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Text(
                    'No stocks available',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white54),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: items.length + 1, // +1 for "View All" button
            itemBuilder: (context, index) {
              if (index == items.length) {
                return _ViewAllButton(
                  label: 'View All Stocks',
                  onTap: () => context.push('/discover/stocks'),
                );
              }
              final item = items[index];
              return StockListTile(
                item: item,
                onTap: () => context.push(
                  '/discover/stock/${item.symbol}',
                  extra: item,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =============================================================================
// Mutual Funds Tab
// =============================================================================

class _MutualFundsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mfAsync = ref.watch(homeTopMutualFundsProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(homeTopMutualFundsProvider);
      },
      child: mfAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (err, _) => ListView(
          children: [
            const SizedBox(height: 80),
            Center(
              child: Text(
                friendlyErrorMessage(err),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        data: (response) {
          final items = response.items;
          if (items.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Text(
                    'No mutual funds available',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white54),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: items.length + 1, // +1 for "View All" button
            itemBuilder: (context, index) {
              if (index == items.length) {
                return _ViewAllButton(
                  label: 'View All Mutual Funds',
                  onTap: () => context.push('/discover/mutual-funds'),
                );
              }
              final item = items[index];
              return MfListTile(
                item: item,
                onTap: () => context.push(
                  '/discover/mf/${item.schemeCode}',
                  extra: item,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =============================================================================
// "View All" button
// =============================================================================

class _ViewAllButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ViewAllButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: TextButton(
          onPressed: onTap,
          child: Text(
            '$label \u2192',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.accentBlue,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Quick nav chip (top shortcuts)
// =============================================================================

class _QuickNavChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickNavChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppTheme.accentBlue),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_utils.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/discover.dart';
import '../../../data/services/recently_viewed_service.dart';
import '../../providers/discover_providers.dart';
import '../../providers/tab_navigation_providers.dart';
import '../../widgets/shimmer_loading.dart';
import 'widgets/sparkline_widget.dart';

/// Bottom padding to clear the FAB.
const double _kBottomPadding = 112;

class DiscoverHomeScreen extends ConsumerStatefulWidget {
  const DiscoverHomeScreen({super.key});

  @override
  ConsumerState<DiscoverHomeScreen> createState() =>
      _DiscoverHomeScreenState();
}

class _DiscoverHomeScreenState extends ConsumerState<DiscoverHomeScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  String _searchQuery = '';
  late final TabController _tabController;

  // LayerLink for anchoring the search overlay to the search bar.
  final LayerLink _searchLayerLink = LayerLink();
  final GlobalKey _searchBarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
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

  void _onStockTap(DiscoverHomeStockItem item) {
    ref
        .read(recentlyViewedProvider.notifier)
        .add(type: 'stock', id: item.symbol, name: item.displayName);
    context.push('/discover/stock/${item.symbol}');
  }

  void _onMfTap(DiscoverHomeMfItem item) {
    ref.read(recentlyViewedProvider.notifier).add(
          type: 'mf',
          id: item.schemeCode,
          name: item.displayName ?? item.schemeName,
        );
    context.push('/discover/mf/${item.schemeCode}', extra: item);
  }

  void _onRecentTap(RecentlyViewedItem item) {
    if (item.type == 'stock') {
      context.push('/discover/stock/${item.id}');
    } else {
      context.push('/discover/mf/${item.id}');
    }
  }

  void _onQuickCategoryTap(QuickCategory cat) {
    if (cat.segment == 'mutual_funds') {
      context.push('/discover/mutual-funds', extra: {
        if (cat.preset != null) 'preset': cat.preset,
        if (cat.filterKey != null && cat.filterValue != null)
          cat.filterKey!: cat.filterValue,
      });
    } else {
      context.push('/discover/stocks', extra: {
        if (cat.preset != null) 'preset': cat.preset,
        if (cat.filterKey != null && cat.filterValue != null)
          cat.filterKey!: cat.filterValue,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Discover tab is index 3 in bottom nav
    ref.listen<int>(bottomTabReselectTickProvider(3), (prev, next) {
      if (prev == null || prev == next) return;
      _scrollToTop();
    });

    final isSearchActive = _searchQuery.length >= 2;
    final homeAsync = ref.watch(discoverHomeDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentBlue,
          labelColor: AppTheme.accentBlue,
          unselectedLabelColor: Colors.white54,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Stocks'),
            Tab(text: 'Mutual Funds'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar — always above dim overlay
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: CompositedTransformTarget(
              link: _searchLayerLink,
              child: _buildSearchBar(),
            ),
          ),
          const SizedBox(height: 8),
          // Feed + overlays
          Expanded(
            child: Stack(
              children: [
                homeAsync.when(
                  loading: () => const ShimmerDiscoverHome(),
                  error: (err, _) => ListView(
                    children: [
                      const SizedBox(height: 80),
                      const Icon(Icons.cloud_off_rounded,
                          size: 48, color: Colors.white24),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          friendlyErrorMessage(err),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              ref.invalidate(discoverHomeDataProvider),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                  ),
                  data: (data) => TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStocksTab(data),
                      _buildMfTab(data),
                    ],
                  ),
                ),
                // Dim overlay when search results are visible
                if (isSearchActive)
                  GestureDetector(
                    onTap: _clearSearch,
                    child:
                        Container(color: Colors.black.withValues(alpha: 0.60)),
                  ),
                if (isSearchActive) _buildSearchOverlay(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stocks Tab
  // ---------------------------------------------------------------------------

  Widget _buildStocksTab(DiscoverHomeData data) {
    final recentlyViewed = ref.watch(recentlyViewedProvider);
    final recentStocks =
        recentlyViewed.where((r) => r.type == 'stock').toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(discoverHomeDataProvider);
        await ref.read(discoverHomeDataProvider.future);
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 4),
        children: [
          // Quick categories (stocks only)
          _buildQuickCategories(
            data.quickCategories
                .where((c) => c.segment == 'stocks')
                .toList(),
          ),
          const SizedBox(height: 12),

          // Recently viewed stocks
          if (recentStocks.isNotEmpty) ...[
            _buildRecentlyViewed(recentStocks),
            const SizedBox(height: 8),
          ],

          // Signal & theme sections
          for (final section in data.stockSections)
            _StockSectionWidget(
              section: section,
              onStockTap: _onStockTap,
            ),

          const SizedBox(height: _kBottomPadding),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MF Tab
  // ---------------------------------------------------------------------------

  Widget _buildMfTab(DiscoverHomeData data) {
    final recentlyViewed = ref.watch(recentlyViewedProvider);
    final recentMfs = recentlyViewed.where((r) => r.type == 'mf').toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(discoverHomeDataProvider);
        await ref.read(discoverHomeDataProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.only(top: 4),
        children: [
          // Quick categories (MFs only)
          _buildQuickCategories(
            data.quickCategories
                .where((c) => c.segment == 'mutual_funds')
                .toList(),
          ),
          const SizedBox(height: 12),

          // Recently viewed MFs
          if (recentMfs.isNotEmpty) ...[
            _buildRecentlyViewed(recentMfs),
            const SizedBox(height: 8),
          ],

          // MF sections
          for (final section in data.mfSections)
            _MfSectionWidget(
              section: section,
              onMfTap: _onMfTap,
            ),

          const SizedBox(height: _kBottomPadding),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recently Viewed (horizontal scroll)
  // ---------------------------------------------------------------------------

  Widget _buildRecentlyViewed(List<RecentlyViewedItem> items) {
    final recentStockSymbols = items
        .where((r) => r.type == 'stock')
        .map((r) => r.id)
        .toList();
    final recentMfCodes = items
        .where((r) => r.type == 'mf')
        .map((r) => r.id)
        .toList();
    final recentStockSparklines = recentStockSymbols.isNotEmpty
        ? ref.watch(discoverStockSparklinesProvider(
            (symbols: recentStockSymbols, days: 7)))
        : null;
    final recentMfSparklines = recentMfCodes.isNotEmpty
        ? ref.watch(discoverMfSparklinesProvider(
            (schemeCodes: recentMfCodes, days: 7)))
        : null;
    final recentStockSparkMap = recentStockSparklines?.valueOrNull ?? {};
    final recentMfSparkMap = recentMfSparklines?.valueOrNull ?? {};

    return _HorizontalSection(
      title: 'Recently Viewed',
      children: items
          .map((item) => _RecentCard(
                item: item,
                onTap: () => _onRecentTap(item),
                sparklineValues: (item.type == 'stock'
                        ? recentStockSparkMap[item.id]
                        : recentMfSparkMap[item.id])
                    ?.map((p) => p.value)
                    .toList(),
              ))
          .toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Quick category chips
  // ---------------------------------------------------------------------------

  Widget _buildQuickCategories(List<QuickCategory> apiCategories) {
    final gridItems = <({String label, IconData icon, VoidCallback onTap})>[
      ...apiCategories.take(8).map((cat) => (
            label: cat.name,
            icon: _quickCategoryIcon(cat) ?? Icons.label_outline,
            onTap: () => _onQuickCategoryTap(cat),
          )),
    ];

    if (gridItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: gridItems.map((item) {
          return _CategoryChip(
            label: item.label,
            icon: item.icon,
            onTap: item.onTap,
          );
        }).toList(),
      ),
    );
  }

  static IconData? _quickCategoryIcon(QuickCategory cat) {
    switch (cat.preset) {
      case 'momentum':
        return Icons.speed;
      case 'value':
      case 'value-mf':
        return Icons.diamond_outlined;
      case 'quality':
        return Icons.verified_outlined;
      case 'dividend':
        return Icons.payments_outlined;
      case 'equity':
        return Icons.show_chart;
      case 'debt':
        return Icons.savings_outlined;
      case 'large-cap':
        return Icons.business;
      case 'small-cap':
        return Icons.store;
      case 'elss':
        return Icons.receipt_long_outlined;
      case 'flexi-cap':
        return Icons.swap_vert_rounded;
      case 'low-risk':
        return Icons.shield_outlined;
      case 'index':
        return Icons.pie_chart_outline;
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Search bar
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final isActive = _searchQuery.length >= 2;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF162A3E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AppTheme.accentBlue
              : Colors.white.withValues(alpha: 0.12),
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: TextField(
        key: _searchBarKey,
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
        cursorColor: AppTheme.accentBlue,
        decoration: InputDecoration(
          hintText: 'Search stocks & mutual funds...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isActive
                ? AppTheme.accentBlue
                : Colors.white.withValues(alpha: 0.50),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        textInputAction: TextInputAction.search,
      ),
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
        onTap: () {
          _clearSearch();
          FocusScope.of(context).unfocus();
        },
        child: Container(
          color: Colors.black54,
          child: CompositedTransformFollower(
            link: _searchLayerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: const Offset(0, 4),
            child: Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () {}, // absorb tap so card doesn't dismiss
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.55,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color:
                                AppTheme.accentBlue.withValues(alpha: 0.20)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: searchAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)),
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              children: [
                                if (hasStocks) ...[
                                  _searchSectionHeader('Stocks'),
                                  ...result.stocks
                                      .map(_buildStockSearchTile),
                                ],
                                if (hasMf) ...[
                                  if (hasStocks) const Divider(height: 1),
                                  _searchSectionHeader('Mutual Funds'),
                                  ...result.mutualFunds
                                      .map(_buildMfSearchTile),
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
        ref
            .read(recentlyViewedProvider.notifier)
            .add(type: 'stock', id: item.symbol, name: item.displayName);
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
        ref.read(recentlyViewedProvider.notifier).add(
              type: 'mf',
              id: item.schemeCode,
              name: item.schemeName,
            );
        context.push('/discover/mf/${item.schemeCode}', extra: item);
      },
    );
  }
}

// =============================================================================
// Stock Section — vertical list of stock tiles
// =============================================================================

class _StockSectionWidget extends StatelessWidget {
  final DiscoverHomeSection<DiscoverHomeStockItem> section;
  final void Function(DiscoverHomeStockItem) onStockTap;

  const _StockSectionWidget({
    required this.section,
    required this.onStockTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              section.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Text(
              section.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ),
          // Stock tiles
          ...section.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _HomeStockTile(
                  item: item,
                  onTap: () => onStockTap(item),
                ),
              )),
        ],
      ),
    );
  }
}

// =============================================================================
// MF Section — vertical list of MF tiles
// =============================================================================

class _MfSectionWidget extends StatelessWidget {
  final DiscoverHomeSection<DiscoverHomeMfItem> section;
  final void Function(DiscoverHomeMfItem) onMfTap;

  const _MfSectionWidget({
    required this.section,
    required this.onMfTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              section.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Text(
              section.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ),
          ...section.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _HomeMfTile(
                  item: item,
                  onTap: () => onMfTap(item),
                ),
              )),
        ],
      ),
    );
  }
}

// =============================================================================
// Home Stock Tile — compact list tile for DiscoverHomeStockItem
// =============================================================================

class _HomeStockTile extends StatelessWidget {
  final DiscoverHomeStockItem item;
  final VoidCallback onTap;

  const _HomeStockTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = item.percentChange3m ?? item.percentChange;
    final isPositive = (change ?? 0) >= 0;
    final changeColor = isPositive ? AppTheme.accentGreen : AppTheme.accentRed;
    final changeLabel = item.percentChange3m != null ? '3M ' : '';
    final scoreColor = item.score >= 70
        ? AppTheme.accentGreen
        : item.score >= 40
            ? AppTheme.accentOrange
            : AppTheme.accentRed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: name + price
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Formatters.fullPrice(item.lastPrice),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: symbol · sector/industry  |  change badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.symbol}${item.sector != null ? ' \u00b7 ${item.industry ?? item.sector}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white54),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: changeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$changeLabel${Formatters.changeTag(change)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: changeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 3: score circle + action tag
            Row(
              children: [
                // Circular score
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scoreColor.withValues(alpha: 0.12),
                    border: Border.all(
                        color: scoreColor.withValues(alpha: 0.4), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.score.toInt().toString(),
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (item.actionTag != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _actionTagColor(item.actionTag!)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.actionTag!,
                      style: TextStyle(
                        color: _actionTagColor(item.actionTag!),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Market cap
                if (item.marketCap != null)
                  Text(
                    _formatMarketCap(item.marketCap!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _actionTagColor(String tag) {
    final lower = tag.toLowerCase();
    if (lower.contains('buy') || lower.contains('accumulate')) {
      return AppTheme.accentGreen;
    }
    if (lower.contains('sell') || lower.contains('reduce')) {
      return AppTheme.accentRed;
    }
    if (lower.contains('hold') || lower.contains('watch')) {
      return AppTheme.accentOrange;
    }
    return AppTheme.accentBlue;
  }

  static String _formatMarketCap(double crores) {
    if (crores >= 1e5) {
      return '\u20B9${(crores / 1e5).toStringAsFixed(1)} L Cr';
    }
    if (crores >= 1e3) {
      return '\u20B9${(crores / 1e3).toStringAsFixed(1)}K Cr';
    }
    return '\u20B9${crores.toStringAsFixed(0)} Cr';
  }
}

// =============================================================================
// Home MF Tile — compact list tile for DiscoverHomeMfItem
// =============================================================================

class _HomeMfTile extends StatelessWidget {
  final DiscoverHomeMfItem item;
  final VoidCallback onTap;

  const _HomeMfTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ret1y = item.returns1y;
    final retPositive = (ret1y ?? 0) >= 0;
    final retColor = retPositive ? AppTheme.accentGreen : AppTheme.accentRed;
    final scoreColor = (item.score) >= 70
        ? AppTheme.accentGreen
        : (item.score) >= 40
            ? AppTheme.accentOrange
            : AppTheme.accentRed;
    final firstBadge =
        item.qualityBadges.isNotEmpty ? item.qualityBadges.first : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: name + 1Y return
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.displayName ?? item.schemeName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (ret1y != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: retColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${ret1y >= 0 ? '+' : ''}${ret1y.toStringAsFixed(1)}% 1Y',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: retColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: category
            if (item.category != null)
              Text(
                item.category!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white54),
              ),
            const SizedBox(height: 8),
            // Row 3: score + badge
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scoreColor.withValues(alpha: 0.12),
                    border: Border.all(
                        color: scoreColor.withValues(alpha: 0.4), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.score.toInt().toString(),
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (firstBadge != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      firstBadge,
                      style: const TextStyle(
                        color: AppTheme.accentTeal,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

// =============================================================================
// Quick category chip
// =============================================================================

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppTheme.accentBlue),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Horizontal Section — for recently viewed
// =============================================================================

class _HorizontalSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _HorizontalSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: children.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => children[i],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Recently Viewed Card
// =============================================================================

class _RecentCard extends StatelessWidget {
  final RecentlyViewedItem item;
  final VoidCallback onTap;
  final List<double>? sparklineValues;

  const _RecentCard(
      {required this.item, required this.onTap, this.sparklineValues});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStock = item.type == 'stock';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isStock ? AppTheme.accentBlue : AppTheme.accentOrange)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isStock ? 'Stock' : 'MF',
                style: TextStyle(
                  color:
                      isStock ? AppTheme.accentBlue : AppTheme.accentOrange,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isStock ? item.id : item.name,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: isStock ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (isStock)
              Text(
                item.name,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white54,
                  fontSize: 10,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const Spacer(),
            if (sparklineValues != null && sparklineValues!.length >= 2)
              SparklineWidget(
                values: sparklineValues!,
                color: (sparklineValues!.last >= sparklineValues!.first)
                    ? AppTheme.accentGreen
                    : AppTheme.accentRed,
                height: 24,
              )
            else
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 10,
                color: Colors.white.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }
}

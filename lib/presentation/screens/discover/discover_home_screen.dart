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
import '../../widgets/shimmer_loading.dart';
import 'widgets/score_bar.dart';
import 'widgets/sparkline_widget.dart';

/// Bottom padding to clear the FAB.
const double _kBottomPadding = 112;

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

  // LayerLink for anchoring the search overlay to the search bar.
  final LayerLink _searchLayerLink = LayerLink();
  final GlobalKey _searchBarKey = GlobalKey();

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

  void _onStockTap(DiscoverHomeStockItem item, {int? initialDays}) {
    ref
        .read(recentlyViewedProvider.notifier)
        .add(type: 'stock', id: item.symbol, name: item.displayName);
    final Map<String, dynamic>? extra =
        initialDays != null ? {'initialDays': initialDays} : null;
    context.push('/discover/stock/${item.symbol}', extra: extra);
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

  void _onSectorChampionTap(DiscoverHomeStockItem item) {
    context.push('/discover/stocks', extra: {
      'preset': 'quality',
      if (item.sector != null) 'sector': item.sector,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSearchActive = _searchQuery.length >= 2;
    final homeAsync = ref.watch(discoverHomeDataProvider);
    final recentlyViewed = ref.watch(recentlyViewedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar — always above dim overlay
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: CompositedTransformTarget(
              link: _searchLayerLink,
              child: _buildSearchBar(),
            ),
          ),
          const SizedBox(height: 10),
          // Feed + overlays
          Expanded(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(discoverHomeDataProvider);
                    ref.invalidate(
                        discoverOverviewProvider(DiscoverSegment.stocks));
                  },
                  child: homeAsync.when(
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
                    data: (data) => _buildFeed(data, recentlyViewed),
                  ),
                ),
                // Dim overlay when search results are visible
                if (isSearchActive)
                  GestureDetector(
                    onTap: _clearSearch,
                    child: Container(color: Colors.black.withValues(alpha: 0.60)),
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
  // Main Feed
  // ---------------------------------------------------------------------------

  Widget _buildFeed(DiscoverHomeData data, List<RecentlyViewedItem> recent) {
    return CustomScrollView(
      slivers: [
        // Market Mood Card (replaces Market Pulse — same data, richer display)
        if (data.marketMood != null)
          SliverToBoxAdapter(
            child: _MarketMoodCard(mood: data.marketMood!),
          ),
        if (data.marketMood != null)
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Quick category chips
        SliverToBoxAdapter(
          child: _buildQuickCategories(data.quickCategories),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Recently Viewed
        if (recent.isNotEmpty)
          SliverToBoxAdapter(
            child: Builder(builder: (_) {
              final recentStockSymbols = recent
                  .where((r) => r.type == 'stock')
                  .map((r) => r.id)
                  .toList();
              final recentMfCodes = recent
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
              final recentStockSparkMap =
                  recentStockSparklines?.valueOrNull ?? {};
              final recentMfSparkMap =
                  recentMfSparklines?.valueOrNull ?? {};
              return _HorizontalSection(
                title: 'Recently Viewed',
                children: recent
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
            }),
          ),

        // Highest Quality Stocks (renamed from "Top Rated Stocks")
        if (data.topStocks.isNotEmpty)
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Highest Quality Stocks',
              seeAllRoute: '/discover/stocks',
              seeAllExtra: const {'preset': 'quality'},
              cardWidth: 160,
              children: data.topStocks
                  .map((s) => _StockCard(
                        item: s,
                        onTap: () => _onStockTap(s),
                        use3mChange: true,
                        showQualityTier: true,
                      ))
                  .toList(),
            ),
          ),

        // Trending This Week (MOVED UP)
        if (data.trendingThisWeek.isNotEmpty)
          SliverToBoxAdapter(
            child: Builder(builder: (_) {
              final trendingSymbols =
                  data.trendingThisWeek.map((s) => s.symbol).toList();
              final trendingSparklines = trendingSymbols.isNotEmpty
                  ? ref.watch(discoverStockSparklinesProvider(
                      (symbols: trendingSymbols, days: 7)))
                  : null;
              final trendingSparkMap =
                  trendingSparklines?.valueOrNull ?? {};
              return _HorizontalSection(
                title: 'Trending This Week',
                cardWidth: 160,
                children: data.trendingThisWeek
                    .map((s) => _StockCard(
                          item: s,
                          onTap: () => _onStockTap(s, initialDays: 7),
                          use1wChange: true,
                          sparklineValues: trendingSparkMap[s.symbol]
                              ?.map((p) => p.value)
                              .toList(),
                        ))
                    .toList(),
              );
            }),
          ),

        // Top Equity Funds
        if (data.topEquityFunds.isNotEmpty)
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Top Equity Funds',
              seeAllRoute: '/discover/mutual-funds',
              seeAllExtra: const {'preset': 'equity'},
              cardWidth: 160,
              children: data.topEquityFunds
                  .map((m) => _MfCard(item: m, onTap: () => _onMfTap(m)))
                  .toList(),
            ),
          ),

        // Top Debt Funds
        if (data.topDebtFunds.isNotEmpty)
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Top Debt Funds',
              seeAllRoute: '/discover/mutual-funds',
              seeAllExtra: const {'preset': 'debt'},
              cardWidth: 160,
              children: data.topDebtFunds
                  .map((m) => _MfCard(item: m, onTap: () => _onMfTap(m)))
                  .toList(),
            ),
          ),

        // Sector Champions — 2-column grid (all sectors)
        if (data.sectorChampions.isNotEmpty)
          SliverToBoxAdapter(
            child: _SectorChampionsGrid(
              items: data.sectorChampions,
              onTap: _onSectorChampionTap,
            ),
          ),

        // Bottom padding for FAB
        const SliverToBoxAdapter(child: SizedBox(height: _kBottomPadding)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Quick category chips
  // ---------------------------------------------------------------------------

  Widget _buildQuickCategories(List<QuickCategory> apiCategories) {
    // Fixed quick-access grid of curated categories
    final gridItems = <({String label, IconData icon, VoidCallback onTap})>[
      (
        label: 'All Stocks',
        icon: Icons.bar_chart_rounded,
        onTap: () =>
            context.push('/discover/stocks', extra: const {'preset': 'all'}),
      ),
      (
        label: 'All MFs',
        icon: Icons.account_balance_rounded,
        onTap: () => context.push('/discover/mutual-funds'),
      ),
      ...apiCategories.take(6).map((cat) => (
            label: cat.name,
            icon: _quickCategoryIcon(cat) ?? Icons.label_outline,
            onTap: () => _onQuickCategoryTap(cat),
          )),
    ];

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
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Search bar — highlighted border when search is active
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search overlay — centered below search bar
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
                            color: AppTheme.accentBlue.withValues(alpha: 0.20)),
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
// Market Pulse Card — uses discoverOverviewProvider
// =============================================================================

class _MarketPulseCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync =
        ref.watch(discoverOverviewProvider(DiscoverSegment.stocks));
    final theme = Theme.of(context);

    return overviewAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (overview) {
        final dist = overview.scoreDistribution;
        final avgScore = overview.avgScore;
        if (dist == null || avgScore == null) return const SizedBox.shrink();

        final total = dist.total;
        if (total == 0) return const SizedBox.shrink();

        final scoreColor = ScoreBar.scoreColor(avgScore);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.insights_rounded,
                        size: 16, color: AppTheme.accentBlue),
                    const SizedBox(width: 6),
                    Text(
                      'Market Pulse',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${overview.totalItems} stocks',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Avg score + distribution bar
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          avgScore.toStringAsFixed(0),
                          style: TextStyle(
                            color: scoreColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Avg Quality',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ScoreDistributionBar(dist: dist, total: total),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Top 5 sectors
                if (overview.topSectors.isNotEmpty)
                  _TopSectorsChart(
                      sectors: overview.topSectors.take(5).toList()),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScoreDistributionBar extends StatelessWidget {
  final ScoreDistribution dist;
  final int total;

  const _ScoreDistributionBar({required this.dist, required this.total});

  @override
  Widget build(BuildContext context) {
    final segments = [
      (dist.excellent, AppTheme.accentGreen, 'Excellent'),
      (dist.good, AppTheme.accentTeal, 'Good'),
      (dist.average, AppTheme.accentOrange, 'Average'),
      (dist.poor, AppTheme.accentRed, 'Below Avg'),
    ];

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: segments
                  .where((s) => s.$1 > 0)
                  .map((s) {
                    final fraction = s.$1 / total;
                    return Flexible(
                      flex: (fraction * 1000).round(),
                      child: Container(color: s.$2),
                    );
                  })
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: segments.map((s) {
            return Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: s.$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      '${s.$1}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _TopSectorsChart extends StatelessWidget {
  final List<TopSegmentEntry> sectors;

  const _TopSectorsChart({required this.sectors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Sectors by Quality',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white38,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        ...sectors.map((sector) {
          final fraction = (sector.avgScore / 100).clamp(0.0, 1.0);
          final color = ScoreBar.scoreColor(sector.avgScore);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    sector.name,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(
                    sector.avgScore.toStringAsFixed(0),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// =============================================================================
// Market Mood Card — from /screener/home market_mood field
// =============================================================================

class _MarketMoodCard extends StatelessWidget {
  final MarketMood mood;

  const _MarketMoodCard({required this.mood});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dist = mood.scoreDistribution;
    final total = dist?.total ?? 0;
    if (total == 0 && mood.summary == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mood_rounded,
                    size: 16, color: AppTheme.accentTeal),
                const SizedBox(width: 6),
                Text(
                  'Market Mood',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (mood.avgScore != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: ScoreBar.scoreColor(mood.avgScore!)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Avg ${mood.avgScore!.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: ScoreBar.scoreColor(mood.avgScore!),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (mood.summary != null) ...[
              const SizedBox(height: 8),
              Text(
                mood.summary!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white70, height: 1.4),
              ),
            ],
            if (dist != null && total > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      _moodBar(dist.excellent / total, AppTheme.accentGreen),
                      _moodBar(dist.good / total, AppTheme.accentTeal),
                      _moodBar(dist.average / total, AppTheme.accentOrange),
                      _moodBar(dist.poor / total, AppTheme.accentRed),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _moodLabel('Excellent', dist.excellent, AppTheme.accentGreen),
                  const SizedBox(width: 12),
                  _moodLabel('Good', dist.good, AppTheme.accentTeal),
                  const SizedBox(width: 12),
                  _moodLabel('Average', dist.average, AppTheme.accentOrange),
                  const SizedBox(width: 12),
                  _moodLabel('Poor', dist.poor, AppTheme.accentRed),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _moodBar(double fraction, Color color) {
    if (fraction <= 0) return const SizedBox.shrink();
    return Expanded(
      flex: (fraction * 100).round().clamp(1, 100),
      child: Container(color: color),
    );
  }

  Widget _moodLabel(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
// Horizontal Section — fixed "See All" tap target
// =============================================================================

class _HorizontalSection extends StatelessWidget {
  final String title;
  final String? seeAllRoute;
  final Map<String, String>? seeAllExtra;
  final List<Widget> children;
  final double cardWidth;

  const _HorizontalSection({
    required this.title,
    this.seeAllRoute,
    this.seeAllExtra,
    required this.children,
    this.cardWidth = 160,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (seeAllRoute != null)
                  TextButton(
                    onPressed: () => context.push(
                      seeAllRoute!,
                      extra: seeAllExtra,
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: Text(
                      'See All',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.accentBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Horizontal list
          SizedBox(
            height: 152,
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
// Stock Card
// =============================================================================

class _StockCard extends StatelessWidget {
  final DiscoverHomeStockItem item;
  final VoidCallback onTap;
  final bool use3mChange;
  final bool use1wChange;
  final bool showQualityTier;
  final List<double>? sparklineValues;

  const _StockCard({
    required this.item,
    required this.onTap,
    this.use3mChange = false,
    this.use1wChange = false,
    this.showQualityTier = false,
    this.sparklineValues,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    late final double pct;
    late final String periodLabel;
    if (use1wChange && item.percentChange1w != null) {
      pct = item.percentChange1w!;
      periodLabel = ' 1W';
    } else if (use3mChange && item.percentChange3m != null) {
      pct = item.percentChange3m!;
      periodLabel = ' 3M';
    } else {
      pct = item.percentChange ?? 0;
      periodLabel = '';
    }

    final isUp = pct >= 0;
    final changeColor = isUp ? AppTheme.accentGreen : AppTheme.accentRed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.symbol,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showQualityTier && item.qualityTier != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: _qualityTierColor(item.qualityTier!)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.qualityTier!,
                      style: TextStyle(
                        color: _qualityTierColor(item.qualityTier!),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              item.displayName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white54,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              Formatters.price(item.lastPrice),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: changeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${Formatters.changeTag(pct)}$periodLabel',
                style: TextStyle(
                  color: changeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 6),
            ScoreBar(score: item.score, height: 4, showLabel: false),
            if (sparklineValues != null && sparklineValues!.length >= 2) ...[
              const SizedBox(height: 4),
              SparklineWidget(
                values: sparklineValues!,
                color: (sparklineValues!.last >= sparklineValues!.first)
                    ? AppTheme.accentGreen
                    : AppTheme.accentRed,
                height: 24,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _qualityTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'excellent':
        return AppTheme.accentGreen;
      case 'good':
        return AppTheme.accentTeal;
      case 'average':
        return AppTheme.accentOrange;
      default:
        return AppTheme.accentRed;
    }
  }
}

// =============================================================================
// MF Card
// =============================================================================

class _MfCard extends StatelessWidget {
  final DiscoverHomeMfItem item;
  final VoidCallback onTap;

  const _MfCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ret1y = item.returns1y;
    final hasReturn = ret1y != null;
    final isUp = (ret1y ?? 0) >= 0;
    final returnColor = isUp ? AppTheme.accentGreen : AppTheme.accentRed;
    final firstBadge =
        item.qualityBadges.isNotEmpty ? item.qualityBadges.first : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.displayName ?? item.schemeName,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (item.category != null)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.category!,
                  style: const TextStyle(
                    color: AppTheme.accentBlue,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const Spacer(),
            Row(
              children: [
                if (hasReturn)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: returnColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${isUp ? '+' : ''}${ret1y.toStringAsFixed(1)}% 1Y',
                      style: TextStyle(
                        color: returnColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (firstBadge != null) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.accentTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        firstBadge,
                        style: const TextStyle(
                          color: AppTheme.accentTeal,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            ScoreBar(score: item.score, height: 4, showLabel: false),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Sector Champions — 2-column grid (all sectors)
// =============================================================================

class _SectorChampionsGrid extends StatelessWidget {
  final List<DiscoverHomeStockItem> items;
  final void Function(DiscoverHomeStockItem) onTap;

  const _SectorChampionsGrid({
    required this.items,
    required this.onTap,
  });

  static IconData _sectorIcon(String? sector) {
    switch (sector?.toLowerCase()) {
      case 'energy':
      case 'oil & gas':
        return Icons.bolt_rounded;
      case 'information technology':
      case 'it':
        return Icons.computer_rounded;
      case 'financial services':
      case 'financials':
        return Icons.account_balance_rounded;
      case 'healthcare':
      case 'pharma':
        return Icons.local_hospital_rounded;
      case 'automobile':
      case 'auto':
        return Icons.directions_car_rounded;
      case 'fmcg':
      case 'consumer goods':
        return Icons.shopping_cart_rounded;
      case 'metals':
      case 'metal':
        return Icons.hardware_rounded;
      case 'realty':
      case 'real estate':
        return Icons.apartment_rounded;
      case 'telecom':
      case 'telecommunication':
        return Icons.cell_tower_rounded;
      case 'media':
        return Icons.movie_rounded;
      case 'construction':
        return Icons.construction_rounded;
      case 'chemicals':
        return Icons.science_rounded;
      case 'textiles':
        return Icons.checkroom_rounded;
      case 'capital goods':
        return Icons.precision_manufacturing_rounded;
      case 'consumer durables':
        return Icons.devices_rounded;
      case 'diversified':
        return Icons.grid_view_rounded;
      case 'services':
        return Icons.miscellaneous_services_rounded;
      case 'power':
        return Icons.electrical_services_rounded;
      default:
        return Icons.business_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Sector Champions',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: items.map((item) {
                final scoreColor = ScoreBar.scoreColor(item.score);
                return GestureDetector(
                  onTap: () => onTap(item),
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 42) / 2,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color:
                                AppTheme.accentBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(
                            _sectorIcon(item.sector),
                            size: 14,
                            color: AppTheme.accentBlue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.sector ?? 'Other',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                item.symbol,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scoreColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            item.score.toStringAsFixed(0),
                            style: TextStyle(
                              color: scoreColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
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

  const _RecentCard({required this.item, required this.onTap, this.sparklineValues});

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

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
import 'widgets/score_bar.dart';

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

  void _onStockTap(DiscoverHomeStockItem item) {
    ref
        .read(recentlyViewedProvider.notifier)
        .add(type: 'stock', id: item.symbol, name: item.displayName);
    context.push('/discover/stock/${item.symbol}', extra: item);
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
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(discoverHomeDataProvider);
            },
            child: homeAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (err, _) => ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Text(
                      friendlyErrorMessage(err),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              data: (data) => _buildFeed(data, recentlyViewed),
            ),
          ),
          if (isSearchActive) _buildSearchOverlay(),
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
        // Search bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: _buildSearchBar(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // Quick nav: All Stocks / All MFs
        SliverToBoxAdapter(
          child: Padding(
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
                    onTap: () => context.push('/discover/mutual-funds'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Recently Viewed (first, only if non-empty)
        if (recent.isNotEmpty)
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Recently Viewed',
              children: recent.map((item) => _RecentCard(
                item: item,
                onTap: () => _onRecentTap(item),
              )).toList(),
            ),
          ),

        // Top Stocks
        if (data.topStocks.isNotEmpty)
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Top Stocks',
              seeAllRoute: '/discover/stocks',
              seeAllExtra: const {'preset': 'quality'},
              children: data.topStocks
                  .map((s) => _StockCard(item: s, onTap: () => _onStockTap(s)))
                  .toList(),
            ),
          ),

        // Top Mutual Funds
        if (data.topMutualFunds.isNotEmpty)
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Top Mutual Funds',
              seeAllRoute: '/discover/mutual-funds',
              children: data.topMutualFunds
                  .map((m) => _MfCard(item: m, onTap: () => _onMfTap(m)))
                  .toList(),
            ),
          ),

        // Top Gainers
        if (data.gainers.isNotEmpty)
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Top Gainers',
              seeAllRoute: '/discover/stocks',
              seeAllExtra: const {'preset': 'momentum'},
              children: data.gainers
                  .map((s) => _StockCard(item: s, onTap: () => _onStockTap(s)))
                  .toList(),
            ),
          ),

        // Top Losers
        if (data.losers.isNotEmpty)
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Top Losers',
              seeAllRoute: '/discover/stocks',
              children: data.losers
                  .map((s) => _StockCard(item: s, onTap: () => _onStockTap(s)))
                  .toList(),
            ),
          ),

        // Sector Spotlight
        if (data.sectorSpotlight.isNotEmpty &&
            data.spotlightSectorName != null)
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: '${data.spotlightSectorName} Spotlight',
              seeAllRoute: '/discover/stocks',
              seeAllExtra: {
                'filterKey': 'sector',
                'filterValue': data.spotlightSectorName!,
              },
              children: data.sectorSpotlight
                  .map((s) => _StockCard(item: s, onTap: () => _onStockTap(s)))
                  .toList(),
            ),
          ),

        // Trending
        if (data.trendingStocks.isNotEmpty)
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Trending',
              seeAllRoute: '/discover/stocks',
              seeAllExtra: const {'preset': 'high-volume'},
              children: data.trendingStocks
                  .map((s) => _StockCard(item: s, onTap: () => _onStockTap(s)))
                  .toList(),
            ),
          ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
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
// Horizontal Section
// =============================================================================

class _HorizontalSection extends StatelessWidget {
  final String title;
  final String? seeAllRoute;
  final Map<String, String>? seeAllExtra;
  final List<Widget> children;

  const _HorizontalSection({
    required this.title,
    this.seeAllRoute,
    this.seeAllExtra,
    required this.children,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'See All →',
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
            height: 148,
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

  const _StockCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = item.percentChange ?? 0;
    final isUp = pct >= 0;
    final changeColor = isUp ? AppTheme.accentGreen : AppTheme.accentRed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Symbol
            Text(
              item.symbol,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Display name
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
            // Price
            Text(
              Formatters.price(item.lastPrice),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            // Change %
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: changeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                Formatters.changeTag(pct),
                style: TextStyle(
                  color: changeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Score bar
            ScoreBar(score: item.score, height: 4, showLabel: false),
          ],
        ),
      ),
    );
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display name
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
            // Category
            if (item.category != null)
              Text(
                item.category!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white38,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const Spacer(),
            // 1Y return
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
            const SizedBox(height: 6),
            // Score bar
            ScoreBar(score: item.score, height: 4, showLabel: false),
          ],
        ),
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

  const _RecentCard({required this.item, required this.onTap});

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
            // Type badge
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
            // ID (symbol / scheme code)
            Text(
              item.id,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Name
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
            // Subtle indicator
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

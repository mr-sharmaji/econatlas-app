import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_utils.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/discover.dart';
import '../../providers/discover_providers.dart';
import '../../providers/tab_navigation_providers.dart';
import '../../widgets/shimmer_loading.dart';

class DiscoverHomeScreen extends ConsumerStatefulWidget {
  const DiscoverHomeScreen({super.key});

  @override
  ConsumerState<DiscoverHomeScreen> createState() =>
      _DiscoverHomeScreenState();
}

class _DiscoverHomeScreenState extends ConsumerState<DiscoverHomeScreen> {
  late final ScrollController _scrollController;
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  // Hardcoded quick category pills as fallback when API data is empty.
  static const _defaultCategories = [
    QuickCategory(name: 'Large Cap', segment: 'mutual_funds', preset: 'large-cap'),
    QuickCategory(name: 'IT Sector', segment: 'stocks', filterKey: 'sector', filterValue: 'IT'),
    QuickCategory(name: 'Flexi Cap', segment: 'mutual_funds', preset: 'flexi-cap'),
    QuickCategory(name: 'Mid Cap', segment: 'mutual_funds', preset: 'mid-cap'),
    QuickCategory(name: 'Low Risk', segment: 'mutual_funds', preset: 'low-risk'),
    QuickCategory(name: 'Quality', segment: 'stocks', preset: 'quality'),
    QuickCategory(name: 'Value', segment: 'stocks', preset: 'value'),
    QuickCategory(name: 'High Volume', segment: 'stocks', preset: 'high-volume'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
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

  void _onCategoryTap(QuickCategory cat) {
    final params = <String, String>{};
    if (cat.preset != null) params['preset'] = cat.preset!;
    if (cat.filterKey != null) params['filterKey'] = cat.filterKey!;
    if (cat.filterValue != null) params['filterValue'] = cat.filterValue!;

    if (cat.segment == 'mutual_funds') {
      context.push('/discover/mutual-funds', extra: params);
    } else {
      context.push('/discover/stocks', extra: params);
    }
  }

  Color _qualityColor(String? tier) {
    switch (tier?.toLowerCase()) {
      case 'excellent':
        return AppTheme.accentGreen;
      case 'good':
        return AppTheme.accentBlue;
      case 'average':
        return AppTheme.accentOrange;
      default:
        return AppTheme.accentGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(bottomTabReselectTickProvider(3), (prev, next) {
      if (prev == null || prev == next) return;
      _scrollToTop();
    });

    final homeAsync = ref.watch(discoverHomeDataProvider);
    final isSearchActive = _searchQuery.length >= 2;

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
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard and search overlay when tapping outside
          FocusScope.of(context).unfocus();
          if (isSearchActive) _clearSearch();
        },
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            // Search bar — always visible at top
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: _buildSearchBar(),
            ),
            Expanded(
              child: Stack(
                children: [
                  // Main scrollable content
                  RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(discoverHomeDataProvider);
                    },
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 112),
                      children: [
                        _buildQuickCategories(homeAsync),
                        const SizedBox(height: 20),
                        _buildTopStocks(homeAsync),
                        const SizedBox(height: 20),
                        _buildTopMutualFunds(homeAsync),
                        const SizedBox(height: 20),
                        _buildTrending(homeAsync),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  // Search overlay
                  if (isSearchActive) _buildSearchOverlay(),
                ],
              ),
            ),
          ],
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
          borderSide: BorderSide(color: AppTheme.accentBlue.withValues(alpha: 0.40)),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.10),
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: searchAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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

  // ---------------------------------------------------------------------------
  // Quick category pills
  // ---------------------------------------------------------------------------

  Widget _buildQuickCategories(AsyncValue<DiscoverHomeData> homeAsync) {
    final categories = homeAsync.valueOrNull?.quickCategories ?? [];
    final pills = categories.isNotEmpty ? categories : _defaultCategories;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pills.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = pills[index];
          return FilterChip(
            label: Text(cat.name),
            onSelected: (_) => _onCategoryTap(cat),
            selected: false,
            showCheckmark: false,
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Stocks
  // ---------------------------------------------------------------------------

  Widget _buildTopStocks(AsyncValue<DiscoverHomeData> homeAsync) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Top Stocks', onSeeAll: () => context.push('/discover/stocks')),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: homeAsync.when(
            loading: () => const ShimmerHorizontalList(
              itemCount: 4,
              itemWidth: 150,
              itemHeight: 130,
            ),
            error: (err, _) => Center(
              child: Text(friendlyErrorMessage(err), style: theme.textTheme.bodySmall),
            ),
            data: (data) {
              if (data.topStocks.isEmpty) {
                return Center(
                  child: Text(
                    'No data available',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
                  ),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: data.topStocks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) =>
                    _buildTopStockCard(data.topStocks[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopStockCard(DiscoverHomeStockItem item) {
    final theme = Theme.of(context);
    final changeColor = (item.percentChange ?? 0) >= 0
        ? AppTheme.accentGreen
        : AppTheme.accentRed;
    final tierColor = _qualityColor(item.qualityTier);

    return GestureDetector(
      onTap: () => context.push('/discover/stock/${item.symbol}', extra: item),
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
            Text(
              item.symbol,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.price(item.lastPrice),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 6),
            Text(
              Formatters.changeTag(item.percentChange),
              style: theme.textTheme.labelMedium?.copyWith(
                color: changeColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  item.score.toStringAsFixed(0),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (item.qualityTier != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.qualityTier!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: tierColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Mutual Funds
  // ---------------------------------------------------------------------------

  Widget _buildTopMutualFunds(AsyncValue<DiscoverHomeData> homeAsync) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Top Mutual Funds',
            onSeeAll: () => context.push('/discover/mutual-funds')),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: homeAsync.when(
            loading: () => const ShimmerHorizontalList(
              itemCount: 4,
              itemWidth: 170,
              itemHeight: 130,
            ),
            error: (err, _) => Center(
              child: Text(friendlyErrorMessage(err), style: theme.textTheme.bodySmall),
            ),
            data: (data) {
              if (data.topMutualFunds.isEmpty) {
                return Center(
                  child: Text(
                    'No data available',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
                  ),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: data.topMutualFunds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) =>
                    _buildTopMfCard(data.topMutualFunds[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopMfCard(DiscoverHomeMfItem item) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.push('/discover/mf/${item.schemeCode}', extra: item),
      child: Container(
        width: 170,
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
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (item.category != null)
              Text(
                item.category!,
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.white54),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const Spacer(),
            Row(
              children: [
                Text(
                  'Score ${item.score.toStringAsFixed(0)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
              ],
            ),
            if (item.qualityBadges.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: item.qualityBadges.take(2).map((badge) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.accentTeal,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Trending
  // ---------------------------------------------------------------------------

  Widget _buildTrending(AsyncValue<DiscoverHomeData> homeAsync) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trending',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: homeAsync.when(
            loading: () => const ShimmerHorizontalList(
              itemCount: 4,
              itemWidth: 130,
              itemHeight: 90,
            ),
            error: (err, _) => Center(
              child: Text(friendlyErrorMessage(err), style: theme.textTheme.bodySmall),
            ),
            data: (data) {
              if (data.trendingStocks.isEmpty) {
                return Center(
                  child: Text(
                    'No trending data',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
                  ),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: data.trendingStocks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) =>
                    _buildTrendingCard(data.trendingStocks[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingCard(DiscoverHomeStockItem item) {
    final theme = Theme.of(context);
    final changeColor = (item.percentChange ?? 0) >= 0
        ? AppTheme.accentGreen
        : AppTheme.accentRed;

    return GestureDetector(
      onTap: () => context.push('/discover/stock/${item.symbol}', extra: item),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.symbol,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.price(item.lastPrice),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.changeTag(item.percentChange),
              style: theme.textTheme.labelMedium?.copyWith(
                color: changeColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  Widget _sectionHeader(String title, {required VoidCallback onSeeAll}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onSeeAll,
          child: Text(
            'See All \u2192',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.accentBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

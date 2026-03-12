import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_utils.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/brief.dart';
import '../../../data/models/discover.dart';
import '../../../data/models/ipo.dart';
import '../../providers/brief_providers.dart';
import '../../providers/discover_providers.dart';
import '../../providers/market_providers.dart';
import '../../providers/tab_navigation_providers.dart';
import '../../widgets/shimmer_loading.dart';
import 'widgets/mover_card.dart';
import 'widgets/sector_chip.dart';

class DiscoverHomeScreen extends ConsumerStatefulWidget {
  const DiscoverHomeScreen({super.key});

  @override
  ConsumerState<DiscoverHomeScreen> createState() =>
      _DiscoverHomeScreenState();
}

class _DiscoverHomeScreenState extends ConsumerState<DiscoverHomeScreen> {
  late final ScrollController _scrollController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
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

  void _onSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    // Push to stock screener with search pre-filled; user can switch to MF from there
    context.push('/discover/stocks', extra: query);
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(bottomTabReselectTickProvider(3), (prev, next) {
      if (prev == null || prev == next) return;
      _scrollToTop();
    });

    final market = ref.watch(briefMarketProvider);
    final postMarketAsync = ref.watch(briefPostMarketProvider(market));
    final gainersAsync = ref.watch(briefTopGainersProvider(market));
    final losersAsync = ref.watch(briefTopLosersProvider(market));
    final sectorsAsync = ref.watch(briefSectorPulseProvider(market));
    final ipoAsync = ref.watch(ipoListProvider('open'));
    final stockOverviewAsync =
        ref.watch(discoverOverviewProvider(DiscoverSegment.stocks));
    final mfOverviewAsync =
        ref.watch(discoverOverviewProvider(DiscoverSegment.mutualFunds));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            onPressed: () => context.push('/discover/compare'),
            icon: const Icon(Icons.compare_arrows_rounded),
            tooltip: 'Compare',
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(briefPostMarketProvider(market));
          ref.invalidate(briefTopGainersProvider(market));
          ref.invalidate(briefTopLosersProvider(market));
          ref.invalidate(briefSectorPulseProvider(market));
          ref.invalidate(ipoListProvider('open'));
          ref.invalidate(
              discoverOverviewProvider(DiscoverSegment.stocks));
          ref.invalidate(
              discoverOverviewProvider(DiscoverSegment.mutualFunds));
        },
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 112),
          children: [
            _searchBar(context),
            const SizedBox(height: 12),
            _marketPulse(context, postMarketAsync, stockOverviewAsync),
            const SizedBox(height: 16),
            _scoreDistribution(context, stockOverviewAsync),
            const SizedBox(height: 16),
            _topSectors(context, stockOverviewAsync),
            const SizedBox(height: 16),
            _sectionTitle(context, 'Top Gainers'),
            const SizedBox(height: 8),
            _moversRow(context, gainersAsync),
            const SizedBox(height: 16),
            _sectionTitle(context, 'Top Losers'),
            const SizedBox(height: 8),
            _moversRow(context, losersAsync),
            const SizedBox(height: 16),
            _sectionTitle(context, 'Sector Performance'),
            const SizedBox(height: 8),
            _sectorsGrid(context, sectorsAsync),
            const SizedBox(height: 16),
            _ipoSection(context, ipoAsync),
            const SizedBox(height: 16),
            _exploreCards(context, stockOverviewAsync, mfOverviewAsync),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search stocks or mutual funds...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: _onSearch,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _onSearch(),
    );
  }

  Widget _marketPulse(
    BuildContext context,
    AsyncValue<PostMarketOverview> async,
    AsyncValue<DiscoverOverview> overviewAsync,
  ) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: async.when(
          loading: () => const ShimmerCard(height: 80),
          error: (err, _) => Text(
            friendlyErrorMessage(err),
            style: theme.textTheme.bodySmall,
          ),
          data: (overview) {
            final total = overview.advancers + overview.decliners;
            final advFraction = total > 0 ? overview.advancers / total : 0.5;
            final avgColor = (overview.avgChangePercent ?? 0) >= 0
                ? AppTheme.accentGreen
                : AppTheme.accentRed;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Market Pulse',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (overviewAsync.valueOrNull?.dataFreshnessMinutes !=
                            null)
                          Text(
                            'Updated ${overviewAsync.valueOrNull!.dataFreshnessMinutes!.round()} min ago',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: Colors.white38),
                          ),
                      ],
                    ),
                    const Spacer(),
                    if (overview.avgChangePercent != null)
                      Text(
                        Formatters.changeTag(overview.avgChangePercent),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: avgColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Advancers vs Decliners bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        Flexible(
                          flex: (advFraction * 100).round(),
                          child: Container(color: AppTheme.accentGreen),
                        ),
                        Flexible(
                          flex: ((1 - advFraction) * 100).round(),
                          child: Container(color: AppTheme.accentRed),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${overview.advancers} Advancers',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.accentGreen,
                      ),
                    ),
                    Text(
                      '${overview.decliners} Decliners',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.accentRed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (overview.topSector != null)
                      _pulseTag(
                        context,
                        icon: Icons.trending_up_rounded,
                        label: overview.topSector!,
                        color: AppTheme.accentGreen,
                      ),
                    if (overview.topSector != null &&
                        overview.bottomSector != null)
                      const SizedBox(width: 10),
                    if (overview.bottomSector != null)
                      _pulseTag(
                        context,
                        icon: Icons.trending_down_rounded,
                        label: overview.bottomSector!,
                        color: AppTheme.accentRed,
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _pulseTag(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreTierColor(double score) {
    if (score >= 75) return AppTheme.accentGreen;
    if (score >= 50) return AppTheme.accentBlue;
    if (score >= 25) return AppTheme.accentOrange;
    return AppTheme.accentRed;
  }

  Widget _scoreDistribution(
    BuildContext context,
    AsyncValue<DiscoverOverview> async,
  ) {
    final theme = Theme.of(context);
    return async.when(
      loading: () => const ShimmerCard(height: 56),
      error: (_, __) => const SizedBox.shrink(),
      data: (overview) {
        final dist = overview.scoreDistribution;
        if (dist == null || dist.total == 0) return const SizedBox.shrink();

        final tiers = [
          ('Excellent', dist.excellent, AppTheme.accentGreen),
          ('Good', dist.good, AppTheme.accentBlue),
          ('Average', dist.average, AppTheme.accentOrange),
          ('Poor', dist.poor, AppTheme.accentRed),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Score Distribution',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (overview.avgScore != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _scoreTierColor(overview.avgScore!)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Avg Score: ${overview.avgScore!.toStringAsFixed(0)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _scoreTierColor(overview.avgScore!),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Stacked bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: tiers
                      .where((t) => t.$2 > 0)
                      .map((t) => Flexible(
                            flex: t.$2,
                            child: Container(color: t.$3),
                          ))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Labels row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: tiers
                  .map((t) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: t.$3,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${t.$1} ${t.$2}',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: Colors.white54),
                          ),
                        ],
                      ))
                  .toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _topSectors(
    BuildContext context,
    AsyncValue<DiscoverOverview> async,
  ) {
    final theme = Theme.of(context);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (overview) {
        if (overview.topSectors.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Performing Sectors',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: overview.topSectors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final entry = overview.topSectors[index];
                  final color = _scoreTierColor(entry.avgScore);
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.name,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          entry.avgScore.toStringAsFixed(0),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color.withValues(alpha: 0.70),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _moversRow(
    BuildContext context,
    AsyncValue<List<BriefStockItem>> async,
  ) {
    return SizedBox(
      height: 100,
      child: async.when(
        loading: () => const ShimmerHorizontalList(
            itemCount: 4, itemWidth: 140, itemHeight: 100),
        error: (err, _) => Center(
          child: Text(
            friendlyErrorMessage(err),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No data available',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white54),
              ),
            );
          }
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length > 5 ? 5 : items.length,
            itemBuilder: (context, index) => MoverCard(item: items[index]),
          );
        },
      ),
    );
  }

  Widget _sectorsGrid(
    BuildContext context,
    AsyncValue<List<BriefSectorItem>> async,
  ) {
    return async.when(
      loading: () => const ShimmerCard(height: 60),
      error: (err, _) => Text(
        friendlyErrorMessage(err),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      data: (sectors) {
        if (sectors.isEmpty) {
          return Text(
            'No sector data available',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white54),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sectors.map((s) => SectorChip(item: s)).toList(),
        );
      },
    );
  }

  Widget _ipoSection(
    BuildContext context,
    AsyncValue<IpoListResponse> async,
  ) {
    final theme = Theme.of(context);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (response) {
        if (response.items.isEmpty) return const SizedBox.shrink();
        final items = response.items.take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'IPO Watch'),
            const SizedBox(height: 8),
            ...items.map((ipo) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ipo.companyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${ipo.ipoType.toUpperCase()} ${ipo.priceBand != null ? '· ${ipo.priceBand}' : ''}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    if (ipo.gmpPercent != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (ipo.gmpPercent! >= 0
                                  ? AppTheme.accentGreen
                                  : AppTheme.accentRed)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'GMP ${Formatters.changeTag(ipo.gmpPercent)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: ipo.gmpPercent! >= 0
                                ? AppTheme.accentGreen
                                : AppTheme.accentRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _exploreCards(
    BuildContext context,
    AsyncValue<DiscoverOverview> stockOverview,
    AsyncValue<DiscoverOverview> mfOverview,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Explore'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _exploreCard(
                context,
                title: 'Stocks',
                subtitle: stockOverview.whenOrNull(
                      data: (d) => '${d.totalItems} stocks ranked',
                    ) ??
                    'Explore ranked stocks',
                icon: Icons.candlestick_chart_rounded,
                color: AppTheme.accentBlue,
                onTap: () => context.push('/discover/stocks'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _exploreCard(
                context,
                title: 'Mutual Funds',
                subtitle: mfOverview.whenOrNull(
                      data: (d) => '${d.totalItems} funds ranked',
                    ) ??
                    'Explore direct funds',
                icon: Icons.account_balance_wallet_outlined,
                color: AppTheme.accentTeal,
                onTap: () => context.push('/discover/mutual-funds'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _exploreCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

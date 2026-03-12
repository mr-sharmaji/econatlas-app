import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_utils.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/brief.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class BriefScreen extends ConsumerStatefulWidget {
  const BriefScreen({super.key});

  @override
  ConsumerState<BriefScreen> createState() => _BriefScreenState();
}

class _BriefScreenState extends ConsumerState<BriefScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(bottomTabReselectTickProvider(3), (prev, next) {
      if (prev == null || prev == next) return;
      _scrollToTop();
    });

    final market = ref.watch(briefMarketProvider);
    final overviewAsync = ref.watch(briefPostMarketProvider(market));
    final gainersAsync = ref.watch(briefTopGainersProvider(market));
    final losersAsync = ref.watch(briefTopLosersProvider(market));
    final activeAsync = ref.watch(briefMostActiveProvider(market));
    final sectorAsync = ref.watch(briefSectorPulseProvider(market));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screener'),
        actions: [
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
          ref.invalidate(briefMostActiveProvider(market));
          ref.invalidate(briefSectorPulseProvider(market));
        },
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 112),
          children: [
            _marketToggle(context, ref, market),
            const SizedBox(height: 10),
            _postMarketCard(context, overviewAsync),
            const SizedBox(height: 10),
            _moversCard(context, gainersAsync, losersAsync),
            const SizedBox(height: 10),
            _mostActiveCard(context, activeAsync),
            const SizedBox(height: 10),
            _sectorPulseCard(context, sectorAsync),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _marketToggle(BuildContext context, WidgetRef ref, String market) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Country',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _marketChoiceCard(
                    context,
                    name: 'India',
                    selected: market == 'IN',
                    badgeStyle: _ScreenerBadgeStyle.india,
                    onTap: () =>
                        ref.read(briefMarketProvider.notifier).state = 'IN',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _marketChoiceCard(
                    context,
                    name: 'United States',
                    selected: market == 'US',
                    badgeStyle: _ScreenerBadgeStyle.us,
                    onTap: () =>
                        ref.read(briefMarketProvider.notifier).state = 'US',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _marketChoiceCard(
    BuildContext context, {
    required String name,
    required _ScreenerBadgeStyle badgeStyle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.white10,
            width: selected ? 1.6 : 1,
          ),
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: selected ? 0.22 : 0.12,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: _ScreenerBadgeBox(style: badgeStyle),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _postMarketCard(
      BuildContext context, AsyncValue<PostMarketOverview> async) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: async.when(
          loading: () => const ShimmerCard(height: 120),
          error: (err, _) => Text(
            friendlyErrorMessage(err),
            style: theme.textTheme.bodySmall,
          ),
          data: (item) {
            final breadthColor = item.advancers >= item.decliners
                ? AppTheme.accentGreen
                : AppTheme.accentRed;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Post Market Overview',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  item.summary,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statPill(
                      context,
                      'Advance/Decline',
                      '${item.advancers}/${item.decliners}',
                      breadthColor,
                    ),
                    const SizedBox(width: 8),
                    _statPill(
                      context,
                      'Avg Move',
                      item.avgChangePercent == null
                          ? 'N/A'
                          : Formatters.changeTag(item.avgChangePercent),
                      (item.avgChangePercent ?? 0) >= 0
                          ? AppTheme.accentGreen
                          : AppTheme.accentRed,
                    ),
                  ],
                ),
                if (item.driverTags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item.driverTags
                        .take(3)
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                tag,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
                if (item.asOf != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Updated ${Formatters.relativeTime(item.asOf!)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white54),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _moversCard(
    BuildContext context,
    AsyncValue<List<BriefStockItem>> gainersAsync,
    AsyncValue<List<BriefStockItem>> losersAsync,
  ) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Gainers / Top Losers',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _moverColumn(
                    context,
                    title: 'Gainers',
                    color: AppTheme.accentGreen,
                    async: gainersAsync,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _moverColumn(
                    context,
                    title: 'Losers',
                    color: AppTheme.accentRed,
                    async: losersAsync,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _moverColumn(
    BuildContext context, {
    required String title,
    required Color color,
    required AsyncValue<List<BriefStockItem>> async,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: async.when(
        loading: () => const ShimmerList(itemCount: 4, itemHeight: 18),
        error: (err, _) => Text(
          friendlyErrorMessage(err),
          style: theme.textTheme.bodySmall,
        ),
        data: (items) {
          if (items.isEmpty) return const Text('No data');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...items.take(5).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.symbol.replaceAll('.NS', ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          Formatters.changeTag(e.percentChange),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _mostActiveCard(
      BuildContext context, AsyncValue<List<BriefStockItem>> async) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: async.when(
          loading: () => const ShimmerList(itemCount: 6, itemHeight: 36),
          error: (err, _) => Text(
            friendlyErrorMessage(err),
            style: theme.textTheme.bodySmall,
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Text('Most active data unavailable');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Most Active',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ...items.take(8).map((e) {
                  final color = (e.percentChange ?? 0) >= 0
                      ? AppTheme.accentGreen
                      : AppTheme.accentRed;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            e.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            Formatters.fullPrice(e.lastPrice),
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            Formatters.changeTag(e.percentChange),
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: color,
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
          },
        ),
      ),
    );
  }

  Widget _sectorPulseCard(
      BuildContext context, AsyncValue<List<BriefSectorItem>> async) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: async.when(
          loading: () => const ShimmerList(itemCount: 5, itemHeight: 30),
          error: (err, _) => Text(
            friendlyErrorMessage(err),
            style: theme.textTheme.bodySmall,
          ),
          data: (sectors) {
            if (sectors.isEmpty) return const Text('Sector data unavailable');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sector Pulse',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ...sectors.take(8).map((s) {
                  final color = s.avgChangePercent >= 0
                      ? AppTheme.accentGreen
                      : AppTheme.accentRed;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.sector,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          Formatters.changeTag(s.avgChangePercent),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${s.gainers}/${s.losers})',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white60),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statPill(
      BuildContext context, String label, String value, Color valueColor) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style:
                  theme.textTheme.labelSmall?.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ScreenerBadgeStyle { india, us }

class _ScreenerBadgeBox extends StatelessWidget {
  const _ScreenerBadgeBox({required this.style});

  final _ScreenerBadgeStyle style;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case _ScreenerBadgeStyle.india:
        return const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF9933),
                Color(0xFFFFFFFF),
                Color(0xFF138808),
              ],
            ),
          ),
          child: SizedBox.expand(),
        );
      case _ScreenerBadgeStyle.us:
        return const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFB22234),
                Color(0xFFFFFFFF),
                Color(0xFF3C3B6E),
              ],
            ),
          ),
          child: SizedBox.expand(),
        );
    }
  }
}

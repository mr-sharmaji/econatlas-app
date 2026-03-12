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

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
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

    final segment = ref.watch(discoverSegmentProvider);
    final overviewAsync = ref.watch(discoverOverviewProvider(segment));
    final stockAsync = ref.watch(discoverStocksProvider);
    final mfAsync = ref.watch(discoverMutualFundsProvider);
    final compareAsync = ref.watch(discoverCompareProvider(segment));

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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(discoverOverviewProvider(segment));
          ref.invalidate(discoverStocksProvider);
          ref.invalidate(discoverMutualFundsProvider);
          ref.invalidate(discoverCompareProvider(segment));
        },
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 112),
          children: [
            _headerCard(context, segment, overviewAsync),
            const SizedBox(height: 10),
            _segmentToggle(context, segment),
            const SizedBox(height: 10),
            if (segment == DiscoverSegment.stocks) ...[
              _stockPresetRow(context),
              const SizedBox(height: 10),
              _stockResults(context, stockAsync),
            ] else ...[
              _mfPresetRow(context),
              const SizedBox(height: 10),
              _mutualFundResults(context, mfAsync),
            ],
            const SizedBox(height: 10),
            _compareTray(context, segment, compareAsync),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _headerCard(
    BuildContext context,
    DiscoverSegment segment,
    AsyncValue<DiscoverOverview> overviewAsync,
  ) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: overviewAsync.when(
          loading: () => const ShimmerCard(height: 96),
          error: (err, _) => Text(
            friendlyErrorMessage(err),
            style: theme.textTheme.bodySmall,
          ),
          data: (overview) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'India Pulse',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    _statusPill(context, overview.sourceStatus),
                    const Spacer(),
                    _helpIcon(
                      context,
                      title: 'How this works',
                      message:
                          'Primary means full source coverage. Fallback means backup sources are used. Limited means some advanced metrics are unavailable.',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  segment == DiscoverSegment.stocks
                      ? 'Ranked NSE stock opportunities with momentum + fundamentals.'
                      : 'Ranked India direct-plan mutual funds with blended risk-return-cost scoring.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _miniStat(
                      context,
                      label: 'Universe',
                      value: '${overview.totalItems}',
                    ),
                    _miniStat(
                      context,
                      label: 'Leaders',
                      value: overview.leaders.isEmpty
                          ? 'N/A'
                          : overview.leaders.take(2).join(', '),
                    ),
                    _miniStat(
                      context,
                      label: 'Laggards',
                      value: overview.laggards.isEmpty
                          ? 'N/A'
                          : overview.laggards.take(2).join(', '),
                    ),
                  ],
                ),
                if (overview.asOf != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Updated ${Formatters.relativeTime(overview.asOf!)}',
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

  Widget _segmentToggle(BuildContext context, DiscoverSegment segment) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SegmentedButton<DiscoverSegment>(
          segments: const [
            ButtonSegment(
              value: DiscoverSegment.stocks,
              icon: Icon(Icons.candlestick_chart_rounded),
              label: Text('Stocks'),
            ),
            ButtonSegment(
              value: DiscoverSegment.mutualFunds,
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: Text('Mutual Funds'),
            ),
          ],
          selected: {segment},
          onSelectionChanged: (selected) {
            ref
                .read(discoverSegmentProvider.notifier)
                .setSegment(selected.first);
          },
          showSelectedIcon: false,
        ),
      ),
    );
  }

  Widget _stockPresetRow(BuildContext context) {
    final preset = ref.watch(discoverStockPresetProvider);
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Stock Presets',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showStockFilters(context),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Advanced'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DiscoverStockPreset.values.map((option) {
                return ChoiceChip(
                  label: Text(option.label),
                  selected: preset == option,
                  onSelected: (_) {
                    ref
                        .read(discoverStockPresetProvider.notifier)
                        .setPreset(option);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mfPresetRow(BuildContext context) {
    final preset = ref.watch(discoverMutualFundPresetProvider);
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Mutual Fund Presets',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showMutualFundFilters(context),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Advanced'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DiscoverMutualFundPreset.values.map((option) {
                return ChoiceChip(
                  label: Text(option.label),
                  selected: preset == option,
                  onSelected: (_) {
                    ref
                        .read(discoverMutualFundPresetProvider.notifier)
                        .setPreset(option);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockResults(
    BuildContext context,
    AsyncValue<DiscoverStockListResponse> async,
  ) {
    final theme = Theme.of(context);
    final selected = ref.watch(discoverStockCompareProvider).toSet();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: async.when(
          loading: () => const ShimmerList(itemCount: 8, itemHeight: 70),
          error: (err, _) => Text(
            friendlyErrorMessage(err),
            style: theme.textTheme.bodySmall,
          ),
          data: (payload) {
            if (payload.items.isEmpty) {
              return const Text('No stocks match the current filters.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Stocks (${payload.count})',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    _statusPill(context, payload.sourceStatus),
                    const Spacer(),
                    _helpIcon(
                      context,
                      title: 'Stock score',
                      message:
                          'Stock score blends momentum + liquidity (50%) and fundamentals (50%). Missing fundamentals trigger internal reweighting.',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...payload.items.map((item) {
                  final isPositive = (item.percentChange ?? 0) >= 0;
                  final color = isPositive ? AppTheme.accentGreen : AppTheme.accentRed;
                  final isSelected = selected.contains(item.symbol);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.white10,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              Formatters.changeTag(item.percentChange),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                ref
                                    .read(discoverStockCompareProvider.notifier)
                                    .toggle(item.symbol);
                              },
                              icon: Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.white60,
                              ),
                              tooltip: 'Compare',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.symbol} · ${item.sector ?? 'N/A'}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white60),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _metricChip(
                              context,
                              'Score',
                              item.score.toStringAsFixed(1),
                            ),
                            _metricChip(
                              context,
                              'Price',
                              Formatters.fullPrice(item.lastPrice),
                            ),
                            _metricChip(
                              context,
                              'P/E',
                              item.peRatio?.toStringAsFixed(1) ?? 'N/A',
                            ),
                            _metricChip(
                              context,
                              'ROE',
                              item.roe == null
                                  ? 'N/A'
                                  : '${item.roe!.toStringAsFixed(1)}%',
                            ),
                          ],
                        ),
                        if (item.whyRanked.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Why: ${item.whyRanked.first}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
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

  Widget _mutualFundResults(
    BuildContext context,
    AsyncValue<DiscoverMutualFundListResponse> async,
  ) {
    final theme = Theme.of(context);
    final selected = ref.watch(discoverMutualFundCompareProvider).toSet();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: async.when(
          loading: () => const ShimmerList(itemCount: 8, itemHeight: 72),
          error: (err, _) => Text(
            friendlyErrorMessage(err),
            style: theme.textTheme.bodySmall,
          ),
          data: (payload) {
            if (payload.items.isEmpty) {
              return const Text('No mutual funds match the current filters.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Mutual Funds (${payload.count})',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    _statusPill(context, payload.sourceStatus),
                    const Spacer(),
                    _helpIcon(
                      context,
                      title: 'Mutual fund score',
                      message:
                          'Mutual fund score blends return, risk, cost, and consistency. Category-relative normalization is used for return ranking.',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...payload.items.map((item) {
                  final isSelected = selected.contains(item.schemeCode);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.white10,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.schemeName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                ref
                                    .read(discoverMutualFundCompareProvider
                                        .notifier)
                                    .toggle(item.schemeCode);
                              },
                              icon: Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.white60,
                              ),
                              tooltip: 'Compare',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.category ?? 'N/A'} · ${item.planType.toUpperCase()}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white60),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _metricChip(
                              context,
                              'Score',
                              item.score.toStringAsFixed(1),
                            ),
                            _metricChip(
                              context,
                              'NAV',
                              Formatters.fullPrice(item.nav),
                            ),
                            _metricChip(
                              context,
                              '3Y Return',
                              item.returns3y == null
                                  ? 'N/A'
                                  : '${item.returns3y!.toStringAsFixed(1)}%',
                            ),
                            _metricChip(
                              context,
                              'Expense',
                              item.expenseRatio == null
                                  ? 'N/A'
                                  : '${item.expenseRatio!.toStringAsFixed(2)}%',
                            ),
                          ],
                        ),
                        if (item.whyRanked.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Why: ${item.whyRanked.first}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
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

  Widget _compareTray(
    BuildContext context,
    DiscoverSegment segment,
    AsyncValue<DiscoverCompareResponse> compareAsync,
  ) {
    final theme = Theme.of(context);
    final stockIds = ref.watch(discoverStockCompareProvider);
    final mfIds = ref.watch(discoverMutualFundCompareProvider);
    final ids = segment == DiscoverSegment.stocks ? stockIds : mfIds;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Compare (${ids.length}/3)',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: ids.isEmpty
                      ? null
                      : () {
                          if (segment == DiscoverSegment.stocks) {
                            ref
                                .read(discoverStockCompareProvider.notifier)
                                .clear();
                          } else {
                            ref
                                .read(discoverMutualFundCompareProvider.notifier)
                                .clear();
                          }
                        },
                  child: const Text('Clear'),
                ),
              ],
            ),
            if (ids.isEmpty)
              Text(
                'Pick up to 3 items from the list to compare key metrics side-by-side.',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ids
                    .map(
                      (id) => Chip(
                        label: Text(id),
                        onDeleted: () {
                          if (segment == DiscoverSegment.stocks) {
                            ref
                                .read(discoverStockCompareProvider.notifier)
                                .toggle(id);
                          } else {
                            ref
                                .read(discoverMutualFundCompareProvider.notifier)
                                .toggle(id);
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              compareAsync.when(
                loading: () => const ShimmerList(itemCount: 2, itemHeight: 24),
                error: (err, _) => Text(
                  friendlyErrorMessage(err),
                  style: theme.textTheme.bodySmall,
                ),
                data: (payload) {
                  final rows = segment == DiscoverSegment.stocks
                      ? payload.stockItems
                          .map((e) => '${e.symbol}: ${e.score.toStringAsFixed(1)}')
                      : payload.mutualFundItems
                          .map((e) => '${e.schemeCode}: ${e.score.toStringAsFixed(1)}');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: rows
                        .map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              line,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusPill(BuildContext context, String sourceStatus) {
    final theme = Theme.of(context);
    final normalized = sourceStatus.toLowerCase();
    final color = switch (normalized) {
      'primary' => AppTheme.accentGreen,
      'fallback' => Colors.amber,
      _ => AppTheme.accentRed,
    };
    final text = switch (normalized) {
      'primary' => 'Primary',
      'fallback' => 'Fallback',
      _ => 'Limited',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _miniStat(BuildContext context,
      {required String label, required String value}) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelSmall,
      ),
    );
  }

  Widget _helpIcon(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return IconButton(
      icon: const Icon(Icons.info_outline_rounded, size: 18),
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
      tooltip: 'Explain',
    );
  }

  Future<void> _showStockFilters(BuildContext context) async {
    final current = ref.read(discoverStockFiltersProvider);
    final minPeCtrl = TextEditingController(
      text: current.minPe?.toStringAsFixed(1) ?? '',
    );
    final maxPeCtrl = TextEditingController(
      text: current.maxPe?.toStringAsFixed(1) ?? '',
    );

    double localMinScore = current.minScore;
    String localSource = current.sourceStatus;
    String localSector = current.sector;
    String localSort = current.sortBy;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Advanced Stock Filters',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    Text('Min Score: ${localMinScore.toStringAsFixed(0)}'),
                    Slider(
                      min: 0,
                      max: 100,
                      value: localMinScore,
                      onChanged: (v) => setModalState(() => localMinScore = v),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: localSource,
                      decoration: const InputDecoration(labelText: 'Source status'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'primary', child: Text('Primary')),
                        DropdownMenuItem(value: 'fallback', child: Text('Fallback')),
                        DropdownMenuItem(value: 'limited', child: Text('Limited')),
                      ],
                      onChanged: (v) => setModalState(() => localSource = v ?? 'all'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: localSector,
                      decoration: const InputDecoration(labelText: 'Sector'),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Financials', child: Text('Financials')),
                        DropdownMenuItem(value: 'IT', child: Text('IT')),
                        DropdownMenuItem(value: 'Energy', child: Text('Energy')),
                        DropdownMenuItem(value: 'Healthcare', child: Text('Healthcare')),
                        DropdownMenuItem(value: 'Consumer', child: Text('Consumer')),
                        DropdownMenuItem(value: 'Auto', child: Text('Auto')),
                      ],
                      onChanged: (v) => setModalState(() => localSector = v ?? 'All'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: localSort,
                      decoration: const InputDecoration(labelText: 'Sort by'),
                      items: const [
                        DropdownMenuItem(value: 'score', child: Text('Score')),
                        DropdownMenuItem(value: 'change', child: Text('Change %')),
                        DropdownMenuItem(value: 'volume', child: Text('Volume')),
                        DropdownMenuItem(value: 'pe', child: Text('P/E')),
                        DropdownMenuItem(value: 'roe', child: Text('ROE')),
                      ],
                      onChanged: (v) => setModalState(() => localSort = v ?? 'score'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: minPeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min P/E'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: maxPeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max P/E'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              ref
                                  .read(discoverStockFiltersProvider.notifier)
                                  .setFilters(const DiscoverStockFilters());
                              Navigator.of(context).pop();
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final minPe = double.tryParse(minPeCtrl.text.trim());
                              final maxPe = double.tryParse(maxPeCtrl.text.trim());
                              ref
                                  .read(discoverStockFiltersProvider.notifier)
                                  .setFilters(
                                    current.copyWith(
                                      minScore: localMinScore,
                                      sourceStatus: localSource,
                                      sector: localSector,
                                      sortBy: localSort,
                                      minPe: minPe,
                                      maxPe: maxPe,
                                    ),
                                  );
                              Navigator.of(context).pop();
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showMutualFundFilters(BuildContext context) async {
    final current = ref.read(discoverMutualFundFiltersProvider);
    final expenseCtrl = TextEditingController(
      text: current.maxExpenseRatio?.toStringAsFixed(2) ?? '',
    );

    double localMinScore = current.minScore;
    String localCategory = current.category;
    String localRisk = current.riskLevel;
    String localSource = current.sourceStatus;
    String localSort = current.sortBy;
    bool localDirectOnly = current.directOnly;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Advanced Mutual Fund Filters',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      value: localDirectOnly,
                      onChanged: (v) => setModalState(() => localDirectOnly = v),
                      title: const Text('Direct plans only'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    Text('Min Score: ${localMinScore.toStringAsFixed(0)}'),
                    Slider(
                      min: 0,
                      max: 100,
                      value: localMinScore,
                      onChanged: (v) => setModalState(() => localMinScore = v),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: localCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Equity', child: Text('Equity')),
                        DropdownMenuItem(value: 'Debt', child: Text('Debt')),
                        DropdownMenuItem(value: 'Hybrid', child: Text('Hybrid')),
                        DropdownMenuItem(value: 'Index', child: Text('Index')),
                      ],
                      onChanged: (v) => setModalState(() => localCategory = v ?? 'All'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: localRisk,
                      decoration: const InputDecoration(labelText: 'Risk level'),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Low', child: Text('Low')),
                        DropdownMenuItem(value: 'Moderately Low', child: Text('Moderately Low')),
                        DropdownMenuItem(value: 'Moderate', child: Text('Moderate')),
                        DropdownMenuItem(value: 'High', child: Text('High')),
                      ],
                      onChanged: (v) => setModalState(() => localRisk = v ?? 'All'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: localSource,
                      decoration: const InputDecoration(labelText: 'Source status'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'primary', child: Text('Primary')),
                        DropdownMenuItem(value: 'fallback', child: Text('Fallback')),
                        DropdownMenuItem(value: 'limited', child: Text('Limited')),
                      ],
                      onChanged: (v) => setModalState(() => localSource = v ?? 'all'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: localSort,
                      decoration: const InputDecoration(labelText: 'Sort by'),
                      items: const [
                        DropdownMenuItem(value: 'score', child: Text('Score')),
                        DropdownMenuItem(value: 'returns_3y', child: Text('3Y Return')),
                        DropdownMenuItem(value: 'expense', child: Text('Expense Ratio')),
                        DropdownMenuItem(value: 'aum', child: Text('AUM')),
                        DropdownMenuItem(value: 'risk', child: Text('Risk score')),
                      ],
                      onChanged: (v) => setModalState(() => localSort = v ?? 'score'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: expenseCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Expense Ratio (%)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              ref
                                  .read(discoverMutualFundFiltersProvider.notifier)
                                  .setFilters(const DiscoverMutualFundFilters());
                              Navigator.of(context).pop();
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final expense =
                                  double.tryParse(expenseCtrl.text.trim());
                              ref
                                  .read(discoverMutualFundFiltersProvider.notifier)
                                  .setFilters(
                                    current.copyWith(
                                      directOnly: localDirectOnly,
                                      minScore: localMinScore,
                                      category: localCategory,
                                      riskLevel: localRisk,
                                      sourceStatus: localSource,
                                      sortBy: localSort,
                                      maxExpenseRatio: expense,
                                    ),
                                  );
                              Navigator.of(context).pop();
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

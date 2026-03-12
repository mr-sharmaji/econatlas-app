import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_utils.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/discover.dart';
import '../../providers/discover_providers.dart';
import '../../widgets/shimmer_loading.dart';
import 'widgets/score_bar.dart';

class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final segment = ref.read(discoverSegmentProvider);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: segment == DiscoverSegment.stocks ? 0 : 1,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final seg = _tabController.index == 0
            ? DiscoverSegment.stocks
            : DiscoverSegment.mutualFunds;
        ref.read(discoverSegmentProvider.notifier).setSegment(seg);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Stocks'),
            Tab(text: 'Mutual Funds'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StockCompareTab(),
          _MfCompareTab(),
        ],
      ),
    );
  }
}

class _StockCompareTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(discoverStockCompareProvider);
    final compareAsync =
        ref.watch(discoverCompareProvider(DiscoverSegment.stocks));
    final theme = Theme.of(context);

    if (ids.isEmpty) {
      return _emptyState(context, 'Select up to 3 stocks from the screener to compare.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _selectedChips(
            context,
            ids: ids,
            onRemove: (id) =>
                ref.read(discoverStockCompareProvider.notifier).toggle(id),
            onClear: () =>
                ref.read(discoverStockCompareProvider.notifier).clear(),
          ),
          const SizedBox(height: 16),
          compareAsync.when(
            loading: () => const ShimmerList(itemCount: 3, itemHeight: 60),
            error: (err, _) => Text(
              friendlyErrorMessage(err),
              style: theme.textTheme.bodySmall,
            ),
            data: (payload) {
              if (payload.stockItems.isEmpty) {
                return const Text('No data available for comparison.');
              }
              return _stockCompareTable(context, payload.stockItems,
                  summary: payload.comparisonSummary);
            },
          ),
        ],
      ),
    );
  }

  Widget _stockCompareTable(
      BuildContext context, List<DiscoverStockItem> items,
      {ComparisonSummary? summary}) {
    final theme = Theme.of(context);

    final metrics = <String, List<String>>{
      'Score': items.map((e) => e.score.toStringAsFixed(1)).toList(),
      'Price': items.map((e) => Formatters.fullPrice(e.lastPrice)).toList(),
      'Change':
          items.map((e) => Formatters.changeTag(e.percentChange)).toList(),
      'P/E': items
          .map((e) => e.peRatio?.toStringAsFixed(1) ?? 'N/A')
          .toList(),
      'ROE': items
          .map((e) => e.roe != null ? '${e.roe!.toStringAsFixed(1)}%' : 'N/A')
          .toList(),
      'ROCE': items
          .map(
              (e) => e.roce != null ? '${e.roce!.toStringAsFixed(1)}%' : 'N/A')
          .toList(),
      'D/E': items
          .map((e) =>
              e.debtToEquity?.toStringAsFixed(2) ?? 'N/A')
          .toList(),
      'Volume':
          items.map((e) => e.volume?.toString() ?? 'N/A').toList(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary != null && summary.winner.isNotEmpty)
          _winnerBadge(theme, summary),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with names
                Row(
                  children: [
                    const SizedBox(width: 72),
                    ...items.map((item) => Expanded(
                          child: Text(
                            item.symbol,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 4),
                const Divider(),
                // Score bars
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              item.symbol,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: Colors.white54),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: ScoreBar(score: item.score)),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 4),
                // Metric rows
                ...metrics.entries.map((entry) {
                  final metricWinner = summary?.metricWinners[entry.key];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            entry.key,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: Colors.white54),
                          ),
                        ),
                        for (int i = 0; i < items.length; i++)
                          Expanded(
                            child: Text(
                              entry.value[i],
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight:
                                    metricWinner == items[i].symbol
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                color: entry.key == 'Change'
                                    ? (entry.value[i].startsWith('+')
                                        ? AppTheme.accentGreen
                                        : entry.value[i].startsWith('-')
                                            ? AppTheme.accentRed
                                            : null)
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MfCompareTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(discoverMutualFundCompareProvider);
    final compareAsync =
        ref.watch(discoverCompareProvider(DiscoverSegment.mutualFunds));
    final theme = Theme.of(context);

    if (ids.isEmpty) {
      return _emptyState(
          context, 'Select up to 3 mutual funds from the screener to compare.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _selectedChips(
            context,
            ids: ids,
            onRemove: (id) =>
                ref.read(discoverMutualFundCompareProvider.notifier).toggle(id),
            onClear: () =>
                ref.read(discoverMutualFundCompareProvider.notifier).clear(),
          ),
          const SizedBox(height: 16),
          compareAsync.when(
            loading: () => const ShimmerList(itemCount: 3, itemHeight: 60),
            error: (err, _) => Text(
              friendlyErrorMessage(err),
              style: theme.textTheme.bodySmall,
            ),
            data: (payload) {
              if (payload.mutualFundItems.isEmpty) {
                return const Text('No data available for comparison.');
              }
              return _mfCompareTable(context, payload.mutualFundItems,
                  summary: payload.comparisonSummary);
            },
          ),
        ],
      ),
    );
  }

  Widget _mfCompareTable(
      BuildContext context, List<DiscoverMutualFundItem> items,
      {ComparisonSummary? summary}) {
    final theme = Theme.of(context);

    final metrics = <String, List<String>>{
      'Score': items.map((e) => e.score.toStringAsFixed(1)).toList(),
      'NAV': items.map((e) => Formatters.fullPrice(e.nav)).toList(),
      '1Y Return': items
          .map((e) =>
              e.returns1y != null ? '${e.returns1y!.toStringAsFixed(1)}%' : 'N/A')
          .toList(),
      '3Y Return': items
          .map((e) =>
              e.returns3y != null ? '${e.returns3y!.toStringAsFixed(1)}%' : 'N/A')
          .toList(),
      'Expense': items
          .map((e) => e.expenseRatio != null
              ? '${e.expenseRatio!.toStringAsFixed(2)}%'
              : 'N/A')
          .toList(),
      'AUM (Cr)': items
          .map(
              (e) => e.aumCr != null ? e.aumCr!.toStringAsFixed(0) : 'N/A')
          .toList(),
      'Sharpe': items
          .map((e) => e.sharpe?.toStringAsFixed(2) ?? 'N/A')
          .toList(),
      'Risk': items.map((e) => e.riskLevel ?? 'N/A').toList(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary != null && summary.winner.isNotEmpty)
          _winnerBadge(theme, summary),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with short names
                Row(
                  children: [
                    const SizedBox(width: 72),
                    ...items.map((item) => Expanded(
                          child: Text(
                            item.schemeCode,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 4),
                const Divider(),
                // Score bars
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              item.schemeCode.length > 6
                                  ? item.schemeCode.substring(0, 6)
                                  : item.schemeCode,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: Colors.white54, fontSize: 9),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: ScoreBar(score: item.score)),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 4),
                // Metric rows
                ...metrics.entries.map((entry) {
                  final metricWinner = summary?.metricWinners[entry.key];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            entry.key,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: Colors.white54),
                          ),
                        ),
                        for (int i = 0; i < items.length; i++)
                          Expanded(
                            child: Text(
                              entry.value[i],
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight:
                                    metricWinner == items[i].schemeCode
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget _winnerBadge(ThemeData theme, ComparisonSummary summary) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded,
              size: 18, color: AppTheme.accentGreen),
          const SizedBox(width: 8),
          Text(
            '${summary.winner} wins by ${summary.scoreDelta.toStringAsFixed(1)} pts',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.accentGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _emptyState(BuildContext context, String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.compare_arrows_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.20),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    ),
  );
}

Widget _selectedChips(
  BuildContext context, {
  required List<String> ids,
  required ValueChanged<String> onRemove,
  required VoidCallback onClear,
}) {
  return Row(
    children: [
      Expanded(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ids
              .map((id) => Chip(
                    label: Text(id),
                    onDeleted: () => onRemove(id),
                    visualDensity: VisualDensity.compact,
                  ))
              .toList(),
        ),
      ),
      TextButton(
        onPressed: ids.isEmpty ? null : onClear,
        child: const Text('Clear'),
      ),
    ],
  );
}

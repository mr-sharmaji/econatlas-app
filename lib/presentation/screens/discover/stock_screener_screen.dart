import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_utils.dart';
import '../../providers/discover_providers.dart';
import '../../widgets/shimmer_loading.dart';
import 'widgets/stock_list_tile.dart';

// ---------------------------------------------------------------------------
// Preset icon mapping
// ---------------------------------------------------------------------------
const _presetIcons = <DiscoverStockPreset, IconData>{
  DiscoverStockPreset.all: Icons.apps,
  DiscoverStockPreset.momentum: Icons.trending_up,
  DiscoverStockPreset.value: Icons.diamond_outlined,
  DiscoverStockPreset.lowVolatility: Icons.shield_outlined,
  DiscoverStockPreset.highVolume: Icons.bar_chart,
  DiscoverStockPreset.breakout: Icons.rocket_launch_outlined,
  DiscoverStockPreset.quality: Icons.verified_outlined,
  DiscoverStockPreset.dividend: Icons.payments_outlined,
  DiscoverStockPreset.largeCap: Icons.business_outlined,
  DiscoverStockPreset.midCap: Icons.domain_outlined,
  DiscoverStockPreset.smallCap: Icons.store_outlined,
};

// ---------------------------------------------------------------------------
// Sort options
// ---------------------------------------------------------------------------
const _sortOptions = [
  (value: 'score', label: 'Score'),
  (value: 'change_3m', label: 'Change 3M'),
  (value: 'change_1y', label: 'Change 1Y'),
  (value: 'market_cap', label: 'Market Cap'),
];

const _smartSorts = [
  (label: 'Top Quality', sortBy: 'score', sortOrder: 'desc', icon: Icons.verified_outlined),
  (label: 'Best 1Y Gain', sortBy: 'change_1y', sortOrder: 'desc', icon: Icons.trending_up_rounded),
  (label: 'Most Active', sortBy: 'change_3m', sortOrder: 'desc', icon: Icons.speed_rounded),
  (label: 'Blue Chips', sortBy: 'market_cap', sortOrder: 'desc', icon: Icons.business_outlined),
];

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class StockScreenerScreen extends ConsumerStatefulWidget {
  final String? initialSearch;
  final String? initialPreset;
  final String? initialFilterKey;
  final String? initialFilterValue;

  const StockScreenerScreen({
    super.key,
    this.initialSearch,
    this.initialPreset,
    this.initialFilterKey,
    this.initialFilterValue,
  });

  @override
  ConsumerState<StockScreenerScreen> createState() =>
      _StockScreenerScreenState();
}

class _StockScreenerScreenState extends ConsumerState<StockScreenerScreen> {
  late final TextEditingController _searchController;
  late final ScrollController _listScrollController;
  Timer? _debounce;

  /// Tracks which top-level segment is selected (All, Strategy, Market Cap).
  String _selectedSegment = 'All';

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.initialSearch ?? '');
    _listScrollController = ScrollController();
    _listScrollController.addListener(_onScroll);
    if (widget.initialPreset != null) {
      final preset = DiscoverStockPreset.values.firstWhere(
        (p) => p.apiValue == widget.initialPreset,
        orElse: () => DiscoverStockPreset.all,
      );
      Future.microtask(() {
        ref.read(discoverStockPresetProvider.notifier).setPreset(preset);
      });
      _selectedSegment = _segmentForPreset(preset);
    }
    if (widget.initialFilterKey == 'sector' &&
        widget.initialFilterValue != null) {
      Future.microtask(() {
        final current = ref.read(discoverStockFiltersProvider);
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
              current.copyWith(sector: widget.initialFilterValue!),
            );
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_listScrollController.hasClients) return;
    final pos = _listScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      ref.read(discoverStocksProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String text) {
    setState(() {}); // Update clear-button visibility
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final current = ref.read(discoverStockFiltersProvider);
      ref
          .read(discoverStockFiltersProvider.notifier)
          .setFilters(current.copyWith(search: text));
    });
  }

  /// Map sort field to which change field to display in tiles.
  StockChangeField _changeFieldForSort(String sortBy) {
    switch (sortBy) {
      case 'change_3m':
        return StockChangeField.threeMonth;
      case 'change_1y':
        return StockChangeField.oneYear;
      case 'change':
        return StockChangeField.daily;
      default:
        return StockChangeField.threeMonth;
    }
  }

  /// Map sort field to sparkline days.
  int _sparklineDaysForSort(String sortBy) {
    switch (sortBy) {
      case 'change':
        return 7;
      case 'change_1y':
        return 365;
      default:
        return 90;
    }
  }

  /// Returns which segment a given preset belongs to.
  String _segmentForPreset(DiscoverStockPreset preset) {
    if (preset == DiscoverStockPreset.all) return 'All';
    for (final seg in DiscoverStockPresetX.segmentLabels) {
      if (DiscoverStockPresetX.subPresetsFor(seg).contains(preset)) {
        return seg;
      }
    }
    return 'All';
  }

  void _showSortSheet() {
    final filters = ref.read(discoverStockFiltersProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Sort By', style: theme.textTheme.titleSmall),
                ),
                ..._sortOptions.map((opt) {
                  final isSelected = filters.sortBy == opt.value;
                  return ListTile(
                    dense: true,
                    title: Text(opt.label),
                    trailing: isSelected
                        ? Icon(
                            filters.sortOrder == 'desc'
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    selected: isSelected,
                    onTap: () {
                      final newOrder = isSelected
                          ? (filters.sortOrder == 'desc' ? 'asc' : 'desc')
                          : 'desc';
                      ref
                          .read(discoverStockFiltersProvider.notifier)
                          .setFilters(filters.copyWith(
                            sortBy: opt.value,
                            sortOrder: newOrder,
                          ));
                      Navigator.pop(ctx);
                    },
                  );
                }),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text('Smart Sorts', style: theme.textTheme.titleSmall),
                ),
                ..._smartSorts.map((smart) {
                  final isActive = filters.sortBy == smart.sortBy &&
                      filters.sortOrder == smart.sortOrder;
                  return ListTile(
                    dense: true,
                    leading: Icon(smart.icon, size: 20,
                        color: isActive ? theme.colorScheme.primary : null),
                    title: Text(smart.label),
                    selected: isActive,
                    onTap: () {
                      ref
                          .read(discoverStockFiltersProvider.notifier)
                          .setFilters(filters.copyWith(
                            sortBy: smart.sortBy,
                            sortOrder: smart.sortOrder,
                          ));
                      Navigator.pop(ctx);
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preset = ref.watch(discoverStockPresetProvider);
    final filters = ref.watch(discoverStockFiltersProvider);
    final stocksAsync = ref.watch(discoverStocksProvider);
    final changeField = _changeFieldForSort(filters.sortBy);

    return Scaffold(
      appBar: AppBar(title: const Text('Stocks')),
      body: Column(
        children: [
          // Row 1: Search field (full width)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              controller: _searchController,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Search stocks...',
                hintStyle: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, size: 20),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {});
                          ref
                              .read(discoverStockFiltersProvider.notifier)
                              .setFilters(ref
                                  .read(discoverStockFiltersProvider)
                                  .copyWith(search: ''));
                        },
                        child: const Icon(Icons.clear, size: 18),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(minWidth: 36),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.10),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Row 2: SegmentedButton (All / Strategy / Market Cap)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: DiscoverStockPresetX.segmentLabels.map((seg) {
                  return ButtonSegment(
                    value: seg,
                    label: Text(seg, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                selected: {_selectedSegment},
                onSelectionChanged: (selected) {
                  final seg = selected.first;
                  setState(() => _selectedSegment = seg);
                  if (seg == 'All') {
                    ref
                        .read(discoverStockPresetProvider.notifier)
                        .setPreset(DiscoverStockPreset.all);
                  }
                  // When selecting a segment, pick the first sub-preset
                  final subs = DiscoverStockPresetX.subPresetsFor(seg);
                  if (subs.isNotEmpty) {
                    ref
                        .read(discoverStockPresetProvider.notifier)
                        .setPreset(subs.first);
                  }
                  if (_searchController.text.isNotEmpty) {
                    _searchController.clear();
                    setState(() {});
                    ref
                        .read(discoverStockFiltersProvider.notifier)
                        .setFilters(ref
                            .read(discoverStockFiltersProvider)
                            .copyWith(search: ''));
                  }
                },
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),

          // Row 3: Sub-preset chips (conditional on segment)
          if (_selectedSegment != 'All') _buildSubPresetChips(preset),

          const SizedBox(height: 4),

          // Results
          Expanded(
            child: stocksAsync.when(
              loading: () =>
                  const ShimmerList(itemCount: 8, itemHeight: 90),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.white24),
                    const SizedBox(height: 12),
                    Text(
                      friendlyErrorMessage(err),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white54),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(discoverStocksProvider),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (paginatedState) {
                final items = paginatedState.items;
                final hasMore = paginatedState.isLoadingMore;
                final allLoaded = !hasMore && items.isNotEmpty;
                final totalCount = paginatedState.totalCount;
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded,
                            size: 48, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text(
                          'No stocks found',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                }

                // Fetch sparklines for visible items
                final symbolsCsv = items.map((e) => e.symbol).join(',');
                final sparkDays = _sparklineDaysForSort(filters.sortBy);
                final sparkAsync = ref.watch(
                  discoverStockSparklinesProvider(
                    (symbolsCsv: symbolsCsv, days: sparkDays),
                  ),
                );
                final sparkMap = sparkAsync.valueOrNull ?? {};

                final sortLabel = _smartSorts
                        .where((s) => s.sortBy == filters.sortBy && s.sortOrder == filters.sortOrder)
                        .map((s) => s.label)
                        .firstOrNull ??
                    _sortOptions
                        .firstWhere((o) => o.value == filters.sortBy,
                            orElse: () => _sortOptions.first)
                        .label;

                return Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(discoverStocksProvider);
                      },
                      child: ListView.builder(
                        controller: _listScrollController,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 60),
                        itemCount: items.length +
                            (hasMore ? 1 : 0) + (allLoaded ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= items.length && hasMore) {
                            return const ShimmerInlineRow(height: 80);
                          }
                          if (index >= items.length && allLoaded) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16),
                              child: Center(
                                child: Text(
                                  '${items.length} results',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: Colors.white38),
                                ),
                              ),
                            );
                          }
                          final item = items[index];
                          final sparkVals = sparkMap[item.symbol]
                              ?.map((p) => p.value)
                              .toList();
                          return StockListTile(
                            item: item,
                            changeField: changeField,
                            sparklineValues: sparkVals,
                            onTap: () => context.push(
                              '/discover/stock/${Uri.encodeComponent(item.symbol)}',
                              extra: item,
                            ),
                          );
                        },
                      ),
                    ),
                    // Sticky bottom sort pill
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _showSortSheet,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface
                                    .withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.3),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sort_rounded,
                                      size: 16,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    sortLabel,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    filters.sortOrder == 'desc'
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                  if (totalCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '$totalCount',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: Colors.white38),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubPresetChips(DiscoverStockPreset selectedPreset) {
    final subs = DiscoverStockPresetX.subPresetsFor(_selectedSegment);
    if (subs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: subs.map((sub) {
            final isSelected = selectedPreset == sub;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                avatar: Icon(
                  _presetIcons[sub] ?? Icons.apps,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                label: Text(sub.label),
                labelStyle: isSelected
                    ? const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      )
                    : null,
                selected: isSelected,
                showCheckmark: false,
                onSelected: (_) {
                  ref
                      .read(discoverStockPresetProvider.notifier)
                      .setPreset(sub);
                  if (_searchController.text.isNotEmpty) {
                    _searchController.clear();
                    setState(() {});
                    ref
                        .read(discoverStockFiltersProvider.notifier)
                        .setFilters(ref
                            .read(discoverStockFiltersProvider)
                            .copyWith(search: ''));
                  }
                },
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

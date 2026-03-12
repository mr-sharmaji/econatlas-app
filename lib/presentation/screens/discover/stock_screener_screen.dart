import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_utils.dart';
import '../../providers/discover_providers.dart';
import '../../widgets/shimmer_loading.dart';
import 'widgets/sort_bar.dart';
import 'widgets/stock_list_tile.dart';

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
        orElse: () => DiscoverStockPreset.momentum,
      );
      Future.microtask(() {
        ref.read(discoverStockPresetProvider.notifier).setPreset(preset);
      });
    }
    if (widget.initialFilterKey == 'sector' && widget.initialFilterValue != null) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preset = ref.watch(discoverStockPresetProvider);
    final filters = ref.watch(discoverStockFiltersProvider);
    final stocksAsync = ref.watch(discoverStocksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stocks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showAdvancedFilters(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search stocks...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                          ref
                              .read(discoverStockFiltersProvider.notifier)
                              .setFilters(ref
                                  .read(discoverStockFiltersProvider)
                                  .copyWith(search: ''));
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.10),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Preset chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: DiscoverStockPreset.values.map((option) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(option.label),
                    selected: preset == option,
                    onSelected: (_) {
                      ref
                          .read(discoverStockPresetProvider.notifier)
                          .setPreset(option);
                      // Clear search when switching presets
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
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Sort bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SortBar(
              sortBy: filters.sortBy,
              sortOrder: filters.sortOrder,
              options: const [
                SortOption(value: 'score', label: 'Score'),
                SortOption(value: 'change', label: 'Change'),
                SortOption(value: 'volume', label: 'Volume'),
                SortOption(value: 'pe', label: 'P/E'),
                SortOption(value: 'roe', label: 'ROE'),
                SortOption(value: 'price', label: 'Price'),
                SortOption(value: 'market_cap', label: 'Mkt Cap'),
              ],
              onSortByChanged: (value) {
                final current = ref.read(discoverStockFiltersProvider);
                ref
                    .read(discoverStockFiltersProvider.notifier)
                    .setFilters(current.copyWith(sortBy: value));
              },
              onSortOrderChanged: (value) {
                final current = ref.read(discoverStockFiltersProvider);
                ref
                    .read(discoverStockFiltersProvider.notifier)
                    .setFilters(current.copyWith(sortOrder: value));
              },
            ),
          ),

          const SizedBox(height: 8),

          // Results list
          Expanded(
            child: stocksAsync.when(
              loading: () =>
                  const ShimmerList(itemCount: 8, itemHeight: 90),
              error: (err, _) => Center(
                child: Text(
                  friendlyErrorMessage(err),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white54),
                ),
              ),
              data: (paginatedState) {
                final items = paginatedState.items;
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'No stocks match',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white54),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(discoverStocksProvider);
                  },
                  child: ListView.builder(
                    controller: _listScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount:
                        items.length + (paginatedState.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      final item = items[index];
                      return StockListTile(
                        item: item,
                        onTap: () => context.push(
                          '/discover/stock/${Uri.encodeComponent(item.symbol)}',
                          extra: item,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAdvancedFilters(BuildContext context) {
    final current = ref.read(discoverStockFiltersProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        double localMinScore = current.minScore;
        String localSector = current.sector;
        final minPeController = TextEditingController(
          text: current.minPe?.toString() ?? '',
        );
        final maxPeController = TextEditingController(
          text: current.maxPe?.toString() ?? '',
        );

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Min Score
                    Text(
                      'Min Score: ${localMinScore.round()}',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    Slider(
                      value: localMinScore,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: localMinScore.round().toString(),
                      onChanged: (v) => setSheetState(() {
                        localMinScore = v;
                      }),
                    ),

                    const SizedBox(height: 12),

                    // Sector
                    DropdownButtonFormField<String>(
                      value: localSector,
                      decoration: const InputDecoration(
                        labelText: 'Sector',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(
                            value: 'Financials', child: Text('Financials')),
                        DropdownMenuItem(value: 'IT', child: Text('IT')),
                        DropdownMenuItem(
                            value: 'Energy', child: Text('Energy')),
                        DropdownMenuItem(
                            value: 'Healthcare', child: Text('Healthcare')),
                        DropdownMenuItem(
                            value: 'Consumer', child: Text('Consumer')),
                        DropdownMenuItem(value: 'Auto', child: Text('Auto')),
                        DropdownMenuItem(
                            value: 'Industrials', child: Text('Industrials')),
                        DropdownMenuItem(
                            value: 'Materials', child: Text('Materials')),
                        DropdownMenuItem(
                            value: 'Telecom', child: Text('Telecom')),
                        DropdownMenuItem(
                            value: 'Real Estate', child: Text('Real Estate')),
                        DropdownMenuItem(
                            value: 'Media', child: Text('Media')),
                        DropdownMenuItem(
                            value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) => setSheetState(() {
                        localSector = v ?? 'All';
                      }),
                    ),

                    const SizedBox(height: 12),

                    // P/E range
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minPeController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Min P/E',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxPeController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Max P/E',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              ref
                                  .read(discoverStockFiltersProvider.notifier)
                                  .setFilters(const DiscoverStockFilters());
                              _searchController.clear();
                              Navigator.pop(ctx);
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final minPe =
                                  double.tryParse(minPeController.text);
                              final maxPe =
                                  double.tryParse(maxPeController.text);
                              ref
                                  .read(discoverStockFiltersProvider.notifier)
                                  .setFilters(
                                    current.copyWith(
                                      minScore: localMinScore,
                                      sector: localSector,
                                      minPe: minPe,
                                      maxPe: maxPe,
                                    ),
                                  );
                              Navigator.pop(ctx);
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

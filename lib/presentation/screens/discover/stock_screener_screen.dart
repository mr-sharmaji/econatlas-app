import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_utils.dart';
import '../../providers/discover_providers.dart';
import '../../widgets/shimmer_loading.dart';
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

  static const _sortOptions = [
    (value: 'score', label: 'Score'),
    (value: 'change', label: 'Change'),
    (value: 'volume', label: 'Volume'),
    (value: 'pe', label: 'P/E'),
    (value: 'roe', label: 'ROE'),
    (value: 'price', label: 'Price'),
    (value: 'market_cap', label: 'Mkt Cap'),
  ];

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

  bool _hasActiveFilters(DiscoverStockFilters filters) {
    return filters.sector != 'All' ||
        filters.minScore != 40 ||
        filters.minPe != null ||
        filters.maxPe != null ||
        filters.minRoe != null ||
        filters.maxDebtToEquity != null ||
        filters.minMarketCap != null ||
        filters.maxMarketCap != null ||
        filters.minDividendYield != null ||
        filters.minPb != null ||
        filters.maxPb != null ||
        filters.minPrice != null ||
        filters.maxPrice != null ||
        filters.minRoce != null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preset = ref.watch(discoverStockPresetProvider);
    final filters = ref.watch(discoverStockFiltersProvider);
    final stocksAsync = ref.watch(discoverStocksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stocks')),
      body: Column(
        children: [
          // Row 1: Search + Sort dropdown + Filter icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Search field
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search stocks...',
                      hintStyle: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 40),
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
                      suffixIconConstraints:
                          const BoxConstraints(minWidth: 36),
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
                const SizedBox(width: 8),
                // Sort dropdown
                SizedBox(
                  height: 40,
                  child: PopupMenuButton<String>(
                    onSelected: (value) {
                      ref
                          .read(discoverStockFiltersProvider.notifier)
                          .setFilters(filters.copyWith(sortBy: value));
                    },
                    itemBuilder: (_) => _sortOptions
                        .map((opt) => PopupMenuItem(
                              value: opt.value,
                              child: Text(opt.label,
                                  style: theme.textTheme.bodySmall),
                            ))
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _sortOptions
                                .firstWhere((o) => o.value == filters.sortBy,
                                    orElse: () => _sortOptions.first)
                                .label,
                            style: theme.textTheme.labelSmall,
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            filters.sortOrder == 'desc'
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Sort order toggle
                SizedBox(
                  width: 32,
                  height: 40,
                  child: IconButton(
                    icon: Icon(
                      filters.sortOrder == 'desc'
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 16,
                    ),
                    onPressed: () {
                      ref
                          .read(discoverStockFiltersProvider.notifier)
                          .setFilters(filters.copyWith(
                              sortOrder:
                                  filters.sortOrder == 'desc' ? 'asc' : 'desc'));
                    },
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tooltip:
                        filters.sortOrder == 'desc' ? 'Descending' : 'Ascending',
                  ),
                ),
                // Filter icon
                SizedBox(
                  width: 32,
                  height: 40,
                  child: IconButton(
                    icon: Icon(
                      Icons.tune,
                      size: 18,
                      color: _hasActiveFilters(filters)
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    onPressed: () => _showAdvancedFilters(context),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),

          // Row 2: Preset chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: DiscoverStockPreset.values.map((option) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(option.label),
                    selected: preset == option,
                    onSelected: (_) {
                      ref
                          .read(discoverStockPresetProvider.notifier)
                          .setPreset(option);
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

          // Row 3: Active filter chips (conditional)
          _buildActiveFilterChips(theme, filters),

          const SizedBox(height: 4),

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

  Widget _buildActiveFilterChips(
      ThemeData theme, DiscoverStockFilters filters) {
    final chips = <Widget>[];

    if (filters.sector != 'All') {
      chips.add(_filterChip(filters.sector, () {
        ref
            .read(discoverStockFiltersProvider.notifier)
            .setFilters(filters.copyWith(sector: 'All'));
      }));
    }
    if (filters.minScore != 40) {
      chips.add(_filterChip('Score ≥${filters.minScore.round()}', () {
        ref
            .read(discoverStockFiltersProvider.notifier)
            .setFilters(filters.copyWith(minScore: 40));
      }));
    }
    if (filters.minPe != null) {
      chips.add(_filterChip('P/E ≥${filters.minPe!.round()}', () {
        ref
            .read(discoverStockFiltersProvider.notifier)
            .setFilters(const DiscoverStockFilters().copyWith(
              search: filters.search,
              sector: filters.sector,
              sortBy: filters.sortBy,
              sortOrder: filters.sortOrder,
              minScore: filters.minScore,
              maxPe: filters.maxPe,
            ));
      }));
    }
    if (filters.maxPe != null) {
      chips.add(_filterChip('P/E ≤${filters.maxPe!.round()}', () {
        ref
            .read(discoverStockFiltersProvider.notifier)
            .setFilters(const DiscoverStockFilters().copyWith(
              search: filters.search,
              sector: filters.sector,
              sortBy: filters.sortBy,
              sortOrder: filters.sortOrder,
              minScore: filters.minScore,
              minPe: filters.minPe,
            ));
      }));
    }
    if (filters.minRoe != null) {
      chips.add(_filterChip('ROE ≥${filters.minRoe!.round()}%', () {
        ref
            .read(discoverStockFiltersProvider.notifier)
            .setFilters(const DiscoverStockFilters().copyWith(
              search: filters.search,
              sector: filters.sector,
              sortBy: filters.sortBy,
              sortOrder: filters.sortOrder,
              minScore: filters.minScore,
            ));
      }));
    }
    if (filters.maxDebtToEquity != null) {
      chips.add(_filterChip('D/E ≤${filters.maxDebtToEquity!.toStringAsFixed(1)}', () {
        ref
            .read(discoverStockFiltersProvider.notifier)
            .setFilters(const DiscoverStockFilters().copyWith(
              search: filters.search,
              sector: filters.sector,
              sortBy: filters.sortBy,
              sortOrder: filters.sortOrder,
              minScore: filters.minScore,
            ));
      }));
    }
    if (filters.minMarketCap != null || filters.maxMarketCap != null) {
      String label = 'Mkt Cap';
      if (filters.maxMarketCap != null && filters.maxMarketCap! <= 5000) {
        label = 'Small Cap';
      } else if (filters.minMarketCap != null && filters.minMarketCap! >= 50000) {
        label = 'Large Cap';
      } else {
        label = 'Mid Cap';
      }
      chips.add(_filterChip(label, () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
          filters.copyWith(minMarketCap: null, maxMarketCap: null),
        );
      }));
    }
    if (filters.minDividendYield != null) {
      chips.add(_filterChip('Div ≥${filters.minDividendYield!.toStringAsFixed(1)}%', () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
          filters.copyWith(minDividendYield: null),
        );
      }));
    }
    if (filters.minPb != null) {
      chips.add(_filterChip('P/B ≥${filters.minPb!.toStringAsFixed(1)}', () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
          filters.copyWith(minPb: null),
        );
      }));
    }
    if (filters.maxPb != null) {
      chips.add(_filterChip('P/B ≤${filters.maxPb!.toStringAsFixed(1)}', () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
          filters.copyWith(maxPb: null),
        );
      }));
    }
    if (filters.minRoce != null) {
      chips.add(_filterChip('ROCE ≥${filters.minRoce!.round()}%', () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
          filters.copyWith(minRoce: null),
        );
      }));
    }
    if (filters.minPrice != null) {
      chips.add(_filterChip('Price ≥₹${filters.minPrice!.round()}', () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
          filters.copyWith(minPrice: null),
        );
      }));
    }
    if (filters.maxPrice != null) {
      chips.add(_filterChip('Price ≤₹${filters.maxPrice!.round()}', () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
          filters.copyWith(maxPrice: null),
        );
      }));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    chips.add(ActionChip(
      label: Text('Clear', style: theme.textTheme.labelSmall),
      onPressed: () {
        ref
            .read(discoverStockFiltersProvider.notifier)
            .setFilters(DiscoverStockFilters(
              search: filters.search,
              sortBy: filters.sortBy,
              sortOrder: filters.sortOrder,
            ));
      },
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
    );
  }

  Widget _filterChip(String label, VoidCallback onRemove) {
    return InputChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onDeleted: onRemove,
      deleteIconColor: Colors.white54,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
        String localMarketCapRange = current.minMarketCap == null && current.maxMarketCap == null
            ? 'All'
            : current.minMarketCap != null && current.minMarketCap! >= 50000
                ? 'Large'
                : current.maxMarketCap != null && current.maxMarketCap! <= 5000
                    ? 'Small'
                    : 'Mid';
        final minPeCtrl = TextEditingController(text: current.minPe?.toString() ?? '');
        final maxPeCtrl = TextEditingController(text: current.maxPe?.toString() ?? '');
        final minRoeCtrl = TextEditingController(text: current.minRoe?.toString() ?? '');
        final maxDeCtrl = TextEditingController(text: current.maxDebtToEquity?.toString() ?? '');
        final minDivCtrl = TextEditingController(text: current.minDividendYield?.toString() ?? '');
        final minPbCtrl = TextEditingController(text: current.minPb?.toString() ?? '');
        final maxPbCtrl = TextEditingController(text: current.maxPb?.toString() ?? '');
        final minPriceCtrl = TextEditingController(text: current.minPrice?.toString() ?? '');
        final maxPriceCtrl = TextEditingController(text: current.maxPrice?.toString() ?? '');
        final minRoceCtrl = TextEditingController(text: current.minRoce?.toString() ?? '');

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final theme = Theme.of(ctx);
            const inputDeco = InputDecoration(border: OutlineInputBorder(), isDense: true);
            const numKb = TextInputType.numberWithOptions(decimal: true);

            return Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filters', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),

                    // Score slider
                    Text('Min Score: ${localMinScore.round()}', style: theme.textTheme.titleSmall),
                    Slider(
                      value: localMinScore, min: 0, max: 100, divisions: 100,
                      label: localMinScore.round().toString(),
                      onChanged: (v) => setSheetState(() => localMinScore = v),
                    ),
                    const SizedBox(height: 8),

                    // Sector
                    DropdownButtonFormField<String>(
                      initialValue: localSector,
                      decoration: inputDeco.copyWith(labelText: 'Sector'),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Financials', child: Text('Financials')),
                        DropdownMenuItem(value: 'IT', child: Text('IT')),
                        DropdownMenuItem(value: 'Energy', child: Text('Energy')),
                        DropdownMenuItem(value: 'Healthcare', child: Text('Healthcare')),
                        DropdownMenuItem(value: 'Consumer', child: Text('Consumer')),
                        DropdownMenuItem(value: 'Auto', child: Text('Auto')),
                        DropdownMenuItem(value: 'Industrials', child: Text('Industrials')),
                        DropdownMenuItem(value: 'Materials', child: Text('Materials')),
                        DropdownMenuItem(value: 'Telecom', child: Text('Telecom')),
                        DropdownMenuItem(value: 'Real Estate', child: Text('Real Estate')),
                        DropdownMenuItem(value: 'Media', child: Text('Media')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) => setSheetState(() => localSector = v ?? 'All'),
                    ),
                    const SizedBox(height: 12),

                    // Market Cap
                    DropdownButtonFormField<String>(
                      initialValue: localMarketCapRange,
                      decoration: inputDeco.copyWith(labelText: 'Market Cap'),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Small', child: Text('Small (< 5K Cr)')),
                        DropdownMenuItem(value: 'Mid', child: Text('Mid (5K-50K Cr)')),
                        DropdownMenuItem(value: 'Large', child: Text('Large (> 50K Cr)')),
                      ],
                      onChanged: (v) => setSheetState(() => localMarketCapRange = v ?? 'All'),
                    ),
                    const SizedBox(height: 12),

                    // P/E range
                    Row(children: [
                      Expanded(child: TextField(controller: minPeCtrl, keyboardType: numKb, decoration: inputDeco.copyWith(labelText: 'Min P/E'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: maxPeCtrl, keyboardType: numKb, decoration: inputDeco.copyWith(labelText: 'Max P/E'))),
                    ]),
                    const SizedBox(height: 12),

                    // ROE + ROCE
                    Row(children: [
                      Expanded(child: TextField(controller: minRoeCtrl, keyboardType: numKb, decoration: inputDeco.copyWith(labelText: 'Min ROE %'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: minRoceCtrl, keyboardType: numKb, decoration: inputDeco.copyWith(labelText: 'Min ROCE %'))),
                    ]),
                    const SizedBox(height: 12),

                    // D/E + Dividend Yield
                    Row(children: [
                      Expanded(child: TextField(controller: maxDeCtrl, keyboardType: numKb, decoration: inputDeco.copyWith(labelText: 'Max D/E'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: minDivCtrl, keyboardType: numKb, decoration: inputDeco.copyWith(labelText: 'Min Div Yield %'))),
                    ]),
                    const SizedBox(height: 12),

                    // P/B range
                    Row(children: [
                      Expanded(child: TextField(controller: minPbCtrl, keyboardType: numKb, decoration: inputDeco.copyWith(labelText: 'Min P/B'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: maxPbCtrl, keyboardType: numKb, decoration: inputDeco.copyWith(labelText: 'Max P/B'))),
                    ]),
                    const SizedBox(height: 12),

                    // Price range
                    Row(children: [
                      Expanded(child: TextField(controller: minPriceCtrl, keyboardType: numKb, decoration: inputDeco.copyWith(labelText: 'Min Price'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: maxPriceCtrl, keyboardType: numKb, decoration: inputDeco.copyWith(labelText: 'Max Price'))),
                    ]),
                    const SizedBox(height: 20),

                    // Actions
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ref.read(discoverStockFiltersProvider.notifier)
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
                            double? minMcap, maxMcap;
                            if (localMarketCapRange == 'Small') {
                              maxMcap = 5000;
                            } else if (localMarketCapRange == 'Mid') {
                              minMcap = 5000;
                              maxMcap = 50000;
                            } else if (localMarketCapRange == 'Large') {
                              minMcap = 50000;
                            }
                            ref.read(discoverStockFiltersProvider.notifier).setFilters(
                              DiscoverStockFilters(
                                search: current.search,
                                sector: localSector,
                                minScore: localMinScore,
                                minPe: double.tryParse(minPeCtrl.text),
                                maxPe: double.tryParse(maxPeCtrl.text),
                                minRoe: double.tryParse(minRoeCtrl.text),
                                minRoce: double.tryParse(minRoceCtrl.text),
                                maxDebtToEquity: double.tryParse(maxDeCtrl.text),
                                minDividendYield: double.tryParse(minDivCtrl.text),
                                minPb: double.tryParse(minPbCtrl.text),
                                maxPb: double.tryParse(maxPbCtrl.text),
                                minPrice: double.tryParse(minPriceCtrl.text),
                                maxPrice: double.tryParse(maxPriceCtrl.text),
                                minMarketCap: minMcap,
                                maxMarketCap: maxMcap,
                                sortBy: current.sortBy,
                                sortOrder: current.sortOrder,
                              ),
                            );
                            Navigator.pop(ctx);
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ]),
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

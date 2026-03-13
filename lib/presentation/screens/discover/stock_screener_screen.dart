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

  int _activeFilterCount(DiscoverStockFilters filters) {
    int count = 0;
    if (filters.sector != 'All') count++;
    if (filters.minScore != 40) count++;
    if (filters.minPe != null) count++;
    if (filters.maxPe != null) count++;
    if (filters.minRoe != null) count++;
    if (filters.maxDebtToEquity != null) count++;
    if (filters.minMarketCap != null) count++;
    if (filters.maxMarketCap != null) count++;
    if (filters.minDividendYield != null) count++;
    if (filters.minPb != null) count++;
    if (filters.maxPb != null) count++;
    if (filters.minPrice != null) count++;
    if (filters.maxPrice != null) count++;
    if (filters.minRoce != null) count++;
    return count;
  }

  bool _hasActiveFilters(DiscoverStockFilters filters) {
    return _activeFilterCount(filters) > 0;
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
        return StockChangeField.daily;
    }
  }

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
          // Row 1: Search + Sort button + Filter icon
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
                // Sort button — single unified button with direction arrow
                _SortButton(
                  currentSort: filters.sortBy,
                  currentOrder: filters.sortOrder,
                  onSortChanged: (sortBy, sortOrder) {
                    ref
                        .read(discoverStockFiltersProvider.notifier)
                        .setFilters(filters.copyWith(
                          sortBy: sortBy,
                          sortOrder: sortOrder,
                        ));
                  },
                ),
                const SizedBox(width: 4),
                // Filter icon with badge
                SizedBox(
                  width: 36,
                  height: 40,
                  child: Badge(
                    isLabelVisible: _hasActiveFilters(filters),
                    label: Text('${_activeFilterCount(filters)}'),
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
                ),
              ],
            ),
          ),

          // Row 2: Preset chips (with "All" first)
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
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded,
                            size: 48, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text(
                          'No stocks match your filters',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: Colors.white54),
                        ),
                        if (_hasActiveFilters(filters)) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => ref
                                .read(discoverStockFiltersProvider.notifier)
                                .setFilters(const DiscoverStockFilters()),
                            icon: const Icon(Icons.filter_alt_off, size: 16),
                            label: const Text('Clear Filters'),
                          ),
                        ],
                      ],
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
                    itemCount: items.length + (hasMore ? 1 : 0) + (allLoaded ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= items.length && hasMore) {
                        return const ShimmerInlineRow(height: 80);
                      }
                      if (index >= items.length && allLoaded) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                      return StockListTile(
                        item: item,
                        changeField: changeField,
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
      chips.add(_filterChip('Score \u2265${filters.minScore.round()}', () {
        ref
            .read(discoverStockFiltersProvider.notifier)
            .setFilters(filters.copyWith(minScore: 40));
      }));
    }
    if (filters.minPe != null) {
      chips.add(_filterChip('P/E \u2265${filters.minPe!.round()}', () {
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
      chips.add(_filterChip('P/E \u2264${filters.maxPe!.round()}', () {
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
      chips.add(_filterChip('ROE \u2265${filters.minRoe!.round()}%', () {
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
      chips.add(_filterChip('D/E \u2264${filters.maxDebtToEquity!.toStringAsFixed(1)}', () {
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
      chips.add(_filterChip('Div \u2265${filters.minDividendYield!.toStringAsFixed(1)}%', () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
          filters.copyWith(minDividendYield: null),
        );
      }));
    }
    if (filters.minPb != null) {
      chips.add(_filterChip('P/B \u2265${filters.minPb!.toStringAsFixed(1)}', () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
          filters.copyWith(minPb: null),
        );
      }));
    }
    if (filters.maxPb != null) {
      chips.add(_filterChip('P/B \u2264${filters.maxPb!.toStringAsFixed(1)}', () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
          filters.copyWith(maxPb: null),
        );
      }));
    }
    if (filters.minRoce != null) {
      chips.add(_filterChip('ROCE \u2265${filters.minRoce!.round()}%', () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
          filters.copyWith(minRoce: null),
        );
      }));
    }
    if (filters.minPrice != null) {
      chips.add(_filterChip('Price \u2265\u20b9${filters.minPrice!.round()}', () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
          filters.copyWith(minPrice: null),
        );
      }));
    }
    if (filters.maxPrice != null) {
      chips.add(_filterChip('Price \u2264\u20b9${filters.maxPrice!.round()}', () {
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
      backgroundColor: const Color(0xFF0F1E31),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        double localMinScore = current.minScore;
        String localSector = current.sector;
        int localMarketCapIdx =
            current.minMarketCap == null && current.maxMarketCap == null
                ? 0
                : current.minMarketCap != null && current.minMarketCap! >= 50000
                    ? 3
                    : current.maxMarketCap != null &&
                            current.maxMarketCap! <= 5000
                        ? 1
                        : 2;
        final minPeCtrl =
            TextEditingController(text: current.minPe?.toString() ?? '');
        final maxPeCtrl =
            TextEditingController(text: current.maxPe?.toString() ?? '');
        final minRoeCtrl =
            TextEditingController(text: current.minRoe?.toString() ?? '');
        final minRoceCtrl =
            TextEditingController(text: current.minRoce?.toString() ?? '');
        final maxDeCtrl = TextEditingController(
            text: current.maxDebtToEquity?.toString() ?? '');
        final minDivCtrl = TextEditingController(
            text: current.minDividendYield?.toString() ?? '');
        final minPbCtrl =
            TextEditingController(text: current.minPb?.toString() ?? '');
        final maxPbCtrl =
            TextEditingController(text: current.maxPb?.toString() ?? '');
        final minPriceCtrl =
            TextEditingController(text: current.minPrice?.toString() ?? '');
        final maxPriceCtrl =
            TextEditingController(text: current.maxPrice?.toString() ?? '');

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final theme = Theme.of(ctx);
            const numKb = TextInputType.numberWithOptions(decimal: true);

            InputDecoration compactInput(String label) => InputDecoration(
                  labelText: label,
                  labelStyle:
                      theme.textTheme.labelSmall?.copyWith(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                );

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header: Filters + Reset
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Filters', style: theme.textTheme.titleMedium),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(discoverStockFiltersProvider.notifier)
                                .setFilters(const DiscoverStockFilters());
                            _searchController.clear();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Score Range
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Score Range',
                            style: theme.textTheme.titleSmall),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${localMinScore.round()}+',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: localMinScore,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      onChanged: (v) =>
                          setSheetState(() => localMinScore = v),
                    ),

                    const SizedBox(height: 12),

                    // Market Cap — SegmentedButton
                    Text('Market Cap', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('All')),
                          ButtonSegment(value: 1, label: Text('Small')),
                          ButtonSegment(value: 2, label: Text('Mid')),
                          ButtonSegment(value: 3, label: Text('Large')),
                        ],
                        selected: {localMarketCapIdx},
                        onSelectionChanged: (s) =>
                            setSheetState(() => localMarketCapIdx = s.first),
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: WidgetStatePropertyAll(
                            theme.textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Sector
                    DropdownButtonFormField<String>(
                      initialValue: localSector,
                      decoration: compactInput('Sector'),
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
                      onChanged: (v) =>
                          setSheetState(() => localSector = v ?? 'All'),
                    ),

                    const SizedBox(height: 16),

                    // ── Valuation ──
                    _sectionDivider(theme, 'Valuation'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                              controller: minPeCtrl,
                              keyboardType: numKb,
                              decoration: compactInput('Min P/E')),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('\u2014',
                              style: TextStyle(color: Colors.white38)),
                        ),
                        Expanded(
                          child: TextField(
                              controller: maxPeCtrl,
                              keyboardType: numKb,
                              decoration: compactInput('Max P/E')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                              controller: minPbCtrl,
                              keyboardType: numKb,
                              decoration: compactInput('Min P/B')),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('\u2014',
                              style: TextStyle(color: Colors.white38)),
                        ),
                        Expanded(
                          child: TextField(
                              controller: maxPbCtrl,
                              keyboardType: numKb,
                              decoration: compactInput('Max P/B')),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Quality ──
                    _sectionDivider(theme, 'Quality'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                              controller: minRoeCtrl,
                              keyboardType: numKb,
                              decoration: compactInput('Min ROE %')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                              controller: minRoceCtrl,
                              keyboardType: numKb,
                              decoration: compactInput('Min ROCE %')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: maxDeCtrl,
                      keyboardType: numKb,
                      decoration: compactInput('Max D/E'),
                    ),

                    const SizedBox(height: 16),

                    // ── Other ──
                    _sectionDivider(theme, 'Other'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: minDivCtrl,
                      keyboardType: numKb,
                      decoration: compactInput('Min Dividend Yield %'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                              controller: minPriceCtrl,
                              keyboardType: numKb,
                              decoration: compactInput('Min Price')),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('\u2014',
                              style: TextStyle(color: Colors.white38)),
                        ),
                        Expanded(
                          child: TextField(
                              controller: maxPriceCtrl,
                              keyboardType: numKb,
                              decoration: compactInput('Max Price')),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Apply button — full width
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          double? minMcap, maxMcap;
                          if (localMarketCapIdx == 1) {
                            maxMcap = 5000;
                          } else if (localMarketCapIdx == 2) {
                            minMcap = 5000;
                            maxMcap = 50000;
                          } else if (localMarketCapIdx == 3) {
                            minMcap = 50000;
                          }
                          ref
                              .read(discoverStockFiltersProvider.notifier)
                              .setFilters(
                                DiscoverStockFilters(
                                  search: current.search,
                                  sector: localSector,
                                  minScore: localMinScore,
                                  minPe: double.tryParse(minPeCtrl.text),
                                  maxPe: double.tryParse(maxPeCtrl.text),
                                  minRoe: double.tryParse(minRoeCtrl.text),
                                  minRoce: double.tryParse(minRoceCtrl.text),
                                  maxDebtToEquity:
                                      double.tryParse(maxDeCtrl.text),
                                  minDividendYield:
                                      double.tryParse(minDivCtrl.text),
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
                        child: const Text('Apply Filters'),
                      ),
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

  Widget _sectionDivider(ThemeData theme, String title) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.08))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white38,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.08))),
      ],
    );
  }
}

/// Unified sort button: shows current sort + direction.
/// Tapping opens a popup. Tapping the same option toggles direction.
class _SortButton extends StatelessWidget {
  final String currentSort;
  final String currentOrder;
  final void Function(String sortBy, String sortOrder) onSortChanged;

  const _SortButton({
    required this.currentSort,
    required this.currentOrder,
    required this.onSortChanged,
  });

  static const _options = [
    (value: 'score', label: 'Score'),
    (value: 'change', label: 'Change'),
    (value: 'change_3m', label: 'Change (3M)'),
    (value: 'change_1y', label: 'Change (1Y)'),
    (value: 'volume', label: 'Volume'),
    (value: 'pe', label: 'P/E'),
    (value: 'roe', label: 'ROE'),
    (value: 'price', label: 'Price'),
    (value: 'market_cap', label: 'Mkt Cap'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentLabel = _options
        .firstWhere((o) => o.value == currentSort,
            orElse: () => _options.first)
        .label;
    final isDesc = currentOrder == 'desc';

    return SizedBox(
      height: 40,
      child: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == currentSort) {
            // Toggle direction
            onSortChanged(currentSort, isDesc ? 'asc' : 'desc');
          } else {
            // New sort field, default to desc
            onSortChanged(value, 'desc');
          }
        },
        itemBuilder: (_) => _options.map((opt) {
          final isSelected = opt.value == currentSort;
          return PopupMenuItem(
            value: opt.value,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    opt.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    isDesc
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
          );
        }).toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(currentLabel, style: theme.textTheme.labelSmall),
              const SizedBox(width: 4),
              Icon(
                isDesc
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

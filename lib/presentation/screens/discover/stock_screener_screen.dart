import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_utils.dart';
import '../../../core/theme.dart';
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
};

// ---------------------------------------------------------------------------
// Sort options shared between the screen and the bottom sheet
// ---------------------------------------------------------------------------
const _sortOptions = [
  (value: 'score', label: 'Score'),
  (value: 'price', label: 'Price'),
  (value: 'pe', label: 'P/E'),
  (value: 'change', label: 'Change'),
  (value: 'change_3m', label: 'Change 3M'),
  (value: 'change_1y', label: 'Change 1Y'),
  (value: 'volume', label: 'Volume'),
  (value: 'roe', label: 'ROE'),
  (value: 'market_cap', label: 'Mkt Cap'),
];

// ---------------------------------------------------------------------------
// All sector labels
// ---------------------------------------------------------------------------
const _allSectors = [
  'All',
  'Financials',
  'IT',
  'Energy',
  'Healthcare',
  'Consumer',
  'Auto',
  'Industrials',
  'Materials',
  'Telecom',
  'Real Estate',
  'Media',
  'Capital Goods',
  'Consumer Durables',
  'Diversified',
  'Services',
  'Power',
  'Other',
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

  bool _hasActiveFilters(DiscoverStockFilters filters) =>
      _activeFilterCount(filters) > 0;

  /// Also count sort as "active" when it's not the default.
  int _sortAndFilterBadge(DiscoverStockFilters filters) {
    int count = _activeFilterCount(filters);
    if (filters.sortBy != 'score' || filters.sortOrder != 'desc') count++;
    return count;
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
          // Row 1: Search + Sort & Filter pill
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
                // Sort & Filter pill button
                _SortFilterPill(
                  badgeCount: _sortAndFilterBadge(filters),
                  onTap: () => _showSortAndFilterSheet(context),
                ),
              ],
            ),
          ),

          // Row 2: Preset chips with icons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: DiscoverStockPreset.values.map((option) {
                final isSelected = preset == option;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    avatar: Icon(
                      _presetIcons[option] ?? Icons.apps,
                      size: 16,
                      color: isSelected
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    label: Text(option.label),
                    selected: isSelected,
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
                    itemCount:
                        items.length + (hasMore ? 1 : 0) + (allLoaded ? 1 : 0),
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

  // ---------------------------------------------------------------------------
  // Active filter chips row
  // ---------------------------------------------------------------------------
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
      chips.add(
          _filterChip('D/E \u2264${filters.maxDebtToEquity!.toStringAsFixed(1)}', () {
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
      } else if (filters.minMarketCap != null &&
          filters.minMarketCap! >= 50000) {
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
      chips.add(_filterChip(
          'Div \u2265${filters.minDividendYield!.toStringAsFixed(1)}%', () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
              filters.copyWith(minDividendYield: null),
            );
      }));
    }
    if (filters.minPb != null) {
      chips.add(
          _filterChip('P/B \u2265${filters.minPb!.toStringAsFixed(1)}', () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
              filters.copyWith(minPb: null),
            );
      }));
    }
    if (filters.maxPb != null) {
      chips.add(
          _filterChip('P/B \u2264${filters.maxPb!.toStringAsFixed(1)}', () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
              filters.copyWith(maxPb: null),
            );
      }));
    }
    if (filters.minRoce != null) {
      chips.add(
          _filterChip('ROCE \u2265${filters.minRoce!.round()}%', () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
              filters.copyWith(minRoce: null),
            );
      }));
    }
    if (filters.minPrice != null) {
      chips.add(
          _filterChip('Price \u2265\u20b9${filters.minPrice!.round()}', () {
        ref.read(discoverStockFiltersProvider.notifier).setFilters(
              filters.copyWith(minPrice: null),
            );
      }));
    }
    if (filters.maxPrice != null) {
      chips.add(
          _filterChip('Price \u2264\u20b9${filters.maxPrice!.round()}', () {
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

  // ---------------------------------------------------------------------------
  // Unified Sort & Filter bottom sheet
  // ---------------------------------------------------------------------------
  void _showSortAndFilterSheet(BuildContext context) {
    final current = ref.read(discoverStockFiltersProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1E31),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _SortFilterSheetBody(
          initial: current,
          onApply: (newFilters) {
            ref
                .read(discoverStockFiltersProvider.notifier)
                .setFilters(newFilters);
            Navigator.pop(sheetContext);
          },
          onReset: () {
            ref
                .read(discoverStockFiltersProvider.notifier)
                .setFilters(const DiscoverStockFilters());
            _searchController.clear();
            Navigator.pop(sheetContext);
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Sort & Filter pill button
// ---------------------------------------------------------------------------
class _SortFilterPill extends StatelessWidget {
  final int badgeCount;
  final VoidCallback onTap;

  const _SortFilterPill({required this.badgeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActive = badgeCount > 0;

    return SizedBox(
      height: 40,
      child: Badge(
        isLabelVisible: hasActive,
        label: Text('$badgeCount'),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: hasActive
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.12),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune,
                    size: 16,
                    color:
                        hasActive ? theme.colorScheme.primary : null,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Sort & Filter',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: hasActive ? theme.colorScheme.primary : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sort & Filter bottom sheet body (StatefulWidget for local state)
// ---------------------------------------------------------------------------
class _SortFilterSheetBody extends StatefulWidget {
  final DiscoverStockFilters initial;
  final ValueChanged<DiscoverStockFilters> onApply;
  final VoidCallback onReset;

  const _SortFilterSheetBody({
    required this.initial,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_SortFilterSheetBody> createState() => _SortFilterSheetBodyState();
}

class _SortFilterSheetBodyState extends State<_SortFilterSheetBody> {
  // Sort
  late String _sortBy;
  late String _sortOrder;

  // Score
  late double _minScore;

  // Market cap
  late int _marketCapIdx; // 0=All, 1=Small, 2=Mid, 3=Large

  // Sector
  late String _sector;

  // Quick filters (toggle states)
  bool _lowPe = false;
  bool _fairPe = false;
  bool _highRoe = false;
  bool _lowDebt = false;
  bool _dividendPaying = false;
  bool _highRoce = false;

  // Advanced text controllers
  late final TextEditingController _minPeCtrl;
  late final TextEditingController _maxPeCtrl;
  late final TextEditingController _minPbCtrl;
  late final TextEditingController _maxPbCtrl;
  late final TextEditingController _minRoeCtrl;
  late final TextEditingController _minRoceCtrl;
  late final TextEditingController _maxDeCtrl;
  late final TextEditingController _minDivCtrl;
  late final TextEditingController _minPriceCtrl;
  late final TextEditingController _maxPriceCtrl;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;

    _sortBy = f.sortBy;
    _sortOrder = f.sortOrder;
    _minScore = f.minScore;
    _sector = f.sector;

    _marketCapIdx = f.minMarketCap == null && f.maxMarketCap == null
        ? 0
        : f.minMarketCap != null && f.minMarketCap! >= 50000
            ? 3
            : f.maxMarketCap != null && f.maxMarketCap! <= 5000
                ? 1
                : 2;

    // Detect quick filter states from current filters
    _lowPe = f.maxPe != null && f.maxPe == 15 && f.minPe == null;
    _fairPe = f.minPe == 15 && f.maxPe == 25;
    _highRoe = f.minRoe == 15;
    _lowDebt = f.maxDebtToEquity == 1;
    _dividendPaying = f.minDividendYield == 0.5;
    _highRoce = f.minRoce == 15;

    _minPeCtrl = TextEditingController(text: f.minPe?.toString() ?? '');
    _maxPeCtrl = TextEditingController(text: f.maxPe?.toString() ?? '');
    _minPbCtrl = TextEditingController(text: f.minPb?.toString() ?? '');
    _maxPbCtrl = TextEditingController(text: f.maxPb?.toString() ?? '');
    _minRoeCtrl = TextEditingController(text: f.minRoe?.toString() ?? '');
    _minRoceCtrl = TextEditingController(text: f.minRoce?.toString() ?? '');
    _maxDeCtrl =
        TextEditingController(text: f.maxDebtToEquity?.toString() ?? '');
    _minDivCtrl =
        TextEditingController(text: f.minDividendYield?.toString() ?? '');
    _minPriceCtrl = TextEditingController(text: f.minPrice?.toString() ?? '');
    _maxPriceCtrl = TextEditingController(text: f.maxPrice?.toString() ?? '');
  }

  @override
  void dispose() {
    _minPeCtrl.dispose();
    _maxPeCtrl.dispose();
    _minPbCtrl.dispose();
    _maxPbCtrl.dispose();
    _minRoeCtrl.dispose();
    _minRoceCtrl.dispose();
    _maxDeCtrl.dispose();
    _minDivCtrl.dispose();
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  void _toggleQuickFilter(String name, bool value) {
    setState(() {
      switch (name) {
        case 'lowPe':
          _lowPe = value;
          if (value) {
            _fairPe = false;
            _minPeCtrl.text = '';
            _maxPeCtrl.text = '15';
          } else {
            _maxPeCtrl.text = '';
          }
          break;
        case 'fairPe':
          _fairPe = value;
          if (value) {
            _lowPe = false;
            _minPeCtrl.text = '15';
            _maxPeCtrl.text = '25';
          } else {
            _minPeCtrl.text = '';
            _maxPeCtrl.text = '';
          }
          break;
        case 'highRoe':
          _highRoe = value;
          _minRoeCtrl.text = value ? '15' : '';
          break;
        case 'lowDebt':
          _lowDebt = value;
          _maxDeCtrl.text = value ? '1' : '';
          break;
        case 'dividendPaying':
          _dividendPaying = value;
          _minDivCtrl.text = value ? '0.5' : '';
          break;
        case 'highRoce':
          _highRoce = value;
          _minRoceCtrl.text = value ? '15' : '';
          break;
      }
    });
  }

  DiscoverStockFilters _buildFilters() {
    double? minMcap, maxMcap;
    if (_marketCapIdx == 1) {
      maxMcap = 5000;
    } else if (_marketCapIdx == 2) {
      minMcap = 5000;
      maxMcap = 50000;
    } else if (_marketCapIdx == 3) {
      minMcap = 50000;
    }

    return DiscoverStockFilters(
      search: widget.initial.search,
      sector: _sector,
      minScore: _minScore,
      sortBy: _sortBy,
      sortOrder: _sortOrder,
      minPe: double.tryParse(_minPeCtrl.text),
      maxPe: double.tryParse(_maxPeCtrl.text),
      minRoe: double.tryParse(_minRoeCtrl.text),
      minRoce: double.tryParse(_minRoceCtrl.text),
      maxDebtToEquity: double.tryParse(_maxDeCtrl.text),
      minDividendYield: double.tryParse(_minDivCtrl.text),
      minPb: double.tryParse(_minPbCtrl.text),
      maxPb: double.tryParse(_maxPbCtrl.text),
      minPrice: double.tryParse(_minPriceCtrl.text),
      maxPrice: double.tryParse(_maxPriceCtrl.text),
      minMarketCap: minMcap,
      maxMarketCap: maxMcap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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

            // Header: Sort & Filter + Reset
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sort & Filter', style: theme.textTheme.titleMedium),
                TextButton(
                  onPressed: widget.onReset,
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Sort By ──
            Text('Sort By', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _sortOptions.map((opt) {
                final isSelected = _sortBy == opt.value;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(opt.label),
                      if (isSelected) ...[
                        const SizedBox(width: 2),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _sortOrder =
                                  _sortOrder == 'desc' ? 'asc' : 'desc';
                            });
                          },
                          child: Icon(
                            _sortOrder == 'desc'
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            size: 14,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      if (_sortBy == opt.value) {
                        _sortOrder = _sortOrder == 'desc' ? 'asc' : 'desc';
                      } else {
                        _sortBy = opt.value;
                        _sortOrder = 'desc';
                      }
                    });
                  },
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Market Cap ──
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
                selected: {_marketCapIdx},
                onSelectionChanged: (s) =>
                    setState(() => _marketCapIdx = s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: WidgetStatePropertyAll(
                    theme.textTheme.labelSmall,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Sector ──
            Text('Sector', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _allSectors.map((sec) {
                final isSelected = _sector == sec;
                return FilterChip(
                  label: Text(sec),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _sector = sec),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Quick Filters ──
            Text('Quick Filters', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilterChip(
                  label: const Text('Low P/E (<15)'),
                  selected: _lowPe,
                  onSelected: (v) => _toggleQuickFilter('lowPe', v),
                  visualDensity: VisualDensity.compact,
                ),
                FilterChip(
                  label: const Text('Fair P/E (15-25)'),
                  selected: _fairPe,
                  onSelected: (v) => _toggleQuickFilter('fairPe', v),
                  visualDensity: VisualDensity.compact,
                ),
                FilterChip(
                  label: const Text('High ROE (>15%)'),
                  selected: _highRoe,
                  onSelected: (v) => _toggleQuickFilter('highRoe', v),
                  visualDensity: VisualDensity.compact,
                ),
                FilterChip(
                  label: const Text('Low Debt (D/E <1)'),
                  selected: _lowDebt,
                  onSelected: (v) => _toggleQuickFilter('lowDebt', v),
                  visualDensity: VisualDensity.compact,
                ),
                FilterChip(
                  label: const Text('Dividend Paying'),
                  selected: _dividendPaying,
                  onSelected: (v) => _toggleQuickFilter('dividendPaying', v),
                  visualDensity: VisualDensity.compact,
                ),
                FilterChip(
                  label: const Text('High ROCE (>15%)'),
                  selected: _highRoce,
                  onSelected: (v) => _toggleQuickFilter('highRoce', v),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Advanced (collapsible) ──
            ExpansionTile(
              title: Text('Advanced', style: theme.textTheme.titleSmall),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                const SizedBox(height: 8),
                // P/E
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minPeCtrl,
                        keyboardType: numKb,
                        decoration: compactInput('Min P/E'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child:
                          Text('\u2014', style: TextStyle(color: Colors.white38)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _maxPeCtrl,
                        keyboardType: numKb,
                        decoration: compactInput('Max P/E'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // P/B
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minPbCtrl,
                        keyboardType: numKb,
                        decoration: compactInput('Min P/B'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child:
                          Text('\u2014', style: TextStyle(color: Colors.white38)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _maxPbCtrl,
                        keyboardType: numKb,
                        decoration: compactInput('Max P/B'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // ROE / ROCE
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minRoeCtrl,
                        keyboardType: numKb,
                        decoration: compactInput('Min ROE %'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _minRoceCtrl,
                        keyboardType: numKb,
                        decoration: compactInput('Min ROCE %'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // D/E
                TextField(
                  controller: _maxDeCtrl,
                  keyboardType: numKb,
                  decoration: compactInput('Max D/E'),
                ),
                const SizedBox(height: 10),
                // Dividend Yield
                TextField(
                  controller: _minDivCtrl,
                  keyboardType: numKb,
                  decoration: compactInput('Min Dividend Yield %'),
                ),
                const SizedBox(height: 10),
                // Price
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minPriceCtrl,
                        keyboardType: numKb,
                        decoration: compactInput('Min Price'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child:
                          Text('\u2014', style: TextStyle(color: Colors.white38)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _maxPriceCtrl,
                        keyboardType: numKb,
                        decoration: compactInput('Max Price'),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Score Range ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Score Range', style: theme.textTheme.titleSmall),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_minScore.round()}+',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _minScore,
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: (v) => setState(() => _minScore = v),
            ),

            const SizedBox(height: 20),

            // Apply button — full width
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => widget.onApply(_buildFilters()),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

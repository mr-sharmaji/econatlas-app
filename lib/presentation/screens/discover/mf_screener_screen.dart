import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_utils.dart';
import '../../../core/theme.dart';
import '../../providers/discover_providers.dart';
import '../../widgets/shimmer_loading.dart';
import 'widgets/mf_list_tile.dart';

// ---------------------------------------------------------------------------
// Preset icon mapping
// ---------------------------------------------------------------------------
const _presetIcons = <DiscoverMutualFundPreset, IconData>{
  DiscoverMutualFundPreset.all: Icons.apps,
  DiscoverMutualFundPreset.equity: Icons.show_chart,
  DiscoverMutualFundPreset.debt: Icons.account_balance,
  DiscoverMutualFundPreset.hybrid: Icons.merge_type,
  DiscoverMutualFundPreset.largeCap: Icons.business,
  DiscoverMutualFundPreset.largeMidCap: Icons.domain,
  DiscoverMutualFundPreset.midCap: Icons.store,
  DiscoverMutualFundPreset.smallCap: Icons.storefront,
  DiscoverMutualFundPreset.flexiCap: Icons.auto_awesome,
  DiscoverMutualFundPreset.multiCap: Icons.grid_view,
  DiscoverMutualFundPreset.elss: Icons.savings,
  DiscoverMutualFundPreset.valueMf: Icons.diamond_outlined,
  DiscoverMutualFundPreset.focused: Icons.center_focus_strong,
  DiscoverMutualFundPreset.sectoral: Icons.category,
  DiscoverMutualFundPreset.indexFund: Icons.trending_up,
  DiscoverMutualFundPreset.shortDuration: Icons.timer,
  DiscoverMutualFundPreset.corporateBond: Icons.apartment,
  DiscoverMutualFundPreset.bankingPsu: Icons.account_balance_wallet,
  DiscoverMutualFundPreset.gilt: Icons.security,
  DiscoverMutualFundPreset.liquid: Icons.water_drop,
  DiscoverMutualFundPreset.overnight: Icons.nightlight_round,
  DiscoverMutualFundPreset.dynamicBond: Icons.swap_vert,
  DiscoverMutualFundPreset.moneyMarket: Icons.monetization_on,
  DiscoverMutualFundPreset.aggressiveHybrid: Icons.speed,
  DiscoverMutualFundPreset.balancedHybrid: Icons.balance,
  DiscoverMutualFundPreset.conservativeHybrid: Icons.shield_outlined,
  DiscoverMutualFundPreset.arbitrage: Icons.swap_horiz,
  DiscoverMutualFundPreset.dynamicAssetAllocation: Icons.auto_graph,
  DiscoverMutualFundPreset.multiAsset: Icons.pie_chart,
  DiscoverMutualFundPreset.equitySavings: Icons.savings,
  DiscoverMutualFundPreset.international: Icons.language,
  DiscoverMutualFundPreset.ultraShort: Icons.timer,
  DiscoverMutualFundPreset.lowDuration: Icons.hourglass_bottom,
  DiscoverMutualFundPreset.mediumDuration: Icons.hourglass_full,
  DiscoverMutualFundPreset.floater: Icons.waves,
  DiscoverMutualFundPreset.targetMaturity: Icons.flag,
  DiscoverMutualFundPreset.creditRisk: Icons.warning_amber,
  DiscoverMutualFundPreset.other: Icons.more_horiz,
  DiscoverMutualFundPreset.fofDomestic: Icons.folder_special,
  DiscoverMutualFundPreset.fofOverseas: Icons.public,
  DiscoverMutualFundPreset.goldSilver: Icons.diamond,
  DiscoverMutualFundPreset.retirement: Icons.elderly,
  DiscoverMutualFundPreset.children: Icons.child_care,
  DiscoverMutualFundPreset.lowRisk: Icons.verified_user,
};

class MfScreenerScreen extends ConsumerStatefulWidget {
  final String? initialSearch;
  final String? initialPreset;

  const MfScreenerScreen({super.key, this.initialSearch, this.initialPreset});

  @override
  ConsumerState<MfScreenerScreen> createState() => _MfScreenerScreenState();
}

class _MfScreenerScreenState extends ConsumerState<MfScreenerScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final TextEditingController _searchController;
  late final ScrollController _listScrollController;
  Timer? _debounce;

  /// Tracks which top-level segment is selected (All, Equity, Debt, Hybrid).
  DiscoverMutualFundPreset? _selectedSegment;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.initialSearch ?? '');
    _listScrollController = ScrollController();
    _listScrollController.addListener(_onScroll);
    if (widget.initialPreset != null) {
      final preset = DiscoverMutualFundPreset.values.firstWhere(
        (p) => p.apiValue == widget.initialPreset,
        orElse: () => DiscoverMutualFundPreset.all,
      );
      Future.microtask(() {
        ref.read(discoverMutualFundPresetProvider.notifier).setPreset(preset);
      });
      _selectedSegment = _segmentForPreset(preset);
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
      ref.read(discoverMutualFundsProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String text) {
    setState(() {}); // Update clear-button visibility
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final current = ref.read(discoverMutualFundFiltersProvider);
      ref
          .read(discoverMutualFundFiltersProvider.notifier)
          .setFilters(current.copyWith(search: text));
    });
  }

  int _activeFilterCount(DiscoverMutualFundFilters filters) {
    int count = 0;
    if (filters.minScore != 0) count++;
    if (filters.riskLevel != 'All') count++;
    if (filters.maxExpenseRatio != null) count++;
    if (filters.minReturn1y != null) count++;
    if (filters.minReturn3y != null) count++;
    if (filters.minReturn5y != null) count++;
    if (filters.minAumCr != null) count++;
    if (filters.minFundAge != null) count++;
    return count;
  }

  bool _hasActiveFilters(DiscoverMutualFundFilters filters) {
    return _activeFilterCount(filters) > 0;
  }

  bool _hasSortChanged(DiscoverMutualFundFilters filters) {
    return filters.sortBy != 'score' || filters.sortOrder != 'desc';
  }

  int _totalBadgeCount(DiscoverMutualFundFilters filters) {
    int count = _activeFilterCount(filters);
    if (_hasSortChanged(filters)) count++;
    return count;
  }

  /// Returns the parent segment for a given preset.
  DiscoverMutualFundPreset? _segmentForPreset(DiscoverMutualFundPreset preset) {
    if (preset == DiscoverMutualFundPreset.all) return null;
    if (preset == DiscoverMutualFundPreset.equity ||
        DiscoverMutualFundPresetX.equitySubCategories.contains(preset)) {
      return DiscoverMutualFundPreset.equity;
    }
    if (preset == DiscoverMutualFundPreset.debt ||
        DiscoverMutualFundPresetX.debtSubCategories.contains(preset)) {
      return DiscoverMutualFundPreset.debt;
    }
    if (preset == DiscoverMutualFundPreset.hybrid ||
        DiscoverMutualFundPresetX.hybridSubCategories.contains(preset)) {
      return DiscoverMutualFundPreset.hybrid;
    }
    if (preset == DiscoverMutualFundPreset.other ||
        DiscoverMutualFundPresetX.otherSubCategories.contains(preset)) {
      return DiscoverMutualFundPreset.other;
    }
    return null;
  }

  /// Returns sub-categories for the currently selected segment.
  List<DiscoverMutualFundPreset> _subCategoriesForSegment() {
    if (_selectedSegment == DiscoverMutualFundPreset.equity) {
      return DiscoverMutualFundPresetX.equitySubCategories;
    }
    if (_selectedSegment == DiscoverMutualFundPreset.debt) {
      return DiscoverMutualFundPresetX.debtSubCategories;
    }
    if (_selectedSegment == DiscoverMutualFundPreset.hybrid) {
      return DiscoverMutualFundPresetX.hybridSubCategories;
    }
    if (_selectedSegment == DiscoverMutualFundPreset.other) {
      return DiscoverMutualFundPresetX.otherSubCategories;
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedPreset = ref.watch(discoverMutualFundPresetProvider);
    final filters = ref.watch(discoverMutualFundFiltersProvider);
    final mfAsync = ref.watch(discoverMutualFundsProvider);
    final badgeCount = _totalBadgeCount(filters);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: const Text('Mutual Funds'), actions: const []),
      endDrawer: _buildFilterDrawer(filters),
      endDrawerEnableOpenDragGesture: false,
      body: Column(
        children: [
          // Row 1: Search + Sort & Filter pill button
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
                      hintText: 'Search funds...',
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
                                    .read(discoverMutualFundFiltersProvider
                                        .notifier)
                                    .setFilters(ref
                                        .read(
                                            discoverMutualFundFiltersProvider)
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
                // Unified Sort & Filter pill button
                Badge(
                  isLabelVisible: badgeCount > 0,
                  label: Text('$badgeCount'),
                  child: ActionChip(
                    avatar: Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: badgeCount > 0
                          ? theme.colorScheme.primary
                          : Colors.white70,
                    ),
                    label: Text(
                      'Sort & Filter',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: badgeCount > 0
                            ? theme.colorScheme.primary
                            : null,
                      ),
                    ),
                    onPressed: () => _showSortAndFilterSheet(context),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: badgeCount > 0
                            ? theme.colorScheme.primary.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Row 2: Tiered segment selector (All / Equity / Debt / Hybrid)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: DiscoverMutualFundPresetX.segments.map((segment) {
                final isAll = segment == DiscoverMutualFundPreset.all;
                final selected = isAll
                    ? _selectedSegment == null &&
                        selectedPreset == DiscoverMutualFundPreset.all
                    : _selectedSegment == segment;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: Icon(
                      _presetIcons[segment] ?? Icons.apps,
                      size: 16,
                      color: selected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    label: Text(segment.label),
                    labelStyle: selected
                        ? const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          )
                        : null,
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() {
                        if (isAll) {
                          _selectedSegment = null;
                        } else {
                          _selectedSegment = segment;
                        }
                      });
                      ref
                          .read(discoverMutualFundPresetProvider.notifier)
                          .setPreset(segment);
                      // Clear search when switching segments
                      if (_searchController.text.isNotEmpty) {
                        _searchController.clear();
                        setState(() {});
                        ref
                            .read(discoverMutualFundFiltersProvider.notifier)
                            .setFilters(ref
                                .read(discoverMutualFundFiltersProvider)
                                .copyWith(search: ''));
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),

          // Row 3: Sub-category chips (conditional on segment selection)
          if (_selectedSegment != null) _buildSubCategoryChips(selectedPreset),

          // Row 4: Active filter chips (conditional)
          _buildActiveFilterChips(theme, filters),

          const SizedBox(height: 4),

          // Results
          Expanded(
            child: mfAsync.when(
              loading: () =>
                  const ShimmerList(itemCount: 8, itemHeight: 96),
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
                          ref.invalidate(discoverMutualFundsProvider),
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
                          'No mutual funds match your filters',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: Colors.white54),
                        ),
                        if (_hasActiveFilters(filters)) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => ref
                                .read(discoverMutualFundFiltersProvider.notifier)
                                .setFilters(const DiscoverMutualFundFilters()),
                            icon: const Icon(Icons.filter_alt_off, size: 16),
                            label: const Text('Clear Filters'),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                // Fetch sparklines for visible items
                final codesCsv = items.map((e) => e.schemeCode).join(',');
                final sparkAsync = ref.watch(
                  discoverMfSparklinesProvider(
                    (codesCsv: codesCsv, days: 365),
                  ),
                );
                final sparkMap = sparkAsync.valueOrNull ?? {};

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(discoverMutualFundsProvider);
                  },
                  child: ListView.builder(
                    controller: _listScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount:
                        items.length + (hasMore ? 1 : 0) + (allLoaded ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= items.length && hasMore) {
                        return const ShimmerInlineRow(height: 86);
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
                      final sparkVals = sparkMap[item.schemeCode]
                          ?.map((p) => p.value)
                          .toList();
                      return MfListTile(
                        item: item,
                        sparklineValues: sparkVals,
                        onTap: () {
                          context.push(
                            '/discover/mf/${Uri.encodeComponent(item.schemeCode)}',
                            extra: item,
                          );
                        },
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

  Widget _buildSubCategoryChips(DiscoverMutualFundPreset selectedPreset) {
    final subCategories = _subCategoriesForSegment();
    if (subCategories.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: subCategories.map((sub) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                avatar: Icon(
                  _presetIcons[sub] ?? Icons.apps,
                  size: 16,
                  color: selectedPreset == sub
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                label: Text(sub.label),
                labelStyle: selectedPreset == sub
                    ? const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      )
                    : null,
                selected: selectedPreset == sub,
                showCheckmark: false,
                onSelected: (_) {
                  ref
                      .read(discoverMutualFundPresetProvider.notifier)
                      .setPreset(sub);
                  if (_searchController.text.isNotEmpty) {
                    _searchController.clear();
                    setState(() {});
                    ref
                        .read(discoverMutualFundFiltersProvider.notifier)
                        .setFilters(ref
                            .read(discoverMutualFundFiltersProvider)
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

  Widget _buildActiveFilterChips(
      ThemeData theme, DiscoverMutualFundFilters filters) {
    final chips = <Widget>[];

    if (filters.minScore != 0) {
      chips.add(_filterChip('Score \u2265${filters.minScore.round()}', () {
        ref
            .read(discoverMutualFundFiltersProvider.notifier)
            .setFilters(filters.copyWith(minScore: 0));
      }));
    }
    if (filters.riskLevel != 'All') {
      chips.add(_filterChip('Risk: ${filters.riskLevel}', () {
        ref
            .read(discoverMutualFundFiltersProvider.notifier)
            .setFilters(filters.copyWith(riskLevel: 'All'));
      }));
    }
    if (filters.maxExpenseRatio != null) {
      chips.add(
          _filterChip('Exp \u2264${filters.maxExpenseRatio!.toStringAsFixed(2)}%', () {
        final reset = DiscoverMutualFundFilters(
          search: filters.search,
          category: filters.category,
          riskLevel: filters.riskLevel,
          directOnly: filters.directOnly,
          minScore: filters.minScore,
          minAumCr: filters.minAumCr,
          minReturn1y: filters.minReturn1y,
          minReturn3y: filters.minReturn3y,
          minReturn5y: filters.minReturn5y,
          minFundAge: filters.minFundAge,
          sortBy: filters.sortBy,
          sortOrder: filters.sortOrder,
        );
        ref
            .read(discoverMutualFundFiltersProvider.notifier)
            .setFilters(reset);
      }));
    }
    if (filters.minReturn1y != null) {
      chips.add(
          _filterChip('1Y \u2265${filters.minReturn1y!.toStringAsFixed(1)}%', () {
        final reset = DiscoverMutualFundFilters(
          search: filters.search,
          category: filters.category,
          riskLevel: filters.riskLevel,
          directOnly: filters.directOnly,
          minScore: filters.minScore,
          minAumCr: filters.minAumCr,
          maxExpenseRatio: filters.maxExpenseRatio,
          minReturn3y: filters.minReturn3y,
          minReturn5y: filters.minReturn5y,
          minFundAge: filters.minFundAge,
          sortBy: filters.sortBy,
          sortOrder: filters.sortOrder,
        );
        ref
            .read(discoverMutualFundFiltersProvider.notifier)
            .setFilters(reset);
      }));
    }
    if (filters.minReturn3y != null) {
      chips.add(
          _filterChip('3Y \u2265${filters.minReturn3y!.toStringAsFixed(1)}%', () {
        final reset = DiscoverMutualFundFilters(
          search: filters.search,
          category: filters.category,
          riskLevel: filters.riskLevel,
          directOnly: filters.directOnly,
          minScore: filters.minScore,
          minAumCr: filters.minAumCr,
          maxExpenseRatio: filters.maxExpenseRatio,
          minReturn1y: filters.minReturn1y,
          minReturn5y: filters.minReturn5y,
          minFundAge: filters.minFundAge,
          sortBy: filters.sortBy,
          sortOrder: filters.sortOrder,
        );
        ref
            .read(discoverMutualFundFiltersProvider.notifier)
            .setFilters(reset);
      }));
    }
    if (filters.minReturn5y != null) {
      chips.add(
          _filterChip('5Y \u2265${filters.minReturn5y!.toStringAsFixed(1)}%', () {
        final reset = DiscoverMutualFundFilters(
          search: filters.search,
          category: filters.category,
          riskLevel: filters.riskLevel,
          directOnly: filters.directOnly,
          minScore: filters.minScore,
          minAumCr: filters.minAumCr,
          maxExpenseRatio: filters.maxExpenseRatio,
          minReturn1y: filters.minReturn1y,
          minReturn3y: filters.minReturn3y,
          minFundAge: filters.minFundAge,
          sortBy: filters.sortBy,
          sortOrder: filters.sortOrder,
        );
        ref
            .read(discoverMutualFundFiltersProvider.notifier)
            .setFilters(reset);
      }));
    }
    if (filters.minAumCr != null) {
      chips.add(
          _filterChip('AUM \u2265${filters.minAumCr!.toStringAsFixed(0)} Cr', () {
        final reset = DiscoverMutualFundFilters(
          search: filters.search,
          category: filters.category,
          riskLevel: filters.riskLevel,
          directOnly: filters.directOnly,
          minScore: filters.minScore,
          maxExpenseRatio: filters.maxExpenseRatio,
          minReturn1y: filters.minReturn1y,
          minReturn3y: filters.minReturn3y,
          minReturn5y: filters.minReturn5y,
          minFundAge: filters.minFundAge,
          sortBy: filters.sortBy,
          sortOrder: filters.sortOrder,
        );
        ref
            .read(discoverMutualFundFiltersProvider.notifier)
            .setFilters(reset);
      }));
    }
    if (filters.minFundAge != null) {
      chips.add(
          _filterChip('Age \u2265${filters.minFundAge!.toStringAsFixed(0)}y', () {
        final reset = DiscoverMutualFundFilters(
          search: filters.search,
          category: filters.category,
          riskLevel: filters.riskLevel,
          directOnly: filters.directOnly,
          minScore: filters.minScore,
          minAumCr: filters.minAumCr,
          maxExpenseRatio: filters.maxExpenseRatio,
          minReturn1y: filters.minReturn1y,
          minReturn3y: filters.minReturn3y,
          minReturn5y: filters.minReturn5y,
          sortBy: filters.sortBy,
          sortOrder: filters.sortOrder,
        );
        ref
            .read(discoverMutualFundFiltersProvider.notifier)
            .setFilters(reset);
      }));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    chips.add(ActionChip(
      label: Text('Clear', style: theme.textTheme.labelSmall),
      onPressed: () {
        ref
            .read(discoverMutualFundFiltersProvider.notifier)
            .setFilters(DiscoverMutualFundFilters(
              search: filters.search,
              category: filters.category,
              directOnly: filters.directOnly,
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
  // Open Sort & Filter endDrawer
  // ---------------------------------------------------------------------------

  void _showSortAndFilterSheet(BuildContext context) {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Widget _buildFilterDrawer(DiscoverMutualFundFilters current) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: AppTheme.cardDark,
      child: SafeArea(
        child: _SortAndFilterSheet(
          key: ValueKey(current.hashCode),
          initial: current,
          onApply: (updated) {
            ref
                .read(discoverMutualFundFiltersProvider.notifier)
                .setFilters(updated);
            _scaffoldKey.currentState?.closeEndDrawer();
          },
          onReset: () {
            ref
                .read(discoverMutualFundFiltersProvider.notifier)
                .setFilters(DiscoverMutualFundFilters(
                  search: current.search,
                  category: current.category,
                  directOnly: current.directOnly,
                ));
            _searchController.clear();
            _scaffoldKey.currentState?.closeEndDrawer();
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Sort & Filter Bottom Sheet (StatefulWidget for local state management)
// =============================================================================

class _SortAndFilterSheet extends StatefulWidget {
  final DiscoverMutualFundFilters initial;
  final ValueChanged<DiscoverMutualFundFilters> onApply;
  final VoidCallback onReset;

  const _SortAndFilterSheet({
    super.key,
    required this.initial,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_SortAndFilterSheet> createState() => _SortAndFilterSheetState();
}

class _SortAndFilterSheetState extends State<_SortAndFilterSheet> {
  static const _sortOptions = [
    (value: 'score', label: 'Score'),
    (value: 'returns_1y', label: '1Y Return'),
    (value: 'returns_3y', label: '3Y Return'),
    (value: 'returns_5y', label: '5Y Return'),
    (value: 'aum', label: 'AUM'),
    (value: 'expense', label: 'Expense Ratio'),
    (value: 'risk', label: 'Risk'),
  ];

  late String _sortBy;
  late String _sortOrder;
  late String _riskLevel;
  late double _minScore;

  // Quick filter toggles
  late bool _lowExpense;
  late bool _high1yReturn;
  late bool _largeAum;
  late bool _established;

  // Advanced text controllers
  late final TextEditingController _minReturn1yCtrl;
  late final TextEditingController _minReturn3yCtrl;
  late final TextEditingController _minReturn5yCtrl;
  late final TextEditingController _maxExpenseCtrl;
  late final TextEditingController _minAumCtrl;
  late final TextEditingController _minFundAgeCtrl;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _sortBy = f.sortBy;
    _sortOrder = f.sortOrder;
    _riskLevel = f.riskLevel;
    _minScore = f.minScore;

    // Detect if quick filters match current state
    _lowExpense = f.maxExpenseRatio == 0.5;
    _high1yReturn = f.minReturn1y == 15;
    _largeAum = f.minAumCr == 5000;
    _established = f.minFundAge == 5;

    // Pre-fill advanced fields (clear if matched by quick filter)
    _maxExpenseCtrl = TextEditingController(
      text: _lowExpense ? '' : (f.maxExpenseRatio?.toString() ?? ''),
    );
    _minReturn1yCtrl = TextEditingController(
      text: _high1yReturn ? '' : (f.minReturn1y?.toString() ?? ''),
    );
    _minReturn3yCtrl = TextEditingController(
      text: f.minReturn3y?.toString() ?? '',
    );
    _minReturn5yCtrl = TextEditingController(
      text: f.minReturn5y?.toString() ?? '',
    );
    _minAumCtrl = TextEditingController(
      text: _largeAum ? '' : (f.minAumCr?.toString() ?? ''),
    );
    _minFundAgeCtrl = TextEditingController(
      text: _established ? '' : (f.minFundAge?.toString() ?? ''),
    );
  }

  @override
  void dispose() {
    _minReturn1yCtrl.dispose();
    _minReturn3yCtrl.dispose();
    _minReturn5yCtrl.dispose();
    _maxExpenseCtrl.dispose();
    _minAumCtrl.dispose();
    _minFundAgeCtrl.dispose();
    super.dispose();
  }

  DiscoverMutualFundFilters _buildFilters() {
    // Quick filters take precedence; if toggled on, use the preset value.
    // If toggled off, fall back to the advanced text field.
    double? maxExpense = _lowExpense
        ? 0.5
        : double.tryParse(_maxExpenseCtrl.text);
    double? minReturn1y = _high1yReturn
        ? 15
        : double.tryParse(_minReturn1yCtrl.text);
    double? minAum = _largeAum
        ? 5000
        : double.tryParse(_minAumCtrl.text);
    double? minFundAge = _established
        ? 5
        : double.tryParse(_minFundAgeCtrl.text);

    return DiscoverMutualFundFilters(
      search: widget.initial.search,
      category: widget.initial.category,
      directOnly: true,
      riskLevel: _riskLevel,
      minScore: _minScore,
      maxExpenseRatio: maxExpense,
      minReturn1y: minReturn1y,
      minReturn3y: double.tryParse(_minReturn3yCtrl.text),
      minReturn5y: double.tryParse(_minReturn5yCtrl.text),
      minAumCr: minAum,
      minFundAge: minFundAge,
      sortBy: _sortBy,
      sortOrder: _sortOrder,
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
            // Header: Sort & Filter + Reset
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sort & Filter', style: theme.textTheme.titleMedium),
                TextButton(
                  onPressed: () {
                    widget.onReset();
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Sort By ──
            Text('Sort By', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sortOptions.map((opt) {
                final isSelected = opt.value == _sortBy;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(opt.label),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        Icon(
                          _sortOrder == 'desc'
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          size: 14,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ],
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      if (isSelected) {
                        // Toggle direction
                        _sortOrder =
                            _sortOrder == 'desc' ? 'asc' : 'desc';
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

            // ── Risk Level ──
            Text('Risk Level', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'All', label: Text('All')),
                  ButtonSegment(value: 'Low', label: Text('Low')),
                  ButtonSegment(value: 'Moderate', label: Text('Med')),
                  ButtonSegment(value: 'High', label: Text('High')),
                ],
                selected: {_riskLevel},
                onSelectionChanged: (v) {
                  setState(() => _riskLevel = v.first);
                },
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Quick Filters ──
            Text('Quick Filters', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Low Expense (<0.5%)'),
                  selected: _lowExpense,
                  onSelected: (v) => setState(() => _lowExpense = v),
                  visualDensity: VisualDensity.compact,
                ),
                FilterChip(
                  label: const Text('High 1Y Return (>15%)'),
                  selected: _high1yReturn,
                  onSelected: (v) => setState(() => _high1yReturn = v),
                  visualDensity: VisualDensity.compact,
                ),
                FilterChip(
                  label: const Text('Large AUM (>5000 Cr)'),
                  selected: _largeAum,
                  onSelected: (v) => setState(() => _largeAum = v),
                  visualDensity: VisualDensity.compact,
                ),
                FilterChip(
                  label: const Text('Established (>5 yrs)'),
                  selected: _established,
                  onSelected: (v) => setState(() => _established = v),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Min Score slider ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Min Score', style: theme.textTheme.titleSmall),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
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

            const SizedBox(height: 4),

            // ── Advanced (collapsible) ──
            ExpansionTile(
              title: Text(
                'Advanced',
                style: theme.textTheme.titleSmall,
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              initiallyExpanded: _hasAdvancedValues(),
              children: [
                const SizedBox(height: 8),
                _sectionLabel(theme, 'Returns'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minReturn1yCtrl,
                        keyboardType: numKb,
                        decoration: compactInput('Min 1Y %'),
                        enabled: !_high1yReturn,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _minReturn3yCtrl,
                        keyboardType: numKb,
                        decoration: compactInput('Min 3Y %'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _minReturn5yCtrl,
                  keyboardType: numKb,
                  decoration: compactInput('Min 5Y Return %'),
                ),
                const SizedBox(height: 16),
                _sectionLabel(theme, 'Cost & Size'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _maxExpenseCtrl,
                        keyboardType: numKb,
                        decoration: compactInput('Max Expense %'),
                        enabled: !_lowExpense,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _minAumCtrl,
                        keyboardType: numKb,
                        decoration: compactInput('Min AUM Cr'),
                        enabled: !_largeAum,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _minFundAgeCtrl,
                  keyboardType: numKb,
                  decoration: compactInput('Min Age (yrs)'),
                  enabled: !_established,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Apply button — full width
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  widget.onApply(_buildFilters());
                },
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasAdvancedValues() {
    final f = widget.initial;
    // Open advanced section if user previously set values that aren't
    // covered by quick filters.
    if (f.minReturn3y != null || f.minReturn5y != null) return true;
    if (f.maxExpenseRatio != null && f.maxExpenseRatio != 0.5) return true;
    if (f.minReturn1y != null && f.minReturn1y != 15) return true;
    if (f.minAumCr != null && f.minAumCr != 5000) return true;
    if (f.minFundAge != null && f.minFundAge != 5) return true;
    return false;
  }

  Widget _sectionLabel(ThemeData theme, String title) {
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

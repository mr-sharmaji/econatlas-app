import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_utils.dart';
import '../../providers/discover_providers.dart';
import '../../widgets/shimmer_loading.dart';
import 'widgets/mf_list_tile.dart';

class MfScreenerScreen extends ConsumerStatefulWidget {
  final String? initialSearch;
  final String? initialPreset;

  const MfScreenerScreen({super.key, this.initialSearch, this.initialPreset});

  @override
  ConsumerState<MfScreenerScreen> createState() => _MfScreenerScreenState();
}

class _MfScreenerScreenState extends ConsumerState<MfScreenerScreen> {
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
      // Derive segment from initial preset
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
    if (filters.minScore != 40) count++;
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
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedPreset = ref.watch(discoverMutualFundPresetProvider);
    final filters = ref.watch(discoverMutualFundFiltersProvider);
    final mfAsync = ref.watch(discoverMutualFundsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mutual Funds')),
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
                // Sort button — single unified button with direction arrow
                _SortButton(
                  currentSort: filters.sortBy,
                  currentOrder: filters.sortOrder,
                  onSortChanged: (sortBy, sortOrder) {
                    ref
                        .read(discoverMutualFundFiltersProvider.notifier)
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
                    label: Text(segment.label),
                    selected: selected,
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
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(discoverMutualFundsProvider);
                  },
                  child: ListView.builder(
                    controller: _listScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: items.length + (hasMore ? 1 : 0) + (allLoaded ? 1 : 0),
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
                      return MfListTile(
                        item: item,
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
                label: Text(sub.label),
                selected: selectedPreset == sub,
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

    if (filters.minScore != 40) {
      chips.add(_filterChip('Score \u2265${filters.minScore.round()}', () {
        ref
            .read(discoverMutualFundFiltersProvider.notifier)
            .setFilters(filters.copyWith(minScore: 40));
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

  void _showAdvancedFilters(BuildContext context) {
    final current = ref.read(discoverMutualFundFiltersProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1E31),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        double localMinScore = current.minScore;
        String localRiskLevel = current.riskLevel;
        final maxExpenseController = TextEditingController(
          text: current.maxExpenseRatio?.toString() ?? '',
        );
        final minReturn1yController = TextEditingController(
          text: current.minReturn1y?.toString() ?? '',
        );
        final minReturn3yController = TextEditingController(
          text: current.minReturn3y?.toString() ?? '',
        );
        final minReturn5yController = TextEditingController(
          text: current.minReturn5y?.toString() ?? '',
        );
        final minAumController = TextEditingController(
          text: current.minAumCr?.toString() ?? '',
        );
        final minFundAgeController = TextEditingController(
          text: current.minFundAge?.toString() ?? '',
        );

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
                                .read(discoverMutualFundFiltersProvider.notifier)
                                .setFilters(const DiscoverMutualFundFilters());
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
                        Text('Min Score', style: theme.textTheme.titleSmall),
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

                    // Risk Level
                    DropdownButtonFormField<String>(
                      initialValue: localRiskLevel,
                      decoration: compactInput('Risk Level'),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Low', child: Text('Low')),
                        DropdownMenuItem(
                            value: 'Moderate', child: Text('Moderate')),
                        DropdownMenuItem(value: 'High', child: Text('High')),
                      ],
                      onChanged: (v) => setSheetState(() {
                        localRiskLevel = v ?? 'All';
                      }),
                    ),

                    const SizedBox(height: 16),

                    // ── Returns ──
                    _sectionDivider(theme, 'Returns'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minReturn1yController,
                            keyboardType: numKb,
                            decoration: compactInput('Min 1Y %'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: minReturn3yController,
                            keyboardType: numKb,
                            decoration: compactInput('Min 3Y %'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: minReturn5yController,
                      keyboardType: numKb,
                      decoration: compactInput('Min 5Y Return %'),
                    ),

                    const SizedBox(height: 16),

                    // ── Risk ──
                    _sectionDivider(theme, 'Risk'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: maxExpenseController,
                      keyboardType: numKb,
                      decoration: compactInput('Max Expense Ratio %'),
                    ),

                    const SizedBox(height: 16),

                    // ── Other ──
                    _sectionDivider(theme, 'Other'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minAumController,
                            keyboardType: numKb,
                            decoration: compactInput('Min AUM Cr'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: minFundAgeController,
                            keyboardType: numKb,
                            decoration: compactInput('Min Age (yrs)'),
                          ),
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
                          final expenseRatio =
                              double.tryParse(maxExpenseController.text);
                          final return1y =
                              double.tryParse(minReturn1yController.text);
                          final return3y =
                              double.tryParse(minReturn3yController.text);
                          final return5y =
                              double.tryParse(minReturn5yController.text);
                          final aum =
                              double.tryParse(minAumController.text);
                          final fundAge =
                              double.tryParse(minFundAgeController.text);
                          ref
                              .read(discoverMutualFundFiltersProvider
                                  .notifier)
                              .setFilters(current.copyWith(
                                minScore: localMinScore,
                                riskLevel: localRiskLevel,
                                maxExpenseRatio: expenseRatio,
                                minReturn1y: return1y,
                                minReturn3y: return3y,
                                minReturn5y: return5y,
                                minAumCr: aum,
                                minFundAge: fundAge,
                                directOnly: true,
                              ));
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
    (value: 'returns_3y', label: '3Y Return'),
    (value: 'returns_5y', label: '5Y Return'),
    (value: 'returns_1y', label: '1Y Return'),
    (value: 'aum', label: 'AUM'),
    (value: 'expense', label: 'Expense'),
    (value: 'risk', label: 'Risk'),
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

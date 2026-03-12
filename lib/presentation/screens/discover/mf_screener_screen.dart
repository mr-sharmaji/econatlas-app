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

  static const _sortOptions = [
    (value: 'score', label: 'Score'),
    (value: 'returns_3y', label: '3Y Return'),
    (value: 'returns_5y', label: '5Y Return'),
    (value: 'returns_1y', label: '1Y Return'),
    (value: 'aum', label: 'AUM'),
    (value: 'expense', label: 'Expense'),
    (value: 'risk', label: 'Risk'),
  ];

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

  bool _hasActiveFilters(DiscoverMutualFundFilters filters) {
    return filters.minScore != 40 ||
        filters.riskLevel != 'All' ||
        filters.maxExpenseRatio != null ||
        filters.minReturn1y != null ||
        filters.minReturn3y != null ||
        filters.minReturn5y != null ||
        filters.minAumCr != null ||
        filters.minFundAge != null;
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
          // Row 1: Search + Sort dropdown + Sort order toggle + Filter icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Search field
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      style: theme.textTheme.bodySmall,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 36),
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
                                child: const Icon(Icons.clear, size: 16),
                              )
                            : null,
                        suffixIconConstraints:
                            const BoxConstraints(minWidth: 32),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.10),
                        isDense: true,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Sort dropdown
                SizedBox(
                  height: 40,
                  child: PopupMenuButton<String>(
                    onSelected: (value) {
                      ref
                          .read(discoverMutualFundFiltersProvider.notifier)
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
                          .read(discoverMutualFundFiltersProvider.notifier)
                          .setFilters(filters.copyWith(
                              sortOrder: filters.sortOrder == 'desc'
                                  ? 'asc'
                                  : 'desc'));
                    },
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tooltip: filters.sortOrder == 'desc'
                        ? 'Descending'
                        : 'Ascending',
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
                      'No mutual funds match',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white54),
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
      chips.add(_filterChip('Score ≥${filters.minScore.round()}', () {
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
          _filterChip('Exp ≤${filters.maxExpenseRatio!.toStringAsFixed(2)}%', () {
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
          _filterChip('1Y ≥${filters.minReturn1y!.toStringAsFixed(1)}%', () {
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
          _filterChip('3Y ≥${filters.minReturn3y!.toStringAsFixed(1)}%', () {
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
          _filterChip('5Y ≥${filters.minReturn5y!.toStringAsFixed(1)}%', () {
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
          _filterChip('AUM ≥${filters.minAumCr!.toStringAsFixed(0)} Cr', () {
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
          _filterChip('Age ≥${filters.minFundAge!.toStringAsFixed(0)}y', () {
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

                    // Risk Level
                    DropdownButtonFormField<String>(
                      initialValue: localRiskLevel,
                      decoration: const InputDecoration(
                        labelText: 'Risk Level',
                        border: OutlineInputBorder(),
                      ),
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

                    const SizedBox(height: 12),

                    // Max Expense Ratio
                    TextField(
                      controller: maxExpenseController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Max Expense Ratio %',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Return fields row 1: 1Y + 3Y
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minReturn1yController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Min 1Y Return %',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: minReturn3yController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Min 3Y Return %',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Return fields row 2: 5Y + AUM
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minReturn5yController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Min 5Y Return %',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: minAumController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Min AUM Cr',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Min Fund Age
                    TextField(
                      controller: minFundAgeController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Min Fund Age (years)',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Reset / Apply
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              ref
                                  .read(discoverMutualFundFiltersProvider
                                      .notifier)
                                  .setFilters(
                                      const DiscoverMutualFundFilters());
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

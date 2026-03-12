import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_utils.dart';
import '../../providers/discover_providers.dart';
import '../../widgets/shimmer_loading.dart';
import 'widgets/sort_bar.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedPreset = ref.watch(discoverMutualFundPresetProvider);
    final filters = ref.watch(discoverMutualFundFiltersProvider);
    final mfAsync = ref.watch(discoverMutualFundsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mutual Funds'),
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
                hintText: 'Search mutual funds...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                          ref
                              .read(discoverMutualFundFiltersProvider.notifier)
                              .setFilters(ref
                                  .read(discoverMutualFundFiltersProvider)
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
              children: DiscoverMutualFundPreset.values.map((option) {
                final selected = selectedPreset == option;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(option.label),
                    selected: selected,
                    onSelected: (_) {
                      ref
                          .read(discoverMutualFundPresetProvider.notifier)
                          .setPreset(option);
                      // Clear search when switching presets
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
                  ),
                );
              }).toList(),
            ),
          ),

          // Sort bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SortBar(
              sortBy: filters.sortBy,
              sortOrder: filters.sortOrder,
              options: const [
                SortOption(value: 'score', label: 'Score'),
                SortOption(value: 'returns_3y', label: '3Y Return'),
                SortOption(value: 'returns_5y', label: '5Y Return'),
                SortOption(value: 'returns_1y', label: '1Y Return'),
                SortOption(value: 'aum', label: 'AUM'),
                SortOption(value: 'expense', label: 'Expense'),
                SortOption(value: 'risk', label: 'Risk'),
              ],
              onSortByChanged: (value) {
                ref
                    .read(discoverMutualFundFiltersProvider.notifier)
                    .setFilters(filters.copyWith(sortBy: value));
              },
              onSortOrderChanged: (value) {
                ref
                    .read(discoverMutualFundFiltersProvider.notifier)
                    .setFilters(filters.copyWith(sortOrder: value));
              },
            ),
          ),

          // Results
          Expanded(
            child: mfAsync.when(
              loading: () =>
                  const ShimmerList(itemCount: 8, itemHeight: 96),
              error: (err, _) => Center(
                child: Text(friendlyErrorMessage(err)),
              ),
              data: (paginatedState) {
                final items = paginatedState.items;
                if (items.isEmpty) {
                  return const Center(
                    child: Text('No mutual funds match'),
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

  void _showAdvancedFilters(BuildContext context) {
    final current = ref.read(discoverMutualFundFiltersProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            var minScore = current.minScore;
            var category = current.category;
            var riskLevel = current.riskLevel;
            var maxExpenseText =
                current.maxExpenseRatio?.toString() ?? '';
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Min Score
                    Text(
                      'Min Score: ${minScore.round()}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Slider(
                      value: minScore,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: minScore.round().toString(),
                      onChanged: (v) =>
                          setLocalState(() => minScore = v),
                    ),

                    const SizedBox(height: 12),

                    // Category
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(
                            value: 'Equity', child: Text('Equity')),
                        DropdownMenuItem(
                            value: 'Debt', child: Text('Debt')),
                        DropdownMenuItem(
                            value: 'Hybrid', child: Text('Hybrid')),
                        DropdownMenuItem(
                            value: 'Index', child: Text('Index')),
                      ],
                      onChanged: (v) =>
                          setLocalState(() => category = v ?? 'All'),
                    ),

                    const SizedBox(height: 12),

                    // Risk Level
                    DropdownButtonFormField<String>(
                      value: riskLevel,
                      decoration: const InputDecoration(
                        labelText: 'Risk Level',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Low', child: Text('Low')),
                        DropdownMenuItem(
                            value: 'Moderately Low',
                            child: Text('Moderately Low')),
                        DropdownMenuItem(
                            value: 'Moderate', child: Text('Moderate')),
                        DropdownMenuItem(
                            value: 'High', child: Text('High')),
                      ],
                      onChanged: (v) =>
                          setLocalState(() => riskLevel = v ?? 'All'),
                    ),

                    const SizedBox(height: 12),

                    // Max Expense Ratio
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Max Expense Ratio',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      controller:
                          TextEditingController(text: maxExpenseText),
                      onChanged: (v) =>
                          setLocalState(() => maxExpenseText = v),
                    ),

                    const SizedBox(height: 20),

                    // Reset / Apply row
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
                              Navigator.pop(context);
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final expenseRatio =
                                  double.tryParse(maxExpenseText);
                              ref
                                  .read(discoverMutualFundFiltersProvider
                                      .notifier)
                                  .setFilters(current.copyWith(
                                    minScore: minScore,
                                    category: category,
                                    riskLevel: riskLevel,
                                    maxExpenseRatio: expenseRatio,
                                    directOnly: true,
                                  ));
                              Navigator.pop(context);
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

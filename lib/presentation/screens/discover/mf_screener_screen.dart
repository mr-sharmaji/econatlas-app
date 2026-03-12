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

  const MfScreenerScreen({super.key, this.initialSearch});

  @override
  ConsumerState<MfScreenerScreen> createState() => _MfScreenerScreenState();
}

class _MfScreenerScreenState extends ConsumerState<MfScreenerScreen> {
  late final TextEditingController _searchController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.initialSearch ?? '');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final current = ref.read(discoverMutualFundFiltersProvider);
      ref
          .read(discoverMutualFundFiltersProvider.notifier)
          .setFilters(current.copyWith(search: text));
    });
  }

  /// Build a concise summary of active filters that differ from defaults.
  String? _activeFilterSummary(DiscoverMutualFundFilters filters) {
    const defaults = DiscoverMutualFundFilters();
    final parts = <String>[];

    if (filters.category != defaults.category) {
      parts.add(filters.category);
    }
    if (filters.riskLevel != defaults.riskLevel) {
      parts.add('${filters.riskLevel} Risk');
    }
    if (filters.minScore != defaults.minScore) {
      parts.add('Min Score ${filters.minScore.round()}');
    }
    if (filters.maxExpenseRatio != null) {
      parts.add('Max Exp ${filters.maxExpenseRatio!.toStringAsFixed(2)}%');
    }
    if (filters.sourceStatus != defaults.sourceStatus) {
      parts.add(filters.sourceStatus[0].toUpperCase() +
          filters.sourceStatus.substring(1));
    }

    return parts.isEmpty ? null : parts.join(' \u00b7 ');
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
              data: (response) {
                final items = response.items;
                if (items.isEmpty) {
                  return const Center(
                    child: Text('No mutual funds match'),
                  );
                }
                final showCount = response.totalCount != null &&
                    response.totalCount! > items.length;
                final filterSummary = _activeFilterSummary(filters);
                // Header takes 1 slot if showCount, plus 1 if filterSummary.
                final headerSlots =
                    (showCount ? 1 : 0) + (filterSummary != null ? 1 : 0);
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: items.length + headerSlots,
                  itemBuilder: (context, index) {
                    // "Showing X of Y funds" header
                    if (showCount && index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Showing ${items.length} of ${response.totalCount} funds',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white54),
                        ),
                      );
                    }
                    // Active filter summary row
                    if (filterSummary != null &&
                        index == (showCount ? 1 : 0)) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          filterSummary,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: Colors.white38),
                        ),
                      );
                    }
                    final itemIndex = index - headerSlots;
                    final item = items[itemIndex];
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
            var sourceStatus = current.sourceStatus;

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

                    const SizedBox(height: 12),

                    // Source Status
                    DropdownButtonFormField<String>(
                      value: sourceStatus,
                      decoration: const InputDecoration(
                        labelText: 'Source Status',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(
                            value: 'primary', child: Text('Primary')),
                        DropdownMenuItem(
                            value: 'fallback', child: Text('Fallback')),
                        DropdownMenuItem(
                            value: 'limited', child: Text('Limited')),
                      ],
                      onChanged: (v) =>
                          setLocalState(() => sourceStatus = v ?? 'all'),
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
                                    sourceStatus: sourceStatus,
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

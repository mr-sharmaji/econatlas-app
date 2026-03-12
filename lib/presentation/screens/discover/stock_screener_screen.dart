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

  const StockScreenerScreen({super.key, this.initialSearch});

  @override
  ConsumerState<StockScreenerScreen> createState() =>
      _StockScreenerScreenState();
}

class _StockScreenerScreenState extends ConsumerState<StockScreenerScreen> {
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
      final current = ref.read(discoverStockFiltersProvider);
      ref
          .read(discoverStockFiltersProvider.notifier)
          .setFilters(current.copyWith(search: text));
    });
  }

  /// Build a concise summary of active filters that differ from defaults.
  String? _buildFilterSummary(DiscoverStockFilters filters) {
    const defaults = DiscoverStockFilters();
    final parts = <String>[];

    if (filters.minScore != defaults.minScore) {
      parts.add('Min Score ${filters.minScore.round()}');
    }
    if (filters.sector != defaults.sector) {
      parts.add('${filters.sector} Sector');
    }
    if (filters.sourceStatus != defaults.sourceStatus) {
      parts.add(filters.sourceStatus[0].toUpperCase() +
          filters.sourceStatus.substring(1));
    }
    if (filters.minPe != null) {
      parts.add('P/E >= ${filters.minPe!.toStringAsFixed(1)}');
    }
    if (filters.maxPe != null) {
      parts.add('P/E <= ${filters.maxPe!.toStringAsFixed(1)}');
    }
    if (filters.search.isNotEmpty) {
      parts.add('"${filters.search}"');
    }

    return parts.isEmpty ? null : parts.join(' \u00b7 ');
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
              data: (response) {
                final items = response.items;
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'No stocks match',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white54),
                    ),
                  );
                }

                final hasHeader = response.totalCount != null &&
                    response.totalCount! > items.length;
                final filterSummary = _buildFilterSummary(filters);

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(discoverStocksProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: items.length + (hasHeader ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0 && hasHeader) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Showing ${items.length} of ${response.totalCount} stocks',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: Colors.white54),
                              ),
                              if (filterSummary != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  filterSummary,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }
                      final itemIndex = hasHeader ? index - 1 : index;
                      final item = items[itemIndex];
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
        String localSourceStatus = current.sourceStatus;
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

                    const SizedBox(height: 12),

                    // Source status
                    DropdownButtonFormField<String>(
                      value: localSourceStatus,
                      decoration: const InputDecoration(
                        labelText: 'Source Status',
                        border: OutlineInputBorder(),
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
                      onChanged: (v) => setSheetState(() {
                        localSourceStatus = v ?? 'all';
                      }),
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
                                      sourceStatus: localSourceStatus,
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

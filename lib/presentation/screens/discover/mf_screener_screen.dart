import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_utils.dart';
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
  DiscoverMutualFundPreset.moneyMarket: Icons.attach_money,
  DiscoverMutualFundPreset.ultraShort: Icons.flash_on,
  DiscoverMutualFundPreset.lowDuration: Icons.access_time,
  DiscoverMutualFundPreset.mediumDuration: Icons.schedule,
  DiscoverMutualFundPreset.dynamicBond: Icons.swap_vert,
  DiscoverMutualFundPreset.floater: Icons.waves,
  DiscoverMutualFundPreset.targetMaturity: Icons.calendar_today,
  DiscoverMutualFundPreset.creditRisk: Icons.warning_amber,
  DiscoverMutualFundPreset.aggressiveHybrid: Icons.trending_up,
  DiscoverMutualFundPreset.balancedHybrid: Icons.balance,
  DiscoverMutualFundPreset.conservativeHybrid: Icons.shield,
  DiscoverMutualFundPreset.arbitrage: Icons.compare_arrows,
  DiscoverMutualFundPreset.dynamicAssetAllocation: Icons.pie_chart,
  DiscoverMutualFundPreset.multiAsset: Icons.dashboard,
  DiscoverMutualFundPreset.equitySavings: Icons.savings_outlined,
  DiscoverMutualFundPreset.fofDomestic: Icons.home,
  DiscoverMutualFundPreset.fofOverseas: Icons.flight,
  DiscoverMutualFundPreset.goldSilver: Icons.auto_awesome,
  DiscoverMutualFundPreset.retirement: Icons.elderly,
  DiscoverMutualFundPreset.children: Icons.child_care,
  DiscoverMutualFundPreset.international: Icons.public,
  DiscoverMutualFundPreset.lowRisk: Icons.verified_user,
};

// ---------------------------------------------------------------------------
// Sort options
// ---------------------------------------------------------------------------
const _sortOptions = [
  (value: 'score', label: 'Score'),
  (value: 'returns_1y', label: '1Y Return'),
  (value: 'returns_3y', label: '3Y Return'),
  (value: 'returns_5y', label: '5Y Return'),
  (value: 'aum', label: 'AUM'),
  (value: 'expense', label: 'Expense Ratio'),
  (value: 'risk', label: 'Risk'),
];

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

  void _showSortSheet() {
    final filters = ref.read(discoverMutualFundFiltersProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text('Sort By',
                          style: Theme.of(ctx).textTheme.titleSmall),
                    ],
                  ),
                ),
                ..._sortOptions.map((opt) {
                  final isSelected = filters.sortBy == opt.value;
                  return ListTile(
                    dense: true,
                    title: Text(opt.label),
                    trailing: isSelected
                        ? Icon(
                            filters.sortOrder == 'desc'
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            size: 18,
                            color: Theme.of(ctx).colorScheme.primary,
                          )
                        : null,
                    selected: isSelected,
                    onTap: () {
                      final newOrder = isSelected
                          ? (filters.sortOrder == 'desc' ? 'asc' : 'desc')
                          : 'desc';
                      ref
                          .read(discoverMutualFundFiltersProvider.notifier)
                          .setFilters(filters.copyWith(
                            sortBy: opt.value,
                            sortOrder: newOrder,
                          ));
                      Navigator.pop(ctx);
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
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
          // Row 1: Search field (full width)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              controller: _searchController,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Search funds...',
                hintStyle: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, size: 20),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {});
                          ref
                              .read(
                                  discoverMutualFundFiltersProvider.notifier)
                              .setFilters(ref
                                  .read(discoverMutualFundFiltersProvider)
                                  .copyWith(search: ''));
                        },
                        child: const Icon(Icons.clear, size: 18),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(minWidth: 36),
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

          // Row 2: SegmentedButton (All / Equity / Debt / Hybrid / Other)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<DiscoverMutualFundPreset>(
                segments: DiscoverMutualFundPresetX.segments.map((seg) {
                  return ButtonSegment(
                    value: seg,
                    label: Text(seg.label,
                        style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                selected: {
                  _selectedSegment ?? DiscoverMutualFundPreset.all,
                },
                onSelectionChanged: (selected) {
                  final seg = selected.first;
                  setState(() {
                    _selectedSegment =
                        seg == DiscoverMutualFundPreset.all ? null : seg;
                  });
                  ref
                      .read(discoverMutualFundPresetProvider.notifier)
                      .setPreset(seg);
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
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),

          // Row 3: Sub-category chips (conditional on segment selection)
          if (_selectedSegment != null) _buildSubCategoryChips(selectedPreset),

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
                final totalCount = paginatedState.totalCount;
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
                      ],
                    ),
                  );
                }
                final codesCsv =
                    items.map((e) => e.schemeCode).join(',');
                final sparkAsync = ref.watch(
                  discoverMfSparklinesProvider(
                    (codesCsv: codesCsv, days: 90),
                  ),
                );
                final sparkMap = sparkAsync.valueOrNull ?? {};
                // Header item count: 1 (results header) + items + loading/end
                final headerCount = 1;
                final totalItems = headerCount + items.length +
                    (hasMore ? 1 : 0) + (allLoaded ? 1 : 0);
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(discoverMutualFundsProvider);
                  },
                  child: ListView.builder(
                    controller: _listScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: totalItems,
                    itemBuilder: (context, index) {
                      // Results header: count + sort
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: Row(
                            children: [
                              Text(
                                totalCount > 0
                                    ? '$totalCount funds'
                                    : '${items.length} funds',
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: Colors.white38),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: _showSortSheet,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _sortOptions
                                            .firstWhere(
                                                (o) =>
                                                    o.value == filters.sortBy,
                                                orElse: () =>
                                                    _sortOptions.first)
                                            .label,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        filters.sortOrder == 'desc'
                                            ? Icons.arrow_downward_rounded
                                            : Icons.arrow_upward_rounded,
                                        size: 14,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final itemIndex = index - headerCount;
                      if (itemIndex >= items.length && hasMore) {
                        return const ShimmerInlineRow(height: 86);
                      }
                      if (itemIndex >= items.length && allLoaded) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16),
                          child: Center(
                            child: Text(
                              '${items.length} results',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: Colors.white38),
                            ),
                          ),
                        );
                      }
                      final item = items[itemIndex];
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
}

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
// Named sort presets — each maps to a sort field + order
const _sortPresets = [
  // Best performers
  (label: 'Top Rated', sortBy: 'score', sortOrder: 'desc', icon: Icons.star_rounded),
  (label: 'Top 1Y Return', sortBy: 'returns_1y', sortOrder: 'desc', icon: Icons.trending_up_rounded),
  (label: 'Best SIP Pick', sortBy: 'returns_3y', sortOrder: 'desc', icon: Icons.savings_outlined),
  (label: 'Proven Winner', sortBy: 'returns_5y', sortOrder: 'desc', icon: Icons.emoji_events_outlined),
  // Cost & size
  (label: 'Low Cost', sortBy: 'expense', sortOrder: 'asc', icon: Icons.trending_down_rounded),
  (label: 'Biggest Funds', sortBy: 'aum', sortOrder: 'desc', icon: Icons.account_balance_outlined),
  (label: 'Smallest Funds', sortBy: 'aum', sortOrder: 'asc', icon: Icons.storefront_outlined),
  // Reverse / contrarian
  (label: 'Worst 1Y Return', sortBy: 'returns_1y', sortOrder: 'asc', icon: Icons.arrow_downward_rounded),
  (label: 'Lowest Rated', sortBy: 'score', sortOrder: 'asc', icon: Icons.star_border_rounded),
  (label: 'Highest Expense', sortBy: 'expense', sortOrder: 'desc', icon: Icons.warning_amber_rounded),
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

  /// Map sort field to sparkline days (max 365 — backend limit).
  int _sparklineDaysForSort(String sortBy) {
    switch (sortBy) {
      case 'returns_1y':
      case 'returns_3y':
      case 'returns_5y':
        return 365;
      default:
        return 90;
    }
  }

  void _showSortSheet() {
    final filters = ref.read(discoverMutualFundFiltersProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Sort By', style: theme.textTheme.titleSmall),
                ),
                ..._sortPresets.map((preset) {
                  final isActive = filters.sortBy == preset.sortBy &&
                      filters.sortOrder == preset.sortOrder;
                  return ListTile(
                    dense: true,
                    leading: Icon(preset.icon, size: 20,
                        color: isActive
                            ? theme.colorScheme.primary
                            : Colors.white38),
                    title: Text(preset.label),
                    selected: isActive,
                    onTap: () {
                      ref
                          .read(discoverMutualFundFiltersProvider.notifier)
                          .setFilters(filters.copyWith(
                            sortBy: preset.sortBy,
                            sortOrder: preset.sortOrder,
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

          // Row 2: Toggle buttons (All / Equity / Debt / Hybrid / Other)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final segments = DiscoverMutualFundPresetX.segments;
                  final selectedSeg =
                      _selectedSegment ?? DiscoverMutualFundPreset.all;
                  // Subtract border widths (1px per segment + 1px extra)
                  final buttonWidth =
                      (constraints.maxWidth - segments.length - 1) /
                          segments.length;
                  return ToggleButtons(
                    isSelected:
                        segments.map((s) => s == selectedSeg).toList(),
                    onPressed: (i) {
                      final seg = segments[i];
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
                            .read(
                                discoverMutualFundFiltersProvider.notifier)
                            .setFilters(ref
                                .read(discoverMutualFundFiltersProvider)
                                .copyWith(search: ''));
                      }
                    },
                    constraints: BoxConstraints(
                      minWidth: buttonWidth,
                      minHeight: 36,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    borderColor: Colors.white.withValues(alpha: 0.15),
                    selectedBorderColor:
                        theme.colorScheme.primary.withValues(alpha: 0.5),
                    fillColor:
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                    selectedColor: theme.colorScheme.primary,
                    color: Colors.white60,
                    textStyle: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    children: segments
                        .map((s) => Text(s.label))
                        .toList(),
                  );
                },
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
                final hasMore = paginatedState.hasMore;
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
                final sparkDays = _sparklineDaysForSort(filters.sortBy);
                final sparkAsync = ref.watch(
                  discoverMfSparklinesProvider(
                    (codesCsv: codesCsv, days: sparkDays),
                  ),
                );
                final sparkMap = sparkAsync.valueOrNull ?? {};
                // Find current sort label
                final sortLabel = _sortPresets
                    .where((s) => s.sortBy == filters.sortBy &&
                        s.sortOrder == filters.sortOrder)
                    .map((s) => s.label)
                    .firstOrNull ?? 'Top Rated';

                return Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(discoverMutualFundsProvider);
                      },
                      child: ListView.builder(
                        controller: _listScrollController,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 60),
                        itemCount: items.length +
                            (hasMore ? 1 : 0) + (allLoaded ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= items.length && hasMore) {
                            return const ShimmerInlineRow(height: 86);
                          }
                          if (index >= items.length && allLoaded) {
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
                          final item = items[index];
                          final sparkVals = sparkMap[item.schemeCode]
                              ?.map((p) => p.value)
                              .toList();
                          return MfListTile(
                            item: item,
                            sparklineValues: sparkVals,
                            sortBy: filters.sortBy,
                            onTap: () {
                              context.push(
                                '/discover/mf/${Uri.encodeComponent(item.schemeCode)}',
                                extra: item,
                              );
                            },
                          );
                        },
                      ),
                    ),
                    // Sticky bottom sort pill
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _showSortSheet,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface
                                    .withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.3),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sort_rounded,
                                      size: 16,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    sortLabel,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    filters.sortOrder == 'desc'
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                  if (totalCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '$totalCount',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: Colors.white38),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/error_utils.dart';
import '../../../core/market_status_helper.dart' show normalizeMarketPhase;
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/discover.dart';
import '../../../data/models/market_price.dart';
import '../../../data/services/starred_stocks_service.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../discover/widgets/mf_list_tile.dart';
import '../discover/widgets/stock_list_tile.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(bottomTabReselectTickProvider(2), (prev, next) {
      if (prev == null || prev == next) return;
      _scrollToTop();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check_rounded),
            tooltip: 'Manage Watchlist',
            onPressed: () => context.push('/watchlist'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentBlue,
          labelColor: AppTheme.accentBlue,
          unselectedLabelColor: Colors.white54,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Markets'),
            Tab(text: 'Stocks'),
            Tab(text: 'Mutual Funds'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Markets tab — watchlist with health card
          RefreshIndicator(
            onRefresh: () async {
              await ref.read(watchlistProvider.notifier).load(silent: true);
              // Use the forceRefresh helpers — `ref.refresh(...future)`
              // would return cached data instantly because both
              // providers use a return-cached + microtask-refresh
              // pattern internally.
              try {
                await Future.wait([
                  forceRefreshLatestMarketPrices(ref),
                  forceRefreshLatestCommodities(ref),
                ]);
              } catch (_) {}
            },
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 112),
              children: [
                _MarketOverviewGrid(),
                const SizedBox(height: 24),
              ],
            ),
          ),
          // Stocks tab — starred discover stocks
          const _StarredFavoritesTab(type: 'stock'),
          const _StarredFavoritesTab(type: 'mf'),
        ],
      ),
    );
  }
}

// =============================================================================
// Starred Favorites Tabs
// =============================================================================

const _favoritesStockSortKey = 'favorites_stock_sort';
const _favoritesMfSortKey = 'favorites_mf_sort';

enum _FavoritesSortMode { change, score, az }

extension _FavoritesSortModeX on _FavoritesSortMode {
  String get storageValue {
    switch (this) {
      case _FavoritesSortMode.change:
        return 'change';
      case _FavoritesSortMode.score:
        return 'score';
      case _FavoritesSortMode.az:
        return 'az';
    }
  }

  String label({required bool isStockTab}) {
    switch (this) {
      case _FavoritesSortMode.change:
        return isStockTab ? '1D Change' : '1Y Return';
      case _FavoritesSortMode.score:
        return 'Score';
      case _FavoritesSortMode.az:
        return 'A-Z';
    }
  }

  static _FavoritesSortMode fromStorage(String? value) {
    switch (value) {
      case 'score':
        return _FavoritesSortMode.score;
      case 'az':
        return _FavoritesSortMode.az;
      case 'change':
      default:
        return _FavoritesSortMode.change;
    }
  }
}

class _StarredFavoritesTab extends ConsumerStatefulWidget {
  final String type;

  const _StarredFavoritesTab({required this.type});

  @override
  ConsumerState<_StarredFavoritesTab> createState() =>
      _StarredFavoritesTabState();
}

class _StarredFavoritesTabState extends ConsumerState<_StarredFavoritesTab> {
  late _FavoritesSortMode _sortMode;
  // Active filter — null = show all, otherwise only rows whose
  // sector (stocks) or category (MFs) equals this string. Toggled
  // via the chip row beneath the summary card.
  String? _activeFilter;

  bool get _isStockTab => widget.type == 'stock';
  String get _sortPreferenceKey =>
      _isStockTab ? _favoritesStockSortKey : _favoritesMfSortKey;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _sortMode =
        _FavoritesSortModeX.fromStorage(prefs.getString(_sortPreferenceKey));
  }

  Future<void> _setSortMode(_FavoritesSortMode mode) async {
    if (_sortMode == mode) return;
    setState(() => _sortMode = mode);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_sortPreferenceKey, mode.storageValue);
  }

  void _toggleFilter(String label) {
    setState(() {
      _activeFilter = _activeFilter == label ? null : label;
    });
  }

  Future<void> _refreshLiveData() async {
    if (_isStockTab) {
      ref.invalidate(starredStockLiveQuotesProvider);
      await ref.read(starredStockLiveQuotesProvider.future);
      return;
    }
    ref.invalidate(starredMfLiveQuotesProvider);
    await ref.read(starredMfLiveQuotesProvider.future);
  }

  /// Show a bottom sheet with long-press row actions (currently just
  /// Remove-from-watchlist). Triggered by a long-press on the row
  /// because horizontal-swipe Dismissible was conflicting with
  /// TabBarView's page-swipe gesture and causing accidental unstars.
  Future<void> _showFavoriteActions(
    BuildContext context,
    StarredItem item,
    String displayName,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.star_outline_rounded,
                  color: AppTheme.accentRed,
                ),
                title: const Text('Remove from watchlist'),
                onTap: () => Navigator.of(ctx).pop('remove'),
              ),
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(ctx).pop(null),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (choice == 'remove') {
      await _removeFavoriteWithUndo(item);
    }
  }

  Future<void> _removeFavoriteWithUndo(StarredItem item) async {
    // Snapshot the item so the Undo path can restore with the exact
    // same name + freshness stamp.
    final snapshot = item;
    await ref.read(starredStocksProvider.notifier).toggle(
          type: item.type,
          id: item.id,
          name: item.name,
          percentChange: item.percentChange,
        );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Text(
          'Removed ${snapshot.name} from watchlist',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await ref.read(starredStocksProvider.notifier).toggle(
                  type: snapshot.type,
                  id: snapshot.id,
                  name: snapshot.name,
                  percentChange: snapshot.percentChange,
                );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final starred = ref
        .watch(starredStocksProvider)
        .where((item) => item.type == widget.type)
        .toList(growable: false);

    if (starred.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 72),
          _FavoritesEmptyState(type: widget.type),
        ],
      );
    }

    return _isStockTab
        ? _buildStockTab(context, starred)
        : _buildMfTab(context, starred);
  }

  Widget _buildStockTab(BuildContext context, List<StarredItem> starred) {
    final liveAsync = ref.watch(starredStockLiveQuotesProvider);
    final liveQuotes =
        liveAsync.valueOrNull ?? const <String, DiscoverStockItem>{};

    if (liveAsync.isLoading && liveQuotes.isEmpty) {
      return _FavoritesLoadingTab(onRefresh: _refreshLiveData);
    }

    final allRows = starred
        .map(
          (item) => _StockFavoriteRowData(
            item: item,
            live: liveQuotes[item.id],
          ),
        )
        .toList(growable: false);

    // Build filterable sector buckets off the live snapshot. Rows
    // without a sector collapse to "Other".
    final sectorCounts = <String, int>{};
    for (final row in allRows) {
      final sector = (row.live?.sector ?? '').trim();
      final key = sector.isEmpty ? 'Other' : sector;
      sectorCounts[key] = (sectorCounts[key] ?? 0) + 1;
    }

    final filterLabel = _activeFilter;
    final filteredRows = (filterLabel == null
            ? allRows
            : allRows.where((row) {
                final sector = (row.live?.sector ?? '').trim();
                final bucket = sector.isEmpty ? 'Other' : sector;
                return bucket == filterLabel;
              }).toList())
        ..sort(_compareStockRows);

    // Summary numbers always reflect the *currently visible* set so
    // that the sector-chip tap instantly redraws the badges above.
    final summary = _buildStockSummary(
      totalFavorites: filteredRows.length,
      rows: filteredRows,
    );

    // Prefetch per-row intraday sparkline data. One batched fetch for
    // all visible symbols, same provider the screener uses.
    final symbolsCsv = filteredRows.map((row) => row.symbol).join(',');
    // days=7 instead of days=1 so the sparkline has at least one
    // trading session's worth of points on a weekend / holiday (the
    // backend query is `trade_date >= CURRENT_DATE - N days`, so
    // days=1 on a Saturday returns just Friday — a single data
    // point which renders as a flat stub). days=7 spans 5 trading
    // sessions ≈ 5 points, enough for a visible trend line.
    final sparkAsync = symbolsCsv.isEmpty
        ? const AsyncValue<Map<String, List<PriceHistoryPoint>>>.data({})
        : ref.watch(discoverStockSparklinesProvider(
            (symbolsCsv: symbolsCsv, days: 7),
          ));
    final sparkMap = sparkAsync.valueOrNull ?? const {};

    final showStaleNotice = liveAsync.hasError && liveQuotes.isEmpty;

    return RefreshIndicator(
      onRefresh: _refreshLiveData,
      // Dashboard watchlist feels too chunky when rendering the
      // screener-sized tiles verbatim. Wrap the whole list in a
      // MediaQuery that scales text down ~15 % so the reused
      // StockListTile / MfListTile widgets look compact here
      // without needing a separate widget variant.
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(0.85),
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 112),
          children: [
            if (showStaleNotice) ...[
              const _FavoritesDataNotice(
                message:
                    'Showing saved favorites while live stock data catches up.',
            ),
            const SizedBox(height: 8),
          ],
          _FavoritesSummaryCard(
            title: 'Stocks Favorites',
            icon: Icons.monitor_heart_outlined,
            averageLabel: 'Avg 1D',
            positiveLabel: 'Gainers',
            negativeLabel: 'Losers',
            summary: summary,
            filterBuckets: sectorCounts,
            activeFilter: filterLabel,
            onFilterTapped: _toggleFilter,
          ),
          const SizedBox(height: 8),
          _FavoritesSortDropdown(
            sortMode: _sortMode,
            isStockTab: true,
            onChanged: _setSortMode,
          ),
          const SizedBox(height: 4),
          if (filteredRows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No favorites in this sector.',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            ),
          for (final row in filteredRows)
            // Long-press opens a bottom sheet with a "Remove from
            // watchlist" action. We deliberately do NOT use
            // Dismissible here because the dashboard lives inside a
            // TabBarView and horizontal swipes were being intercepted
            // by the Dismissible gesture detector, causing accidental
            // unstars when the user just wanted to switch tabs.
            GestureDetector(
              key: ValueKey('fav-stock-${row.item.id}'),
              behavior: HitTestBehavior.opaque,
              onLongPress: () =>
                  _showFavoriteActions(context, row.item, row.displayName),
              child: Builder(
                builder: (context) {
                  final live = row.live;
                  if (live != null) {
                    return StockListTile(
                      item: live,
                      changeField: StockChangeField.daily,
                      sparklineValues:
                          sparkMap[row.symbol]?.map((p) => p.value).toList(),
                      onTap: () => context.push(
                        '/discover/stock/${Uri.encodeComponent(row.symbol)}',
                        extra: live,
                      ),
                    );
                  }
                  // No live snapshot yet — thin placeholder row that
                  // still links to the detail screen.
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        row.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: const Text(
                        'Waiting for live data…',
                        style: TextStyle(color: Colors.white38),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(
                        '/discover/stock/${Uri.encodeComponent(row.symbol)}',
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildMfTab(BuildContext context, List<StarredItem> starred) {
    final liveAsync = ref.watch(starredMfLiveQuotesProvider);
    final liveQuotes =
        liveAsync.valueOrNull ?? const <String, DiscoverMutualFundItem>{};

    if (liveAsync.isLoading && liveQuotes.isEmpty) {
      return _FavoritesLoadingTab(onRefresh: _refreshLiveData);
    }

    final allRows = starred
        .map(
          (item) => _MfFavoriteRowData(
            item: item,
            live: liveQuotes[item.id],
          ),
        )
        .toList(growable: false);

    // Coarse category buckets (Equity / Debt / Hybrid / Other) —
    // same taxonomy the screener uses. Missing categories collapse
    // to "Other".
    final categoryCounts = <String, int>{};
    for (final row in allRows) {
      final category = (row.live?.category ?? '').trim();
      final key = category.isEmpty ? 'Other' : _canonicalMfCategory(category);
      categoryCounts[key] = (categoryCounts[key] ?? 0) + 1;
    }

    final filterLabel = _activeFilter;
    final filteredRows = (filterLabel == null
            ? allRows
            : allRows.where((row) {
                final category = (row.live?.category ?? '').trim();
                final bucket = category.isEmpty
                    ? 'Other'
                    : _canonicalMfCategory(category);
                return bucket == filterLabel;
              }).toList())
        ..sort(_compareMfRows);

    final summary = _buildMfSummary(
      totalFavorites: filteredRows.length,
      rows: filteredRows,
    );

    final codesCsv = filteredRows.map((row) => row.item.id).join(',');
    final sparkAsync = codesCsv.isEmpty
        ? const AsyncValue<Map<String, List<PriceHistoryPoint>>>.data({})
        : ref.watch(discoverMfSparklinesProvider(
            (codesCsv: codesCsv, days: 30),
          ));
    final sparkMap = sparkAsync.valueOrNull ?? const {};

    final showStaleNotice = liveAsync.hasError && liveQuotes.isEmpty;

    return RefreshIndicator(
      onRefresh: _refreshLiveData,
      // Same text-scale compaction as the stock tab — see the
      // comment on _buildStockTab for rationale.
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(0.85),
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 112),
          children: [
            if (showStaleNotice) ...[
              const _FavoritesDataNotice(
                message:
                    'Showing saved favorites while live mutual fund data catches up.',
            ),
            const SizedBox(height: 8),
          ],
          _FavoritesSummaryCard(
            title: 'Mutual Funds Favorites',
            icon: Icons.account_balance_wallet_outlined,
            averageLabel: 'Avg 1Y',
            positiveLabel: 'Positive',
            negativeLabel: 'Negative',
            summary: summary,
            filterBuckets: categoryCounts,
            activeFilter: filterLabel,
            onFilterTapped: _toggleFilter,
          ),
          const SizedBox(height: 8),
          _FavoritesSortDropdown(
            sortMode: _sortMode,
            isStockTab: false,
            onChanged: _setSortMode,
          ),
          const SizedBox(height: 4),
          if (filteredRows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No favorites in this category.',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            ),
          for (final row in filteredRows)
            // Long-press → remove sheet (see stock tab for rationale
            // on why we no longer use Dismissible inside a TabBarView).
            GestureDetector(
              key: ValueKey('fav-mf-${row.item.id}'),
              behavior: HitTestBehavior.opaque,
              onLongPress: () =>
                  _showFavoriteActions(context, row.item, row.displayName),
              child: Builder(
                builder: (context) {
                  final live = row.live;
                  if (live != null) {
                    return MfListTile(
                      item: live,
                      sparklineValues:
                          sparkMap[row.item.id]?.map((p) => p.value).toList(),
                      onTap: () => context.push(
                        '/discover/mf/${row.item.id}',
                        extra: live,
                      ),
                    );
                  }
                  // No live snapshot yet — show a thin placeholder row
                  // that still links to the detail screen.
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        row.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: const Text(
                        'Waiting for live data…',
                        style: TextStyle(color: Colors.white38),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          context.push('/discover/mf/${row.item.id}'),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      ),
    );
  }

  // Normalise a raw AMFI / ET Money category string into one of
  // {Equity, Debt, Hybrid, Other} — the 4-way chip row the UI shows.
  static String _canonicalMfCategory(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('equity')) return 'Equity';
    if (lower.contains('debt')) return 'Debt';
    if (lower.contains('hybrid')) return 'Hybrid';
    return 'Other';
  }

  int _compareStockRows(_StockFavoriteRowData a, _StockFavoriteRowData b) {
    switch (_sortMode) {
      case _FavoritesSortMode.change:
        return _compareNullableDesc(a.effectiveChange, b.effectiveChange, () {
          return a.symbol.toLowerCase().compareTo(b.symbol.toLowerCase());
        });
      case _FavoritesSortMode.score:
        return _compareNullableDesc(a.live?.score, b.live?.score, () {
          return a.symbol.toLowerCase().compareTo(b.symbol.toLowerCase());
        });
      case _FavoritesSortMode.az:
        final byName = a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );
        if (byName != 0) return byName;
        return a.symbol.toLowerCase().compareTo(b.symbol.toLowerCase());
    }
  }

  int _compareMfRows(_MfFavoriteRowData a, _MfFavoriteRowData b) {
    switch (_sortMode) {
      case _FavoritesSortMode.change:
        return _compareNullableDesc(a.effectiveReturn1y, b.effectiveReturn1y,
            () {
          return a.displayName
              .toLowerCase()
              .compareTo(b.displayName.toLowerCase());
        });
      case _FavoritesSortMode.score:
        return _compareNullableDesc(a.live?.score, b.live?.score, () {
          return a.displayName
              .toLowerCase()
              .compareTo(b.displayName.toLowerCase());
        });
      case _FavoritesSortMode.az:
        return a.displayName
            .toLowerCase()
            .compareTo(b.displayName.toLowerCase());
    }
  }
}

int _compareNullableDesc(
  double? a,
  double? b,
  int Function() onTie,
) {
  if (a == null && b == null) return onTie();
  if (a == null) return 1;
  if (b == null) return -1;
  final byValue = b.compareTo(a);
  if (byValue != 0) return byValue;
  return onTie();
}

class _StockFavoriteRowData {
  final StarredItem item;
  final DiscoverStockItem? live;

  const _StockFavoriteRowData({
    required this.item,
    required this.live,
  });

  String get symbol => item.id;
  String get displayName => live?.displayName ?? item.name;
  double? get effectiveChange => live?.percentChange ?? item.percentChange;
  DateTime? get freshness => live?.sourceTimestamp;
}

class _MfFavoriteRowData {
  final StarredItem item;
  final DiscoverMutualFundItem? live;

  const _MfFavoriteRowData({
    required this.item,
    required this.live,
  });

  String get displayName => live?.displayName ?? live?.schemeName ?? item.name;
  double? get effectiveReturn1y => live?.returns1y ?? item.percentChange;
  DateTime? get freshness => live?.navDate ?? live?.sourceTimestamp;
}

class _FavoritesSummaryData {
  final int totalFavorites;
  final int measuredCount;
  final int positiveCount;
  final int negativeCount;
  final int flatCount;
  final double? averageChange;
  final String? bestLabel;
  final double? bestValue;
  final String? worstLabel;
  final double? worstValue;
  final DateTime? freshest;

  const _FavoritesSummaryData({
    required this.totalFavorites,
    required this.measuredCount,
    required this.positiveCount,
    required this.negativeCount,
    required this.flatCount,
    required this.averageChange,
    required this.bestLabel,
    required this.bestValue,
    required this.worstLabel,
    required this.worstValue,
    required this.freshest,
  });
}

_FavoritesSummaryData _buildStockSummary({
  required int totalFavorites,
  required List<_StockFavoriteRowData> rows,
}) {
  final measurable =
      rows.where((row) => row.effectiveChange != null).toList(growable: false);
  final positive = measurable.where((row) => row.effectiveChange! > 0).length;
  final negative = measurable.where((row) => row.effectiveChange! < 0).length;
  final average = measurable.isEmpty
      ? null
      : measurable.fold<double>(0, (sum, row) => sum + row.effectiveChange!) /
          measurable.length;
  final sorted = [...measurable]
    ..sort((a, b) => b.effectiveChange!.compareTo(a.effectiveChange!));
  return _FavoritesSummaryData(
    totalFavorites: totalFavorites,
    measuredCount: measurable.length,
    positiveCount: positive,
    negativeCount: negative,
    flatCount: measurable.length - positive - negative,
    averageChange: average,
    bestLabel: sorted.isNotEmpty ? sorted.first.symbol : null,
    bestValue: sorted.isNotEmpty ? sorted.first.effectiveChange : null,
    worstLabel: sorted.length > 1 ? sorted.last.symbol : null,
    worstValue: sorted.length > 1 ? sorted.last.effectiveChange : null,
    freshest:
        _latestDate(rows.map((row) => row.freshness).whereType<DateTime>()),
  );
}

_FavoritesSummaryData _buildMfSummary({
  required int totalFavorites,
  required List<_MfFavoriteRowData> rows,
}) {
  final measurable = rows
      .where((row) => row.effectiveReturn1y != null)
      .toList(growable: false);
  final positive = measurable.where((row) => row.effectiveReturn1y! > 0).length;
  final negative = measurable.where((row) => row.effectiveReturn1y! < 0).length;
  final average = measurable.isEmpty
      ? null
      : measurable.fold<double>(0, (sum, row) => sum + row.effectiveReturn1y!) /
          measurable.length;
  final sorted = [...measurable]
    ..sort((a, b) => b.effectiveReturn1y!.compareTo(a.effectiveReturn1y!));
  return _FavoritesSummaryData(
    totalFavorites: totalFavorites,
    measuredCount: measurable.length,
    positiveCount: positive,
    negativeCount: negative,
    flatCount: measurable.length - positive - negative,
    averageChange: average,
    bestLabel: sorted.isNotEmpty ? sorted.first.displayName : null,
    bestValue: sorted.isNotEmpty ? sorted.first.effectiveReturn1y : null,
    worstLabel: sorted.length > 1 ? sorted.last.displayName : null,
    worstValue: sorted.length > 1 ? sorted.last.effectiveReturn1y : null,
    freshest:
        _latestDate(rows.map((row) => row.freshness).whereType<DateTime>()),
  );
}

DateTime? _latestDate(Iterable<DateTime> values) {
  DateTime? latest;
  for (final value in values) {
    if (latest == null || value.isAfter(latest)) {
      latest = value;
    }
  }
  return latest;
}

class _FavoritesSummaryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String averageLabel;
  final String positiveLabel;
  final String negativeLabel;
  final _FavoritesSummaryData summary;
  /// Sector (stocks) / category (MFs) breakdown of the full
  /// favorites universe. Keys are label strings, values are
  /// counts. Used to build the inline filter chip row.
  final Map<String, int> filterBuckets;
  /// The currently-active filter label (or null for "all").
  final String? activeFilter;
  /// Called when a chip is tapped. Tapping the active chip again
  /// should clear the filter (the parent handles that logic).
  final ValueChanged<String> onFilterTapped;

  const _FavoritesSummaryCard({
    required this.title,
    required this.icon,
    required this.averageLabel,
    required this.positiveLabel,
    required this.negativeLabel,
    required this.summary,
    this.filterBuckets = const {},
    this.activeFilter,
    required this.onFilterTapped,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avgColor = (summary.averageChange ?? 0) >= 0
        ? AppTheme.accentGreen
        : AppTheme.accentRed;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row — tight spacing, chip pushed to the right.
            Row(
              children: [
                Icon(icon, size: 14, color: AppTheme.accentBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.2,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (summary.averageChange != null)
                  _MetricChip(
                    label:
                        '$averageLabel ${_formatPercent(summary.averageChange, digits: 1)}',
                    color: avgColor,
                  )
                else
                  Text(
                    'No live moves yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Stats row — tighter horizontal spacing (12 instead of
            // 16) and smaller vertical spacing on wrap (6 instead of
            // 10) to compact the card.
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _HealthStat(
                  label: 'Total',
                  value: '${summary.totalFavorites}',
                  color: AppTheme.accentBlue,
                ),
                _HealthStat(
                  label: positiveLabel,
                  value: '${summary.positiveCount}',
                  color: AppTheme.accentGreen,
                ),
                _HealthStat(
                  label: negativeLabel,
                  value: '${summary.negativeCount}',
                  color: AppTheme.accentRed,
                ),
                _HealthStat(
                  label: 'Flat',
                  value: '${summary.flatCount}',
                  color: Colors.white38,
                ),
              ],
            ),
            // Best and Worst now stacked in separate rows so both
            // symbol labels get the full card width to avoid
            // mid-row ellipsis on longer fund names.
            if (summary.bestLabel != null) ...[
              const SizedBox(height: 8),
              _PerformerChip(
                label: 'Best',
                symbol: summary.bestLabel!,
                pct: summary.bestValue ?? 0,
                color: AppTheme.accentGreen,
              ),
            ],
            if (summary.worstLabel != null) ...[
              const SizedBox(height: 6),
              _PerformerChip(
                label: 'Worst',
                symbol: summary.worstLabel!,
                pct: summary.worstValue ?? 0,
                color: AppTheme.accentRed,
              ),
            ],
            if (filterBuckets.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildFilterChipRow(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChipRow(ThemeData theme) {
    // Sort by count DESC so the most-populated bucket leads.
    final entries = filterBuckets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final selected = entry.key == activeFilter;
          return FilterChip(
            label: Text(
              '${entry.key} (${entry.value})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.white70,
              ),
            ),
            selected: selected,
            onSelected: (_) => onFilterTapped(entry.key),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            selectedColor: AppTheme.accentBlue.withValues(alpha: 0.60),
            backgroundColor: AppTheme.accentBlue.withValues(alpha: 0.12),
            checkmarkColor: Colors.white,
            showCheckmark: false,
            side: BorderSide(
              color: selected
                  ? AppTheme.accentBlue
                  : AppTheme.accentBlue.withValues(alpha: 0.25),
              width: 0.8,
            ),
          );
        },
      ),
    );
  }
}

/// Compact sort dropdown used on both Stocks and MFs tabs. Replaces
/// the ChoiceChip row + Edit toggle. Renders as a single menu button
/// aligned to the right.
class _FavoritesSortDropdown extends StatelessWidget {
  final _FavoritesSortMode sortMode;
  final bool isStockTab;
  final ValueChanged<_FavoritesSortMode> onChanged;

  const _FavoritesSortDropdown({
    required this.sortMode,
    required this.isStockTab,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            Icons.sort_rounded,
            size: 16,
            color: Colors.white54,
          ),
          const SizedBox(width: 6),
          Text(
            'Sort:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<_FavoritesSortMode>(
              value: sortMode,
              dropdownColor: AppTheme.cardDark,
              isDense: true,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: Colors.white54,
              ),
              items: [
                for (final mode in _FavoritesSortMode.values)
                  DropdownMenuItem(
                    value: mode,
                    child: Text(
                      mode.label(isStockTab: isStockTab),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
              onChanged: (mode) {
                if (mode != null) onChanged(mode);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoritesLoadingTab extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _FavoritesLoadingTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 112),
        children: const [
          ShimmerCard(height: 170),
          SizedBox(height: 10),
          ShimmerCard(height: 80),
          ShimmerCard(height: 80),
          ShimmerCard(height: 80),
          ShimmerCard(height: 80),
        ],
      ),
    );
  }
}

class _FavoritesDataNotice extends StatelessWidget {
  final String message;

  const _FavoritesDataNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      color: AppTheme.accentBlue.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: AppTheme.accentBlue,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesEmptyState extends StatelessWidget {
  final String type;

  const _FavoritesEmptyState({required this.type});

  bool get _isStock => type == 'stock';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title =
        _isStock ? 'No starred stocks yet' : 'No starred mutual funds yet';
    final body = _isStock
        ? 'Star companies from Discover and they will show up here with live prices, 1D moves, and quick watchlist actions.'
        : 'Star funds from Discover and they will show up here with fresh NAVs, 1Y returns, and quick watchlist actions.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(
                _isStock
                    ? Icons.star_border_rounded
                    : Icons.account_balance_wallet_outlined,
                size: 44,
                color: Colors.white.withValues(alpha: 0.16),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white38,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white24,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.go('/discover'),
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Open Discover'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Market Overview Grid (existing)
// =============================================================================

class _MarketOverviewGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketAsync = ref.watch(latestMarketPricesProvider);
    final commodityAsync = ref.watch(latestCommoditiesProvider);
    final cryptoAsync = ref.watch(latestCryptoProvider);
    final unitSystem = ref.watch(unitSystemProvider);
    final watchlistAsync = ref.watch(watchlistProvider);
    String phaseFor(MarketPrice p) => normalizeMarketPhase(p.marketPhase);

    return marketAsync.when(
      loading: () => const ShimmerList(itemCount: 4, itemHeight: 70),
      error: (err, _) => ErrorView(
        message: friendlyErrorMessage(err),
        onRetry: () => ref.invalidate(latestMarketPricesProvider),
      ),
      data: (marketPrices) {
        final commodities = commodityAsync.valueOrNull ?? [];
        final cryptos = cryptoAsync.valueOrNull ?? [];
        final allPrices = [...marketPrices, ...commodities, ...cryptos];

        final usdInrPrice =
            allPrices.where((p) => p.asset == 'USD/INR').toList();
        final usdInrRate =
            usdInrPrice.isNotEmpty ? usdInrPrice.first.price : null;

        final watchlistAssets = watchlistAsync.valueOrNull;
        if (watchlistAssets == null) {
          if (watchlistAsync.isLoading) {
            return const ShimmerList(itemCount: 4, itemHeight: 70);
          }
          // Error state — show retry
          return ErrorView(
            message: 'Failed to load watchlist',
            onRetry: () => ref.read(watchlistProvider.notifier).load(),
          );
        }
        final byAsset = <String, MarketPrice>{};
        for (final price in allPrices) {
          byAsset.putIfAbsent(price.asset, () => price);
        }
        final rows = watchlistAssets
            .map(
              (asset) => _DashboardWatchlistRow(
                asset: asset,
                price: byAsset[asset],
              ),
            )
            .toList();

        if (watchlistAssets.isEmpty) {
          return const EmptyView(message: 'Your watchlist is empty');
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (final row in rows)
                row.price != null
                    ? _DashboardTile(
                        price: row.price!,
                        usdInrRate: usdInrRate,
                        unitSystem: unitSystem,
                        phase: phaseFor(row.price!),
                      )
                    : _DashboardFallbackTile(asset: row.asset),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardWatchlistRow {
  final String asset;
  final MarketPrice? price;

  const _DashboardWatchlistRow({
    required this.asset,
    required this.price,
  });
}

class _DashboardTile extends StatelessWidget {
  final MarketPrice price;
  final double? usdInrRate;
  final UnitSystem unitSystem;
  final String phase;

  const _DashboardTile({
    required this.price,
    required this.usdInrRate,
    required this.unitSystem,
    this.phase = 'closed',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCommodity = price.instrumentType == 'commodity';
    final isCrypto = price.instrumentType == 'crypto';
    final useIndianCommodity = unitSystem == UnitSystem.indian &&
        usdInrRate != null &&
        (isCommodity || isCrypto);
    final fx = usdInrRate ?? 1.0;
    final displayValue = assetDisplayValue(
      asset: price.asset,
      rawPrice: price.price,
      useIndianUnits: useIndianCommodity,
      usdInrRate: fx,
      instrumentType: price.instrumentType,
    );
    final display = assetDisplayPriceAndUnit(
      asset: price.asset,
      rawPrice: price.price,
      useIndianUnits: useIndianCommodity,
      usdInrRate: fx,
      instrumentType: price.instrumentType,
      sourceUnit: price.unit,
    );
    final displayPrice = display.$1;
    final unitLabel = display.$2;

    final previousDisplayValue = price.previousClose == null
        ? null
        : assetDisplayValue(
            asset: price.asset,
            rawPrice: price.previousClose!,
            useIndianUnits: useIndianCommodity,
            usdInrRate: fx,
            instrumentType: price.instrumentType,
          );
    final changeTag = Formatters.changeWithDiff(
      current: displayValue,
      previous: previousDisplayValue,
      pct: price.changePercent,
    );
    final pctColor = (price.changePercent ?? 0) >= 0
        ? AppTheme.accentGreen
        : AppTheme.accentRed;
    final tickTs = price.lastTickTimestamp ?? price.timestamp;
    final freshness = Formatters.marketFreshnessSubtitle(
      tickTime: tickTs,
      isPredictive: price.isPredictive ?? false,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: InkWell(
        onTap: () {
          final encoded = Uri.encodeComponent(price.asset);
          if (price.instrumentType == 'crypto') {
            context.push('/crypto/detail/$encoded', extra: price);
          } else {
            context.push('/market/detail/$encoded', extra: price);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              AssetLogoBadge(
                asset: price.asset,
                instrumentType: price.instrumentType,
                size: 20,
                borderRadius: 6,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayName(price.asset),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        MarketStatusPill(phase: phase),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      freshness,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white30,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$displayPrice$unitLabel',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (changeTag.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      changeTag,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pctColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HealthStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
            height: 1.1,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.white38,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// Small coloured pill used in the favourites summary card header to
/// show an aggregate metric like "Avg 1D +0.42%". Borrowed back from
/// the deleted _StockFavoriteCard/_MfFavoriteCard widgets — still
/// needed by _FavoritesSummaryCard.
class _MetricChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSubtle;

  const _MetricChip({
    required this.label,
    required this.color,
    this.isSubtle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isSubtle ? 0.10 : 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// "Best / Worst" performer chip used at the bottom of the favourites
/// summary card. Displays a short symbol + its % change in the chip's
/// colour.
class _PerformerChip extends StatelessWidget {
  final String label;
  final String symbol;
  final double pct;
  final Color color;

  const _PerformerChip({
    required this.label,
    required this.symbol,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              symbol,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatPercent(pct, digits: 1),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact +0.00% / -0.00% / 0.0% formatter used by the summary
/// card header and the performer chips.
String _formatPercent(double? value, {int digits = 1}) {
  if (value == null) return '—';
  if (value == 0) return '0.${'0' * digits}%';
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(digits)}%';
}

class _DashboardFallbackTile extends StatelessWidget {
  final String asset;

  const _DashboardFallbackTile({required this.asset});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            AssetLogoBadge(
              asset: asset,
              size: 20,
              borderRadius: 6,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName(asset),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Syncing latest quote',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white30,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '--',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white54,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

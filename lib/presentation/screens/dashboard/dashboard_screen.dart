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
              await Future.wait([
                ref.refresh(latestMarketPricesProvider.future),
                ref.refresh(latestCommoditiesProvider.future),
              ]);
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
  bool _isEditMode = false;

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

  Future<void> _refreshLiveData() async {
    if (_isStockTab) {
      ref.invalidate(starredStockLiveQuotesProvider);
      await ref.read(starredStockLiveQuotesProvider.future);
      return;
    }
    ref.invalidate(starredMfLiveQuotesProvider);
    await ref.read(starredMfLiveQuotesProvider.future);
  }

  Future<void> _removeFavorite(StarredItem item) async {
    await ref.read(starredStocksProvider.notifier).toggle(
          type: item.type,
          id: item.id,
          name: item.name,
          percentChange: item.percentChange,
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
      return _FavoritesLoadingTab(
        onRefresh: _refreshLiveData,
        isStockTab: true,
        sortMode: _sortMode,
        isEditMode: _isEditMode,
        onSortSelected: _setSortMode,
        onToggleEdit: () => setState(() => _isEditMode = !_isEditMode),
      );
    }

    final rows = starred
        .map(
          (item) => _StockFavoriteRowData(
            item: item,
            live: liveQuotes[item.id],
          ),
        )
        .toList(growable: false)
      ..sort(_compareStockRows);

    final summary =
        _buildStockSummary(totalFavorites: starred.length, rows: rows);
    final showStaleNotice = liveAsync.hasError && liveQuotes.isEmpty;

    return RefreshIndicator(
      onRefresh: _refreshLiveData,
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
          ),
          const SizedBox(height: 10),
          _FavoritesControlsRow(
            isStockTab: true,
            sortMode: _sortMode,
            isEditMode: _isEditMode,
            onSortSelected: _setSortMode,
            onToggleEdit: () => setState(() => _isEditMode = !_isEditMode),
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            _StockFavoriteCard(
              row: row,
              isEditMode: _isEditMode,
              onRemove: () => _removeFavorite(row.item),
            ),
        ],
      ),
    );
  }

  Widget _buildMfTab(BuildContext context, List<StarredItem> starred) {
    final liveAsync = ref.watch(starredMfLiveQuotesProvider);
    final liveQuotes =
        liveAsync.valueOrNull ?? const <String, DiscoverMutualFundItem>{};

    if (liveAsync.isLoading && liveQuotes.isEmpty) {
      return _FavoritesLoadingTab(
        onRefresh: _refreshLiveData,
        isStockTab: false,
        sortMode: _sortMode,
        isEditMode: _isEditMode,
        onSortSelected: _setSortMode,
        onToggleEdit: () => setState(() => _isEditMode = !_isEditMode),
      );
    }

    final rows = starred
        .map(
          (item) => _MfFavoriteRowData(
            item: item,
            live: liveQuotes[item.id],
          ),
        )
        .toList(growable: false)
      ..sort(_compareMfRows);

    final summary = _buildMfSummary(totalFavorites: starred.length, rows: rows);
    final showStaleNotice = liveAsync.hasError && liveQuotes.isEmpty;

    return RefreshIndicator(
      onRefresh: _refreshLiveData,
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
          ),
          const SizedBox(height: 10),
          _FavoritesControlsRow(
            isStockTab: false,
            sortMode: _sortMode,
            isEditMode: _isEditMode,
            onSortSelected: _setSortMode,
            onToggleEdit: () => setState(() => _isEditMode = !_isEditMode),
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            _MfFavoriteCard(
              row: row,
              isEditMode: _isEditMode,
              onRemove: () => _removeFavorite(row.item),
            ),
        ],
      ),
    );
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

  const _FavoritesSummaryCard({
    required this.title,
    required this.icon,
    required this.averageLabel,
    required this.positiveLabel,
    required this.negativeLabel,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avgColor = (summary.averageChange ?? 0) >= 0
        ? AppTheme.accentGreen
        : AppTheme.accentRed;
    final coverageText = summary.freshest != null
        ? '${Formatters.updatedFreshness(summary.freshest!)} · ${summary.measuredCount}/${summary.totalFavorites} tracked'
        : summary.measuredCount > 0
            ? 'Using saved favorite snapshots for ${summary.measuredCount}/${summary.totalFavorites} items'
            : 'Waiting for fresh data';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.accentBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
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
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 10,
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
            if (summary.bestLabel != null && summary.worstLabel != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PerformerChip(
                      label: 'Best',
                      symbol: summary.bestLabel!,
                      pct: summary.bestValue ?? 0,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PerformerChip(
                      label: 'Worst',
                      symbol: summary.worstLabel!,
                      pct: summary.worstValue ?? 0,
                      color: AppTheme.accentRed,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              coverageText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesControlsRow extends StatelessWidget {
  final bool isStockTab;
  final _FavoritesSortMode sortMode;
  final bool isEditMode;
  final ValueChanged<_FavoritesSortMode> onSortSelected;
  final VoidCallback onToggleEdit;

  const _FavoritesControlsRow({
    required this.isStockTab,
    required this.sortMode,
    required this.isEditMode,
    required this.onSortSelected,
    required this.onToggleEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in _FavoritesSortMode.values)
                  ChoiceChip(
                    label: Text(mode.label(isStockTab: isStockTab)),
                    selected: sortMode == mode,
                    onSelected: (_) => onSortSelected(mode),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onToggleEdit,
            icon: Icon(
              isEditMode ? Icons.check_rounded : Icons.edit_outlined,
              size: 16,
            ),
            label: Text(isEditMode ? 'Done' : 'Edit'),
          ),
        ],
      ),
    );
  }
}

class _FavoritesLoadingTab extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final bool isStockTab;
  final _FavoritesSortMode sortMode;
  final bool isEditMode;
  final ValueChanged<_FavoritesSortMode> onSortSelected;
  final VoidCallback onToggleEdit;

  const _FavoritesLoadingTab({
    required this.onRefresh,
    required this.isStockTab,
    required this.sortMode,
    required this.isEditMode,
    required this.onSortSelected,
    required this.onToggleEdit,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 112),
        children: [
          const ShimmerCard(height: 170),
          const SizedBox(height: 10),
          _FavoritesControlsRow(
            isStockTab: isStockTab,
            sortMode: sortMode,
            isEditMode: isEditMode,
            onSortSelected: onSortSelected,
            onToggleEdit: onToggleEdit,
          ),
          const SizedBox(height: 8),
          const ShimmerCard(height: 124),
          const ShimmerCard(height: 124),
          const ShimmerCard(height: 124),
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

class _StockFavoriteCard extends StatelessWidget {
  final _StockFavoriteRowData row;
  final bool isEditMode;
  final Future<void> Function() onRemove;

  const _StockFavoriteCard({
    required this.row,
    required this.isEditMode,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sector = row.live?.sector ?? row.live?.industry;
    final freshness = row.freshness != null
        ? Formatters.updatedFreshness(row.freshness!)
        : 'Saved ${Formatters.relativeTime(DateTime.fromMillisecondsSinceEpoch(row.item.timestamp))}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: InkWell(
        onTap: () => context.push('/discover/stock/${row.item.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.show_chart_rounded,
                  size: 18,
                  color: AppTheme.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.symbol,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (row.live != null)
                          Text(
                            '₹ ${Formatters.fullPrice(row.live!.lastPrice)}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sector != null && sector.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sector,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (row.effectiveChange != null)
                          _MetricChip(
                            label:
                                _formatPercent(row.effectiveChange, digits: 1),
                            color: _changeColor(row.effectiveChange),
                          ),
                        if (row.live != null)
                          _MetricChip(
                            label:
                                'Score ${row.live!.score.toStringAsFixed(0)}',
                            color: AppTheme.accentBlue,
                          ),
                        if (row.live?.actionTag != null &&
                            row.live!.actionTag!.trim().isNotEmpty)
                          _MetricChip(
                            label: row.live!.actionTag!,
                            color: AppTheme.accentBlue,
                            isSubtle: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            freshness,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (isEditMode)
                          IconButton(
                            onPressed: onRemove,
                            tooltip: 'Remove favorite',
                            icon: const Icon(
                              Icons.remove_circle_outline_rounded,
                              color: AppTheme.accentRed,
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MfFavoriteCard extends StatelessWidget {
  final _MfFavoriteRowData row;
  final bool isEditMode;
  final Future<void> Function() onRemove;

  const _MfFavoriteCard({
    required this.row,
    required this.isEditMode,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final live = row.live;
    final subtitleParts = <String>[
      if ((live?.category ?? '').trim().isNotEmpty) live!.category!.trim(),
      if ((live?.fundClassification ?? '').trim().isNotEmpty)
        live!.fundClassification!.trim(),
    ];
    final metaParts = <String>[
      if (live?.expenseRatio != null)
        'Expense ${live!.expenseRatio!.toStringAsFixed(2)}%',
      if (live?.aumCr != null) 'AUM ₹${Formatters.fullPrice(live!.aumCr!)} Cr',
    ];
    final freshness = row.freshness != null
        ? Formatters.updatedFreshness(row.freshness!)
        : 'Saved ${Formatters.relativeTime(DateTime.fromMillisecondsSinceEpoch(row.item.timestamp))}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: InkWell(
        onTap: () => context.push('/discover/mf/${row.item.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: AppTheme.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            row.displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (live != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              '₹ ${Formatters.fullPrice(live.nav)}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (subtitleParts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitleParts.join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (row.effectiveReturn1y != null)
                          _MetricChip(
                            label:
                                '${_formatPercent(row.effectiveReturn1y, digits: 1)} 1Y',
                            color: _changeColor(row.effectiveReturn1y),
                          ),
                        if (live != null)
                          _MetricChip(
                            label: 'Score ${live.score.toStringAsFixed(0)}',
                            color: AppTheme.accentBlue,
                          ),
                        if ((live?.riskLevel ?? '').trim().isNotEmpty)
                          _MetricChip(
                            label: live!.riskLevel!,
                            color: _riskColor(live.riskLevel),
                            isSubtle: true,
                          ),
                      ],
                    ),
                    if (metaParts.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        metaParts.join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            freshness,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (isEditMode)
                          IconButton(
                            onPressed: onRemove,
                            tooltip: 'Remove favorite',
                            icon: const Icon(
                              Icons.remove_circle_outline_rounded,
                              color: AppTheme.accentRed,
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white38,
              fontSize: 10,
            ),
          ),
          Expanded(
            child: Text(
              symbol,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _formatPercent(pct, digits: 1),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isSubtle ? 0.1 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: isSubtle ? 0.18 : 0.24),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

String _formatPercent(double? value, {int digits = 1}) {
  if (value == null) return '—';
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(digits)}%';
}

Color _changeColor(double? value) {
  if (value == null) return Colors.white38;
  return value >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
}

Color _riskColor(String? value) {
  switch ((value ?? '').toLowerCase()) {
    case 'low':
    case 'low to moderate':
      return AppTheme.accentGreen;
    case 'moderately high':
    case 'high':
    case 'very high':
      return AppTheme.accentRed;
    case 'moderate':
    default:
      return AppTheme.accentBlue;
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white30,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
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

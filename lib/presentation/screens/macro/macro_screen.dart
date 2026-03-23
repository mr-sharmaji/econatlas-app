import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../core/error_utils.dart';
import '../../../core/square_badge_assets.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/macro_indicator.dart';
import '../../../data/models/macro_forecast.dart';
import '../../../data/models/econ_calendar_event.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

// =============================================================================
// Helpers & Config
// =============================================================================

String _countryLabel(String code) {
  switch (code.toUpperCase()) {
    case 'IN': return 'India';
    case 'US': return 'United States';
    default: return code;
  }
}

Color _macroValueColor(String indicatorName, double value) {
  switch (indicatorName) {
    case 'inflation':
    case 'inflation_cpi':
    case 'core_inflation':
      return value > 6 ? AppTheme.accentRed : (value > 4 ? AppTheme.accentOrange : AppTheme.accentGreen);
    case 'unemployment':
      return value > 6 ? AppTheme.accentRed : (value > 4 ? AppTheme.accentOrange : AppTheme.accentGreen);
    case 'gdp_growth':
    case 'iip':
      return value >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
    case 'pmi_manufacturing':
    case 'pmi_services':
      return value >= 50 ? AppTheme.accentGreen : AppTheme.accentRed;
    default:
      return Colors.white70;
  }
}

MacroIndicator? _latest(List<MacroIndicator> list, String name, String country) {
  final matches = list
      .where((i) => i.indicatorName == name && i.country == country)
      .toList();
  if (matches.isEmpty) return null;
  matches.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return matches.first;
}

/// Explainer text shown on tap
const _explainers = {
  'gdp_growth': 'Gross Domestic Product growth rate. Measures how fast the economy is expanding. Higher is better.',
  'inflation': 'Consumer Price Index (CPI) year-over-year change. Measures how fast prices are rising. RBI targets 4%.',
  'core_inflation': 'CPI excluding food and fuel. Shows underlying inflation trend without volatile components.',
  'unemployment': 'Percentage of labor force actively looking for work but unable to find it.',
  'repo_rate': 'Rate at which the central bank lends to commercial banks. Key tool for controlling inflation.',
  'pmi_manufacturing': 'Purchasing Managers Index for manufacturing. Above 50 = expansion, below 50 = contraction.',
  'pmi_services': 'Purchasing Managers Index for services sector. Above 50 = expansion.',
  'iip': 'Index of Industrial Production. Measures factory output growth year-over-year.',
  'forex_reserves': 'Foreign exchange reserves held by the central bank. Buffer against external shocks.',
  'trade_balance': 'Difference between exports and imports. Negative = trade deficit.',
  'current_account_deficit': 'Broadest measure of trade including services, income, and transfers.',
  'fiscal_deficit': 'Government spending minus revenue as % of GDP. Lower = more disciplined fiscal policy.',
  'bank_credit_growth': 'Rate at which banks are lending to the private sector. Proxy for credit demand.',
};

/// Ordered metrics per country
const _indiaMetrics = [
  'gdp_growth', 'inflation', 'core_inflation', 'repo_rate',
  'pmi_manufacturing', 'pmi_services', 'iip', 'unemployment',
  'forex_reserves', 'trade_balance', 'current_account_deficit',
  'fiscal_deficit', 'bank_credit_growth',
];

const _usMetrics = [
  'gdp_growth', 'inflation', 'core_inflation', 'repo_rate',
  'pmi_manufacturing', 'pmi_services', 'iip', 'unemployment',
  'trade_balance',
];

// =============================================================================
// MacroScreen
// =============================================================================

class MacroScreen extends ConsumerStatefulWidget {
  const MacroScreen({super.key});

  @override
  ConsumerState<MacroScreen> createState() => _MacroScreenState();
}

class _MacroScreenState extends ConsumerState<MacroScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

  void _openDetail(MacroIndicator ind) {
    context.push(
      '/macro/detail/${ind.country}/${ind.indicatorName}',
      extra: ind,
    );
  }

  void _showExplainer(BuildContext context, String indicatorName) {
    final text = _explainers[indicatorName];
    if (text == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(displayName(indicatorName)),
        content: Text(text),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(bottomTabReselectTickProvider(4), (prev, next) {
      if (prev == null || prev == next) return;
      _scrollToTop();
    });

    final macroAsync = ref.watch(allMacroIndicatorsProvider);
    final forecastAsync = ref.watch(macroForecastsProvider);
    final calendarAsync = ref.watch(econCalendarProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Economy'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allMacroIndicatorsProvider);
          ref.invalidate(macroForecastsProvider);
          ref.invalidate(econCalendarProvider);
        },
        child: macroAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [ShimmerList(itemCount: 8)],
          ),
          error: (err, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [ErrorView(
              message: friendlyErrorMessage(err),
              onRetry: () => ref.invalidate(allMacroIndicatorsProvider),
            )],
          ),
          data: (indicators) {
            final filtered = indicators
                .where((i) =>
                    i.indicatorName != 'interest_rate' &&
                    i.indicatorName != 'fii_net_cash' &&
                    i.indicatorName != 'dii_net_cash')
                .toList();

            if (filtered.isEmpty) {
              return const EmptyView(
                message: 'No macro data available',
                icon: Icons.analytics_outlined,
              );
            }

            // Get forecasts for inline display
            final forecasts = forecastAsync.valueOrNull ?? [];
            final forecastMap = <String, Map<int, double>>{};
            for (final f in forecasts) {
              final key = '${f.country}_${f.indicatorName}';
              forecastMap.putIfAbsent(key, () => {})[f.forecastYear] = f.value;
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 112),
              children: [
                // ── Upcoming Events Banner ──
                calendarAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (events) {
                    if (events.isEmpty) return const SizedBox.shrink();
                    final next = events.first;
                    final daysAway = next.eventDate.difference(DateTime.now()).inDays;
                    final dateStr = DateFormat('dd MMM').format(next.eventDate);
                    Color instColor;
                    switch (next.institution) {
                      case 'RBI': instColor = AppTheme.accentOrange; break;
                      case 'Fed': instColor = AppTheme.accentBlue; break;
                      default: instColor = Colors.white54;
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: instColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: instColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event, size: 16, color: instColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${next.eventName} · $dateStr',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: instColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: instColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              daysAway == 0 ? 'Today' : daysAway == 1 ? 'Tomorrow' : '${daysAway}d',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: instColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // ── India Section ──
                _CountryHeader(code: 'IN', label: 'India'),
                const SizedBox(height: 8),
                _MetricGrid(
                  indicators: filtered,
                  metricNames: _indiaMetrics,
                  country: 'IN',
                  forecastMap: forecastMap,
                  onTap: _openDetail,
                  onInfoTap: (name) => _showExplainer(context, name),
                ),
                const SizedBox(height: 20),

                // ── US Section ──
                _CountryHeader(code: 'US', label: 'United States'),
                const SizedBox(height: 8),
                _MetricGrid(
                  indicators: filtered,
                  metricNames: _usMetrics,
                  country: 'US',
                  forecastMap: forecastMap,
                  onTap: _openDetail,
                  onInfoTap: (name) => _showExplainer(context, name),
                ),
                const SizedBox(height: 20),

                // ── Forecast Table ──
                forecastAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (fcs) => fcs.isEmpty
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CountrySectionLabel(label: 'IMF Projections'),
                            const SizedBox(height: 8),
                            _ForecastSection(forecasts: fcs),
                            const SizedBox(height: 20),
                          ],
                        ),
                ),

                // ── Calendar ──
                calendarAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (events) => events.isEmpty
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CountrySectionLabel(label: 'Economic Calendar'),
                            const SizedBox(height: 8),
                            _CalendarSection(events: events),
                          ],
                        ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Country Header
// =============================================================================

class _CountryHeader extends StatelessWidget {
  final String code;
  final String label;
  const _CountryHeader({required this.code, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SquareBadgeSvg(
          assetPath: SquareBadgeAssets.flagPathForCountryCode(code),
          size: 20,
          borderRadius: 4,
        ),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _CountrySectionLabel extends StatelessWidget {
  final String label;
  const _CountrySectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

// =============================================================================
// 2-Column Metric Grid
// =============================================================================

class _MetricGrid extends StatelessWidget {
  final List<MacroIndicator> indicators;
  final List<String> metricNames;
  final String country;
  final Map<String, Map<int, double>> forecastMap;
  final ValueChanged<MacroIndicator> onTap;
  final ValueChanged<String> onInfoTap;

  const _MetricGrid({
    required this.indicators,
    required this.metricNames,
    required this.country,
    required this.forecastMap,
    required this.onTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    // Filter to metrics that have data
    final available = metricNames
        .where((name) => _latest(indicators, name, country) != null)
        .toList();

    if (available.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No data available', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white38)),
      );
    }

    // Build 2-column grid
    final rows = <Widget>[];
    for (int i = 0; i < available.length; i += 2) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildCard(context, available[i])),
          const SizedBox(width: 8),
          if (i + 1 < available.length)
            Expanded(child: _buildCard(context, available[i + 1]))
          else
            const Expanded(child: SizedBox.shrink()),
        ],
      ));
      if (i + 2 < available.length) rows.add(const SizedBox(height: 8));
    }

    return Column(children: rows);
  }

  Widget _buildCard(BuildContext context, String name) {
    final theme = Theme.of(context);
    final ind = _latest(indicators, name, country)!;
    final value = Formatters.macroValue(ind.value, ind.indicatorName);
    final color = _macroValueColor(ind.indicatorName, ind.value);
    final dateStr = DateFormat('MMM yyyy').format(ind.timestamp);

    // Forecast inline
    final forecastKey = '${country}_${name}';
    final fcs = forecastMap[forecastKey];
    String? forecastLabel;
    if (fcs != null && fcs.isNotEmpty) {
      final nextYear = fcs.keys.where((y) => y >= DateTime.now().year).toList()..sort();
      if (nextYear.isNotEmpty) {
        final y = nextYear.first;
        forecastLabel = '${fcs[y]!.toStringAsFixed(1)}% ${y}F';
      }
    }

    return GestureDetector(
      onTap: () => onTap(ind),
      onLongPress: () => onInfoTap(name),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Indicator name + info icon
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayName(name),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white54,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => onInfoTap(name),
                  child: Icon(Icons.info_outline, size: 14, color: Colors.white24),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: Big value
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            // Row 3: Date + forecast
            Row(
              children: [
                Text(
                  dateStr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
                if (forecastLabel != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      forecastLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.accentBlue,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Forecast Section
// =============================================================================

class _ForecastSection extends StatelessWidget {
  final List<MacroForecast> forecasts;

  const _ForecastSection({required this.forecasts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gdpForecasts = forecasts.where((f) => f.indicatorName == 'gdp_growth').toList();
    final inflForecasts = forecasts.where((f) => f.indicatorName == 'inflation').toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (gdpForecasts.isNotEmpty) ...[
              Text('GDP Growth', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _forecastTable(theme, gdpForecasts),
              const SizedBox(height: 12),
            ],
            if (inflForecasts.isNotEmpty) ...[
              Text('Inflation', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _forecastTable(theme, inflForecasts),
            ],
            const SizedBox(height: 8),
            Text(
              'Source: IMF World Economic Outlook',
              style: theme.textTheme.labelSmall?.copyWith(color: Colors.white38, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _forecastTable(ThemeData theme, List<MacroForecast> data) {
    final years = data.map((f) => f.forecastYear).toSet().toList()..sort();
    final inData = {for (final f in data.where((f) => f.country == 'IN')) f.forecastYear: f.value};
    final usData = {for (final f in data.where((f) => f.country == 'US')) f.forecastYear: f.value};

    return Table(
      columnWidths: {
        0: const FlexColumnWidth(1.2),
        for (int i = 1; i <= years.length; i++) i: const FlexColumnWidth(1),
      },
      children: [
        TableRow(children: [
          const SizedBox.shrink(),
          ...years.map((y) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${y}F', textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.white54)),
          )),
        ]),
        _countryRow(theme, 'IN', 'India', years, inData),
        _countryRow(theme, 'US', 'US', years, usData),
      ],
    );
  }

  TableRow _countryRow(ThemeData theme, String code, String label, List<int> years, Map<int, double> data) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SquareBadgeSvg(assetPath: SquareBadgeAssets.flagPathForCountryCode(code), size: 12, borderRadius: 2),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
        ]),
      ),
      ...years.map((y) {
        final val = data[y];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            val != null ? '${val.toStringAsFixed(1)}%' : '—',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: val != null && val >= 0 ? AppTheme.accentGreen : AppTheme.accentRed,
            ),
          ),
        );
      }),
    ]);
  }
}

// =============================================================================
// Calendar Section
// =============================================================================

class _CalendarSection extends StatelessWidget {
  final List<EconCalendarEvent> events;

  const _CalendarSection({required this.events});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final upcoming = events.take(6).toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          children: [
            for (int i = 0; i < upcoming.length; i++) ...[
              _eventRow(theme, upcoming[i], now),
              if (i < upcoming.length - 1)
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _eventRow(ThemeData theme, EconCalendarEvent event, DateTime now) {
    final daysAway = event.eventDate.difference(now).inDays;
    final isThisWeek = daysAway <= 7 && daysAway >= 0;
    final dateStr = DateFormat('dd MMM').format(event.eventDate);
    Color instColor;
    switch (event.institution) {
      case 'RBI': instColor = AppTheme.accentOrange; break;
      case 'Fed': instColor = AppTheme.accentBlue; break;
      case 'ECB': instColor = AppTheme.accentTeal; break;
      case 'BoJ': instColor = AppTheme.accentRed; break;
      default: instColor = Colors.white54;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(dateStr, style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600, color: isThisWeek ? AppTheme.accentGreen : Colors.white54)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: instColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(event.institution, style: theme.textTheme.labelSmall?.copyWith(
              color: instColor, fontWeight: FontWeight.w700, fontSize: 10)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(event.eventName, style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: isThisWeek ? FontWeight.w600 : FontWeight.w400),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(
            daysAway == 0 ? 'Today' : daysAway == 1 ? 'Tomorrow' : '${daysAway}d',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isThisWeek ? AppTheme.accentGreen : Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class MacroDetailScreen extends ConsumerStatefulWidget {
  final String indicatorName;
  final MacroIndicator? initialIndicator;
  final String? countryOverride;

  const MacroDetailScreen({
    super.key,
    required this.indicatorName,
    this.countryOverride,
    this.initialIndicator,
  });

  @override
  ConsumerState<MacroDetailScreen> createState() => _MacroDetailScreenState();
}

class _MacroDetailScreenState extends ConsumerState<MacroDetailScreen> {
  ChartRange _chartRange = ChartRange.oneYear;
  final ScrollController _rangeScrollController = ScrollController();
  bool _showRangeScrollHint = true;

  @override
  void initState() {
    super.initState();
    _rangeScrollController.addListener(_onRangeScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRangeScroll());
  }

  @override
  void dispose() {
    _rangeScrollController.removeListener(_onRangeScroll);
    _rangeScrollController.dispose();
    super.dispose();
  }

  void _onRangeScroll() {
    if (!_rangeScrollController.hasClients) return;
    final atEnd = _rangeScrollController.offset >=
        _rangeScrollController.position.maxScrollExtent - 4;
    if (_showRangeScrollHint == atEnd) {
      setState(() => _showRangeScrollHint = !atEnd);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String country = widget.initialIndicator?.country ??
        widget.countryOverride ??
        ref.watch(selectedCountryProvider);
    final historyAsync = ref.watch(macroHistoryProvider(country));

    return Scaffold(
      appBar: AppBar(title: Text(displayName(widget.indicatorName))),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(macroHistoryProvider(country)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.initialIndicator != null) ...[
              _buildTopCard(theme, historyAsync.valueOrNull),
              const SizedBox(height: 16),
            ],
            Text('Historical Data',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _chartRangeChips(context),
            const SizedBox(height: 12),
            historyAsync.when(
              loading: () => const ShimmerCard(height: 200),
              error: (err, _) => ErrorView(
                message: friendlyErrorMessage(err),
                onRetry: () => ref.invalidate(macroHistoryProvider(country)),
              ),
              data: (indicators) {
                final byIndicator = indicators
                    .where((i) => i.indicatorName == widget.indicatorName)
                    .toList()
                  ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
                if (byIndicator.isEmpty) {
                  return const EmptyView(message: 'No historical data');
                }
                final filtered = _filterByRange(byIndicator);
                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(
                      child: Text(
                        'No data in this range',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  );
                }
                final isShortRange = _chartRange == ChartRange.oneMonth ||
                    _chartRange == ChartRange.threeMonths;
                final values = filtered.map((i) => i.value).toList();
                final open = values.first;
                final close = values.last;
                final high = values.reduce((a, b) => a > b ? a : b);
                final low = values.reduce((a, b) => a < b ? a : b);
                final avg =
                    values.fold<double>(0, (s, p) => s + p) / values.length;
                final spreadPct =
                    open != 0 ? ((high - low) / open) * 100 : null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MacroRangeStatsCard(
                      open: open,
                      high: high,
                      low: low,
                      close: close,
                      avg: avg,
                      spreadPct: spreadPct,
                    ),
                    const SizedBox(height: 12),
                    PriceLineChart(
                      prices: values,
                      timestamps: filtered.map((i) => i.timestamp).toList(),
                      unit: 'percent',
                      isShortRange: isShortRange,
                      pricePrefix: null,
                      chartUnitHint: '%',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCard(ThemeData theme, List<MacroIndicator>? history) {
    final ind = widget.initialIndicator!;
    double? rangePct;
    if (history != null && history.isNotEmpty) {
      final byIndicator = history
          .where((i) => i.indicatorName == widget.indicatorName)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final filtered = _filterByRange(byIndicator);
      if (filtered.length >= 2) {
        final first = filtered.first.value;
        final last = filtered.last.value;
        if (first != 0) rangePct = ((last - first) / first) * 100;
      }
    }
    final rangeLabel = _chartRange.label;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Formatters.macroValue(ind.value, ind.indicatorName),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (rangePct != null) ...[
              const SizedBox(height: 6),
              Text(
                '$rangeLabel change  ${Formatters.changeTag(rangePct)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: (rangePct >= 0)
                      ? AppTheme.accentGreen
                      : AppTheme.accentRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${_countryLabel(ind.country)} · Last updated ${Formatters.relativeTime(ind.timestamp)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MacroIndicator> _filterByRange(List<MacroIndicator> sorted) {
    if (_chartRange == ChartRange.all) return sorted;
    final cutoff = DateTime.now().subtract(_chartRange.duration);
    return sorted.where((i) => !i.timestamp.isBefore(cutoff)).toList();
  }

  Widget _chartRangeChips(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          SingleChildScrollView(
            controller: _rangeScrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...ChartRange.values.map((r) {
                  final selected = r == _chartRange;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(r.label),
                      selected: selected,
                      onSelected: (_) => setState(() => _chartRange = r),
                      selectedColor: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.4),
                      checkmarkColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                }),
                const SizedBox(width: 24),
              ],
            ),
          ),
          if (_showRangeScrollHint)
            IgnorePointer(
              child: Container(
                width: 32,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      theme.scaffoldBackgroundColor.withValues(alpha: 0),
                      theme.scaffoldBackgroundColor,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MacroRangeStatsCard extends StatelessWidget {
  final double open;
  final double high;
  final double low;
  final double close;
  final double avg;
  final double? spreadPct;

  const _MacroRangeStatsCard({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.avg,
    this.spreadPct,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: _stat(theme, 'Open',
                        Formatters.price(open, unit: 'percent'))),
                const SizedBox(width: 12),
                Expanded(
                    child: _stat(theme, 'High',
                        Formatters.price(high, unit: 'percent'))),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: _stat(
                        theme, 'Low', Formatters.price(low, unit: 'percent'))),
                const SizedBox(width: 12),
                Expanded(
                    child: _stat(theme, 'Close',
                        Formatters.price(close, unit: 'percent'))),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: _stat(
                        theme, 'Avg', Formatters.price(avg, unit: 'percent'))),
                if (spreadPct != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                      child: _stat(theme, 'High–Low',
                          Formatters.price(spreadPct!, unit: 'percent'))),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(ThemeData theme, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}

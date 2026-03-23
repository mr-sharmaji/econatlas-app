import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/macro_indicator.dart';
import '../../data/models/macro_forecast.dart';
import '../../data/models/econ_calendar_event.dart';
import '../../data/models/institutional_flow_overview.dart';
import '../../data/models/macro_metadata.dart';
import '../../data/models/macro_regime.dart';
import '../../data/models/macro_summary.dart';
import '../../data/models/macro_linkage.dart';
import '../../data/models/economic_event.dart';
import '../../core/constants.dart';
import 'repository_providers.dart';

const _economyCoreIndicators = <String>[
  'gdp_growth',
  'inflation',
  'repo_rate',
  'unemployment',
];
const _economyWorldCountries = <String>['IN', 'US', 'EU', 'JP'];
const _economyHiddenIndicators = <String>{'fii_net_cash', 'dii_net_cash'};
const _economyFocusCountries = <String>['IN', 'US'];

const _economyLabels = <String, String>{
  'gdp_growth': 'GDP Growth',
  'inflation': 'Inflation',
  'repo_rate': 'Policy Rate',
  'unemployment': 'Unemployment',
  'core_inflation': 'Core Inflation',
  'food_inflation': 'Food Inflation',
  'pmi_manufacturing': 'PMI Manufacturing',
  'pmi_services': 'PMI Services',
  'iip': 'Industrial Production',
  'bank_credit_growth': 'Bank Credit Growth',
  'trade_balance': 'Trade Balance',
  'current_account_deficit': 'Current Account',
  'fiscal_deficit': 'Fiscal Deficit',
  'forex_reserves': 'FX Reserves',
  'bond_yield_10y': '10Y Yield',
  'bond_yield_2y': '2Y Yield',
  'gst_collection': 'GST Collection',
};

const _economyExtraOrder = <String>[
  'core_inflation',
  'food_inflation',
  'iip',
  'pmi_manufacturing',
  'pmi_services',
  'bank_credit_growth',
  'trade_balance',
  'current_account_deficit',
  'fiscal_deficit',
  'forex_reserves',
  'bond_yield_10y',
  'bond_yield_2y',
  'gst_collection',
];

final selectedCountryProvider = StateProvider<String>((ref) => 'IN');

final allMacroIndicatorsProvider =
    FutureProvider.autoDispose<List<MacroIndicator>>((ref) async {
  final repo = ref.watch(macroRepositoryProvider);
  final response = await repo.getMacroIndicators(latestOnly: true);
  return response.indicators;
});

final macroIndicatorsProvider =
    FutureProvider.autoDispose<List<MacroIndicator>>((ref) async {
  final country = ref.watch(selectedCountryProvider);
  final repo = ref.watch(macroRepositoryProvider);
  final response =
      await repo.getMacroIndicators(country: country, latestOnly: true);
  return response.indicators;
});

final macroHistoryProvider = FutureProvider.autoDispose
    .family<List<MacroIndicator>, String>((ref, country) async {
  final repo = ref.watch(macroRepositoryProvider);
  final response = await repo.getMacroIndicators(
    country: country,
    limit: AppConstants.chartDataLimit,
  );
  return response.indicators;
});

class EconomyMetricData {
  final String indicator;
  final String label;
  final double? value;
  final double? delta;

  const EconomyMetricData({
    required this.indicator,
    required this.label,
    this.value,
    this.delta,
  });
}

class EconomyCountryFocusData {
  final String country;
  final List<EconomyMetricData> coreMetrics;
  final List<EconomyMetricData> extraMetrics;

  const EconomyCountryFocusData({
    required this.country,
    required this.coreMetrics,
    required this.extraMetrics,
  });
}

String _metricLabel(String indicator) =>
    _economyLabels[indicator] ?? indicator.replaceAll('_', ' ');

MacroIndicator? _latestMetric(List<MacroIndicator> rows, String indicator) {
  MacroIndicator? latest;
  for (final row in rows) {
    if (row.indicatorName != indicator) continue;
    if (latest == null || row.timestamp.isAfter(latest.timestamp)) {
      latest = row;
    }
  }
  return latest;
}

double? _metricDelta(List<MacroIndicator> rows, String indicator) {
  final points = rows.where((r) => r.indicatorName == indicator).toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  if (points.length < 2) return null;
  return points[0].value - points[1].value;
}

EconomyMetricData _toMetric(List<MacroIndicator> rows, String indicator) {
  final latest = _latestMetric(rows, indicator);
  return EconomyMetricData(
    indicator: indicator,
    label: _metricLabel(indicator),
    value: latest?.value,
    delta: _metricDelta(rows, indicator),
  );
}

int _metricSortIndex(String indicator) {
  final idx = _economyExtraOrder.indexOf(indicator);
  if (idx >= 0) return idx;
  return _economyExtraOrder.length + indicator.codeUnitAt(0);
}

final economyFocusCountriesProvider =
    Provider.autoDispose<List<String>>((ref) => _economyFocusCountries);

final economyWorldSnapshotProvider =
    FutureProvider.autoDispose<List<EconomyMetricData>>((ref) async {
  final repo = ref.watch(macroRepositoryProvider);
  final historyByCountry = <String, List<MacroIndicator>>{};

  for (final country in _economyWorldCountries) {
    final response = await repo.getMacroIndicators(
      country: country,
      limit: AppConstants.chartDataLimit,
    );
    historyByCountry[country] = response.indicators;
  }

  return _economyCoreIndicators.map((indicator) {
    final values = <double>[];
    final deltas = <double>[];
    for (final country in _economyWorldCountries) {
      final history = historyByCountry[country] ?? const <MacroIndicator>[];
      final latest = _latestMetric(history, indicator);
      if (latest != null) values.add(latest.value);
      final delta = _metricDelta(history, indicator);
      if (delta != null) deltas.add(delta);
    }

    final value =
        values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
    final delta =
        deltas.isEmpty ? null : deltas.reduce((a, b) => a + b) / deltas.length;

    return EconomyMetricData(
      indicator: indicator,
      label: _metricLabel(indicator),
      value: value,
      delta: delta,
    );
  }).toList(growable: false);
});

final economyCountryFocusProvider = FutureProvider.autoDispose
    .family<EconomyCountryFocusData, String>((ref, country) async {
  final repo = ref.watch(macroRepositoryProvider);
  final response = await repo.getMacroIndicators(
    country: country,
    limit: AppConstants.chartDataLimit,
  );
  final rows = response.indicators
      .where((r) => !_economyHiddenIndicators.contains(r.indicatorName))
      .toList(growable: false);

  final core = _economyCoreIndicators
      .map((indicator) => _toMetric(rows, indicator))
      .toList(growable: false);

  final byIndicator = <String>{for (final row in rows) row.indicatorName};
  final extras = byIndicator
      .where((indicator) => !_economyCoreIndicators.contains(indicator))
      .map((indicator) => _toMetric(rows, indicator))
      .toList()
    ..sort((a, b) {
      final left = _metricSortIndex(a.indicator);
      final right = _metricSortIndex(b.indicator);
      if (left != right) return left.compareTo(right);
      return a.label.compareTo(b.label);
    });

  return EconomyCountryFocusData(
    country: country,
    coreMetrics: core,
    extraMetrics: extras,
  );
});

final institutionalFlowsOverviewProvider =
    FutureProvider.autoDispose<InstitutionalFlowsOverview>((ref) async {
  final ds = ref.watch(remoteDataSourceProvider);
  return ds.getInstitutionalFlowsOverview(sessions: 30);
});

final macroForecastsProvider =
    FutureProvider.autoDispose<List<MacroForecast>>((ref) async {
  final ds = ref.watch(remoteDataSourceProvider);
  final response = await ds.getMacroForecasts();
  return response.forecasts;
});

final econCalendarProvider =
    FutureProvider.autoDispose<List<EconCalendarEvent>>((ref) async {
  final ds = ref.watch(remoteDataSourceProvider);
  final response = await ds.getEconCalendar(daysAhead: 180);
  return response.events;
});

final econCalendarWithHistoryProvider =
    FutureProvider.autoDispose<List<EconCalendarEvent>>((ref) async {
  final ds = ref.watch(remoteDataSourceProvider);
  final response = await ds.getEconCalendar(daysAhead: 365, includePast: true);
  return response.events;
});

final macroMetadataProvider =
    FutureProvider.autoDispose<List<MacroIndicatorMetadata>>((ref) async {
  final ds = ref.watch(remoteDataSourceProvider);
  final response = await ds.getMacroMetadata();
  return response.items;
});

final macroMetadataByCountryProvider = FutureProvider.autoDispose
    .family<List<MacroIndicatorMetadata>, String>((ref, country) async {
  final ds = ref.watch(remoteDataSourceProvider);
  final response = await ds.getMacroMetadata(country: country);
  return response.items;
});

final macroRegimeProvider =
    FutureProvider.autoDispose<MacroRegimeResponse>((ref) async {
  final ds = ref.watch(remoteDataSourceProvider);
  return ds.getMacroRegime();
});

final macroSummaryProvider =
    FutureProvider.autoDispose<MacroSummaryResponse>((ref) async {
  final ds = ref.watch(remoteDataSourceProvider);
  return ds.getMacroSummary();
});

typedef MacroLinkagesQuery = ({
  String country,
  String indicator,
  int windowDays
});

final macroLinkagesProvider = FutureProvider.autoDispose
    .family<MacroLinkagesResponse, MacroLinkagesQuery>((ref, query) async {
  final ds = ref.watch(remoteDataSourceProvider);
  return ds.getMacroLinkages(
    country: query.country,
    indicator: query.indicator,
    windowDays: query.windowDays,
  );
});

final economicEventsProvider =
    FutureProvider.autoDispose<List<EconomicEvent>>((ref) async {
  final ds = ref.watch(remoteDataSourceProvider);
  final response = await ds.getEvents(limit: 120);
  return response.events;
});

/// History for India — used by economy page sparklines
final indiaHistoryProvider =
    FutureProvider.autoDispose<List<MacroIndicator>>((ref) async {
  final repo = ref.watch(macroRepositoryProvider);
  final response = await repo.getMacroIndicators(country: 'IN', limit: 5000);
  return response.indicators;
});

/// History for US — used by economy page sparklines
final usHistoryProvider =
    FutureProvider.autoDispose<List<MacroIndicator>>((ref) async {
  final repo = ref.watch(macroRepositoryProvider);
  final response = await repo.getMacroIndicators(country: 'US', limit: 5000);
  return response.indicators;
});

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

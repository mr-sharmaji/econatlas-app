import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/macro_indicator.dart';
import '../../data/models/macro_forecast.dart';
import '../../data/models/econ_calendar_event.dart';
import '../../data/models/institutional_flow_overview.dart';
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

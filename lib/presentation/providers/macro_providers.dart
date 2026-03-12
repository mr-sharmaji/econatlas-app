import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/macro_indicator.dart';
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

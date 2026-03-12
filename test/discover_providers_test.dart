import 'package:flutter_test/flutter_test.dart';
import 'package:econatlas_app/presentation/providers/discover_providers.dart';

void main() {
  test('stock preset mapping round-trip', () {
    for (final preset in DiscoverStockPreset.values) {
      final parsed = DiscoverStockPresetX.fromApi(preset.apiValue);
      expect(parsed, preset);
    }
  });

  test('mutual fund preset mapping round-trip', () {
    for (final preset in DiscoverMutualFundPreset.values) {
      final parsed = DiscoverMutualFundPresetX.fromApi(preset.apiValue);
      expect(parsed, preset);
    }
  });

  test('stock filters serialize and parse', () {
    const filters = DiscoverStockFilters(
      search: 'HDFC',
      sector: 'Financials',
      minScore: 55,
      minPe: 10,
      maxPe: 25,
      sourceStatus: 'primary',
      sortBy: 'roe',
      sortOrder: 'desc',
    );

    final parsed = DiscoverStockFilters.fromJson(filters.toJson());
    expect(parsed.search, 'HDFC');
    expect(parsed.sector, 'Financials');
    expect(parsed.minScore, 55);
    expect(parsed.minPe, 10);
    expect(parsed.maxPe, 25);
    expect(parsed.sourceStatus, 'primary');
  });

  test('mutual fund filters serialize and parse', () {
    const filters = DiscoverMutualFundFilters(
      category: 'Equity',
      riskLevel: 'Moderate',
      directOnly: true,
      minScore: 60,
      maxExpenseRatio: 1.2,
      sourceStatus: 'fallback',
    );

    final parsed = DiscoverMutualFundFilters.fromJson(filters.toJson());
    expect(parsed.category, 'Equity');
    expect(parsed.riskLevel, 'Moderate');
    expect(parsed.directOnly, true);
    expect(parsed.minScore, 60);
    expect(parsed.maxExpenseRatio, 1.2);
    expect(parsed.sourceStatus, 'fallback');
  });
}

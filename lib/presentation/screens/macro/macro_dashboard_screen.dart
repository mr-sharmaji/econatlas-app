import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/error_utils.dart';
import '../../../core/square_badge_assets.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/econ_calendar_event.dart';
import '../../../data/models/macro_indicator.dart';
import '../../../data/models/macro_metadata.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

const _focusCountries = <String>['IN', 'US'];
const _worldCountries = <String>['IN', 'US', 'EU', 'JP'];
const _countryNames = <String, String>{
  'IN': 'India',
  'US': 'United States',
  'EU': 'Europe',
  'JP': 'Japan',
};

const _neutralPolicyRate = <String, double>{
  'IN': 6.0,
  'US': 2.5,
  'EU': 2.0,
  'JP': 1.0,
};

String _countryLabel(String code) => _countryNames[code] ?? code;

double? _latestByCountry(
  List<MacroIndicator> rows,
  String country,
  String indicator,
) {
  MacroIndicator? latest;
  for (final row in rows) {
    if (row.country != country || row.indicatorName != indicator) {
      continue;
    }
    if (latest == null || row.timestamp.isAfter(latest.timestamp)) {
      latest = row;
    }
  }
  return latest?.value;
}

class _MetricVisualState {
  final Color color;
  final String context;

  const _MetricVisualState({
    required this.color,
    required this.context,
  });
}

_MetricVisualState _metricVisual({
  required EconomyMetricData metric,
  required MacroIndicatorMetadata? metadata,
  required String? country,
}) {
  final value = metric.value;
  if (value == null) {
    return const _MetricVisualState(
      color: Colors.white70,
      context: 'Latest value is not available yet.',
    );
  }
  final t = metadata?.thresholds ?? const <String, double>{};
  final indicator = metric.indicator;

  if (indicator == 'inflation') {
    final target = country == 'IN'
        ? (t['target_in'] ?? 4.0)
        : (t['target_us_eu_jp'] ?? 2.0);
    if (value <= target) {
      return const _MetricVisualState(
        color: AppTheme.accentGreen,
        context: 'Inflation is at or below target.',
      );
    }
    if (value <= target + 1.5) {
      return const _MetricVisualState(
        color: AppTheme.accentOrange,
        context: 'Inflation is above target and needs monitoring.',
      );
    }
    return const _MetricVisualState(
      color: AppTheme.accentRed,
      context: 'Inflation is well above target and may pressure policy.',
    );
  }

  if (indicator == 'core_inflation') {
    final elevated = t['elevated'] ?? 4.0;
    final sticky = t['sticky'] ?? 5.0;
    if (value >= sticky) {
      return const _MetricVisualState(
        color: AppTheme.accentRed,
        context: 'Core inflation is sticky at elevated levels.',
      );
    }
    if (value >= elevated) {
      return const _MetricVisualState(
        color: AppTheme.accentOrange,
        context: 'Core inflation remains elevated.',
      );
    }
    return const _MetricVisualState(
      color: AppTheme.accentGreen,
      context: 'Core inflation is relatively contained.',
    );
  }

  if (indicator == 'food_inflation') {
    final elevated = t['elevated'] ?? 6.0;
    final high = t['high'] ?? 8.0;
    if (value >= high) {
      return const _MetricVisualState(
        color: AppTheme.accentRed,
        context: 'Food inflation is high and can strain households.',
      );
    }
    if (value >= elevated) {
      return const _MetricVisualState(
        color: AppTheme.accentOrange,
        context: 'Food inflation is elevated.',
      );
    }
    return const _MetricVisualState(
      color: AppTheme.accentGreen,
      context: 'Food inflation is in a manageable range.',
    );
  }

  if (indicator == 'gdp_growth') {
    final slowdown = t['slowdown'] ?? 2.0;
    final strong = t['strong'] ?? 6.0;
    if (value >= strong) {
      return const _MetricVisualState(
        color: AppTheme.accentGreen,
        context: 'Growth momentum is strong.',
      );
    }
    if (value <= slowdown) {
      return const _MetricVisualState(
        color: AppTheme.accentRed,
        context: 'Growth is weak and may signal slowdown.',
      );
    }
    return const _MetricVisualState(
      color: AppTheme.accentOrange,
      context: 'Growth is moderate.',
    );
  }

  if (indicator == 'unemployment') {
    final moderate = t['moderate'] ?? 4.5;
    final high = t['high'] ?? 6.0;
    if (value >= high) {
      return const _MetricVisualState(
        color: AppTheme.accentRed,
        context: 'Unemployment is high.',
      );
    }
    if (value >= moderate) {
      return const _MetricVisualState(
        color: AppTheme.accentOrange,
        context: 'Unemployment is moderately elevated.',
      );
    }
    return const _MetricVisualState(
      color: AppTheme.accentGreen,
      context: 'Labor market appears healthy.',
    );
  }

  if (indicator == 'repo_rate') {
    final neutral = _neutralPolicyRate[country] ?? 2.5;
    final restrictiveGap = t['restrictive_gap'] ?? 1.5;
    if (value >= neutral + restrictiveGap) {
      return const _MetricVisualState(
        color: AppTheme.accentOrange,
        context: 'Policy appears restrictive versus neutral levels.',
      );
    }
    return const _MetricVisualState(
      color: AppTheme.accentBlue,
      context: 'Policy stance is near neutral range.',
    );
  }

  if (indicator.startsWith('pmi_')) {
    final expansion = t['expansion'] ?? 50.0;
    final strong = t['strong'] ?? 55.0;
    if (value >= strong) {
      return const _MetricVisualState(
        color: AppTheme.accentGreen,
        context: 'Business activity shows strong expansion.',
      );
    }
    if (value >= expansion) {
      return const _MetricVisualState(
        color: AppTheme.accentOrange,
        context: 'Business activity is expanding.',
      );
    }
    return const _MetricVisualState(
      color: AppTheme.accentRed,
      context: 'Business activity indicates contraction.',
    );
  }

  if (indicator == 'iip' || indicator == 'bank_credit_growth') {
    final weak = t['weak'] ?? 0.0;
    final strong = t['strong'] ?? 5.0;
    if (value >= strong) {
      return const _MetricVisualState(
        color: AppTheme.accentGreen,
        context: 'Momentum is strong.',
      );
    }
    if (value >= weak) {
      return const _MetricVisualState(
        color: AppTheme.accentOrange,
        context: 'Momentum is positive but moderate.',
      );
    }
    return const _MetricVisualState(
      color: AppTheme.accentRed,
      context: 'Momentum is weak.',
    );
  }

  if (indicator == 'trade_balance' || indicator == 'current_account_deficit') {
    if (value >= 0) {
      return const _MetricVisualState(
        color: AppTheme.accentGreen,
        context: 'Balance is in surplus territory.',
      );
    }
    if (value >= -20) {
      return const _MetricVisualState(
        color: AppTheme.accentOrange,
        context: 'Balance is in moderate deficit.',
      );
    }
    return const _MetricVisualState(
      color: AppTheme.accentRed,
      context: 'Balance is in a wide deficit.',
    );
  }

  if (indicator == 'fiscal_deficit') {
    final wide = t['wide'] ?? 5.0;
    if (value > wide) {
      return const _MetricVisualState(
        color: AppTheme.accentRed,
        context: 'Fiscal deficit is wider than preferred.',
      );
    }
    return const _MetricVisualState(
      color: AppTheme.accentOrange,
      context: 'Fiscal deficit is within a manageable range.',
    );
  }

  return const _MetricVisualState(
    color: AppTheme.accentBlue,
    context: 'Reference trend is available from macro source metadata.',
  );
}

String _metricValueLabel(EconomyMetricData metric) {
  if (metric.value == null) return 'n/a';
  return Formatters.macroValue(metric.value!, metric.indicator);
}

String _metricDeltaLabel(EconomyMetricData metric) {
  final delta = metric.delta;
  if (delta == null) return 'No prior release';
  if (delta.abs() < 0.005) return 'Flat vs prev';
  final sign = delta >= 0 ? '+' : '';
  if (_isPercentMetric(metric.indicator)) {
    return '$sign${delta.toStringAsFixed(2)} pct pts';
  }
  return '$sign${delta.toStringAsFixed(2)}';
}

void _showMetricHelper(
  BuildContext context, {
  required EconomyMetricData metric,
  required MacroIndicatorMetadata? metadata,
  required _MetricVisualState visual,
}) {
  final metricName = metadata?.displayName.isNotEmpty == true
      ? metadata!.displayName
      : metric.label;
  final helperText = metadata?.helperText.trim();
  final fallbackText = '${metric.label} insight is not available yet.';
  final resolvedHelper =
      (helperText != null && helperText.isNotEmpty) ? helperText : fallbackText;

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppTheme.cardDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final bottomClearance = media.padding.bottom + 96;
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomClearance),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                metricName,
                style: TextStyle(
                  color: visual.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                resolvedHelper,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _MetricGroup {
  final String title;
  final List<EconomyMetricData> metrics;

  const _MetricGroup({
    required this.title,
    required this.metrics,
  });
}

List<_MetricGroup> _extraGroups(List<EconomyMetricData> extras) {
  final prices = <EconomyMetricData>[];
  final activity = <EconomyMetricData>[];
  final external = <EconomyMetricData>[];
  final fiscal = <EconomyMetricData>[];
  final other = <EconomyMetricData>[];

  for (final metric in extras) {
    switch (metric.indicator) {
      case 'core_inflation':
      case 'food_inflation':
        prices.add(metric);
        break;
      case 'iip':
      case 'pmi_manufacturing':
      case 'pmi_services':
      case 'bank_credit_growth':
        activity.add(metric);
        break;
      case 'trade_balance':
      case 'current_account_deficit':
      case 'forex_reserves':
      case 'bond_yield_10y':
      case 'bond_yield_2y':
        external.add(metric);
        break;
      case 'fiscal_deficit':
      case 'gst_collection':
        fiscal.add(metric);
        break;
      default:
        other.add(metric);
        break;
    }
  }

  final groups = <_MetricGroup>[];
  if (prices.isNotEmpty) {
    groups.add(_MetricGroup(title: 'Prices', metrics: prices));
  }
  if (activity.isNotEmpty) {
    groups.add(_MetricGroup(title: 'Activity', metrics: activity));
  }
  if (external.isNotEmpty) {
    groups.add(_MetricGroup(title: 'External', metrics: external));
  }
  if (fiscal.isNotEmpty) {
    groups.add(_MetricGroup(title: 'Fiscal', metrics: fiscal));
  }
  if (other.isNotEmpty) {
    groups.add(_MetricGroup(title: 'Other', metrics: other));
  }
  return groups;
}

class MacroDashboardScreen extends ConsumerStatefulWidget {
  const MacroDashboardScreen({super.key});

  @override
  ConsumerState<MacroDashboardScreen> createState() =>
      _MacroDashboardScreenState();
}

class _MacroDashboardScreenState extends ConsumerState<MacroDashboardScreen> {
  final ScrollController _scrollController = ScrollController();
  String _selectedCountry = 'IN';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(allMacroIndicatorsProvider);
    ref.invalidate(econCalendarProvider);
    ref.invalidate(macroMetadataProvider);
    for (final country in _focusCountries) {
      ref.invalidate(macroMetadataByCountryProvider(country));
    }
    for (final country in _focusCountries) {
      ref.invalidate(economyCountryFocusProvider(country));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(bottomTabReselectTickProvider(4), (prev, next) {
      if (prev == null || prev == next) return;
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });

    final worldAsync = ref.watch(allMacroIndicatorsProvider);
    final countryAsync =
        ref.watch(economyCountryFocusProvider(_selectedCountry));
    final eventsAsync = ref.watch(econCalendarProvider);
    final metadataAsync =
        ref.watch(macroMetadataByCountryProvider(_selectedCountry));
    final metadataByIndicator = {
      for (final item
          in metadataAsync.valueOrNull ?? const <MacroIndicatorMetadata>[])
        item.indicatorName: item,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Economy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          children: [
            _SectionCard(
              title: null,
              child: worldAsync.when(
                loading: () => const ShimmerCard(height: 152),
                error: (err, _) => ErrorView(
                  message: friendlyErrorMessage(err),
                  onRetry: () => ref.invalidate(allMacroIndicatorsProvider),
                ),
                data: (latest) => _WorldSnapshotGrid(latest: latest),
              ),
            ),
            const SizedBox(height: 10),
            _SectionCard(
              title: null,
              child: eventsAsync.when(
                loading: () => const ShimmerCard(height: 110),
                error: (err, _) => ErrorView(
                  message: friendlyErrorMessage(err),
                  onRetry: () => ref.invalidate(econCalendarProvider),
                ),
                data: (events) => _EventsCard(events: events),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: countryAsync.when(
                  loading: () => const ShimmerCard(height: 240),
                  error: (err, _) => ErrorView(
                    message: friendlyErrorMessage(err),
                    onRetry: () => ref.invalidate(
                      economyCountryFocusProvider(_selectedCountry),
                    ),
                  ),
                  data: (payload) {
                    final groups = _extraGroups(payload.extraMetrics);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CountrySegmentedControl(
                          selectedCountry: _selectedCountry,
                          onSelected: (country) {
                            setState(() => _selectedCountry = country);
                          },
                        ),
                        const SizedBox(height: 10),
                        _CompactMetricRows(
                          metrics: payload.coreMetrics,
                          country: _selectedCountry,
                          metadataByIndicator: metadataByIndicator,
                        ),
                        for (final group in groups) ...[
                          const SizedBox(height: 10),
                          Text(
                            group.title,
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.2,
                              color: Colors.white60,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          _CompactMetricRows(
                            metrics: group.metrics,
                            country: _selectedCountry,
                            metadataByIndicator: metadataByIndicator,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _WorldSnapshotGrid extends StatelessWidget {
  final List<MacroIndicator> latest;

  const _WorldSnapshotGrid({required this.latest});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: _worldCountries.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (_, index) {
        final country = _worldCountries[index];
        final gdp = _latestByCountry(latest, country, 'gdp_growth');
        final inflation = _latestByCountry(latest, country, 'inflation');
        final policy = _latestByCountry(latest, country, 'repo_rate');
        final unemployment = _latestByCountry(latest, country, 'unemployment');

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SquareBadgeSvg(
                    assetPath:
                        SquareBadgeAssets.flagPathForCountryCode(country),
                    size: 14,
                    borderRadius: 2,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _countryLabel(country),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _WorldMetricRow(
                label: 'GDP',
                value: gdp == null
                    ? 'n/a'
                    : Formatters.macroValue(gdp, 'gdp_growth'),
              ),
              _WorldMetricRow(
                label: 'Inflation',
                value: inflation == null
                    ? 'n/a'
                    : Formatters.macroValue(inflation, 'inflation'),
              ),
              _WorldMetricRow(
                label: 'Policy',
                value: policy == null
                    ? 'n/a'
                    : Formatters.macroValue(policy, 'repo_rate'),
              ),
              _WorldMetricRow(
                label: 'Unemployment',
                value: unemployment == null
                    ? 'n/a'
                    : Formatters.macroValue(unemployment, 'unemployment'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WorldMetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _WorldMetricRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white60,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountrySegmentedControl extends StatelessWidget {
  final String selectedCountry;
  final ValueChanged<String> onSelected;

  const _CountrySegmentedControl({
    required this.selectedCountry,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: _focusCountries.map((country) {
          final selected = selectedCountry == country;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(country),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: selected
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.transparent,
                ),
                child: Text(
                  _countryLabel(country),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : Colors.white70,
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _CompactMetricRows extends StatelessWidget {
  final List<EconomyMetricData> metrics;
  final String? country;
  final Map<String, MacroIndicatorMetadata> metadataByIndicator;

  const _CompactMetricRows({
    required this.metrics,
    required this.country,
    required this.metadataByIndicator,
  });

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const Text(
        'No data available.',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            _MetricRow(
              metric: metrics[i],
              country: country,
              metadata: metadataByIndicator[metrics[i].indicator],
            ),
            if (i < metrics.length - 1)
              const Divider(height: 1, color: Colors.white12),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final EconomyMetricData metric;
  final String? country;
  final MacroIndicatorMetadata? metadata;

  const _MetricRow({
    required this.metric,
    required this.country,
    required this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    final visual = _metricVisual(
      metric: metric,
      metadata: metadata,
      country: country,
    );
    final value = _metricValueLabel(metric);

    return InkWell(
      onTap: () => _showMetricHelper(
        context,
        metric: metric,
        metadata: metadata,
        visual: visual,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      metric.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.info_outline,
                    size: 13,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: visual.color,
                    ),
                  ),
                  Text(
                    _metricDeltaLabel(metric),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isPercentMetric(String indicator) {
  return indicator.contains('rate') ||
      indicator.contains('inflation') ||
      indicator.contains('gdp') ||
      indicator.contains('unemployment') ||
      indicator == 'iip' ||
      indicator == 'fiscal_deficit' ||
      indicator == 'bank_credit_growth';
}

class _EventsCard extends StatelessWidget {
  final List<EconCalendarEvent> events;

  const _EventsCard({required this.events});

  Color _importanceColor(String? importance) {
    switch ((importance ?? '').toLowerCase()) {
      case 'high':
        return AppTheme.accentRed;
      case 'medium':
        return AppTheme.accentOrange;
      default:
        return AppTheme.accentBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = events
        .where(
            (e) => !e.eventDate.isBefore(now.subtract(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    final shortlist = upcoming.take(2).toList(growable: false);

    if (shortlist.isEmpty) {
      return const Text(
        'No upcoming events.',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < shortlist.length; i++) ...[
            _EventRow(
              event: shortlist[i],
              importanceColor: _importanceColor(shortlist[i].importance),
            ),
            if (i < shortlist.length - 1)
              const Divider(height: 1, color: Colors.white12),
          ],
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final EconCalendarEvent event;
  final Color importanceColor;

  const _EventRow({
    required this.event,
    required this.importanceColor,
  });

  String _countdownLabel(DateTime now) {
    final days = event.eventDate.difference(now).inDays;
    if (days <= 0) return 'Today';
    return '${days}d';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          SquareBadgeSvg(
            assetPath: SquareBadgeAssets.flagPathForCountryCode(event.country),
            size: 14,
            borderRadius: 2,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.eventName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_countryLabel(event.country)} · ${DateFormat('EEE, dd MMM').format(event.eventDate)}',
                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: importanceColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _countdownLabel(now),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white60,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

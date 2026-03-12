import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/error_utils.dart';
import '../../../core/utils.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'tax/tax_engine.dart';
import 'tax/tax_ui.dart';

class CapitalGainsScreen extends ConsumerStatefulWidget {
  const CapitalGainsScreen({super.key});

  @override
  ConsumerState<CapitalGainsScreen> createState() => _CapitalGainsScreenState();
}

class _CapitalGainsScreenState extends ConsumerState<CapitalGainsScreen>
    with WidgetsBindingObserver {
  final TextEditingController _buyValueController = TextEditingController();
  final TextEditingController _sellValueController = TextEditingController();

  String _assetType = '';
  DateTime _purchaseDate = DateTime.now();
  DateTime _saleDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final prefs = ref.read(sharedPreferencesProvider);
    final today = _todayIst();
    _buyValueController.text = formatIndianAmountInput(
      prefs.getString(AppConstants.prefTaxCapitalPurchaseAmount) ?? '0',
    );
    _sellValueController.text = formatIndianAmountInput(
      prefs.getString(AppConstants.prefTaxCapitalSaleAmount) ?? '0',
    );
    _assetType = prefs.getString(AppConstants.prefTaxCapitalAssetType) ?? '';
    _purchaseDate = _parseStoredDate(
          prefs.getString(AppConstants.prefTaxCapitalPurchaseDate),
        ) ??
        _subtractCalendarMonths(today, 16);
    _saleDate = _parseStoredDate(
            prefs.getString(AppConstants.prefTaxCapitalSaleDate)) ??
        today;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _buyValueController.dispose();
    _sellValueController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.viewInsetsOf(context).bottom <= 0) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configAsync = ref.watch(taxConfigProvider);
    final selectedFy = ref.watch(selectedTaxFyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Capital Gains')),
      body: configAsync.when(
        loading: () => const Center(child: ShimmerCard(height: 220)),
        error: (err, _) => ErrorView(
          message: friendlyErrorMessage(err),
          onRetry: () => ref.invalidate(taxConfigProvider),
        ),
        data: (state) {
          final config = state.config;
          final rules = config.ruleSetFor(selectedFy).capitalGains;
          final assetOptions = rules.assets.keys.toList()..sort();
          if (assetOptions.isEmpty) {
            return const Center(
              child: EmptyView(message: 'No capital gains assets configured'),
            );
          }

          final preferredDefault = assetOptions.contains('listed_equity')
              ? 'listed_equity'
              : assetOptions.first;
          if (!assetOptions.contains(_assetType)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _assetType = preferredDefault);
              _persistAssetType(preferredDefault);
            });
          }

          final effectiveAssetType =
              assetOptions.contains(_assetType) ? _assetType : preferredDefault;
          final invalidDateRange = _saleDate.isBefore(_purchaseDate);
          final holdingMonths = invalidDateRange
              ? 0
              : _fullCalendarMonthsBetween(_purchaseDate, _saleDate);

          final result = TaxEngine.computeCapitalGains(
            rules: rules,
            assetType: effectiveAssetType,
            buyValue: parseIndianAmountInput(_buyValueController.text),
            sellValue: parseIndianAmountInput(_sellValueController.text),
            holdingMonths: holdingMonths,
          );

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 130),
                children: [
                  taxHelperCard(
                    theme: theme,
                    title: 'Quick pointers',
                    points: config.helperPoints.capitalGains,
                  ),
                  const SizedBox(height: 10),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Calculation details',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    _resetDefaults(assetOptions: assetOptions),
                                icon: const Icon(Icons.restart_alt_rounded),
                                label: const Text('Reset'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          AdaptiveSelectField<String>(
                            label: 'Asset type',
                            value: effectiveAssetType,
                            decoration: modernTaxInputDecoration(
                              theme,
                              label: 'Asset type',
                              icon: Icons.category_outlined,
                            ),
                            options: assetOptions
                                .map(
                                  (e) => AdaptiveSelectOption(
                                    value: e,
                                    label: _assetName(e),
                                    subtitle: _assetDropdownNote(
                                      rules.assets[e]?.note ?? '',
                                    ),
                                    searchTokens: [
                                      e,
                                      rules.assets[e]?.note ?? '',
                                    ],
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _assetType = value);
                              _persistAssetType(value);
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _buyValueController,
                            keyboardType: TextInputType.number,
                            inputFormatters: const [
                              IndianAmountInputFormatter()
                            ],
                            decoration: modernTaxInputDecoration(
                              theme,
                              label: 'Purchase amount',
                              icon: Icons.shopping_bag_outlined,
                            ),
                            onChanged: (value) {
                              _persistValue(
                                AppConstants.prefTaxCapitalPurchaseAmount,
                                parseIndianAmountInput(value)
                                    .round()
                                    .toString(),
                              );
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _sellValueController,
                            keyboardType: TextInputType.number,
                            inputFormatters: const [
                              IndianAmountInputFormatter()
                            ],
                            decoration: modernTaxInputDecoration(
                              theme,
                              label: 'Sale amount',
                              icon: Icons.sell_outlined,
                            ),
                            onChanged: (value) {
                              _persistValue(
                                AppConstants.prefTaxCapitalSaleAmount,
                                parseIndianAmountInput(value)
                                    .round()
                                    .toString(),
                              );
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildDateField(
                            theme: theme,
                            label: 'Purchase date',
                            value: _purchaseDate,
                            icon: Icons.event_note_rounded,
                            onPick: () => _pickDate(
                              initialDate: _purchaseDate,
                              onPicked: (picked) {
                                setState(() => _purchaseDate = picked);
                                _persistDate(
                                  AppConstants.prefTaxCapitalPurchaseDate,
                                  picked,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildDateField(
                            theme: theme,
                            label: 'Sale date',
                            value: _saleDate,
                            icon: Icons.event_available_rounded,
                            onPick: () => _pickDate(
                              initialDate: _saleDate,
                              onPicked: (picked) {
                                setState(() => _saleDate = picked);
                                _persistDate(
                                  AppConstants.prefTaxCapitalSaleDate,
                                  picked,
                                );
                              },
                            ),
                          ),
                          if (invalidDateRange) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Sale date cannot be before purchase date.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFFF8A8A),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Breakdown',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _line(
                            'Gain type',
                            result.isLongTerm ? 1 : 0,
                            customText:
                                result.isLongTerm ? 'Long term' : 'Short term',
                          ),
                          _line('Gross gain', result.gain),
                          _line('Taxable gain', result.taxableGain),
                          _line(
                            'Applied tax rate',
                            result.appliedRate * 100,
                            suffix: '%',
                            forcePositive: true,
                          ),
                          _line('Estimated tax', result.tax),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: glassResultBar(
                  theme: theme,
                  bottomInset: MediaQuery.of(context).padding.bottom,
                  children: [
                    Text(
                      'Net gain: ₹${Formatters.fullPrice(result.netGain)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Estimated tax: ₹${Formatters.fullPrice(result.tax)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateField({
    required ThemeData theme,
    required String label,
    required DateTime value,
    required IconData icon,
    required VoidCallback onPick,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPick,
      child: InputDecorator(
        decoration: modernTaxInputDecoration(
          theme,
          label: label,
          icon: icon,
        ),
        child: Text(_formatDate(value)),
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1990, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    onPicked(DateTime(picked.year, picked.month, picked.day));
  }

  String _assetName(String key) {
    switch (key) {
      case 'listed_equity':
        return 'Listed Equity';
      case 'equity_mf':
        return 'Equity Mutual Fund';
      case 'business_trust_units':
        return 'Business Trust Units (REIT/InvIT)';
      case 'immovable_property':
        return 'Immovable Property';
      case 'unlisted_shares':
        return 'Unlisted Shares';
      case 'listed_bonds_debentures':
        return 'Listed Bonds/Debentures';
      case 'gold_other_assets':
        return 'Gold/Other Assets';
      case 'debt_like_special':
        return 'Debt-like Special Assets';
      default:
        return key;
    }
  }

  String _assetDropdownNote(String note) {
    final trimmed = note.trim();
    if (trimmed.isEmpty) return 'Asset-specific tax rules apply.';
    return trimmed;
  }

  Widget _line(
    String label,
    double value, {
    String? customText,
    String suffix = '',
    bool forcePositive = false,
  }) {
    final isNegative = !forcePositive && value < 0;
    final sign = isNegative
        ? '-₹'
        : suffix.isNotEmpty
            ? ''
            : '₹';
    final text = customText ??
        '$sign${suffix.isNotEmpty ? value.toStringAsFixed(2) : Formatters.fullPrice(value.abs())}$suffix';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  int _fullCalendarMonthsBetween(DateTime start, DateTime end) {
    if (end.isBefore(start)) return 0;
    var months = (end.year - start.year) * 12 + (end.month - start.month);
    if (end.day < start.day) {
      months -= 1;
    }
    return months < 0 ? 0 : months;
  }

  DateTime _subtractCalendarMonths(DateTime date, int months) {
    final totalMonths = (date.year * 12 + date.month - 1) - months;
    final year = totalMonths ~/ 12;
    final month = (totalMonths % 12) + 1;
    final maxDay = DateTime(year, month + 1, 0).day;
    final day = date.day > maxDay ? maxDay : date.day;
    return DateTime(year, month, day);
  }

  DateTime _todayIst() {
    final now =
        DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _parseStoredDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  String _formatDate(DateTime dt) {
    final month = switch (dt.month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      12 => 'Dec',
      _ => 'Jan',
    };
    return '${dt.day.toString().padLeft(2, '0')} $month ${dt.year}';
  }

  void _persistValue(String key, String value) {
    ref.read(sharedPreferencesProvider).setString(key, value);
  }

  void _persistAssetType(String value) {
    ref.read(sharedPreferencesProvider).setString(
          AppConstants.prefTaxCapitalAssetType,
          value,
        );
  }

  void _persistDate(String key, DateTime value) {
    ref.read(sharedPreferencesProvider).setString(
          key,
          DateTime(value.year, value.month, value.day)
              .toIso8601String()
              .split('T')
              .first,
        );
  }

  void _resetDefaults({required List<String> assetOptions}) {
    final today = _todayIst();
    final preferredDefault = assetOptions.contains('listed_equity')
        ? 'listed_equity'
        : assetOptions.first;
    final purchaseDefault = _subtractCalendarMonths(today, 16);

    _assetType = preferredDefault;
    _buyValueController.text = formatIndianAmountInput('0');
    _sellValueController.text = formatIndianAmountInput('0');
    _purchaseDate = purchaseDefault;
    _saleDate = today;

    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(AppConstants.prefTaxCapitalAssetType, preferredDefault);
    prefs.setString(AppConstants.prefTaxCapitalPurchaseAmount, '0');
    prefs.setString(AppConstants.prefTaxCapitalSaleAmount, '0');
    prefs.setString(
      AppConstants.prefTaxCapitalPurchaseDate,
      purchaseDefault.toIso8601String().split('T').first,
    );
    prefs.setString(
      AppConstants.prefTaxCapitalSaleDate,
      today.toIso8601String().split('T').first,
    );

    setState(() {});
  }
}

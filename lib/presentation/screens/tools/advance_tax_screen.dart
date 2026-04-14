import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/error_utils.dart';
import '../../../core/utils.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'tax/tax_engine.dart';
import 'tax/tax_ui.dart';

class AdvanceTaxScreen extends ConsumerStatefulWidget {
  const AdvanceTaxScreen({super.key});

  @override
  ConsumerState<AdvanceTaxScreen> createState() => _AdvanceTaxScreenState();
}

class _AdvanceTaxScreenState extends ConsumerState<AdvanceTaxScreen>
    with WidgetsBindingObserver, KeyboardDismissMixin<AdvanceTaxScreen> {
  final TextEditingController _liabilityController = TextEditingController();
  final TextEditingController _paidController = TextEditingController();
  DateTime _paymentDateIst =
      DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  int _currentInstallmentIndex = 0;
  bool _hasManualInstallmentSelection = false;

  @override
  void initState() {
    super.initState();
    // Observer removed (keyboard bug fix).
    final prefs = ref.read(sharedPreferencesProvider);
    final todayIst = _nowIst();
    _liabilityController.text = formatIndianAmountInput(
      prefs.getString(AppConstants.prefTaxAdvanceLiability) ?? '0',
    );
    _paidController.text = formatIndianAmountInput(
      prefs.getString(AppConstants.prefTaxAdvancePaid) ?? '0',
    );
    _paymentDateIst = _parseStoredDate(
          prefs.getString(AppConstants.prefTaxAdvancePaymentDate),
        ) ??
        DateTime(todayIst.year, todayIst.month, todayIst.day, 12);
    _currentInstallmentIndex =
        prefs.getInt(AppConstants.prefTaxAdvanceInstallmentIndex) ?? 0;
    _hasManualInstallmentSelection =
        prefs.getBool(AppConstants.prefTaxAdvanceManualInstallment) ?? false;
  }

  @override
  void dispose() {
    // Observer cleanup removed.
    _liabilityController.dispose();
    _paidController.dispose();
    super.dispose();
  }

  // didChangeMetrics removed — caused keyboard dismiss bug.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configAsync = ref.watch(taxConfigProvider);
    final selectedFy = ref.watch(selectedTaxFyProvider);

    return DismissKeyboardOnTap(
      child: Scaffold(
      appBar: AppBar(title: const Text('Advance Tax')),
      body: configAsync.when(
        loading: () => const Center(child: ShimmerCard(height: 220)),
        error: (err, _) => ErrorView(
          message: friendlyErrorMessage(err),
          onRetry: () => ref.invalidate(taxConfigProvider),
        ),
        data: (state) {
          final config = state.config;
          final fyIds = config.supportedFy.map((e) => e.id).toSet();
          final effectiveFy =
              fyIds.contains(selectedFy) ? selectedFy : config.defaultFy;
          if (effectiveFy != selectedFy) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedTaxFyProvider.notifier).set(effectiveFy);
            });
          }
          final rules = config.ruleSetFor(effectiveFy).advanceTax;
          final fyStartYear = _fyStartYearFromId(effectiveFy);
          final result = TaxEngine.computeAdvanceTax(
            rules: rules,
            totalLiability: parseIndianAmountInput(_liabilityController.text),
            paidTillNow: parseIndianAmountInput(_paidController.text),
            currentInstallmentIndex: _currentInstallmentIndex,
            fyStartYear: fyStartYear,
            paymentDate: DateTime(
              _paymentDateIst.year,
              _paymentDateIst.month,
              _paymentDateIst.day,
            ),
          );
          final maxIndex = (result.installments.isEmpty
              ? 0
              : result.installments.length - 1);
          final defaultIndex = _resolveDefaultInstallmentIndex(
            installments: result.installments,
            fyId: effectiveFy,
          ).clamp(0, maxIndex);

          if ((_currentInstallmentIndex > maxIndex) ||
              (!_hasManualInstallmentSelection &&
                  _currentInstallmentIndex != defaultIndex)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _currentInstallmentIndex = defaultIndex);
              _persistInstallmentState();
            });
          }

          final currentInstallment = result.installments.isEmpty
              ? null
              : result
                  .installments[_currentInstallmentIndex.clamp(0, maxIndex)];
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
                children: [
                  taxHelperCard(
                    theme: theme,
                    title: 'Quick pointers',
                    points: config.helperPoints.advanceTax,
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
                                onPressed: () => _resetDefaults(defaultIndex),
                                icon: const Icon(Icons.restart_alt_rounded),
                                label: const Text('Reset'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          AdaptiveSelectField<String>(
                            label: 'Financial year',
                            value: effectiveFy,
                            decoration: modernTaxInputDecoration(
                              theme,
                              label: 'Financial year',
                              icon: Icons.calendar_today_rounded,
                            ),
                            options: config.supportedFy
                                .map(
                                  (fy) => AdaptiveSelectOption(
                                    value: fy.id,
                                    label: fy.label,
                                    searchTokens: [fy.id],
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) return;
                              _hasManualInstallmentSelection = false;
                              _persistInstallmentState();
                              ref
                                  .read(selectedTaxFyProvider.notifier)
                                  .set(value);
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _liabilityController,
                            keyboardType: TextInputType.number,
                            inputFormatters: const [
                              IndianAmountInputFormatter()
                            ],
                            decoration: modernTaxInputDecoration(
                              theme,
                              label: 'Total annual tax liability',
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                            onChanged: (value) {
                              _persistValue(
                                AppConstants.prefTaxAdvanceLiability,
                                parseIndianAmountInput(value)
                                    .round()
                                    .toString(),
                              );
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _paidController,
                            keyboardType: TextInputType.number,
                            inputFormatters: const [
                              IndianAmountInputFormatter()
                            ],
                            decoration: modernTaxInputDecoration(
                              theme,
                              label: 'Tax already paid',
                              icon: Icons.check_circle_outline_rounded,
                            ),
                            onChanged: (value) {
                              _persistValue(
                                AppConstants.prefTaxAdvancePaid,
                                parseIndianAmountInput(value)
                                    .round()
                                    .toString(),
                              );
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _paymentDateIst,
                                firstDate: DateTime(fyStartYear, 4, 1),
                                lastDate: DateTime(fyStartYear + 2, 3, 31),
                              );
                              if (picked == null) return;
                              setState(() {
                                _paymentDateIst = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  12,
                                );
                              });
                              _persistPaymentDate();
                            },
                            child: InputDecorator(
                              decoration: modernTaxInputDecoration(
                                theme,
                                label: 'Planned payment date',
                                icon: Icons.event_available_rounded,
                              ),
                              child: Text(_formatDate(_paymentDateIst)),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                final now = _nowIst();
                                setState(() {
                                  _paymentDateIst = DateTime(
                                      now.year, now.month, now.day, 12);
                                });
                                _persistPaymentDate();
                              },
                              child: const Text('Today'),
                            ),
                          ),
                          AdaptiveSelectField<int>(
                            label: 'Current installment',
                            value: _currentInstallmentIndex.clamp(0, maxIndex),
                            decoration: modernTaxInputDecoration(
                              theme,
                              label: 'Current installment',
                              icon: Icons.timeline_rounded,
                            ),
                            options: result.installments
                                .asMap()
                                .entries
                                .map(
                                  (e) => AdaptiveSelectOption(
                                    value: e.key,
                                    label:
                                        '${e.value.label} (${_formatDueDateForFy(e.value.dueDate, effectiveFy)})',
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) return;
                              _hasManualInstallmentSelection = true;
                              setState(() => _currentInstallmentIndex = value);
                              _persistInstallmentState();
                            },
                          ),
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
                            'Installment timeline',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...result.installments.map(
                            (row) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${row.label} • ${_formatDueDateForFy(row.dueDate, effectiveFy)} • ${row.cumulativePercent.toStringAsFixed(0)}%',
                                    ),
                                  ),
                                  Text(
                                    '₹${Formatters.fullPrice(row.cumulativeTarget)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                      'Estimated payable: ₹${Formatters.fullPrice(result.totalPayable)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentInstallment == null
                          ? 'No installment data available'
                          : '${currentInstallment.label} due ${_formatDueDateForFy(currentInstallment.dueDate, effectiveFy)}  |  Shortfall ₹${Formatters.fullPrice(result.currentShortfall)}',
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
    ),
    );
  }

  int _resolveDefaultInstallmentIndex({
    required List<AdvanceTaxInstallmentBreakdown> installments,
    required String fyId,
  }) {
    if (installments.isEmpty) return 0;
    final selectedFyStartYear = _fyStartYearFromId(fyId);
    final now = _nowIst();
    final currentFyStartYear = now.month >= 4 ? now.year : now.year - 1;
    if (selectedFyStartYear < currentFyStartYear) {
      return installments.length - 1;
    }
    if (selectedFyStartYear > currentFyStartYear) {
      return 0;
    }

    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < installments.length; i++) {
      final due = _dueDateForFy(installments[i].dueDate, selectedFyStartYear);
      if (!due.isBefore(today)) {
        return i;
      }
    }
    return installments.length - 1;
  }

  String _formatDueDateForFy(String dueDate, String fyId) {
    final fyStartYear = _fyStartYearFromId(fyId);
    final due = _dueDateForFy(dueDate, fyStartYear);
    final month = switch (due.month) {
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
      _ => 'Mar',
    };
    return '${due.day.toString().padLeft(2, '0')} $month ${due.year}';
  }

  DateTime _dueDateForFy(String dueDate, int fyStartYear) {
    final parts = dueDate.split(' ');
    if (parts.length != 2) return DateTime(fyStartYear, 3, 31);
    final day = int.tryParse(parts[0]) ?? 1;
    final month = switch (parts[1].toLowerCase()) {
      'jan' => 1,
      'feb' => 2,
      'mar' => 3,
      'apr' => 4,
      'may' => 5,
      'jun' => 6,
      'jul' => 7,
      'aug' => 8,
      'sep' => 9,
      'oct' => 10,
      'nov' => 11,
      'dec' => 12,
      _ => 3,
    };
    final year = month >= 4 ? fyStartYear : fyStartYear + 1;
    return DateTime(year, month, day);
  }

  int _fyStartYearFromId(String fyId) {
    final match = RegExp(r'^FY(\d{4})-\d{2}$').firstMatch(fyId.trim());
    if (match == null) return DateTime.now().year;
    return int.tryParse(match.group(1) ?? '') ?? DateTime.now().year;
  }

  DateTime _nowIst() =>
      DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

  DateTime? _parseStoredDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day, 12);
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

  void _persistPaymentDate() {
    ref.read(sharedPreferencesProvider).setString(
          AppConstants.prefTaxAdvancePaymentDate,
          DateTime(
            _paymentDateIst.year,
            _paymentDateIst.month,
            _paymentDateIst.day,
            12,
          ).toIso8601String(),
        );
  }

  void _persistInstallmentState() {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setInt(
      AppConstants.prefTaxAdvanceInstallmentIndex,
      _currentInstallmentIndex,
    );
    prefs.setBool(
      AppConstants.prefTaxAdvanceManualInstallment,
      _hasManualInstallmentSelection,
    );
  }

  void _resetDefaults(int defaultIndex) {
    final now = _nowIst();
    _liabilityController.text = formatIndianAmountInput('0');
    _paidController.text = formatIndianAmountInput('0');
    _paymentDateIst = DateTime(now.year, now.month, now.day, 12);
    _hasManualInstallmentSelection = false;
    _currentInstallmentIndex = defaultIndex;

    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(AppConstants.prefTaxAdvanceLiability, '0');
    prefs.setString(AppConstants.prefTaxAdvancePaid, '0');
    prefs.setString(
      AppConstants.prefTaxAdvancePaymentDate,
      _paymentDateIst.toIso8601String(),
    );
    prefs.setInt(AppConstants.prefTaxAdvanceInstallmentIndex, defaultIndex);
    prefs.setBool(AppConstants.prefTaxAdvanceManualInstallment, false);
    setState(() {});
  }
}

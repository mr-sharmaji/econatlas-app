import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/error_utils.dart';
import '../../../core/utils.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'tax/tax_engine.dart';
import 'tax/tax_ui.dart';

class IncomeTaxScreen extends ConsumerStatefulWidget {
  const IncomeTaxScreen({super.key});

  @override
  ConsumerState<IncomeTaxScreen> createState() => _IncomeTaxScreenState();
}

class _IncomeTaxScreenState extends ConsumerState<IncomeTaxScreen>
    {
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _deductionController = TextEditingController();

  TaxRegime _regime = TaxRegime.newRegime;
  AgeBucket _ageBucket = AgeBucket.below60;
  bool _isResident = true;
  bool _showProfileDetails = false;

  @override
  void initState() {
    super.initState();
    // WidgetsBindingObserver removed — was only used for
    // didChangeMetrics which caused the keyboard dismiss bug.
    final prefs = ref.read(sharedPreferencesProvider);
    _salaryController.text = formatIndianAmountInput(
      prefs.getString(AppConstants.prefTaxSalary) ?? '0',
    );
    _deductionController.text = formatIndianAmountInput(
      prefs.getString(AppConstants.prefTaxDeductions) ?? '0',
    );
    _regime = (prefs.getString(AppConstants.prefTaxRegime) ?? 'new') == 'old'
        ? TaxRegime.old
        : TaxRegime.newRegime;
    _ageBucket = AgeBucket.values.elementAt(
      (prefs.getInt(AppConstants.prefTaxAgeBucket) ?? 0)
          .clamp(0, AgeBucket.values.length - 1),
    );
    _isResident = prefs.getBool(AppConstants.prefTaxResident) ?? true;
  }

  @override
  void dispose() {
    // Observer cleanup no longer needed.
    _salaryController.dispose();
    _deductionController.dispose();
    super.dispose();
  }

  // didChangeMetrics was removed — it was dismissing the keyboard
  // during the keyboard open animation because viewInsetsOf reports
  // bottom=0 transiently during the animation. This made it
  // impossible to type in the income/deduction fields.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stickyColor = theme.colorScheme.surface.withValues(alpha: 0.96);
    final configAsync = ref.watch(taxConfigProvider);
    final selectedFy = ref.watch(selectedTaxFyProvider);

    final overlay = SystemUiOverlayStyle(
      systemNavigationBarColor: stickyColor,
      systemNavigationBarIconBrightness: theme.brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        appBar: AppBar(title: const Text('Income Tax')),
        body: configAsync.when(
          loading: () => const Center(child: ShimmerCard(height: 240)),
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
            final rules = config.ruleSetFor(effectiveFy).incomeTax;
            final result = TaxEngine.computeIncomeTax(
              rules: rules,
              salary: parseIndianAmountInput(_salaryController.text),
              extraDeductions:
                  parseIndianAmountInput(_deductionController.text),
              regime: _regime,
              ageBucket: _ageBucket,
              resident: _isResident,
            );

            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
                  children: [
                    taxHelperCard(
                      theme: theme,
                      title: 'Quick pointers',
                      points: config.helperPoints.incomeTax,
                    ),
                    const SizedBox(height: 10),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: AdaptiveSelectField<String>(
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
                            ref.read(selectedTaxFyProvider.notifier).set(value);
                          },
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
                              'Tax regime',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _RegimeToggle(
                              regime: _regime,
                              onChanged: (value) {
                                _regime = value;
                                ref.read(sharedPreferencesProvider).setString(
                                      AppConstants.prefTaxRegime,
                                      _regime == TaxRegime.old ? 'old' : 'new',
                                    );
                                setState(() {});
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
                                  onPressed: _resetDefaults,
                                  icon: const Icon(Icons.restart_alt_rounded),
                                  label: const Text('Reset'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _salaryController,
                              keyboardType: TextInputType.number,
                              inputFormatters: const [
                                IndianAmountInputFormatter()
                              ],
                              decoration: modernTaxInputDecoration(
                                theme,
                                label: 'Annual income',
                                hint: '12,00,000',
                                icon: Icons.account_balance_wallet_outlined,
                              ),
                              onChanged: (value) {
                                ref.read(sharedPreferencesProvider).setString(
                                      AppConstants.prefTaxSalary,
                                      parseIndianAmountInput(value)
                                          .round()
                                          .toString(),
                                    );
                                setState(() {});
                              },
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _deductionController,
                              enabled: _regime == TaxRegime.old,
                              keyboardType: TextInputType.number,
                              inputFormatters: const [
                                IndianAmountInputFormatter()
                              ],
                              decoration: modernTaxInputDecoration(
                                theme,
                                label: 'Additional deductions',
                                hint: '1,50,000',
                                helper: _regime == TaxRegime.old
                                    ? 'Old regime deductions (80C, 80D, etc.)'
                                    : 'Not applied in new regime',
                                icon: Icons.savings_outlined,
                              ),
                              onChanged: (value) {
                                ref.read(sharedPreferencesProvider).setString(
                                      AppConstants.prefTaxDeductions,
                                      parseIndianAmountInput(value)
                                          .round()
                                          .toString(),
                                    );
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => setState(() =>
                                  _showProfileDetails = !_showProfileDetails),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Tax profile',
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    _showProfileDetails
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                  ),
                                ],
                              ),
                            ),
                            if (_showProfileDetails) ...[
                              const SizedBox(height: 8),
                              AdaptiveSelectField<AgeBucket>(
                                label: 'Age bucket',
                                value: _ageBucket,
                                decoration: modernTaxInputDecoration(
                                  theme,
                                  label: 'Age bucket',
                                  icon: Icons.person_outline_rounded,
                                ),
                                options: const [
                                  AdaptiveSelectOption(
                                    value: AgeBucket.below60,
                                    label: 'Below 60 years',
                                  ),
                                  AdaptiveSelectOption(
                                    value: AgeBucket.age60to80,
                                    label: '60 to 80 years',
                                  ),
                                  AdaptiveSelectOption(
                                    value: AgeBucket.above80,
                                    label: 'Above 80 years',
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  _ageBucket = value;
                                  ref.read(sharedPreferencesProvider).setInt(
                                        AppConstants.prefTaxAgeBucket,
                                        _ageBucket.index,
                                      );
                                  setState(() {});
                                },
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  _isResident = !_isResident;
                                  ref.read(sharedPreferencesProvider).setBool(
                                      AppConstants.prefTaxResident,
                                      _isResident);
                                  setState(() {});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      const Expanded(
                                        child: Text('Resident individual'),
                                      ),
                                      const SizedBox(width: 8),
                                      Checkbox(
                                        value: _isResident,
                                        visualDensity: const VisualDensity(
                                          horizontal: -4,
                                          vertical: -4,
                                        ),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        onChanged: (value) {
                                          _isResident = value ?? false;
                                          ref
                                              .read(sharedPreferencesProvider)
                                              .setBool(
                                                AppConstants.prefTaxResident,
                                                _isResident,
                                              );
                                          setState(() {});
                                        },
                                      ),
                                    ],
                                  ),
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
                            _line('Gross income', result.salary),
                            _line('Standard deduction',
                                -result.standardDeduction),
                            _line('Other deductions used',
                                -result.deductionsUsed),
                            _line('Taxable income', result.taxableIncome),
                            _line('Base tax', result.baseTax),
                            _line('Rebate', -result.rebate),
                            _line('Surcharge', result.surcharge),
                            _line('Health and education cess', result.cess),
                            const Divider(height: 20),
                            _line(
                              'Total tax payable',
                              result.totalTax,
                              isStrong: true,
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
                        'Estimated tax: ₹${Formatters.fullPrice(result.totalTax)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Effective rate: ${result.effectiveRate.toStringAsFixed(2)}%  |  Monthly post-tax: ₹${Formatters.fullPrice(result.monthlyNetIncome)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
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

  Widget _line(String label, double value, {bool isStrong = false}) {
    final sign = value < 0 ? '-₹' : '₹';
    final color = value < 0 ? const Color(0xFFFF8080) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isStrong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$sign${Formatters.fullPrice(value.abs())}',
            style: TextStyle(
              color: color,
              fontWeight: isStrong ? FontWeight.w800 : FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  void _resetDefaults() {
    _salaryController.text = formatIndianAmountInput('0');
    _deductionController.text = formatIndianAmountInput('0');
    _regime = TaxRegime.newRegime;
    _ageBucket = AgeBucket.below60;
    _isResident = true;

    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(AppConstants.prefTaxSalary, '0');
    prefs.setString(AppConstants.prefTaxDeductions, '0');
    prefs.setString(AppConstants.prefTaxRegime, 'new');
    prefs.setInt(AppConstants.prefTaxAgeBucket, _ageBucket.index);
    prefs.setBool(AppConstants.prefTaxResident, true);
    setState(() {});
  }
}

class _RegimeToggle extends StatelessWidget {
  const _RegimeToggle({
    required this.regime,
    required this.onChanged,
  });

  final TaxRegime regime;
  final ValueChanged<TaxRegime> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected =
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.35);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RegimeButton(
              label: 'New regime',
              selected: regime == TaxRegime.newRegime,
              selectedColor: selected,
              onTap: () => onChanged(TaxRegime.newRegime),
            ),
          ),
          Expanded(
            child: _RegimeButton(
              label: 'Old regime',
              selected: regime == TaxRegime.old,
              selectedColor: selected,
              onTap: () => onChanged(TaxRegime.old),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegimeButton extends StatelessWidget {
  const _RegimeButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? selectedColor : Colors.transparent,
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

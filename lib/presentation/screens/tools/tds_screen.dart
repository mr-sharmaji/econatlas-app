import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/error_utils.dart';
import '../../../core/utils.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'tax/tax_engine.dart';
import 'tax/tax_ui.dart';

enum _TdsPerspective { payer, receiver }

class TdsScreen extends ConsumerStatefulWidget {
  const TdsScreen({super.key});

  @override
  ConsumerState<TdsScreen> createState() => _TdsScreenState();
}

class _TdsScreenState extends ConsumerState<TdsScreen>
    with WidgetsBindingObserver, KeyboardDismissMixin<TdsScreen> {
  final TextEditingController _amountController = TextEditingController();

  _TdsPerspective _perspective = _TdsPerspective.receiver;
  String _selectedPaymentType = '';
  String _selectedRecipient = 'individual';
  bool _panAvailable = true;
  String _selected194jType = 'others';
  bool _defaultsLoaded = false;

  late final bool _hasStoredRecipient;
  late final bool _hasStoredPan;
  late final bool _hasStoredSubtype;

  @override
  void initState() {
    super.initState();
    // Observer removed (keyboard bug fix).
    final prefs = ref.read(sharedPreferencesProvider);

    _amountController.text = formatIndianAmountInput(
      prefs.getString(AppConstants.prefTaxTdsAmount) ?? '0',
    );

    final perspectiveRaw =
        prefs.getString(AppConstants.prefTaxTdsPerspective) ?? 'receiver';
    _perspective = perspectiveRaw == 'payer'
        ? _TdsPerspective.payer
        : _TdsPerspective.receiver;

    _selectedPaymentType =
        prefs.getString(AppConstants.prefTaxTdsPaymentType) ?? '';
    _selectedRecipient =
        prefs.getString(AppConstants.prefTaxTdsRecipient) ?? 'individual';
    _panAvailable = prefs.getBool(AppConstants.prefTaxTdsPan) ?? true;
    _selected194jType =
        prefs.getString(AppConstants.prefTaxTdsSubtype) ?? 'others';

    _hasStoredRecipient = prefs.containsKey(AppConstants.prefTaxTdsRecipient);
    _hasStoredPan = prefs.containsKey(AppConstants.prefTaxTdsPan);
    _hasStoredSubtype = prefs.containsKey(AppConstants.prefTaxTdsSubtype);
  }

  @override
  void dispose() {
    // Observer cleanup removed.
    _amountController.dispose();
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
      appBar: AppBar(title: const Text('TDS Calculator')),
      body: configAsync.when(
        loading: () => const Center(child: ShimmerCard(height: 240)),
        error: (err, _) => ErrorView(
          message: friendlyErrorMessage(err),
          onRetry: () => ref.invalidate(taxConfigProvider),
        ),
        data: (state) {
          final config = state.config;
          final rules = config.ruleSetFor(selectedFy).tds;
          final paymentTypes = rules.paymentTypes
              .where((row) => row.value.trim().isNotEmpty)
              .toList(growable: false);

          if (paymentTypes.isEmpty) {
            return const Center(
              child: EmptyView(message: 'No TDS payment types configured'),
            );
          }

          if (!_defaultsLoaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _defaultsLoaded = true;
                if (!_hasStoredPan) {
                  _panAvailable = rules.defaults.pan.toLowerCase() != 'no';
                }
                if (!_hasStoredRecipient) {
                  _selectedRecipient =
                      rules.defaults.recipient.toLowerCase() == 'other'
                          ? 'other'
                          : 'individual';
                }
                if (!_hasStoredSubtype) {
                  _selected194jType = rules.defaults.fees194j;
                }
              });
            });
          }

          final nextPaymentType = paymentTypes.any(
            (row) => row.value == _selectedPaymentType,
          )
              ? _selectedPaymentType
              : paymentTypes.first.value;
          if (nextPaymentType != _selectedPaymentType) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _selectedPaymentType = nextPaymentType);
              _persistString(
                  AppConstants.prefTaxTdsPaymentType, nextPaymentType);
            });
          }

          final selectedType = paymentTypes.firstWhere(
            (row) =>
                row.value ==
                (nextPaymentType.isEmpty
                    ? paymentTypes.first.value
                    : nextPaymentType),
          );

          if (selectedType.subTypeOptions.isNotEmpty &&
              !selectedType.subTypeOptions
                  .any((s) => s.value == _selected194jType)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final fallbackSubtype = selectedType.subTypeOptions.first.value;
              setState(() => _selected194jType = fallbackSubtype);
              _persistString(AppConstants.prefTaxTdsSubtype, fallbackSubtype);
            });
          }

          final defaultRecipient =
              rules.defaults.recipient == 'other' ? 'other' : 'individual';
          final effectiveRecipient = _selectedRecipient.isEmpty
              ? defaultRecipient
              : _selectedRecipient;

          final result = TaxEngine.computeTds(
            rules: rules,
            paymentTypeValue: selectedType.value,
            amount: parseIndianAmountInput(_amountController.text),
            panAvailable: _panAvailable,
            recipient: effectiveRecipient,
            fee194jType: _selected194jType,
          );

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
                children: [
                  taxHelperCard(
                    theme: theme,
                    title: 'Quick pointers',
                    points: _effectiveTdsPointers(config.helperPoints.tds),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PerspectiveToggle(
                            selected: _perspective,
                            onChanged: (value) {
                              setState(() => _perspective = value);
                              _persistString(
                                AppConstants.prefTaxTdsPerspective,
                                value == _TdsPerspective.payer
                                    ? 'payer'
                                    : 'receiver',
                              );
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
                                onPressed: () => _resetForm(
                                    rules: rules, paymentTypes: paymentTypes),
                                icon: const Icon(Icons.restart_alt_rounded),
                                label: const Text('Reset'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _recipientHeading(_perspective),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _RecipientToggle(
                            selected: effectiveRecipient,
                            onChanged: (value) {
                              setState(() => _selectedRecipient = value);
                              _persistString(
                                  AppConstants.prefTaxTdsRecipient, value);
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _recipientHelper(
                              perspective: _perspective,
                              recipient: effectiveRecipient,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              setState(() => _panAvailable = !_panAvailable);
                              _persistBool(
                                  AppConstants.prefTaxTdsPan, _panAvailable);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
                              child: Row(
                                children: [
                                  const Expanded(child: Text('PAN available')),
                                  Checkbox(
                                    value: _panAvailable,
                                    visualDensity: const VisualDensity(
                                      horizontal: -4,
                                      vertical: -4,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (value) {
                                      _panAvailable = value ?? false;
                                      _persistBool(
                                        AppConstants.prefTaxTdsPan,
                                        _panAvailable,
                                      );
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          AdaptiveSelectField<String>(
                            label: 'Type of payment',
                            value: selectedType.value,
                            decoration: modernTaxInputDecoration(
                              theme,
                              label: 'Type of payment',
                              icon: Icons.list_alt_rounded,
                            ),
                            options: paymentTypes
                                .map(
                                  (row) => AdaptiveSelectOption(
                                    value: row.value,
                                    label: row.label,
                                    subtitle: row.description,
                                    searchTokens: [
                                      row.sectionCode,
                                      row.description,
                                    ],
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) return;
                              final next = paymentTypes
                                  .firstWhere((row) => row.value == value);
                              setState(() {
                                _selectedPaymentType = value;
                                if (next.subTypeOptions.isNotEmpty &&
                                    !next.subTypeOptions.any(
                                        (r) => r.value == _selected194jType)) {
                                  _selected194jType =
                                      next.subTypeOptions.first.value;
                                }
                              });
                              _persistString(
                                  AppConstants.prefTaxTdsPaymentType, value);
                              _persistString(
                                AppConstants.prefTaxTdsSubtype,
                                _selected194jType,
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: const [
                              IndianAmountInputFormatter()
                            ],
                            decoration: modernTaxInputDecoration(
                              theme,
                              label: 'Payment amount',
                              icon: Icons.payments_outlined,
                            ),
                            onChanged: (value) {
                              _persistString(
                                AppConstants.prefTaxTdsAmount,
                                parseIndianAmountInput(value)
                                    .round()
                                    .toString(),
                              );
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.10),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _line(
                                  'Threshold',
                                  '₹${Formatters.fullPrice(result.threshold)}',
                                ),
                                _line(
                                  'Applied rate',
                                  '${(result.appliedRate * 100).toStringAsFixed(2)}%',
                                ),
                              ],
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
                    if (_perspective == _TdsPerspective.receiver) ...[
                      Text(
                        'TDS deducted: ₹${Formatters.fullPrice(result.tdsAmount)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You receive: ₹${Formatters.fullPrice(result.netAmount)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ] else ...[
                      Text(
                        'TDS to deposit: ₹${Formatters.fullPrice(result.tdsAmount)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Amount to payee: ₹${Formatters.fullPrice(result.netAmount)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
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

  String _recipientHeading(_TdsPerspective perspective) {
    return perspective == _TdsPerspective.payer
        ? 'Payee type'
        : 'Receiver type';
  }

  String _recipientHelper({
    required _TdsPerspective perspective,
    required String recipient,
  }) {
    final personType = recipient == 'individual'
        ? 'Individual covers personal/HUF style cases.'
        : 'Other covers company, firm, LLP, trust, or similar entities.';
    if (perspective == _TdsPerspective.payer) return personType;
    return personType;
  }

  List<String> _effectiveTdsPointers(List<String> source) {
    return const [
      'Receiver shows net amount after deduction. Payer shows TDS to deduct/deposit before payment.',
      'Threshold is the minimum amount where TDS starts; applied rate is the actual percentage used for your current inputs.',
      'PAN availability can change the applied rate and final TDS amount.',
    ];
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  void _persistString(String key, String value) {
    ref.read(sharedPreferencesProvider).setString(key, value);
  }

  void _persistBool(String key, bool value) {
    ref.read(sharedPreferencesProvider).setBool(key, value);
  }

  void _resetForm({
    required TdsRules rules,
    required List<TdsPaymentTypeRule> paymentTypes,
  }) {
    _perspective = _TdsPerspective.receiver;
    _amountController.text = formatIndianAmountInput('0');
    _selectedPaymentType = paymentTypes.first.value;
    _selectedRecipient = rules.defaults.recipient.toLowerCase() == 'other'
        ? 'other'
        : 'individual';
    _panAvailable = rules.defaults.pan.toLowerCase() != 'no';
    final activeType = paymentTypes.first;
    _selected194jType = activeType.subTypeOptions.any(
      (row) => row.value == rules.defaults.fees194j,
    )
        ? rules.defaults.fees194j
        : (activeType.subTypeOptions.isNotEmpty
            ? activeType.subTypeOptions.first.value
            : 'others');

    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(AppConstants.prefTaxTdsPerspective, 'receiver');
    prefs.setString(AppConstants.prefTaxTdsAmount, '0');
    prefs.setString(AppConstants.prefTaxTdsPaymentType, _selectedPaymentType);
    prefs.setString(AppConstants.prefTaxTdsRecipient, _selectedRecipient);
    prefs.setBool(AppConstants.prefTaxTdsPan, _panAvailable);
    prefs.setString(AppConstants.prefTaxTdsSubtype, _selected194jType);
    setState(() {});
  }
}

class _PerspectiveToggle extends StatelessWidget {
  const _PerspectiveToggle({
    required this.selected,
    required this.onChanged,
  });

  final _TdsPerspective selected;
  final ValueChanged<_TdsPerspective> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedColor =
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.28);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'Receiver',
              selected: selected == _TdsPerspective.receiver,
              selectedColor: selectedColor,
              onTap: () => onChanged(_TdsPerspective.receiver),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: 'Payer',
              selected: selected == _TdsPerspective.payer,
              selectedColor: selectedColor,
              onTap: () => onChanged(_TdsPerspective.payer),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientToggle extends StatelessWidget {
  const _RecipientToggle({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedColor =
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.28);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'Individual',
              selected: selected == 'individual',
              selectedColor: selectedColor,
              onTap: () => onChanged('individual'),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: 'Other',
              selected: selected == 'other',
              selectedColor: selectedColor,
              onTap: () => onChanged('other'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
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

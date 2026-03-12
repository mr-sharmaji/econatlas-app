import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/error_utils.dart';
import '../../../core/utils.dart';
import '../../../data/models/converter_fx_snapshot.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class CurrencyConverterScreen extends ConsumerStatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  ConsumerState<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState
    extends ConsumerState<CurrencyConverterScreen> with WidgetsBindingObserver {
  final TextEditingController _amountController = TextEditingController();
  Timer? _autoRefreshTimer;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(AppConstants.prefConverterAmount) ?? '1';
    _amountController.text = saved;
    _autoRefreshTimer = Timer.periodic(AppConstants.marketRefreshInterval, (_) {
      if (!mounted || _lifecycleState != AppLifecycleState.resumed) return;
      ref.invalidate(converterDataProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(converterDataProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final converterDataAsync = ref.watch(converterDataProvider);
    final fromCode = ref.watch(converterFromCurrencyProvider);
    final toCode = ref.watch(converterToCurrencyProvider);
    final data = converterDataAsync.valueOrNull;
    final cachedState = _cachedStateFromPrefs();
    final effectiveState = data ?? cachedState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Converter'),
        actions: [
          _appBarStatusChip(theme, converterDataAsync, cachedState),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(14),
            children: [
              converterDataAsync.when(
                loading: () {
                  if (cachedState != null &&
                      cachedState.ratesInrByCode.isNotEmpty) {
                    final selection = _resolveSelection(
                      cachedState.ratesInrByCode,
                      fromCode: fromCode,
                      toCode: toCode,
                    );
                    _syncSelectedCodes(
                      fromCode: fromCode,
                      toCode: toCode,
                      selection: selection,
                    );
                    return _content(
                      theme,
                      cachedState,
                      options: selection.options,
                      fromCode: selection.fromCode,
                      toCode: selection.toCode,
                      showOfflineHint: false,
                    );
                  }
                  return const ShimmerCard(height: 220);
                },
                error: (err, _) {
                  if (cachedState != null &&
                      cachedState.ratesInrByCode.isNotEmpty) {
                    final selection = _resolveSelection(
                      cachedState.ratesInrByCode,
                      fromCode: fromCode,
                      toCode: toCode,
                    );
                    _syncSelectedCodes(
                      fromCode: fromCode,
                      toCode: toCode,
                      selection: selection,
                    );
                    return _content(
                      theme,
                      cachedState,
                      options: selection.options,
                      fromCode: selection.fromCode,
                      toCode: selection.toCode,
                      showOfflineHint: true,
                    );
                  }
                  return ErrorView(
                    message: friendlyErrorMessage(err),
                    onRetry: () => ref.invalidate(converterDataProvider),
                  );
                },
                data: (state) {
                  if (state.mode == ConverterDataMode.offlineNoData ||
                      state.ratesInrByCode.isEmpty) {
                    return _offlineNoDataState(theme);
                  }
                  final selection = _resolveSelection(
                    state.ratesInrByCode,
                    fromCode: fromCode,
                    toCode: toCode,
                  );
                  _syncSelectedCodes(
                    fromCode: fromCode,
                    toCode: toCode,
                    selection: selection,
                  );
                  return _content(
                    theme,
                    state,
                    options: selection.options,
                    fromCode: selection.fromCode,
                    toCode: selection.toCode,
                  );
                },
              ),
              const SizedBox(height: 92),
            ],
          ),
          if (effectiveState != null &&
              effectiveState.ratesInrByCode.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: _resultBar(theme, effectiveState, fromCode, toCode),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content(
    ThemeData theme,
    ConverterDataState state, {
    required List<String> options,
    required String fromCode,
    required String toCode,
    bool showOfflineHint = true,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter amount',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.14),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                prefixIcon: Container(
                  margin: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calculate_rounded),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    width: 1.4,
                  ),
                ),
              ),
              onChanged: (value) {
                ref
                    .read(sharedPreferencesProvider)
                    .setString(AppConstants.prefConverterAmount, value.trim());
                setState(() {});
              },
            ),
            const SizedBox(height: 10),
            _quickAmountChips(),
            const SizedBox(height: 12),
            _selector(
              context,
              label: 'From',
              code: fromCode,
              options: options,
              onSelected: (v) =>
                  ref.read(converterFromCurrencyProvider.notifier).set(v),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  ref.read(converterFromCurrencyProvider.notifier).set(toCode);
                  ref.read(converterToCurrencyProvider.notifier).set(fromCode);
                },
                icon: const Icon(Icons.swap_vert_rounded),
                label: const Text('Swap'),
              ),
            ),
            const SizedBox(height: 8),
            _selector(
              context,
              label: 'To',
              code: toCode,
              options: options,
              onSelected: (v) =>
                  ref.read(converterToCurrencyProvider.notifier).set(v),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      _amountController.text = '1';
                      ref
                          .read(sharedPreferencesProvider)
                          .setString(AppConstants.prefConverterAmount, '1');
                      setState(() {});
                    },
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ),
            if (showOfflineHint &&
                state.mode == ConverterDataMode.offlineCached) ...[
              const SizedBox(height: 12),
              Text(
                state.fetchedAt == null
                    ? 'Using cached rates while offline.'
                    : 'Using cached rates from ${Formatters.relativeTime(state.fetchedAt!)}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultBar(
    ThemeData theme,
    ConverterDataState state,
    String fromCode,
    String toCode,
  ) {
    final selection = _resolveSelection(
      state.ratesInrByCode,
      fromCode: fromCode,
      toCode: toCode,
    );
    final map = state.ratesInrByCode;
    final from = map[selection.fromCode];
    final to = map[selection.toCode];
    final amount = _parseAmount();
    final value =
        (amount != null && from != null && to != null && from > 0 && to > 0)
            ? (amount * from) / to
            : null;
    final unitRate =
        (from != null && to != null && from > 0 && to > 0) ? from / to : null;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          color: theme.colorScheme.surface.withValues(alpha: 0.96),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value == null
                    ? 'Enter a valid amount'
                    : '${Formatters.fullPrice(amount ?? 0)} ${selection.fromCode} = ${Formatters.fullPrice(value)} ${selection.toCode}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                unitRate == null
                    ? 'Rate unavailable'
                    : '1 ${selection.fromCode} = ${Formatters.fullPrice(unitRate)} ${selection.toCode}',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appBarStatusChip(
    ThemeData theme,
    AsyncValue<ConverterDataState> converterDataAsync,
    ConverterDataState? cachedState,
  ) {
    return converterDataAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (state) {
        if (state.mode == ConverterDataMode.offlineNoData ||
            state.ratesInrByCode.isEmpty) {
          return const SizedBox.shrink();
        }
        final isLive = state.mode == ConverterDataMode.onlineFresh;
        return _statusChip(
          theme,
          isLive ? 'Live rates' : 'Saved rates',
          isLive: isLive,
        );
      },
    );
  }

  Widget _statusChip(
    ThemeData theme,
    String label, {
    required bool isLive,
  }) {
    final bg = isLive
        ? Colors.green.withValues(alpha: 0.16)
        : Colors.orange.withValues(alpha: 0.18);
    final border = isLive
        ? Colors.green.withValues(alpha: 0.35)
        : Colors.orange.withValues(alpha: 0.35);
    final textColor = isLive ? Colors.green.shade300 : Colors.orange.shade300;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  ConverterDataState? _cachedStateFromPrefs() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(AppConstants.prefConverterFxSnapshot);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final snapshot = ConverterFxSnapshot.fromJson(decoded);
      if (snapshot.ratesInrByCode.isEmpty) return null;
      return ConverterDataState(
        mode: ConverterDataMode.offlineCached,
        ratesInrByCode: snapshot.ratesInrByCode,
        fetchedAt: snapshot.fetchedAt,
        sourceCount: snapshot.sourceCount,
      );
    } catch (_) {
      return null;
    }
  }

  Widget _selector(
    BuildContext context, {
    required String label,
    required String code,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    final theme = Theme.of(context);
    final name = _currencyNameByCode[code.toUpperCase()] ?? code;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await _openPicker(
          context: context,
          title: 'Select $label currency',
          options: options,
          selected: code,
        );
        if (picked != null) onSelected(picked);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white60,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    code,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Future<String?> _openPicker({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String selected,
  }) {
    String query = '';
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filtered = options.where((option) {
            if (query.isEmpty) return true;
            final code = option.toUpperCase();
            final name = (_currencyNameByCode[code] ?? option).toLowerCase();
            final q = query.toLowerCase();
            return code.contains(query.toUpperCase()) || name.contains(q);
          }).toList();

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search currency code or name',
                      ),
                      onChanged: (value) =>
                          setModalState(() => query = value.trim()),
                    ),
                  ),
                  const Divider(height: 1),
                  if (filtered.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'No currencies found.',
                          style: Theme.of(ctx)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final option = filtered[i];
                          final isSelected = option == selected;
                          return ListTile(
                            onTap: () => Navigator.of(ctx).pop(option),
                            selected: isSelected,
                            selectedTileColor: Theme.of(ctx)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                            title: Text(
                              '${option.toUpperCase()} · ${_currencyNameByCode[option.toUpperCase()] ?? option}',
                              style:
                                  Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle_rounded,
                                    color: Theme.of(ctx).colorScheme.primary)
                                : null,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _offlineNoDataState(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 32, color: Colors.white70),
            const SizedBox(height: 10),
            Text(
              'No offline rates available',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Connect once to download currency rates for offline conversion.',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(converterDataProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  ({String fromCode, String toCode, List<String> options}) _resolveSelection(
    Map<String, double> ratesInrByCode, {
    required String fromCode,
    required String toCode,
  }) {
    final options = ratesInrByCode.keys.toList()..sort();
    final effectiveFrom = options.contains(fromCode) ? fromCode : options.first;
    final effectiveTo = options.contains(toCode)
        ? toCode
        : (options.contains('INR') ? 'INR' : options.last);
    return (fromCode: effectiveFrom, toCode: effectiveTo, options: options);
  }

  void _syncSelectedCodes({
    required String fromCode,
    required String toCode,
    required ({String fromCode, String toCode, List<String> options}) selection,
  }) {
    if (selection.fromCode != fromCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(converterFromCurrencyProvider.notifier)
            .set(selection.fromCode);
      });
    }
    if (selection.toCode != toCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(converterToCurrencyProvider.notifier).set(selection.toCode);
      });
    }
  }

  double? _parseAmount() {
    final raw = _amountController.text.replaceAll(',', '').trim();
    return double.tryParse(raw);
  }

  void _setQuickAmount(String value) {
    _amountController.text = value;
    _amountController.selection = TextSelection.fromPosition(
      TextPosition(offset: _amountController.text.length),
    );
    ref
        .read(sharedPreferencesProvider)
        .setString(AppConstants.prefConverterAmount, value);
    setState(() {});
  }

  Widget _quickAmountChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _quickAmounts
          .map(
            (chip) => ActionChip(
              label: Text(chip.label),
              onPressed: () => _setQuickAmount(chip.value),
            ),
          )
          .toList(),
    );
  }
}

class _QuickAmountData {
  final String label;
  final String value;

  const _QuickAmountData({
    required this.label,
    required this.value,
  });
}

const _quickAmounts = [
  _QuickAmountData(label: '1', value: '1'),
  _QuickAmountData(label: '100', value: '100'),
  _QuickAmountData(label: '1,000', value: '1000'),
  _QuickAmountData(label: '10,000', value: '10000'),
];

const Map<String, String> _currencyNameByCode = {
  'INR': 'Indian Rupee',
  'USD': 'US Dollar',
  'EUR': 'Euro',
  'GBP': 'British Pound',
  'JPY': 'Japanese Yen',
  'AUD': 'Australian Dollar',
  'CAD': 'Canadian Dollar',
  'CHF': 'Swiss Franc',
  'CNY': 'Chinese Yuan',
  'SGD': 'Singapore Dollar',
  'HKD': 'Hong Kong Dollar',
  'KRW': 'South Korean Won',
  'AED': 'UAE Dirham',
  'NZD': 'New Zealand Dollar',
  'SAR': 'Saudi Riyal',
  'QAR': 'Qatari Riyal',
  'KWD': 'Kuwaiti Dinar',
  'BHD': 'Bahraini Dinar',
  'OMR': 'Omani Rial',
  'ILS': 'Israeli Shekel',
  'THB': 'Thai Baht',
  'MYR': 'Malaysian Ringgit',
  'IDR': 'Indonesian Rupiah',
  'PHP': 'Philippine Peso',
  'TWD': 'Taiwan Dollar',
  'VND': 'Vietnamese Dong',
  'BDT': 'Bangladeshi Taka',
  'LKR': 'Sri Lankan Rupee',
  'PKR': 'Pakistani Rupee',
  'NPR': 'Nepalese Rupee',
  'SEK': 'Swedish Krona',
  'NOK': 'Norwegian Krone',
  'DKK': 'Danish Krone',
  'PLN': 'Polish Zloty',
  'TRY': 'Turkish Lira',
  'ZAR': 'South African Rand',
  'BRL': 'Brazilian Real',
  'MXN': 'Mexican Peso',
};

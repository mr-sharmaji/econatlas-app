import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_utils.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'tax/tax_calculator_catalog.dart';
import 'tax/tax_ui.dart';

class TaxHubScreen extends ConsumerWidget {
  const TaxHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final configAsync = ref.watch(taxConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tax Hub')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          configAsync.when(
            loading: () => const ShimmerCard(height: 180),
            error: (err, _) => ErrorView(
              message: friendlyErrorMessage(err),
              onRetry: () => ref.invalidate(taxConfigProvider),
            ),
            data: (state) {
              final config = state.config;

              final calculators = taxCalculatorCatalog
                  .where((c) => c.visible)
                  .toList()
                ..sort((a, b) => a.order.compareTo(b.order));
              final startYear = currentFyStartYearIst();
              final fyLabel =
                  '$startYear-${((startYear + 1) % 100).toString().padLeft(2, '0')}';
              final ayLabel =
                  '${startYear + 1}-${((startYear + 2) % 100).toString().padLeft(2, '0')}';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current FY: $fyLabel   AY: $ayLabel',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Financial Year is when you earn income. Assessment Year is when that income is assessed and filed.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  taxHelperCard(
                    theme: theme,
                    title: 'Before you calculate',
                    points: config.helperPoints.hub,
                  ),
                  const SizedBox(height: 10),
                  ...calculators.map(
                    (calculator) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CalculatorCard(
                        title: calculator.title,
                        subtitle: calculator.subtitle,
                        onTap: () => context.push(_routeFor(calculator.key)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _routeFor(String key) {
    switch (key) {
      case 'income_tax':
        return '/tools/tax/income';
      case 'capital_gains':
        return '/tools/tax/capital-gains';
      case 'advance_tax':
        return '/tools/tax/advance-tax';
      case 'tds':
        return '/tools/tax/tds';
      default:
        return '/tools/tax/income';
    }
  }
}

class _CalculatorCard extends StatelessWidget {
  const _CalculatorCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.14),
        ),
        child: Row(
          children: [
            const Icon(Icons.calculate_rounded, color: Colors.white70),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

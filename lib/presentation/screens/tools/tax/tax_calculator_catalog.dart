import '../../../../data/models/tax_config.dart';

const List<TaxCalculatorMeta> taxCalculatorCatalog = [
  TaxCalculatorMeta(
    key: 'income_tax',
    title: 'Income Tax',
    subtitle: 'Salary and deduction estimator',
    visible: true,
    order: 1,
  ),
  TaxCalculatorMeta(
    key: 'capital_gains',
    title: 'Capital Gains',
    subtitle: 'Asset-wise capital gain estimate',
    visible: true,
    order: 2,
  ),
  TaxCalculatorMeta(
    key: 'advance_tax',
    title: 'Advance Tax',
    subtitle: 'Installment and shortfall planner',
    visible: true,
    order: 3,
  ),
  TaxCalculatorMeta(
    key: 'tds',
    title: 'TDS',
    subtitle: 'Payment-type deduction calculator',
    visible: true,
    order: 4,
  ),
];

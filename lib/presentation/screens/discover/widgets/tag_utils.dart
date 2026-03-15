import 'package:flutter/material.dart';

import '../../../../core/theme.dart';

class TagDisplay {
  final String label;
  final IconData icon;
  final Color color;

  const TagDisplay({
    required this.label,
    required this.icon,
    required this.color,
  });
}

const Map<String, TagDisplay> _tagMappings = {
  'low_debt': TagDisplay(
    label: 'Low Debt',
    icon: Icons.shield_outlined,
    color: AppTheme.accentGreen,
  ),
  'high_growth': TagDisplay(
    label: 'High Growth',
    icon: Icons.trending_up,
    color: AppTheme.accentTeal,
  ),
  'profitable': TagDisplay(
    label: 'Profitable',
    icon: Icons.check_circle_outline,
    color: AppTheme.accentGreen,
  ),
  'momentum': TagDisplay(
    label: 'Momentum',
    icon: Icons.speed,
    color: AppTheme.accentBlue,
  ),
  'trending': TagDisplay(
    label: 'Trending',
    icon: Icons.trending_up,
    color: AppTheme.accentBlue,
  ),
  'value': TagDisplay(
    label: 'Value',
    icon: Icons.diamond_outlined,
    color: AppTheme.accentOrange,
  ),
  'undervalued': TagDisplay(
    label: 'Undervalued',
    icon: Icons.arrow_downward,
    color: AppTheme.accentGreen,
  ),
  'growth': TagDisplay(
    label: 'Growth',
    icon: Icons.show_chart,
    color: AppTheme.accentTeal,
  ),
  'volatile': TagDisplay(
    label: 'Volatile',
    icon: Icons.warning_amber,
    color: AppTheme.accentRed,
  ),
  'risk': TagDisplay(
    label: 'Risk',
    icon: Icons.warning_amber,
    color: AppTheme.accentRed,
  ),
  'dividend': TagDisplay(
    label: 'Dividend',
    icon: Icons.payments_outlined,
    color: AppTheme.accentOrange,
  ),
  'yield': TagDisplay(
    label: 'Yield',
    icon: Icons.payments_outlined,
    color: AppTheme.accentOrange,
  ),
  'quality': TagDisplay(
    label: 'Quality',
    icon: Icons.verified_outlined,
    color: Colors.purple,
  ),
  'strong': TagDisplay(
    label: 'Strong',
    icon: Icons.verified_outlined,
    color: Colors.purple,
  ),
  'fii': TagDisplay(
    label: 'FII Interest',
    icon: Icons.account_balance,
    color: AppTheme.accentBlue,
  ),
  'dii': TagDisplay(
    label: 'DII Interest',
    icon: Icons.account_balance,
    color: AppTheme.accentBlue,
  ),
};

TagDisplay getTagDisplay(String rawTag) {
  final lower = rawTag.toLowerCase();

  // Exact match first
  if (_tagMappings.containsKey(lower)) return _tagMappings[lower]!;

  // Partial match
  for (final entry in _tagMappings.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }

  // Fallback: title case the raw tag
  final label = rawTag
      .split('_')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
  return TagDisplay(
    label: label,
    icon: Icons.label_outline,
    color: Colors.white54,
  );
}

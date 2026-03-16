import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../data/models/discover.dart';

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

// ---------------------------------------------------------------------------
// Severity → color mapping
// ---------------------------------------------------------------------------

Color severityColor(String severity) {
  switch (severity) {
    case 'positive':
      return AppTheme.accentGreen;
    case 'negative':
      return AppTheme.accentRed;
    default:
      return AppTheme.accentBlue;
  }
}

Color severityBackground(String severity) {
  switch (severity) {
    case 'positive':
      return AppTheme.accentGreen.withValues(alpha: 0.12);
    case 'negative':
      return AppTheme.accentRed.withValues(alpha: 0.12);
    default:
      return AppTheme.accentBlue.withValues(alpha: 0.10);
  }
}

// ---------------------------------------------------------------------------
// Category → display name & icon
// ---------------------------------------------------------------------------

const Map<String, String> _categoryLabels = {
  'classification': 'Classification',
  'style': 'Style',
  'conviction': 'Conviction',
  'strength': 'Strengths',
  'valuation': 'Valuation',
  'risk': 'Risks',
  'trend': 'Trends',
  'context': 'Context',
  'ownership': 'Ownership',
};

const Map<String, IconData> _categoryIcons = {
  'classification': Icons.category_outlined,
  'style': Icons.style_outlined,
  'conviction': Icons.psychology,
  'strength': Icons.verified_outlined,
  'valuation': Icons.attach_money,
  'risk': Icons.warning_amber_rounded,
  'trend': Icons.trending_up,
  'context': Icons.lightbulb_outline,
  'ownership': Icons.people_outline,
};

String categoryLabel(String category) =>
    _categoryLabels[category] ?? category;

IconData categoryIcon(String category) =>
    _categoryIcons[category] ?? Icons.label_outline;

// ---------------------------------------------------------------------------
// TagV2 → TagDisplay conversion
// ---------------------------------------------------------------------------

TagDisplay getTagV2Display(TagV2 tag) {
  // Try exact match from legacy map first for icon resolution
  final legacy = _tagMappings[tag.tag.toLowerCase()];
  if (legacy != null) {
    return TagDisplay(
      label: legacy.label,
      icon: legacy.icon,
      color: severityColor(tag.severity),
    );
  }
  // Fallback: use category icon and severity color
  return TagDisplay(
    label: tag.tag,
    icon: categoryIcon(tag.category),
    color: severityColor(tag.severity),
  );
}

// ---------------------------------------------------------------------------
// Group TagV2 list by category (preserves priority order within groups)
// ---------------------------------------------------------------------------

/// Groups tags by category, ordered by the defined category order.
/// Tags within each group remain sorted by priority (lower = higher priority).
Map<String, List<TagV2>> groupTagsByCategory(List<TagV2> tags) {
  const categoryOrder = [
    'conviction',
    'strength',
    'risk',
    'valuation',
    'trend',
    'context',
    'ownership',
    'style',
    'classification',
  ];

  final grouped = <String, List<TagV2>>{};
  for (final tag in tags) {
    if (tag.isExpired) continue;
    grouped.putIfAbsent(tag.category, () => []).add(tag);
  }

  // Return in defined order
  final ordered = <String, List<TagV2>>{};
  for (final cat in categoryOrder) {
    if (grouped.containsKey(cat)) {
      ordered[cat] = grouped[cat]!;
    }
  }
  // Any unknown categories at the end
  for (final entry in grouped.entries) {
    if (!ordered.containsKey(entry.key)) {
      ordered[entry.key] = entry.value;
    }
  }
  return ordered;
}

/// Returns the single best tag for list tile display.
/// Skips classification tags (market cap is implied).
/// Prefers positive/negative over neutral.
TagV2? bestTagForListTile(List<TagV2> tags) {
  final candidates = tags
      .where((t) => !t.isExpired && t.category != 'classification')
      .toList();
  if (candidates.isEmpty) return null;
  // Already sorted by priority from API, so take first
  return candidates.first;
}

// ---------------------------------------------------------------------------
// Legacy flat-string tag mappings (backward compat)
// ---------------------------------------------------------------------------

const Map<String, TagDisplay> _tagMappings = {
  // ── Legacy snake_case tags ──
  'low_debt': TagDisplay(label: 'Low Debt', icon: Icons.shield_outlined, color: AppTheme.accentGreen),
  'high_growth': TagDisplay(label: 'High Growth', icon: Icons.trending_up, color: AppTheme.accentTeal),
  'profitable': TagDisplay(label: 'Profitable', icon: Icons.check_circle_outline, color: AppTheme.accentGreen),
  'momentum': TagDisplay(label: 'Momentum', icon: Icons.speed, color: AppTheme.accentBlue),
  'trending': TagDisplay(label: 'Trending', icon: Icons.trending_up, color: AppTheme.accentBlue),
  'value': TagDisplay(label: 'Value', icon: Icons.diamond_outlined, color: AppTheme.accentOrange),
  'undervalued': TagDisplay(label: 'Undervalued', icon: Icons.arrow_downward, color: AppTheme.accentGreen),
  'growth': TagDisplay(label: 'Growth', icon: Icons.show_chart, color: AppTheme.accentTeal),
  'volatile': TagDisplay(label: 'Volatile', icon: Icons.warning_amber, color: AppTheme.accentRed),
  'risk': TagDisplay(label: 'Risk', icon: Icons.warning_amber, color: AppTheme.accentRed),
  'dividend': TagDisplay(label: 'Dividend', icon: Icons.payments_outlined, color: AppTheme.accentOrange),
  'yield': TagDisplay(label: 'Yield', icon: Icons.payments_outlined, color: AppTheme.accentOrange),
  'quality': TagDisplay(label: 'Quality', icon: Icons.verified_outlined, color: Colors.purple),
  'strong': TagDisplay(label: 'Strong', icon: Icons.verified_outlined, color: Colors.purple),
  'fii': TagDisplay(label: 'FII Interest', icon: Icons.account_balance, color: AppTheme.accentBlue),
  'dii': TagDisplay(label: 'DII Interest', icon: Icons.account_balance, color: AppTheme.accentBlue),

  // ── Backend human-readable tags (from _generate_tags) ──
  // Market cap
  'large cap': TagDisplay(label: 'Large Cap', icon: Icons.business, color: AppTheme.accentBlue),
  'mid cap': TagDisplay(label: 'Mid Cap', icon: Icons.business_center, color: AppTheme.accentTeal),
  'small cap': TagDisplay(label: 'Small Cap', icon: Icons.store, color: AppTheme.accentOrange),

  // Lynch classification
  'turnaround story': TagDisplay(label: 'Turnaround Story', icon: Icons.refresh_rounded, color: AppTheme.accentOrange),
  'fast grower': TagDisplay(label: 'Fast Grower', icon: Icons.rocket_launch_rounded, color: AppTheme.accentGreen),
  'stalwart': TagDisplay(label: 'Stalwart', icon: Icons.shield_rounded, color: AppTheme.accentBlue),
  'cyclical play': TagDisplay(label: 'Cyclical Play', icon: Icons.loop_rounded, color: AppTheme.accentOrange),
  'asset play': TagDisplay(label: 'Asset Play', icon: Icons.account_balance_wallet, color: AppTheme.accentTeal),
  'slow grower': TagDisplay(label: 'Slow Grower', icon: Icons.trending_flat, color: AppTheme.accentGray),

  // Quality
  'high quality': TagDisplay(label: 'High Quality', icon: Icons.verified_rounded, color: AppTheme.accentGreen),
  'paper profits': TagDisplay(label: 'Paper Profits', icon: Icons.warning_rounded, color: AppTheme.accentRed),
  'high pledge risk': TagDisplay(label: 'High Pledge Risk', icon: Icons.warning_amber_rounded, color: AppTheme.accentRed),
  'consistent compounder': TagDisplay(label: 'Consistent Compounder', icon: Icons.auto_graph, color: AppTheme.accentGreen),
  'sector leader': TagDisplay(label: 'Sector Leader', icon: Icons.emoji_events_rounded, color: Colors.amber),

  // Compounding
  'decade compounder': TagDisplay(label: 'Decade Compounder', icon: Icons.auto_graph, color: AppTheme.accentGreen),
  '5y wealth creator': TagDisplay(label: '5Y Wealth Creator', icon: Icons.trending_up, color: AppTheme.accentTeal),

  // Financial strength
  'debt free': TagDisplay(label: 'Debt Free', icon: Icons.shield_outlined, color: AppTheme.accentGreen),
  'fcf machine': TagDisplay(label: 'FCF Machine', icon: Icons.monetization_on_outlined, color: AppTheme.accentGreen),
  'cash rich': TagDisplay(label: 'Cash Rich', icon: Icons.savings_outlined, color: AppTheme.accentGreen),
  'strong cash flow': TagDisplay(label: 'Strong Cash Flow', icon: Icons.water_drop_outlined, color: AppTheme.accentTeal),
  'capital allocator': TagDisplay(label: 'Capital Allocator', icon: Icons.account_tree, color: AppTheme.accentTeal),

  // Valuation
  'peg bargain': TagDisplay(label: 'PEG Bargain', icon: Icons.local_offer, color: AppTheme.accentGreen),
  'value pick': TagDisplay(label: 'Value Pick', icon: Icons.diamond_outlined, color: AppTheme.accentGreen),
  'analyst strong buy': TagDisplay(label: 'Analyst Strong Buy', icon: Icons.thumb_up_rounded, color: AppTheme.accentGreen),
  'analyst undervalued': TagDisplay(label: 'Analyst Undervalued', icon: Icons.trending_up, color: AppTheme.accentTeal),
  'growth at fair price': TagDisplay(label: 'Growth at Fair Price', icon: Icons.balance, color: AppTheme.accentTeal),
  'richly valued': TagDisplay(label: 'Richly Valued', icon: Icons.attach_money, color: AppTheme.accentRed),
  'growth stock': TagDisplay(label: 'Growth Stock', icon: Icons.show_chart, color: AppTheme.accentTeal),
  'high dividend': TagDisplay(label: 'High Dividend', icon: Icons.payments_outlined, color: AppTheme.accentOrange),

  // Quality trends
  'margin expansion': TagDisplay(label: 'Margin Expansion', icon: Icons.expand_less, color: AppTheme.accentGreen),
  'deleveraging': TagDisplay(label: 'Deleveraging', icon: Icons.trending_down, color: AppTheme.accentGreen),
  'margin fortress': TagDisplay(label: 'Margin Fortress', icon: Icons.fort, color: AppTheme.accentGreen),

  // Divergence
  'momentum without quality': TagDisplay(label: 'Momentum Without Quality', icon: Icons.warning_amber, color: AppTheme.accentOrange),
  'quality weak momentum': TagDisplay(label: 'Quality Weak Momentum', icon: Icons.speed, color: AppTheme.accentOrange),

  // Sector-specific
  'nim expander': TagDisplay(label: 'NIM Expander', icon: Icons.account_balance, color: AppTheme.accentTeal),
  'r&d intensive': TagDisplay(label: 'R&D Intensive', icon: Icons.biotech, color: AppTheme.accentBlue),
  'capacity expansion': TagDisplay(label: 'Capacity Expansion', icon: Icons.factory, color: AppTheme.accentBlue),

  // Regime
  'defensive pick': TagDisplay(label: 'Defensive Pick', icon: Icons.shield_rounded, color: AppTheme.accentBlue),
  'bear market resilient': TagDisplay(label: 'Bear Market Resilient', icon: Icons.shield_rounded, color: AppTheme.accentBlue),

  // Ownership
  'high promoter': TagDisplay(label: 'High Promoter', icon: Icons.person, color: AppTheme.accentBlue),
  'fii favorite': TagDisplay(label: 'FII Favorite', icon: Icons.account_balance, color: AppTheme.accentBlue),
  'dii backed': TagDisplay(label: 'DII Backed', icon: Icons.account_balance, color: AppTheme.accentBlue),
  'promoter buying': TagDisplay(label: 'Promoter Buying', icon: Icons.add_circle_outline, color: AppTheme.accentGreen),
  'fii buying': TagDisplay(label: 'FII Buying', icon: Icons.add_circle_outline, color: AppTheme.accentGreen),
  'dii buying': TagDisplay(label: 'DII Buying', icon: Icons.add_circle_outline, color: AppTheme.accentGreen),

  // Technicals
  'bullish trend': TagDisplay(label: 'Bullish Trend', icon: Icons.trending_up, color: AppTheme.accentGreen),
  'bearish trend': TagDisplay(label: 'Bearish Trend', icon: Icons.trending_down, color: AppTheme.accentRed),
  'low free float': TagDisplay(label: 'Low Free Float', icon: Icons.lock_outline, color: AppTheme.accentOrange),

  // Other
  'negative eps': TagDisplay(label: 'Negative EPS', icon: Icons.remove_circle_outline, color: AppTheme.accentRed),

  // ── Conviction tags ──
  'strong conviction': TagDisplay(label: 'Strong Conviction', icon: Icons.verified_rounded, color: AppTheme.accentGreen),
  'improving setup': TagDisplay(label: 'Improving Setup', icon: Icons.trending_up, color: AppTheme.accentGreen),
  'technicals lagging': TagDisplay(label: 'Technicals Lagging', icon: Icons.speed, color: AppTheme.accentOrange),
  'momentum without fundamentals': TagDisplay(label: 'Momentum Without Fundamentals', icon: Icons.warning_amber, color: AppTheme.accentRed),
  'weak conviction': TagDisplay(label: 'Weak Conviction', icon: Icons.remove_circle_outline, color: AppTheme.accentRed),

  // ── Risk context tags ──
  'oversold quality': TagDisplay(label: 'Oversold Quality', icon: Icons.local_offer, color: AppTheme.accentGreen),
  'low risk setup': TagDisplay(label: 'Low Risk Setup', icon: Icons.shield_rounded, color: AppTheme.accentGreen),
  'high risk momentum': TagDisplay(label: 'High Risk Momentum', icon: Icons.warning_amber_rounded, color: AppTheme.accentRed),
  'overbought warning': TagDisplay(label: 'Overbought Warning', icon: Icons.trending_down, color: AppTheme.accentRed),
  'near 52w low': TagDisplay(label: 'Near 52W Low', icon: Icons.arrow_downward, color: AppTheme.accentOrange),
  'near 52w high': TagDisplay(label: 'Near 52W High', icon: Icons.arrow_upward, color: AppTheme.accentGreen),

  // ── Context tags ──
  'sector outperformer': TagDisplay(label: 'Sector Outperformer', icon: Icons.emoji_events_rounded, color: AppTheme.accentGreen),
  'sector laggard': TagDisplay(label: 'Sector Laggard', icon: Icons.trending_down, color: AppTheme.accentRed),
  'recovery candidate': TagDisplay(label: 'Recovery Candidate', icon: Icons.refresh_rounded, color: AppTheme.accentOrange),
  'data limited': TagDisplay(label: 'Data Limited', icon: Icons.info_outline, color: AppTheme.accentBlue),
};

/// Legacy: resolve a flat string tag to display info.
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

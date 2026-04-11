import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme.dart';

/// Native renderer for the backend's `data_card` SSE payload.
///
/// Replaces markdown tables that were unreadable on mobile. Branches
/// on the `kind` field:
///   * `comparison`  → stacked entity blocks on narrow screens, 2-3
///                     column side-by-side on wide screens, with the
///                     winner per metric highlighted green.
///   * `ranked_list` → vertical list of tappable rows with a primary
///                     value chip + 2-3 secondary pills each.
///   * `metric_grid` → 2-column labeled key/value grid grouped into
///                     optional section headings.
class DataCardWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  const DataCardWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final kind = data['kind'] as String? ?? '';
    switch (kind) {
      case 'comparison':
        return _ComparisonCard(data: data);
      case 'ranked_list':
        return _RankedListCard(data: data);
      case 'metric_grid':
        return _MetricGridCard(data: data);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// comparison — N entities × M metrics
// ─────────────────────────────────────────────────────────────────────

class _ComparisonCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ComparisonCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = data['title'] as String? ?? '';
    final entities = (data['entities'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final metrics = (data['metrics'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (entities.length < 2 || metrics.isEmpty) {
      return const SizedBox.shrink();
    }

    // Narrow layout (< 600px): stacked entity blocks with metric bullets.
    // Wide layout (>= 600px): side-by-side table-like grid.
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        return Container(
          margin: const EdgeInsets.only(bottom: 8, top: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty) ...[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (isNarrow)
                _buildStacked(theme, entities, metrics)
              else
                _buildSideBySide(context, theme, entities, metrics),
            ],
          ),
        );
      },
    );
  }

  // Stacked: each entity becomes a tile with metric rows inside.
  Widget _buildStacked(
    ThemeData theme,
    List<Map<String, dynamic>> entities,
    List<Map<String, dynamic>> metrics,
  ) {
    final winnerIdx = _computeWinners(entities.length, metrics);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < entities.length; i++) ...[
          _EntityBlock(
            entity: entities[i],
            metrics: metrics,
            entityIndex: i,
            winnerIdx: winnerIdx,
          ),
          if (i < entities.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  // Side-by-side: metrics on rows, entities on columns.
  Widget _buildSideBySide(
    BuildContext context,
    ThemeData theme,
    List<Map<String, dynamic>> entities,
    List<Map<String, dynamic>> metrics,
  ) {
    final winnerIdx = _computeWinners(entities.length, metrics);
    final cellStyle = theme.textTheme.bodySmall?.copyWith(fontSize: 12);
    final headStyle = cellStyle?.copyWith(
      fontWeight: FontWeight.w700,
      color: Colors.white70,
    );

    return Column(
      children: [
        // Header row — entity names
        Row(
          children: [
            const Expanded(flex: 2, child: SizedBox.shrink()),
            for (final e in entities)
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () {
                    final id = e['id'] as String? ?? '';
                    if (id.isNotEmpty) {
                      context.push('/discover/stock/$id');
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      (e['id'] as String?) ?? (e['name'] as String? ?? ''),
                      style: headStyle,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // Metric rows
        for (int m = 0; m < metrics.length; m++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    metrics[m]['label'] as String? ?? '',
                    style: cellStyle?.copyWith(color: Colors.white60),
                  ),
                ),
                for (int e = 0; e < entities.length; e++)
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        _valueString(metrics[m], e),
                        style: cellStyle?.copyWith(
                          color: winnerIdx[m] == e
                              ? AppTheme.accentGreen
                              : Colors.white,
                          fontWeight: winnerIdx[m] == e
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // Returns winnerIdx[metric_index] = entity_index with the best value,
  // or -1 if no winner (all null / higher_is_better == null / ties).
  List<int> _computeWinners(
    int entityCount,
    List<Map<String, dynamic>> metrics,
  ) {
    final out = <int>[];
    for (final m in metrics) {
      final hib = m['higher_is_better'];
      if (hib == null) {
        out.add(-1);
        continue;
      }
      final numeric = (m['numeric'] as List<dynamic>? ?? []);
      if (numeric.length != entityCount) {
        out.add(-1);
        continue;
      }
      double? best;
      int bestIdx = -1;
      for (int i = 0; i < entityCount; i++) {
        final v = numeric[i];
        if (v == null) continue;
        final d = (v as num).toDouble();
        if (best == null) {
          best = d;
          bestIdx = i;
          continue;
        }
        if (hib == true && d > best) {
          best = d;
          bestIdx = i;
        } else if (hib == false && d < best) {
          best = d;
          bestIdx = i;
        }
      }
      out.add(bestIdx);
    }
    return out;
  }

  String _valueString(Map<String, dynamic> metric, int entityIdx) {
    final values = metric['values'] as List<dynamic>? ?? [];
    if (entityIdx >= values.length) return '—';
    final v = values[entityIdx];
    if (v == null) return '—';
    return v.toString();
  }
}

class _EntityBlock extends StatelessWidget {
  final Map<String, dynamic> entity;
  final List<Map<String, dynamic>> metrics;
  final int entityIndex;
  final List<int> winnerIdx;

  const _EntityBlock({
    required this.entity,
    required this.metrics,
    required this.entityIndex,
    required this.winnerIdx,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = entity['id'] as String? ?? '';
    final name = entity['name'] as String? ?? id;
    final subtitle = entity['subtitle'] as String? ?? '';
    final pct = (entity['percent_change'] as num?)?.toDouble();
    final isUp = (pct ?? 0) >= 0;
    final pctColor = isUp ? AppTheme.accentGreen : AppTheme.accentRed;

    return GestureDetector(
      onTap: () {
        if (id.isNotEmpty) {
          context.push('/discover/stock/$id');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          '$id · $subtitle',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                if (pct != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: pctColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${isUp ? '+' : ''}${pct.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: pctColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (int m = 0; m < metrics.length; m++)
              _MetricRow(
                label: metrics[m]['label'] as String? ?? '',
                value: _valueString(metrics[m], entityIndex),
                isWinner: winnerIdx[m] == entityIndex,
              ),
          ],
        ),
      ),
    );
  }

  String _valueString(Map<String, dynamic> metric, int entityIdx) {
    final values = metric['values'] as List<dynamic>? ?? [];
    if (entityIdx >= values.length) return '—';
    final v = values[entityIdx];
    if (v == null) return '—';
    return v.toString();
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isWinner;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(fontSize: 12);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: style?.copyWith(color: Colors.white54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isWinner)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      size: 11,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                Flexible(
                  child: Text(
                    value,
                    style: style?.copyWith(
                      color: isWinner ? AppTheme.accentGreen : Colors.white,
                      fontWeight:
                          isWinner ? FontWeight.w700 : FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ranked_list — vertical tappable rows
// ─────────────────────────────────────────────────────────────────────

class _RankedListCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RankedListCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = data['title'] as String? ?? '';
    final entityType = data['entity_type'] as String? ?? 'stock';
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],
          for (int i = 0; i < items.length; i++) ...[
            _RankedListRow(
              rank: i + 1,
              item: items[i],
              entityType: entityType,
            ),
            if (i < items.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.05),
              ),
          ],
        ],
      ),
    );
  }
}

class _RankedListRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> item;
  final String entityType;

  const _RankedListRow({
    required this.rank,
    required this.item,
    required this.entityType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = item['id'] as String? ?? '';
    final name = item['name'] as String? ?? id;
    final subtitle = item['subtitle'] as String? ?? '';
    final primaryValue = item['primary_value'] as String? ?? '';
    final primaryTone = item['primary_tone'] as String? ?? 'neutral';
    final pills = (item['pills'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final primaryColor = switch (primaryTone) {
      'positive' => AppTheme.accentGreen,
      'negative' => AppTheme.accentRed,
      'warn' => AppTheme.accentOrange,
      _ => Colors.white70,
    };

    return GestureDetector(
      onTap: () {
        if (id.isEmpty) return;
        if (entityType == 'stock') {
          context.push('/discover/stock/$id');
        } else if (entityType == 'mutual_fund') {
          context.push('/discover/mf/$id');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '$rank',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white38,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (primaryValue.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      primaryValue,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            if (pills.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final p in pills)
                      _Pill(
                        label: p['label'] as String? ?? '',
                        value: p['value']?.toString() ?? '',
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;

  const _Pill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 10, color: Colors.white70),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(color: Colors.white38),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// metric_grid — 2-col labeled grid with optional section headings
// ─────────────────────────────────────────────────────────────────────

class _MetricGridCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _MetricGridCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = data['title'] as String? ?? '';
    final subtitle = data['subtitle'] as String? ?? '';
    final sections = (data['sections'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (sections.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          if (subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ),
          const SizedBox(height: 10),
          for (int s = 0; s < sections.length; s++) ...[
            if ((sections[s]['heading'] as String? ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  sections[s]['heading'] as String,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white38,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            for (final m in (sections[s]['metrics'] as List<dynamic>? ?? []))
              _MetricGridRow(
                metric: Map<String, dynamic>.from(m as Map),
              ),
            if (s < sections.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _MetricGridRow extends StatelessWidget {
  final Map<String, dynamic> metric;

  const _MetricGridRow({required this.metric});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = metric['label'] as String? ?? '';
    final value = metric['value']?.toString() ?? '—';
    final tone = metric['tone'] as String? ?? 'neutral';
    final color = switch (tone) {
      'positive' => AppTheme.accentGreen,
      'negative' => AppTheme.accentRed,
      'warn' => AppTheme.accentOrange,
      _ => Colors.white,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

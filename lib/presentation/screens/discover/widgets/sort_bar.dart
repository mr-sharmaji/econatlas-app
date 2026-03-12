import 'package:flutter/material.dart';

/// A compact sort control: dropdown for sort field + toggle for asc/desc.
class SortBar extends StatelessWidget {
  final String sortBy;
  final String sortOrder;
  final List<SortOption> options;
  final ValueChanged<String> onSortByChanged;
  final ValueChanged<String> onSortOrderChanged;

  const SortBar({
    super.key,
    required this.sortBy,
    required this.sortOrder,
    required this.options,
    required this.onSortByChanged,
    required this.onSortOrderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'Sort:',
          style: theme.textTheme.labelMedium?.copyWith(color: Colors.white54),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((opt) {
                final selected = sortBy == opt.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(opt.label),
                    selected: selected,
                    onSelected: (_) => onSortByChanged(opt.value),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            sortOrder == 'desc'
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            size: 18,
          ),
          onPressed: () {
            onSortOrderChanged(sortOrder == 'desc' ? 'asc' : 'desc');
          },
          tooltip: sortOrder == 'desc' ? 'Descending' : 'Ascending',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class SortOption {
  final String value;
  final String label;

  const SortOption({required this.value, required this.label});
}

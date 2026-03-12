import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

@immutable
class AdaptiveSelectOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final List<String> searchTokens;

  const AdaptiveSelectOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.searchTokens = const [],
  });
}

class AdaptiveSelectField<T> extends StatelessWidget {
  const AdaptiveSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.decoration,
    this.hintText,
    this.enabled = true,
    this.searchThreshold = 5,
    this.enableSearch = true,
  });

  final String label;
  final T? value;
  final List<AdaptiveSelectOption<T>> options;
  final ValueChanged<T?> onChanged;
  final InputDecoration? decoration;
  final String? hintText;
  final bool enabled;
  final int searchThreshold;
  final bool enableSearch;

  bool get _useSearchBottomSheet => options.length > searchThreshold;

  @override
  Widget build(BuildContext context) {
    final effectiveDecoration =
        decoration ?? InputDecoration(labelText: label, hintText: hintText);
    final selected = _selectedOption();

    return DropdownSearch<AdaptiveSelectOption<T>>(
      enabled: enabled && options.isNotEmpty,
      selectedItem: selected,
      compareFn: (a, b) => a.value == b.value,
      itemAsString: (item) => item.label,
      onChanged: (option) => onChanged(option?.value),
      decoratorProps: DropDownDecoratorProps(
        decoration: effectiveDecoration,
      ),
      dropdownBuilder: (context, selectedItem) {
        if (selectedItem == null) {
          return Text(
            hintText ?? 'Select',
            overflow: TextOverflow.ellipsis,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedItem.label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if ((selectedItem.subtitle ?? '').trim().isNotEmpty)
              Text(
                selectedItem.subtitle!.trim(),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
          ],
        );
      },
      items: (filter, _) {
        final query = filter.trim().toLowerCase();
        if (query.isEmpty) {
          return options;
        }
        return options.where((item) {
          if (item.label.toLowerCase().contains(query)) return true;
          if ((item.subtitle ?? '').toLowerCase().contains(query)) return true;
          return item.searchTokens
              .map((token) => token.toLowerCase())
              .any((token) => token.contains(query));
        }).toList(growable: false);
      },
      popupProps: _useSearchBottomSheet
          ? PopupProps.bottomSheet(
              showSearchBox: enableSearch,
              fit: FlexFit.loose,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.72,
              ),
              title: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              bottomSheetProps: const BottomSheetProps(
                showDragHandle: true,
              ),
              searchFieldProps: const TextFieldProps(
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              itemBuilder: _popupItemBuilder,
              emptyBuilder: (context, searchEntry) => const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: Text('No options found')),
              ),
            )
          : PopupProps.menu(
              fit: FlexFit.loose,
              showSearchBox: false,
              constraints: const BoxConstraints(maxHeight: 320),
              itemBuilder: _popupItemBuilder,
            ),
    );
  }

  Widget _popupItemBuilder(
    BuildContext context,
    AdaptiveSelectOption<T> item,
    bool isDisabled,
    bool isSelected,
  ) {
    final selected = item.value == value;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.16)
            : Colors.transparent,
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: selected ? theme.colorScheme.primary : Colors.transparent,
        ),
        title: Text(
          item.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle:
            (item.subtitle ?? '').trim().isEmpty ? null : Text(item.subtitle!),
        trailing: null,
      ),
    );
  }

  AdaptiveSelectOption<T>? _selectedOption() {
    for (final option in options) {
      if (option.value == value) return option;
    }
    return null;
  }
}

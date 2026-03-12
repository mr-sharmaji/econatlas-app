import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String _onlyDigits(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

String _groupIndianDigits(String digits) {
  if (digits.isEmpty) return '';
  final normalized = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (normalized.length <= 3) return normalized;
  final head = normalized.substring(0, normalized.length - 3);
  final tail = normalized.substring(normalized.length - 3);
  final groups = <String>[];
  var i = head.length;
  while (i > 2) {
    groups.insert(0, head.substring(i - 2, i));
    i -= 2;
  }
  groups.insert(0, head.substring(0, i));
  return '${groups.join(',')},$tail';
}

String formatIndianAmountInput(String raw) =>
    _groupIndianDigits(_onlyDigits(raw));

double parseIndianAmountInput(String raw) {
  final digits = _onlyDigits(raw);
  if (digits.isEmpty) return 0.0;
  return double.tryParse(digits) ?? 0.0;
}

int parseIndianIntInput(String raw) {
  final digits = _onlyDigits(raw);
  if (digits.isEmpty) return 0;
  return int.tryParse(digits) ?? 0;
}

DateTime nowIstDateTime() =>
    DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

int currentFyStartYearIst({DateTime? nowIst}) {
  final now = nowIst ?? nowIstDateTime();
  return now.month >= 4 ? now.year : now.year - 1;
}

String fyIdFromStartYear(int startYear) =>
    'FY$startYear-${((startYear + 1) % 100).toString().padLeft(2, '0')}';

String ayIdFromFyStartYear(int startYear) =>
    'AY${startYear + 1}-${((startYear + 2) % 100).toString().padLeft(2, '0')}';

class IndianAmountInputFormatter extends TextInputFormatter {
  const IndianAmountInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _onlyDigits(newValue.text);
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final formatted = _groupIndianDigits(digits);
    final baseOffset =
        newValue.selection.baseOffset.clamp(0, newValue.text.length).toInt();
    final digitsBeforeCursor =
        _onlyDigits(newValue.text.substring(0, baseOffset)).length;

    var nextOffset = formatted.length;
    if (digitsBeforeCursor <= 0) {
      nextOffset = 0;
    } else if (digitsBeforeCursor < digits.length) {
      var seen = 0;
      for (var i = 0; i < formatted.length; i++) {
        if (RegExp(r'[0-9]').hasMatch(formatted[i])) {
          seen += 1;
          if (seen == digitsBeforeCursor) {
            nextOffset = i + 1;
            break;
          }
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: nextOffset),
      composing: TextRange.empty,
    );
  }
}

InputDecoration modernTaxInputDecoration(
  ThemeData theme, {
  required String label,
  String? hint,
  String? helper,
  IconData icon = Icons.calculate_rounded,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    filled: true,
    fillColor:
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    prefixIcon: Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: theme.colorScheme.primary.withValues(alpha: 0.7),
        width: 1.4,
      ),
    ),
  );
}

Widget glassResultBar({
  required ThemeData theme,
  required List<Widget> children,
  double bottomInset = 0,
}) {
  return ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(14, 8, 14, 12 + bottomInset),
        color: theme.colorScheme.surface.withValues(alpha: 0.96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    ),
  );
}

Widget taxHelperCard({
  required ThemeData theme,
  required String title,
  required List<String> points,
}) {
  if (points.isEmpty) {
    return const SizedBox.shrink();
  }
  final visible = points.take(3).toList(growable: false);
  return Card(
    margin: EdgeInsets.zero,
    color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...visible.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.circle,
                      size: 7,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      point,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

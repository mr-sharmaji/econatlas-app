import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:timezone/timezone.dart' as tz;
import 'constants.dart';

class Formatters {
  Formatters._();

  static final _percentFormat = NumberFormat('0.00');
  static final _dateFormat = DateFormat('MMM d, yyyy');
  static final _dateTimeFormat = DateFormat('MMM d, yyyy HH:mm');
  static final _asOfDateFormat = DateFormat('EEE, dd MMM');
  static final _asOfDateWithYearFormat = DateFormat('EEE, dd MMM yyyy');
  static String _absoluteTimeZoneId = ChartTimezone.deviceLocal.id;

  static void setAbsoluteTimeZone(String timeZoneId) {
    _absoluteTimeZoneId = ChartTimezone.fromId(timeZoneId).id;
  }

  static DateTime _toDisplayTime(DateTime dt, {String? timeZoneId}) {
    final tzId = timeZoneId ?? _absoluteTimeZoneId;
    if (tzId == ChartTimezone.deviceLocal.id) {
      return dt.toLocal();
    }
    try {
      final loc = tz.getLocation(tzId);
      return tz.TZDateTime.from(dt.toUtc(), loc);
    } catch (_) {
      return dt.toLocal();
    }
  }

  /// Indian style: 1,52,434.87 (from right: last 3 digits, then groups of 2).
  static String _indianFormat(double value, {bool decimals = true}) {
    final isNegative = value < 0;
    value = value.abs();
    final intPart = value.floor();
    final fracPart = value - intPart;
    String s = intPart.toString();
    final len = s.length;
    if (len <= 3) {
      final out = decimals && fracPart > 0
          ? '$s${fracPart.toStringAsFixed(2).substring(1)}'
          : s;
      return isNegative ? '-$out' : out;
    }
    final parts = <String>[];
    // Last 3 digits (hundreds)
    parts.add(s.substring(len - 3));
    int i = len - 3;
    while (i > 0) {
      final take = i >= 2 ? 2 : 1;
      parts.insert(0, s.substring(i - take, i));
      i -= take;
    }
    String result = parts.join(',');
    if (decimals && fracPart > 0) {
      result += fracPart.toStringAsFixed(2).substring(1);
    }
    return isNegative ? '-$result' : result;
  }

  static String price(double value, {String? unit}) {
    if (unit == 'percent') {
      return '${_percentFormat.format(value)}%';
    }
    if (unit == 'inr') {
      return fxInrPrice(value);
    }
    if (value == value.roundToDouble() && value.abs() >= 100) {
      return _indianFormat(value, decimals: false);
    }
    return _indianFormat(value);
  }

  static String fullPrice(double value) {
    if (value == value.roundToDouble()) {
      return _indianFormat(value, decimals: false);
    }
    return _indianFormat(value);
  }

  static String fxInrPrice(double value) {
    final abs = value.abs();
    if (abs >= 1) {
      return fullPrice(value);
    }
    final decimals = abs >= 0.1
        ? 4
        : abs >= 0.01
            ? 5
            : 6;
    final fixed = value.toStringAsFixed(decimals);
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static String changeTag(double? pct) {
    if (pct == null) return '';
    final sign = pct >= 0 ? '+' : '';
    return '$sign${_percentFormat.format(pct)}%';
  }

  static String changeWithDiff({
    required double current,
    double? previous,
    double? pct,
  }) {
    double? resolvedPct = pct;
    double? diff;

    if (previous != null && previous != 0) {
      diff = current - previous;
      resolvedPct ??= (diff / previous) * 100;
    } else if (resolvedPct != null) {
      final prev = current / (1 + (resolvedPct / 100));
      diff = current - prev;
    }

    final pctLabel = changeTag(resolvedPct);
    if (diff == null && pctLabel.isEmpty) return '';
    if (diff == null) return pctLabel;

    final sign = diff >= 0 ? '+' : '';
    final diffLabel = '$sign${fullPrice(diff)}';
    if (pctLabel.isEmpty) return diffLabel;
    return '$diffLabel ($pctLabel)';
  }

  static String date(DateTime dt) => _dateFormat.format(_toDisplayTime(dt));

  static String dateTime(DateTime dt) =>
      _dateTimeFormat.format(_toDisplayTime(dt));

  static String asOfDate(DateTime dt, {DateTime? now}) {
    final local = _toDisplayTime(dt);
    final localNow = _toDisplayTime(now ?? DateTime.now());
    if (local.year == localNow.year) {
      return _asOfDateFormat.format(local);
    }
    return _asOfDateWithYearFormat.format(local);
  }

  /// Short label for chart axis: compact for 1M, month/year for longer ranges.
  static String chartAxisDate(DateTime dt, {required bool isShortRange}) {
    final local = _toDisplayTime(dt);
    if (isShortRange) {
      return DateFormat('MMM d').format(local);
    }
    return DateFormat("MMM ''yy").format(local);
  }

  /// Time-only label for 1D intraday chart (e.g. 09:30, 14:00). [timeZoneId] e.g. Asia/Kolkata, America/New_York.
  static String chartAxisTime(DateTime dt,
      {String timeZoneId = 'Asia/Kolkata'}) {
    return DateFormat('HH:mm')
        .format(_toDisplayTime(dt, timeZoneId: timeZoneId));
  }

  static String relativeTime(DateTime dt) => timeago.format(dt.toLocal());

  /// Human-friendly quote freshness label based on true tick age.
  /// Keep copy precise: always show relative age instead of "just now".
  static String updatedFreshness(
    DateTime tickTime, {
    bool allowJustNow = false,
    int justNowSeconds = 75,
  }) {
    // [allowJustNow]/[justNowSeconds] are kept for API compatibility.
    return 'Updated ${relativeTime(tickTime)}';
  }

  /// Shared asset subtitle copy for list surfaces.
  /// Predictive rows keep "Indicative" wording; all others use "Updated ...".
  static String marketFreshnessSubtitle({
    required DateTime tickTime,
    bool isPredictive = false,
  }) {
    if (isPredictive) {
      return 'Indicative · last quoted ${relativeTime(tickTime)}';
    }
    return updatedFreshness(tickTime);
  }

  static String confidence(double value) => '${(value * 100).toInt()}%';

  static String macroValue(double value, String indicator) {
    if (indicator.contains('rate') ||
        indicator.contains('inflation') ||
        indicator.contains('gdp') ||
        indicator.contains('unemployment')) {
      return '${_percentFormat.format(value)}%';
    }
    return _indianFormat(value);
  }

  static double goldToIndian(double usdPerOz, double usdInrRate) {
    return (usdPerOz / 31.1035) * 10 * usdInrRate;
  }

  static double silverToIndian(double usdPerOz, double usdInrRate) {
    return (usdPerOz / 31.1035) * 1000 * usdInrRate;
  }

  static double copperToIndian(double usdPerLb, double usdInrRate) {
    return usdPerLb * 2.20462 * usdInrRate;
  }

  static double barrelToIndian(double usdPerBarrel, double usdInrRate) {
    return usdPerBarrel * usdInrRate;
  }

  static double mmbtuToIndian(double usdPerMmbtu, double usdInrRate) {
    return usdPerMmbtu * usdInrRate;
  }
}

/// Converts raw price to display value for charts/lists (e.g. USD/oz -> ₹/10g for gold when Indian).
/// [useIndianUnits] true when user preference is Indian (₹, /10g etc).
double assetDisplayValue({
  required String asset,
  required double rawPrice,
  required bool useIndianUnits,
  required double usdInrRate,
  required String instrumentType,
}) {
  if (instrumentType == 'commodity' && useIndianUnits) {
    final a = asset.toLowerCase();
    switch (a) {
      case 'gold':
        return Formatters.goldToIndian(rawPrice, usdInrRate);
      case 'silver':
        return Formatters.silverToIndian(rawPrice, usdInrRate);
      case 'copper':
        return Formatters.copperToIndian(rawPrice, usdInrRate);
      case 'crude oil':
        return Formatters.barrelToIndian(rawPrice, usdInrRate);
      case 'natural gas':
        return Formatters.mmbtuToIndian(rawPrice, usdInrRate);
      case 'platinum':
      case 'palladium':
        return Formatters.goldToIndian(rawPrice, usdInrRate);
      default:
        return rawPrice * usdInrRate;
    }
  }
  if (instrumentType == 'currency' && asset.toUpperCase().contains('INR')) {
    return rawPrice;
  }
  return rawPrice;
}

/// Display string for price (e.g. "₹ 5,158.70" or "$ 2,180.10") and compact unit label (e.g. " /10g").
(String displayPrice, String unitLabel) assetDisplayPriceAndUnit({
  required String asset,
  required double rawPrice,
  required bool useIndianUnits,
  required double usdInrRate,
  required String instrumentType,
  String? sourceUnit,
}) {
  final a = asset.toLowerCase();
  if (instrumentType == 'commodity' && useIndianUnits) {
    switch (a) {
      case 'gold':
        return (
          '₹ ${Formatters.fullPrice(Formatters.goldToIndian(rawPrice, usdInrRate))}',
          ' /10g'
        );
      case 'silver':
        return (
          '₹ ${Formatters.fullPrice(Formatters.silverToIndian(rawPrice, usdInrRate))}',
          ' /kg'
        );
      case 'copper':
        return (
          '₹ ${Formatters.fullPrice(Formatters.copperToIndian(rawPrice, usdInrRate))}',
          ' /kg'
        );
      case 'crude oil':
        return (
          '₹ ${Formatters.fullPrice(Formatters.barrelToIndian(rawPrice, usdInrRate))}',
          ' /bbl'
        );
      case 'natural gas':
        return (
          '₹ ${Formatters.fullPrice(Formatters.mmbtuToIndian(rawPrice, usdInrRate))}',
          ' /MMBtu'
        );
      case 'platinum':
      case 'palladium':
        return (
          '₹ ${Formatters.fullPrice(Formatters.goldToIndian(rawPrice, usdInrRate))}',
          ' /10g'
        );
      default:
        return ('₹ ${Formatters.fullPrice(rawPrice * usdInrRate)}', '');
    }
  }
  if (instrumentType == 'commodity') {
    final unitCode = (sourceUnit ?? '').trim();
    final rawUnit = unitCode.isEmpty ? null : Entities.unitLabelsIntl[unitCode];
    final fallbackUnit = switch (a) {
      'gold' || 'silver' || 'platinum' || 'palladium' => '/oz',
      'copper' => '/lb',
      'crude oil' => '/bbl',
      'natural gas' => '/MMBtu',
      _ => null,
    };
    final normalized = rawUnit ?? fallbackUnit;
    return (
      '\$ ${Formatters.fullPrice(rawPrice)}',
      normalized == null ? '' : ' $normalized',
    );
  }
  if (instrumentType == 'currency' &&
      (asset.contains('INR') || asset.contains('inr'))) {
    return ('₹ ${Formatters.fxInrPrice(rawPrice)}', '');
  }
  if (instrumentType == 'bond_yield') {
    return (Formatters.fullPrice(rawPrice), '%');
  }
  return (Formatters.fullPrice(rawPrice), '');
}

String displayName(String entity) {
  final raw = Entities.displayNames[entity] ?? _titleCase(entity);
  return raw.replaceFirst(
    RegExp(r'^[\u{1F1E6}-\u{1F1FF}]{2}\s*', unicode: true),
    '',
  );
}

String displayRegionName(String region) {
  final normalized = region.trim().toLowerCase();
  if (normalized == 'fx') return 'Currencies';
  return region;
}

String friendlyImpact(String? impact) {
  if (impact == null) return '';
  return Impacts.friendlyLabels[impact] ?? _titleCase(impact);
}

String _titleCase(String s) {
  return s
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

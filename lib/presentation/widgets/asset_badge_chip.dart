import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/constants.dart';
import '../../core/square_badge_assets.dart';
import 'square_badge_svg.dart';

enum AssetBadgeStyle {
  india,
  us,
  europe,
  japan,
  global,
  asia,
  middleEast,
  americas,
  africa,
  currenciesOther,
  metals,
  energy,
  agriculture,
  softs,
  fertilizers,
  crypto,
  fallback,
}

enum AssetBadgeMode {
  asset,
  category,
}

class AssetBadgeSpec {
  final Gradient? gradient;
  final Color background;
  final Color borderColor;
  final Color foreground;
  final IconData? icon;
  final String? glyph;

  const AssetBadgeSpec({
    this.gradient,
    required this.background,
    required this.borderColor,
    required this.foreground,
    this.icon,
    this.glyph,
  });

  bool get isGradient => gradient != null;
}

class AssetBadgeResolver {
  const AssetBadgeResolver._();

  static AssetBadgeStyle forAsset({
    required String asset,
    required String instrumentType,
  }) {
    final normalizedType = instrumentType.trim().toLowerCase();
    switch (normalizedType) {
      case 'index':
        if (Entities.indicesIndia.contains(asset)) return AssetBadgeStyle.india;
        if (Entities.indicesUS.contains(asset)) return AssetBadgeStyle.us;
        if (Entities.indicesEurope.contains(asset)) {
          return AssetBadgeStyle.europe;
        }
        if (Entities.indicesJapan.contains(asset)) return AssetBadgeStyle.japan;
        return AssetBadgeStyle.global;
      case 'currency':
        if (Entities.fxMajor.contains(asset)) return AssetBadgeStyle.global;
        if (Entities.fxAsiaPacific.contains(asset)) return AssetBadgeStyle.asia;
        if (Entities.fxMiddleEast.contains(asset)) {
          return AssetBadgeStyle.middleEast;
        }
        if (Entities.fxEurope.contains(asset)) return AssetBadgeStyle.europe;
        if (Entities.fxAmericas.contains(asset)) {
          return AssetBadgeStyle.americas;
        }
        if (Entities.fxAfrica.contains(asset)) return AssetBadgeStyle.africa;
        return AssetBadgeStyle.currenciesOther;
      case 'commodity':
        final normalizedAsset = asset.trim().toLowerCase();
        if (normalizedAsset == 'crude oil' ||
            normalizedAsset == 'brent crude' ||
            normalizedAsset == 'natural gas' ||
            normalizedAsset == 'gasoline' ||
            normalizedAsset == 'heating oil') {
          return AssetBadgeStyle.energy;
        }
        if (normalizedAsset == 'gold' ||
            normalizedAsset == 'silver' ||
            normalizedAsset == 'copper' ||
            normalizedAsset == 'aluminum' ||
            normalizedAsset == 'zinc' ||
            normalizedAsset == 'iron ore' ||
            normalizedAsset == 'platinum' ||
            normalizedAsset == 'palladium') {
          return AssetBadgeStyle.metals;
        }
        if (normalizedAsset == 'wheat' ||
            normalizedAsset == 'corn' ||
            normalizedAsset == 'soybeans' ||
            normalizedAsset == 'rice' ||
            normalizedAsset == 'oats') {
          return AssetBadgeStyle.agriculture;
        }
        if (normalizedAsset == 'cotton' ||
            normalizedAsset == 'sugar' ||
            normalizedAsset == 'coffee' ||
            normalizedAsset == 'cocoa' ||
            normalizedAsset == 'palm oil' ||
            normalizedAsset == 'rubber') {
          return AssetBadgeStyle.softs;
        }
        if (normalizedAsset == 'urea' ||
            normalizedAsset == 'dap fertilizer' ||
            normalizedAsset == 'potash' ||
            normalizedAsset == 'tsp fertilizer') {
          return AssetBadgeStyle.fertilizers;
        }
        return AssetBadgeStyle.energy;
      case 'crypto':
        return AssetBadgeStyle.crypto;
      case 'bond_yield':
        if (asset == 'India 10Y Bond Yield') return AssetBadgeStyle.india;
        if (asset.startsWith('US ')) return AssetBadgeStyle.us;
        if (asset == 'Germany 10Y Bond Yield') return AssetBadgeStyle.europe;
        if (asset == 'Japan 10Y Bond Yield') return AssetBadgeStyle.japan;
        return AssetBadgeStyle.global;
      default:
        return AssetBadgeStyle.fallback;
    }
  }

  static AssetBadgeSpec resolveSpec({
    required AssetBadgeStyle style,
    String? asset,
    String? instrumentType,
    AssetBadgeMode mode = AssetBadgeMode.asset,
  }) {
    if (mode == AssetBadgeMode.category) {
      return AssetBadgeSpec(
        gradient: _gradientForStyle(style),
        background: Colors.transparent,
        borderColor: Colors.white.withValues(alpha: 0.14),
        foreground: Colors.white,
      );
    }

    final normalizedAsset = (asset ?? '').trim().toLowerCase();
    final normalizedType = (instrumentType ?? '').trim().toLowerCase();
    final background = _assetColorOverrides[normalizedAsset] ??
        _assetClassColor(normalizedType, style);

    if (normalizedType == 'currency') {
      final lead = _currencyLead(asset);
      return AssetBadgeSpec(
        background: background,
        borderColor: Colors.white.withValues(alpha: 0.22),
        foreground: Colors.white,
        glyph: _currencyCode(lead),
      );
    }

    return AssetBadgeSpec(
      background: background,
      borderColor: Colors.white.withValues(alpha: 0.22),
      foreground: Colors.white,
      icon: _assetIconOverrides[normalizedAsset] ??
          _defaultIconForType(normalizedType, style),
    );
  }

  static Color _assetClassColor(String instrumentType, AssetBadgeStyle style) {
    switch (instrumentType) {
      case 'index':
        return const Color(0xFF1E4F8A);
      case 'currency':
        switch (style) {
          case AssetBadgeStyle.asia:
            return const Color(0xFF7B3E6B);
          case AssetBadgeStyle.middleEast:
            return const Color(0xFF2B5D64);
          case AssetBadgeStyle.europe:
            return const Color(0xFF224A81);
          case AssetBadgeStyle.americas:
            return const Color(0xFF2C5C45);
          case AssetBadgeStyle.africa:
            return const Color(0xFF7A5520);
          case AssetBadgeStyle.global:
            return const Color(0xFF244A6D);
          default:
            return const Color(0xFF355D7E);
        }
      case 'commodity':
        return style == AssetBadgeStyle.energy
            ? const Color(0xFF3B2A21)
            : const Color(0xFF6A5A2F);
      case 'crypto':
        return const Color(0xFF3A2F5E);
      case 'bond_yield':
        return const Color(0xFF3E4D73);
      default:
        return const Color(0xFF4A4F57);
    }
  }

  static IconData _defaultIconForType(
    String instrumentType,
    AssetBadgeStyle style,
  ) {
    switch (instrumentType) {
      case 'index':
        return FontAwesomeIcons.chartLine;
      case 'commodity':
        return style == AssetBadgeStyle.energy
            ? FontAwesomeIcons.fire
            : FontAwesomeIcons.gem;
      case 'bond_yield':
        return FontAwesomeIcons.landmark;
      case 'currency':
        return FontAwesomeIcons.globe;
      case 'crypto':
        return FontAwesomeIcons.bitcoin;
      default:
        return Icons.circle_rounded;
    }
  }

  static String _currencyLead(String? asset) {
    final raw = (asset ?? '').trim().toUpperCase();
    if (!raw.contains('/')) return '';
    return raw.split('/').first.trim();
  }

  static String _currencyCode(String lead) {
    if (lead.isEmpty) return '?';
    if (lead.length <= 2) return lead;
    return lead.substring(0, 2);
  }

  static Gradient _gradientForStyle(AssetBadgeStyle style) {
    switch (style) {
      case AssetBadgeStyle.india:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF9933),
            Color(0xFFFFFFFF),
            Color(0xFF138808),
          ],
        );
      case AssetBadgeStyle.us:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFB22234),
            Color(0xFFFFFFFF),
            Color(0xFF3C3B6E),
          ],
        );
      case AssetBadgeStyle.europe:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF003399),
            Color(0xFF1E5ACD),
            Color(0xFFFFCC00),
          ],
        );
      case AssetBadgeStyle.japan:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF6C6D1),
            Color(0xFFBC002D),
          ],
        );
      case AssetBadgeStyle.global:
        return const LinearGradient(
          colors: [Color(0xFF0A84FF), Color(0xFF5AC8FA)],
        );
      case AssetBadgeStyle.asia:
        return const LinearGradient(
          colors: [Color(0xFFFF9500), Color(0xFFFF2D55)],
        );
      case AssetBadgeStyle.middleEast:
        return const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF2C3E50)],
        );
      case AssetBadgeStyle.americas:
        return const LinearGradient(
          colors: [Color(0xFF34C759), Color(0xFF007AFF)],
        );
      case AssetBadgeStyle.africa:
        return const LinearGradient(
          colors: [Color(0xFFFF9500), Color(0xFF30D158)],
        );
      case AssetBadgeStyle.currenciesOther:
        return const LinearGradient(
          colors: [Color(0xFF30D158), Color(0xFF0A84FF)],
        );
      case AssetBadgeStyle.metals:
        return const LinearGradient(
          colors: [Color(0xFFB0B0B0), Color(0xFF6D6D6D)],
        );
      case AssetBadgeStyle.energy:
        return const LinearGradient(
          colors: [Color(0xFFFF9F0A), Color(0xFF1C1C1E)],
        );
      case AssetBadgeStyle.agriculture:
        return const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
        );
      case AssetBadgeStyle.softs:
        return const LinearGradient(
          colors: [Color(0xFF8D6E63), Color(0xFFD7CCC8)],
        );
      case AssetBadgeStyle.fertilizers:
        return const LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF4DB6AC)],
        );
      case AssetBadgeStyle.crypto:
        return const LinearGradient(
          colors: [Color(0xFF3A2F5E), Color(0xFF7B61FF)],
        );
      case AssetBadgeStyle.fallback:
        return const LinearGradient(
          colors: [Color(0xFF6E6E73), Color(0xFF3A3A3C)],
        );
    }
  }
}

class AssetBadgeChip extends StatelessWidget {
  final AssetBadgeStyle style;
  final String? asset;
  final String? instrumentType;
  final AssetBadgeMode mode;
  final double size;
  final double borderRadius;
  final bool showBorder;

  const AssetBadgeChip({
    super.key,
    required this.style,
    this.asset,
    this.instrumentType,
    this.mode = AssetBadgeMode.asset,
    this.size = 20,
    this.borderRadius = 6,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final currencyLead = AssetBadgeResolver._currencyLead(asset);
    final normalizedType = (instrumentType ?? '').trim().toLowerCase();
    if (mode == AssetBadgeMode.asset && normalizedType == 'currency') {
      return SquareBadgeSvg(
        assetPath: SquareBadgeAssets.flagPathForCurrencyLead(currencyLead),
        size: size,
        borderRadius: borderRadius,
      );
    }

    if (mode == AssetBadgeMode.category) {
      final mappedCountry = _countryCodeForCategoryStyle(style);
      final categoryPath = _categoryPathForStyle(style);
      return SquareBadgeSvg(
        assetPath: mappedCountry != null
            ? SquareBadgeAssets.flagPathForCountryCode(mappedCountry)
            : categoryPath,
        size: size,
        borderRadius: borderRadius,
      );
    }

    final spec = AssetBadgeResolver.resolveSpec(
      style: style,
      asset: asset,
      instrumentType: instrumentType,
      mode: mode,
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: spec.isGradient ? null : spec.background,
        gradient: spec.gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(
                color: spec.borderColor,
                width: 1,
              )
            : null,
      ),
      child: Center(
        child:
            mode == AssetBadgeMode.category ? null : _buildAssetContent(spec),
      ),
    );
  }

  String? _countryCodeForCategoryStyle(AssetBadgeStyle style) {
    switch (style) {
      case AssetBadgeStyle.india:
        return 'IN';
      case AssetBadgeStyle.us:
        return 'US';
      case AssetBadgeStyle.japan:
        return 'JP';
      case AssetBadgeStyle.europe:
        return 'EU';
      default:
        return null;
    }
  }

  String _categoryPathForStyle(AssetBadgeStyle style) {
    switch (style) {
      case AssetBadgeStyle.global:
        return SquareBadgeAssets.categoryPathForKey('global');
      case AssetBadgeStyle.asia:
        return SquareBadgeAssets.categoryPathForKey('asia');
      case AssetBadgeStyle.middleEast:
        return SquareBadgeAssets.categoryPathForKey('middle_east');
      case AssetBadgeStyle.americas:
        return SquareBadgeAssets.categoryPathForKey('americas');
      case AssetBadgeStyle.africa:
        return SquareBadgeAssets.categoryPathForKey('africa');
      case AssetBadgeStyle.currenciesOther:
        return SquareBadgeAssets.categoryPathForKey('currencies_other');
      case AssetBadgeStyle.metals:
        return SquareBadgeAssets.categoryPathForKey('metals');
      case AssetBadgeStyle.energy:
        return SquareBadgeAssets.categoryPathForKey('energy');
      case AssetBadgeStyle.agriculture:
        return SquareBadgeAssets.categoryPathForKey('agriculture');
      case AssetBadgeStyle.softs:
        return SquareBadgeAssets.categoryPathForKey('softs');
      case AssetBadgeStyle.fertilizers:
        return SquareBadgeAssets.categoryPathForKey('fertilizers');
      case AssetBadgeStyle.fallback:
        return SquareBadgeAssets.categoryPathForKey('fallback');
      case AssetBadgeStyle.crypto:
        return SquareBadgeAssets.categoryPathForKey('crypto');
      case AssetBadgeStyle.india:
      case AssetBadgeStyle.us:
      case AssetBadgeStyle.europe:
      case AssetBadgeStyle.japan:
        return SquareBadgeAssets.globalCategoryPath;
    }
  }

  Widget _buildAssetContent(AssetBadgeSpec spec) {
    if (spec.glyph != null) {
      return Text(
        spec.glyph!,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: spec.foreground,
          fontSize: size * 0.52,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    if (spec.icon == null) return const SizedBox.shrink();
    return Icon(
      spec.icon,
      size: size * 0.62,
      color: spec.foreground,
    );
  }
}

const Map<String, IconData> _assetIconOverrides = {
  'nifty 50': FontAwesomeIcons.chartSimple,
  'sensex': FontAwesomeIcons.chartColumn,
  'gift nifty': FontAwesomeIcons.bolt,
  'nifty 500': FontAwesomeIcons.chartPie,
  'nifty bank': FontAwesomeIcons.buildingColumns,
  'nifty it': FontAwesomeIcons.microchip,
  'nifty midcap 150': FontAwesomeIcons.chartArea,
  'nifty smallcap 250': FontAwesomeIcons.chartSimple,
  'nifty auto': FontAwesomeIcons.carSide,
  'nifty pharma': FontAwesomeIcons.capsules,
  'nifty metal': FontAwesomeIcons.industry,
  'nasdaq': FontAwesomeIcons.waveSquare,
  'nasdaq 100': FontAwesomeIcons.arrowTrendUp,
  's&p500': FontAwesomeIcons.chartSimple,
  'dow jones': FontAwesomeIcons.chartColumn,
  'cboe vix': FontAwesomeIcons.waveSquare,
  's&p 500 tech': FontAwesomeIcons.microchip,
  's&p 500 financials': FontAwesomeIcons.buildingColumns,
  's&p 500 energy': FontAwesomeIcons.fire,
  'ftse 100': FontAwesomeIcons.chartSimple,
  'dax': FontAwesomeIcons.chartArea,
  'cac 40': FontAwesomeIcons.chartPie,
  'euro stoxx 50': FontAwesomeIcons.chartColumn,
  'nikkei 225': FontAwesomeIcons.waveSquare,
  'topix': FontAwesomeIcons.chartSimple,
  'gold': FontAwesomeIcons.coins,
  'silver': FontAwesomeIcons.coins,
  'platinum': FontAwesomeIcons.gem,
  'palladium': FontAwesomeIcons.gem,
  'copper': FontAwesomeIcons.screwdriverWrench,
  'crude oil': FontAwesomeIcons.oilCan,
  'brent crude': FontAwesomeIcons.oilWell,
  'natural gas': FontAwesomeIcons.fire,
  'gasoline': FontAwesomeIcons.gasPump,
  'heating oil': FontAwesomeIcons.temperatureHigh,
  'aluminum': FontAwesomeIcons.cubes,
  // Agriculture
  'wheat': FontAwesomeIcons.seedling,
  'corn': FontAwesomeIcons.wheatAwn,
  'soybeans': FontAwesomeIcons.leaf,
  'rice': FontAwesomeIcons.bowlRice,
  'oats': FontAwesomeIcons.wheatAwn,
  // Softs
  'cotton': FontAwesomeIcons.cloud,
  'sugar': FontAwesomeIcons.cubesStacked,
  'coffee': FontAwesomeIcons.mugHot,
  'cocoa': FontAwesomeIcons.candyCane,
  // Fertilizers
  'urea': FontAwesomeIcons.flask,
  'dap fertilizer': FontAwesomeIcons.vial,
  'potash': FontAwesomeIcons.mountain,
  'tsp fertilizer': FontAwesomeIcons.vials,

  'iron ore': FontAwesomeIcons.mountain,
  'coal': FontAwesomeIcons.fire,
  'palm oil': FontAwesomeIcons.droplet,
  'rubber': FontAwesomeIcons.circle,
  'zinc': FontAwesomeIcons.cubesStacked,
  'india 10y bond yield': FontAwesomeIcons.landmark,
  'us 10y treasury yield': FontAwesomeIcons.buildingColumns,
  'us 2y treasury yield': FontAwesomeIcons.scaleBalanced,
  'germany 10y bond yield': FontAwesomeIcons.landmark,
  'japan 10y bond yield': FontAwesomeIcons.landmark,
};

const Map<String, Color> _assetColorOverrides = {
  'nifty 50': Color(0xFF16498A),
  'sensex': Color(0xFF0F667A),
  'gift nifty': Color(0xFF7A4B12),
  'nifty 500': Color(0xFF2F4F93),
  'nifty bank': Color(0xFF2E516D),
  'nifty it': Color(0xFF1C5570),
  'nifty midcap 150': Color(0xFF475781),
  'nifty smallcap 250': Color(0xFF5D4A81),
  'nifty auto': Color(0xFF37556E),
  'nifty pharma': Color(0xFF2F6A5A),
  'nifty metal': Color(0xFF60656D),
  'nasdaq': Color(0xFF284B89),
  'nasdaq 100': Color(0xFF2A3F82),
  's&p500': Color(0xFF254B7B),
  'dow jones': Color(0xFF2E5A74),
  'cboe vix': Color(0xFF6A4B74),
  's&p 500 tech': Color(0xFF2D5480),
  's&p 500 financials': Color(0xFF445E7B),
  's&p 500 energy': Color(0xFF7A4F2A),
  'ftse 100': Color(0xFF335B78),
  'dax': Color(0xFF385472),
  'cac 40': Color(0xFF2E5A7F),
  'euro stoxx 50': Color(0xFF335F8A),
  'nikkei 225': Color(0xFF6E4455),
  'topix': Color(0xFF67496E),
  'usd/inr': Color(0xFF2E4D73),
  'eur/inr': Color(0xFF345A7A),
  'gbp/inr': Color(0xFF3A5679),
  'jpy/inr': Color(0xFF6F4E59),
  'aud/inr': Color(0xFF2A6276),
  'cad/inr': Color(0xFF3C566C),
  'chf/inr': Color(0xFF4A5967),
  'gold': Color(0xFF8A6A22),
  'silver': Color(0xFF6B7682),
  'platinum': Color(0xFF5B6676),
  'palladium': Color(0xFF5D717C),
  'copper': Color(0xFF8A4D2A),
  'crude oil': Color(0xFF3A281F),
  'brent crude': Color(0xFF4A3020),
  'natural gas': Color(0xFF1F4F63),
  'gasoline': Color(0xFF5A3828),
  'heating oil': Color(0xFF6A3A2A),
  'aluminum': Color(0xFF707882),
  // Agriculture
  'wheat': Color(0xFF6B7A2E),
  'corn': Color(0xFF7A8A2A),
  'soybeans': Color(0xFF5A6A28),
  'rice': Color(0xFF8A8A5A),
  'oats': Color(0xFF7A7A4A),
  // Softs
  'cotton': Color(0xFF8A8A8A),
  'sugar': Color(0xFF7A6A5A),
  'coffee': Color(0xFF4A3020),
  'cocoa': Color(0xFF3A2010),
  // Fertilizers
  'urea': Color(0xFF2A6A4A),
  'dap fertilizer': Color(0xFF3A5A6A),
  'potash': Color(0xFF6A4A3A),
  'tsp fertilizer': Color(0xFF4A5A4A),

  'iron ore': Color(0xFF8A4A2A),
  'coal': Color(0xFF3A3A3A),
  'palm oil': Color(0xFF6A7A2A),
  'rubber': Color(0xFF5A4A3A),
  'zinc': Color(0xFF6A7A8A),
  'india 10y bond yield': Color(0xFF3F546F),
  'us 10y treasury yield': Color(0xFF445872),
  'us 2y treasury yield': Color(0xFF4A5970),
  'germany 10y bond yield': Color(0xFF42566A),
  'japan 10y bond yield': Color(0xFF4F4F70),
};

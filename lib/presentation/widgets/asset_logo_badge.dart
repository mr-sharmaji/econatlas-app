import 'package:flutter/material.dart';

import '../../core/asset_logo_manifest.dart';
import '../../core/constants.dart';
import '../../core/square_badge_assets.dart';
import 'asset_badge_chip.dart';
import 'square_badge_svg.dart';

class AssetLogoResolver {
  const AssetLogoResolver._();

  static String normalizeAssetKey(String asset) {
    final normalized = asset.trim().toLowerCase();
    final safe = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return safe.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  }

  static AssetLogoMeta? forAsset(String asset) {
    return assetLogoManifest[normalizeAssetKey(asset)];
  }

  static String inferInstrumentType(String asset) {
    if (Entities.commodities.contains(asset)) return 'commodity';
    if (Entities.crypto.contains(asset)) return 'crypto';
    if (Entities.fx.contains(asset)) return 'currency';
    if (Entities.bonds.contains(asset)) return 'bond_yield';
    if (Entities.indicesIndia.contains(asset) ||
        Entities.indicesUS.contains(asset) ||
        Entities.indicesEurope.contains(asset) ||
        Entities.indicesJapan.contains(asset)) {
      return 'index';
    }
    return 'index';
  }

  static String? currencyLeadCode(String asset) {
    if (!asset.contains('/')) return null;
    final code = asset.split('/').first.trim().toUpperCase();
    return code.isEmpty ? null : code;
  }
}

class AssetLogoBadge extends StatelessWidget {
  final String asset;
  final String? instrumentType;
  final double size;
  final double borderRadius;

  const AssetLogoBadge({
    super.key,
    required this.asset,
    this.instrumentType,
    this.size = 20,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedType =
        (instrumentType == null || instrumentType!.trim().isEmpty)
            ? AssetLogoResolver.inferInstrumentType(asset)
            : instrumentType!.trim().toLowerCase();

    if (resolvedType == 'currency') {
      final lead = AssetLogoResolver.currencyLeadCode(asset);
      return SquareBadgeSvg(
        assetPath: SquareBadgeAssets.flagPathForCurrencyLead(lead),
        size: size,
        borderRadius: borderRadius,
      );
    }

    final logo = AssetLogoResolver.forAsset(asset);
    if (logo != null) {
      return SquareBadgeSvg(
        assetPath: logo.logoPath,
        size: size,
        borderRadius: borderRadius,
      );
    }

    final fallbackStyle = AssetBadgeResolver.forAsset(
      asset: asset,
      instrumentType: resolvedType,
    );
    return AssetBadgeChip(
      style: fallbackStyle,
      asset: asset,
      instrumentType: resolvedType,
      mode: AssetBadgeMode.asset,
      size: size,
      borderRadius: borderRadius,
    );
  }
}

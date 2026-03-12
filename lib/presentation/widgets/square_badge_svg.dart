import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SquareBadgeSvg extends StatelessWidget {
  final String assetPath;
  final double size;
  final double borderRadius;

  const SquareBadgeSvg({
    super.key,
    required this.assetPath,
    this.size = 20,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SvgPicture.asset(
          assetPath,
          fit: BoxFit.cover,
          width: size,
          height: size,
        ),
      ),
    );
  }
}

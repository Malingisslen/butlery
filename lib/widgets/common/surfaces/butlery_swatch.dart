// lib/widgets/common/surfaces/butlery_swatch.dart

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';

/// A small filled square that names a colour, such as a shopping category's.
/// Round things are [ButleryDisc]; this is the square counterpart.
class ButlerySwatch extends StatelessWidget {
  const ButlerySwatch({
    required this.color,
    this.size = AppDimensions.space24,
    super.key,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        ),
      ),
    );
  }
}

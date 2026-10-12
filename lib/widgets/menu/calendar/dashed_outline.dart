/// The dashed 1.5 dp outline of a free place that is waiting for a dish, with
/// the control radius (approved placement picture 78-menu-placement).
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';

class DashedOutline extends Decoration {
  const DashedOutline({required this.color});

  final Color color;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DashedOutlinePainter(color);
}

class _DashedOutlinePainter extends BoxPainter {
  _DashedOutlinePainter(this.color);

  final Color color;

  static const double _width = 1.5;
  static const double _dash = 4;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = (offset & size).deflate(_width / 2);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(AppDimensions.radiusControl),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), paint);
        distance += _dash + _gap;
      }
    }
  }
}

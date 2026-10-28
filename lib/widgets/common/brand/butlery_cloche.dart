// lib/widgets/common/brand/butlery_cloche.dart
//
// The cloche, painted from the locked drawing (the
// 160 x 160 mark): a dome on a plate, saffron knob. [ButleryCloche] draws it
// alone on the page background; [ButleryClocheMark] sets the same dome in
// cream on the green app-icon plate, as the onboarding screens do.
//
// [lift] opens the cloche: 0 is closed, 1 is raised and tilted off the plate
// with the food and its steam showing under it (the last onboarding screen).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/brand_colors.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart'
    show parseSvgPath;

final Path _plate = parseSvgPath('M28 113H132');
final Path _dome = parseSvgPath(
  'M40.5 104 C40.5 81.09 57.88 64.5 80 64.5 C102.12 64.5 119.5 81.09 119.5 104',
);
final Path _stem = parseSvgPath('M80 55V60');
final Path _foodLight = parseSvgPath(
  'M46 110 C46 97 57 90 66 90 C75 90 86 97 86 110 Z',
);
final Path _foodDark = parseSvgPath(
  'M80 110 C80 99 89 92 98 92 C107 92 116 99 116 110 Z',
);
final Path _steamLeft = parseSvgPath('M68 90 C64 82 72 78 68 70');
final Path _steamRight = parseSvgPath('M94 92 C90 84 98 80 94 72');
final RRect _knob = RRect.fromRectAndRadius(
  const Rect.fromLTWH(72, 48, 16, 8),
  const Radius.circular(4),
);

/// Where the cover, the food and the steam stand: the closed cloche is
/// [ButleryClochePose.closed], and the animated start screen walks it through
/// the poses in between.
@immutable
class ButleryClochePose {
  const ButleryClochePose({
    this.coverTurn = 0,
    this.coverDx = 0,
    this.coverDy = 0,
    this.coverOpacity = 1,
    this.foodOpacity = 0,
    this.steamOpacity = 0,
    this.steamRise = 0,
  });

  static const closed = ButleryClochePose();

  /// The cover raised and tilted off the plate with the food showing under it.
  static const lifted = ButleryClochePose(
    coverTurn: 22,
    coverDx: 3,
    coverDy: -42,
    foodOpacity: 1,
    steamOpacity: 0.5,
  );

  /// Between [closed] (0) and [lifted] (1).
  factory ButleryClochePose.lift(double t) {
    final k = t.clamp(0.0, 1.0);
    return ButleryClochePose(
      coverTurn: lifted.coverTurn * k,
      coverDx: lifted.coverDx * k,
      coverDy: lifted.coverDy * k,
      foodOpacity: Curves.easeIn.transform(k),
      steamOpacity: lifted.steamOpacity * Curves.easeIn.transform(k),
    );
  }

  /// Degrees, about the plate's left end.
  final double coverTurn;
  final double coverDx;
  final double coverDy;
  final double coverOpacity;
  final double foodOpacity;
  final double steamOpacity;

  /// How far the steam has risen, in drawing units.
  final double steamRise;

  @override
  bool operator ==(Object other) =>
      other is ButleryClochePose &&
      other.coverTurn == coverTurn &&
      other.coverDx == coverDx &&
      other.coverDy == coverDy &&
      other.coverOpacity == coverOpacity &&
      other.foodOpacity == foodOpacity &&
      other.steamOpacity == steamOpacity &&
      other.steamRise == steamRise;

  @override
  int get hashCode => Object.hash(
    coverTurn,
    coverDx,
    coverDy,
    coverOpacity,
    foodOpacity,
    steamOpacity,
    steamRise,
  );
}

/// The cloche on the page background: [color] is the dome and the plate.
class ButleryCloche extends StatelessWidget {
  const ButleryCloche({
    this.size = 96,
    this.lift = 0,
    this.pose,
    this.color,
    this.steamColor,
    super.key,
  });

  final double size;

  /// 0 closed, 1 raised with the food showing. Ignored when [pose] is given.
  final double lift;

  final ButleryClochePose? pose;

  /// Null takes the ink of the current theme.
  final Color? color;

  /// Null takes the theme's outline colour.
  final Color? steamColor;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? Theme.of(context).colorScheme.onSurface;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _ClochePainter(
          ink: ink,
          pose: pose ?? ButleryClochePose.lift(lift),
          steam: steamColor ?? Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

/// The app-icon plate: a rounded green square with the cream dome and the
/// saffron knob, the mark every onboarding screen opens with.
class ButleryClocheMark extends StatelessWidget {
  const ButleryClocheMark({this.size = 56, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final markInset = size * 0.14;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: BrandColors.markGround,
            borderRadius: BorderRadius.circular(size * 0.25),
          ),
          child: Padding(
            padding: EdgeInsets.all(markInset),
            child: CustomPaint(
              painter: _ClochePainter(
                ink: BrandColors.markInk,
                pose: ButleryClochePose.closed,
                steam: BrandColors.markInk,
                // The drawing crops to the cloche (viewBox 25 25 110 110).
                crop: const Rect.fromLTWH(25, 25, 110, 110),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClochePainter extends CustomPainter {
  _ClochePainter({
    required this.ink,
    required this.pose,
    required this.steam,
    this.crop = const Rect.fromLTWH(0, 0, 160, 160),
  });

  final Color ink;
  final ButleryClochePose pose;
  final Color steam;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / crop.width, size.height / crop.height);
    canvas.translate(-crop.left, -crop.top);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = ink;
    canvas.drawPath(_plate, stroke);

    if (pose.foodOpacity > 0) {
      canvas.drawPath(
        _foodLight,
        Paint()
          ..color = BrandColors.markAccent.withValues(alpha: pose.foodOpacity),
      );
      canvas.drawPath(
        _foodDark,
        Paint()
          ..color = AppColors.illustrationBrown.withValues(
            alpha: pose.foodOpacity,
          ),
      );
    }
    if (pose.steamOpacity > 0) {
      canvas.save();
      canvas.translate(0, -pose.steamRise);
      final steamPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = steam.withValues(alpha: pose.steamOpacity);
      canvas.drawPath(_steamLeft, steamPaint);
      canvas.drawPath(_steamRight, steamPaint);
      canvas.restore();
    }

    if (pose.coverOpacity > 0) {
      // The cover turns about the plate's left end as it rises.
      canvas.save();
      canvas.translate(43, 104);
      canvas.rotate(pose.coverTurn * math.pi / 180);
      canvas.translate(-43 + pose.coverDx, -104 + pose.coverDy);
      final a = pose.coverOpacity;
      canvas.drawPath(
        _dome,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.butt
          ..color = ink.withValues(alpha: a),
      );
      final saffron = BrandColors.markAccent.withValues(alpha: a);
      canvas.drawPath(
        _stem,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..color = saffron,
      );
      canvas.drawRRect(_knob, Paint()..color = saffron);
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ClochePainter old) =>
      old.ink != ink || old.pose != pose || old.steam != steam;
}

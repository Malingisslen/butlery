// lib/widgets/common/brand/start_splash.dart
//
// The start screen (Skarmar v12 del 1 #start): the cloche on the green, its
// cover lifting to show the food and closing again, the word mark, the line
// "Din butler i köket" and what the app is waiting for. The animation is
// slow and repeats; with reduced motion the cover stays off and the food
// stands.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/brand_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/brand/butlery_cloche.dart';
import 'package:butlery/widgets/common/brand/butlery_lockup.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

class StartSplash extends StatefulWidget {
  const StartSplash({this.message, super.key});

  /// What the app is waiting for; null says "Dukar upp ditt kök …".
  final String? message;

  /// The drawing's keyframes (5 s): the cover rests, rises and tilts away,
  /// is gone while the food steams, and comes back down.
  @visibleForTesting
  static ButleryClochePose poseAt(double t) {
    double between(double a, double b, double x) =>
        ((x - a) / (b - a)).clamp(0.0, 1.0);
    final rise = Curves.easeInOut.transform(between(0.14, 0.46, t));
    final away = between(0.46, 0.56, t);
    final back = between(0.86, 0.91, t);
    final settle = Curves.easeInOut.transform(between(0.91, 1.0, t));

    double turn;
    double dx;
    double dy;
    double coverOpacity;
    if (t < 0.46) {
      turn = 20 * rise;
      dx = -5 * rise;
      dy = -34 * rise;
      coverOpacity = 1;
    } else if (t < 0.86) {
      turn = 20 + 14 * away;
      dx = -5 - 7 * away;
      dy = -34 - 30 * away;
      coverOpacity = t < 0.56 ? 1 - away : 0;
    } else if (t < 0.91) {
      turn = 34 - 11 * back;
      dx = -12 + 4 * back;
      dy = -64 + 21 * back;
      coverOpacity = back;
    } else {
      turn = 23 * (1 - settle);
      dx = -8 * (1 - settle);
      dy = -43 * (1 - settle);
      coverOpacity = 1;
    }

    final food = t < 0.56
        ? 0.0
        : t < 0.6
        ? between(0.56, 0.6, t)
        : t <= 0.78
        ? 1.0
        : 1 - between(0.78, 0.86, t);
    final steamT = between(0.6, 0.78, t);
    final steam = t < 0.6 || t > 0.78
        ? 0.0
        : steamT < 0.45
        ? 0.5 * (steamT / 0.45)
        : 0.5 * (1 - (steamT - 0.45) / 0.55) + 0.0;
    return ButleryClochePose(
      coverTurn: turn,
      coverDx: dx,
      coverDy: dy,
      coverOpacity: coverOpacity,
      foodOpacity: food,
      steamOpacity: steam,
      steamRise: 15 * steamT,
    );
  }

  @override
  State<StartSplash> createState() => _StartSplashState();
}

class _StartSplashState extends State<StartSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    return ColoredBox(
      color: BrandColors.markGround,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (_, _) => ButleryCloche(
                        size: 150,
                        color: BrandColors.markInk,
                        steamColor: AppColors.neutralMedium,
                        pose: reduced
                            ? const ButleryClochePose(
                                coverOpacity: 0,
                                foodOpacity: 1,
                              )
                            : StartSplash.poseAt(_controller.value),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space24),
                    const ButleryWordmark(),
                    const SizedBox(height: AppDimensions.space8),
                    Text(
                      context.l10n.startSplashTagline.toUpperCase(),
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.rustLight,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 120,
              child: PlateLine(
                semanticLabel: widget.message ?? context.l10n.startSplashBusy,
              ),
            ),
            const SizedBox(height: AppDimensions.space12),
            Text(
              widget.message ?? context.l10n.startSplashBusy,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.neutralMedium,
              ),
            ),
            const SizedBox(height: AppDimensions.space32),
          ],
        ),
      ),
    );
  }
}

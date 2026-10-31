import 'package:flutter/material.dart';

import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/widgets/common/brand/butlery_cloche.dart';

/// The cloche that lifts its cover when [lifted] turns true, the one motion
/// every place that reveals something shares.
class ButleryClocheLift extends StatelessWidget {
  const ButleryClocheLift({
    required this.lifted,
    this.size = 112,
    this.onEnd,
    super.key,
  });

  final bool lifted;
  final double size;

  /// Called when the cover has reached the end of the animation.
  final VoidCallback? onEnd;

  static const Duration duration = Duration(milliseconds: 700);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: lifted ? 1 : 0),
      duration: AnimationUtils.getDuration(context, duration),
      curve: Curves.easeInOut,
      onEnd: onEnd,
      builder: (_, lift, _) => ButleryCloche(size: size, lift: lift),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Skelettkomponenter.
///
/// **Skelettet står stilla.** Beslut B-18 (låst 2026-07-25) stryker både
/// snurran och shimmern, och skälet gäller båda: rörelse ska inte simulera
/// framsteg som inte mäts. Ett svepande ljus över en tom ruta säger att något
/// händer just nu, vilket ingen vet. Rutan får därför en lugn yta, och
/// tallrikslinjen bär beskedet om att det pågår.
///
/// Skelett används bara där formen redan är känd — en lista som fylls på, ett
/// kort som får innehåll. Är formen okänd är ett skelett en gissning.
class SkeletonComponents {
  /// En stillastående skelettruta.
  static Widget skeletonBox({
    double? width,
    double? height,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? margin,
  }) {
    return _SkeletonBox(
      width: width,
      height: height,
      borderRadius: borderRadius,
      margin: margin,
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;

  const _SkeletonBox({
    this.width,
    this.height,
    this.borderRadius,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppDimensions.borderRadiusS),
        // En lugn yta, inte en gradient. Färgen är den upphöjda ytans, så
        // rutan läses som "här kommer något" och inte som innehåll.
        color: cs.surfaceContainerHighest,
      ),
    );
  }
}

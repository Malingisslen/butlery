// lib/widgets/common/indicators/loading_indicator.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/indicators/loading_semantics.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// Laddningsindikator med oförändrad publik yta som ritar tallrikslinjen.
///
/// Beslut B-18 (beslutslogg.md:25, låst): ingen spinner, ingen shimmer —
/// tallrikslinje + text. produktregler.md:163: "inga cirkulära
/// border-spinners". Den här klassen ritade tidigare en plattformsanpassad
/// cirkulär snurra; nu ritar den [PlateLine] centrerad i samma
/// `SizedBox(size × size)` som snurran fyllde. Radhöjden och den bundna
/// bredden på varje anropsställe är därmed desamma som förut — ett naket
/// `LoadingIndicator()` i en `Row` får fortfarande en bunden bredd.
///
/// Anropsställena flyttas till [PlateLine] direkt när vyerna tar in det nya
/// (paket 4); klassen står kvar till dess.
///
/// Semantiken (BUT-895, BUT-1173) är oförändrad ([LoadingSemantics]):
/// obestämd läser [semanticLabel] eller `a11yLoading` som live-region,
/// bestämd läser procentvärdet.
class LoadingIndicator extends StatelessWidget {
  /// Sidan på den kvadrat linjen ligger centrerad i. Linjen är lika bred.
  final double? size;

  /// Används inte. Tallrikslinjen har en fast tjocklek ([PlateLine.thickness]).
  final double? strokeWidth;

  final EdgeInsetsGeometry? padding;

  /// Används inte. Tallrikslinjen tar sina färger ur tokens
  /// `progressIndicator` och `progressTrack` (tokens.json:161-168), per läge.
  final Color? color;

  /// Skärmläsarens etikett. Null ger `a11yLoading`.
  final String? semanticLabel;

  /// Bestämd progress i `0.0..1.0`, annars null. (BUT-1173)
  final double? value;

  /// Används inte. Rännan är token `progressTrack` (tokens.json:161-164).
  final Color? backgroundColor;

  const LoadingIndicator({
    super.key,
    this.size,
    this.strokeWidth,
    this.padding,
    this.color,
    this.semanticLabel,
    this.value,
    this.backgroundColor,
  });

  /// Liten indikator för appfält och knappar.
  const LoadingIndicator.small({
    super.key,
    this.color,
    this.semanticLabel,
  }) : size = AppDimensions.iconSizeS,
       strokeWidth = 2,
       padding = const EdgeInsets.all(AppDimensions.spacingL),
       value = null,
       backgroundColor = null;

  @override
  Widget build(BuildContext context) {
    final indicatorSize = size ?? AppDimensions.iconSizeM;
    // Semantiken ligger ytterst, som förut, så att BUT-1173:s nod är
    // LoadingIndicators egen. Linjens egen semantik stängs av därunder så
    // att det finns en enda nod.
    final Widget indicator = LoadingSemantics(
      value: value,
      semanticLabel: semanticLabel,
      child: SizedBox(
        width: indicatorSize,
        height: indicatorSize,
        child: Center(
          child: ExcludeSemantics(
            child: PlateLine(value: value, width: indicatorSize),
          ),
        ),
      ),
    );

    if (padding != null) {
      return Padding(padding: padding!, child: indicator);
    }
    return indicator;
  }
}

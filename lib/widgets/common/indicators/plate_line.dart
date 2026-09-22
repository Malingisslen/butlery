// lib/widgets/common/indicators/plate_line.dart
//
// Tallrikslinjen — appens enda laddningsindikator.
//
// Beslut B-18 (låst 2026-07-25): **ingen spinner, ingen shimmer.** Skälet står
// i beslutet självt — rörelse ska inte simulera framsteg som inte mäts. En
// cirkulär snurra och en shimmer-svep påstår båda att något rör sig framåt
// utan att veta om det gör det. Tallrikslinjen är vad designsystemet sätter i
// stället: bestämd i accentorange på en lugn ränna, obestämd som ett
// segment som pulserar på plats.
//
// Linjen bär aldrig beskedet ensam. Regeln är "tallrikslinje + text": texten
// säger vad som hämtas, linjen säger bara att något pågår.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/indicators/loading_semantics.dart';

/// Tallrikslinjen: en vågrät progresslinje.
///
/// Två former, båda ritade i Komponentark v1:303-309:
///
/// * **Bestämd** ([value] satt): fylls vänster till höger i accentorange
///   (token progressIndicator) på rännan (token progressTrack). v1:305.
/// * **Obestämd** ([value] null): ett stillastående segment som pulserar i
///   opacitet på plats (v1:306 och :309, Grafisk manual v6:209). Det rör sig
///   aldrig i sidled, för rörelse ska inte simulera framsteg som inte mäts
///   (B-18, beslutslogg.md:25). Vid reducerad rörelse står det still i full
///   opacitet (v1:309, tillganglighetshandoff:179, Grafisk manual v6:589,
///   tokens.json motion.reducedMotion).
///
/// Har du ett verkligt mått, skicka det: en linje som visar riktig progress
/// är alltid bättre än en som bara säger att något pågår.
///
/// Linjen bär sin egen semantik ([LoadingSemantics]): en live-region med
/// [semanticLabel] som namn, eller procentvärdet när [value] är satt
/// (Butlery tillganglighetshandoff.dc.html:179 — etiketten ska vara vad som
/// laddas).
class PlateLine extends StatefulWidget {
  const PlateLine({
    this.value,
    this.width,
    this.semanticLabel,
    super.key,
  });

  /// 0–1 när arbetet går att mäta, annars null.
  final double? value;

  /// Bredd. Null fyller tillgängligt utrymme.
  final double? width;

  /// Vad som laddas, för skärmläsaren. Null ger `a11yLoading`.
  final String? semanticLabel;

  /// Linjens tjocklek: 4 px i båda formerna (Komponentark v1:305-306,
  /// `height:4px`).
  static const double thickness = 4.0;

  /// Det obestämda segmentets läge och bredd som andel av linjen, avläst ur
  /// ritningen (Komponentark v1:306: `left:22%`, `width:34%`).
  static const double segmentStart = 0.22;
  static const double segmentWidth = 0.34;

  /// Pulsens nedre opacitet. Ritningen anger inte värdet; tolkning, vald så
  /// att pulsen är lugn och inte drar uppmärksamhet (Grafisk manual v6:589).
  static const double pulseMinOpacity = 0.4;

  /// En halv puls (full opacitet till [pulseMinOpacity]). Ingen token finns
  /// för pulsen; tolkning.
  static const Duration pulseHalfCycle = Duration(milliseconds: 1200);

  /// Det obestämda segmentet. Nyckeln finns för prov, inte för identitet i
  /// appen.
  static const Key segmentKey = ValueKey<String>('plateLine.segment');

  /// Den obestämda formens ränna.
  static const Key trackKey = ValueKey<String>('plateLine.track');

  @override
  State<PlateLine> createState() => _PlateLineState();
}

class _PlateLineState extends State<PlateLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: PlateLine.pulseHalfCycle,
  );

  // Börjar i full opacitet, så att första bildrutan visar segmentet.
  // Easing: tokens.json motion.easing.standard, cubic-bezier(0.33,0,0.2,1).
  late final Animation<double> _opacity =
      Tween<double>(begin: 1.0, end: PlateLine.pulseMinOpacity).animate(
        CurvedAnimation(
          parent: _pulse,
          curve: const Cubic(0.33, 0, 0.2, 1),
        ),
      );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQueryData.disableAnimations (tokens.json motion.reducedMotion).
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncPulse();
  }

  @override
  void didUpdateWidget(PlateLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.value == null) != (widget.value == null)) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    final pulsera = widget.value == null && !_reduceMotion;
    if (pulsera) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      // Står still i slutläget: full opacitet.
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final morkt = Theme.of(context).brightness == Brightness.dark;
    // Rännan: token progressTrack. Ljust #E6EAD9, mörkt
    // rgba(245,244,237,0.18) (tokens.json semantic progressTrack).
    final ranna = morkt ? AppColorsDark.progressTrack : AppColors.progressTrack;

    final value = widget.value;
    final Widget bar;
    if (value != null) {
      // Bestämd: token progressIndicator, #CE7C1E i båda lägena
      // (tokens.json semantic progressIndicator).
      final linje = morkt
          ? AppColorsDark.progressIndicator
          : AppColors.progressIndicator;
      bar = ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusKnob),
        child: LinearProgressIndicator(
          value: value,
          minHeight: PlateLine.thickness,
          backgroundColor: ranna,
          valueColor: AlwaysStoppedAnimation<Color>(linje),
        ),
      );
    } else {
      // Obestämd: ritningens segment är #A9B2A0 (Komponentark v1:306). Token
      // surface.disabled bär det värdet i ljust; i mörkt tar vi samma tokens
      // mörka värde, #4A5C50. Tolkning: ritningen har ingen egen token för
      // segmentet.
      final segment = morkt
          ? AppColorsDark.surfaceDisabled
          : AppColors.surfaceDisabled;
      bar = SizedBox(
        height: PlateLine.thickness,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusKnob),
          child: ColoredBox(
            key: PlateLine.trackKey,
            color: ranna,
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  Positioned(
                    left: box.maxWidth * PlateLine.segmentStart,
                    width: box.maxWidth * PlateLine.segmentWidth,
                    top: 0,
                    bottom: 0,
                    child: FadeTransition(
                      opacity: _opacity,
                      child: DecoratedBox(
                        key: PlateLine.segmentKey,
                        decoration: BoxDecoration(
                          color: segment,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusKnob,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return LoadingSemantics(
      value: value,
      semanticLabel: widget.semanticLabel,
      child: widget.width == null
          ? bar
          : SizedBox(width: widget.width, child: bar),
    );
  }
}

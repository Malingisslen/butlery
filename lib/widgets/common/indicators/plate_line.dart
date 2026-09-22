// lib/widgets/common/indicators/plate_line.dart
//
// Tallrikslinjen — appens enda laddningsindikator.
//
// Beslut B-18 (låst 2026-07-25): **ingen spinner, ingen shimmer.** Skälet står
// i beslutet självt — rörelse ska inte simulera framsteg som inte mäts. En
// cirkulär snurra och en shimmer-svep påstår båda att något rör sig framåt
// utan att veta om det gör det. Tallrikslinjen är vad designsystemet sätter i
// stället, i accentorange på en lugn ränna.
//
// Linjen bär aldrig beskedet ensam. Regeln är "tallrikslinje + text": texten
// säger vad som hämtas, linjen säger bara att något pågår.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/indicators/loading_semantics.dart';

/// Tallrikslinjen: en vågrät progresslinje i accentorange.
///
/// [value] null ger obestämd progress — använd den när arbetet inte går att
/// mäta. Har du ett verkligt mått, skicka det: en linje som visar riktig
/// progress är alltid bättre än en som bara rör sig.
///
/// Linjen bär sin egen semantik ([LoadingSemantics]): en live-region med
/// [semanticLabel] som namn, eller procentvärdet när [value] är satt
/// (Butlery tillganglighetshandoff.dc.html:179 — etiketten ska vara vad som
/// laddas).
class PlateLine extends StatelessWidget {
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

  /// Linjens tjocklek. Samma i alla lägen — tallrikslinjen är en linje, inte
  /// en yta, och tjockleken bär ingen betydelse.
  static const double thickness = 3.0;

  @override
  Widget build(BuildContext context) {
    final morkt = Theme.of(context).brightness == Brightness.dark;
    final rand = morkt ? AppColorsDark.progressTrack : AppColors.progressTrack;
    final linje = morkt
        ? AppColorsDark.progressIndicator
        : AppColors.progressIndicator;

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusKnob),
      child: LinearProgressIndicator(
        value: value,
        minHeight: thickness,
        backgroundColor: rand,
        valueColor: AlwaysStoppedAnimation<Color>(linje),
      ),
    );

    return LoadingSemantics(
      value: value,
      semanticLabel: semanticLabel,
      child: width == null ? bar : SizedBox(width: width, child: bar),
    );
  }
}

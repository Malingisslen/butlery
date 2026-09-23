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
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/l10n/app_localizations.dart';
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

// PlateLine.segmentStart and segmentWidth as whole-percent flex factors.
const int _segmentStartFlex = 22;
const int _segmentWidthFlex = 34;
const int _segmentRestFlex = 100 - _segmentStartFlex - _segmentWidthFlex;

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
    final colors = context.butleryColors;
    // Rännan: token progressTrack. Ljust #E6EAD9, mörkt
    // rgba(245,244,237,0.18) (tokens.json semantic progressTrack).
    final ranna = colors.progressTrack;

    final value = widget.value;
    final Widget bar;
    if (value != null) {
      // Bestämd: token progressIndicator, #CE7C1E i båda lägena
      // (tokens.json semantic progressIndicator).
      final linje = colors.progressIndicator;
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
      final segment = colors.surfaceDisabled;
      bar = SizedBox(
        height: PlateLine.thickness,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusKnob),
          child: ColoredBox(
            key: PlateLine.trackKey,
            color: ranna,
            // Flex, not a LayoutBuilder: a dialog measures its content's
            // intrinsic width, which a LayoutBuilder cannot answer. 22 / 34 /
            // 44 is the drawn segment (Komponentark v1:306).
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: _segmentStartFlex),
                Expanded(
                  flex: _segmentWidthFlex,
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
                const Spacer(flex: _segmentRestFlex),
              ],
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

/// Tallrikslinjen i en knapp: en upptagen knapp behåller sin form och sitt
/// namn och får en linje längs sin nederkant (Komponentark v1:307, :365,
/// :372; Grafisk manual v6:423, "tallrikslinje i underkanten, aldrig
/// spinner").
///
/// Ritningen (Komponentark v1:307 och :372) är 4 px hög och ligger kant i kant
/// med knappens nederkant. Rännan är knappens förgrund med 18 % (`rgba(23,37,
/// 29,.18)` på saffran, tokens.json opacityLadder.onInk 0.18). Segmentet är
/// förgrunden själv, börjar i vänsterkanten och är 58 % brett. Linjen är
/// obestämd: den pulserar i opacitet på plats och står still vid reducerad
/// rörelse, som [PlateLine] (Komponentark v1:309).
///
/// Färgen är knappens egen textfärg. Ritningen visar bara saffranshjälten
/// (ink #17251D på saffran); att ink-primären och konturknappen får sin
/// egen förgrund på samma sätt är en tolkning av regeln "i knappens egen
/// textfärg".
///
/// Linjen bär ingen semantik. Knappen säger själv att den arbetar
/// ([BusyButtonSemantics]), så att beskedet inte läses två gånger.
class ButtonPlateLine extends StatefulWidget {
  const ButtonPlateLine({this.color, super.key});

  /// Förgrunden. Null läser knappens textfärg ur [DefaultTextStyle], som en
  /// knapps Material sätter till knappens förgrund.
  final Color? color;

  /// Segmentets bredd som andel av knappen (Komponentark v1:372, `width:58%`).
  static const double segmentWidth = 0.58;

  /// Rännans opacitet av förgrunden (Komponentark v1:372, `.18`; tokens.json
  /// opacityLadder.onInk).
  static const double trackAlpha = 0.18;

  /// Rännan. Nyckeln finns för prov.
  static const Key trackKey = ValueKey<String>('buttonPlateLine.track');

  /// Segmentet. Nyckeln finns för prov.
  static const Key segmentKey = ValueKey<String>('buttonPlateLine.segment');

  @override
  State<ButtonPlateLine> createState() => _ButtonPlateLineState();
}

class _ButtonPlateLineState extends State<ButtonPlateLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: PlateLine.pulseHalfCycle,
  );

  // Samma puls som den fristående linjen (tokens.json motion.easing.standard).
  late final Animation<double> _opacity =
      Tween<double>(begin: 1.0, end: PlateLine.pulseMinOpacity).animate(
        CurvedAnimation(parent: _pulse, curve: const Cubic(0.33, 0, 0.2, 1)),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _pulse
        ..stop()
        ..value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ??
        DefaultTextStyle.of(context).style.color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return ExcludeSemantics(
      child: SizedBox(
        height: PlateLine.thickness,
        width: double.infinity,
        child: ColoredBox(
          key: ButtonPlateLine.trackKey,
          color: color.withValues(alpha: ButtonPlateLine.trackAlpha),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: ButtonPlateLine.segmentWidth,
              heightFactor: 1,
              child: FadeTransition(
                opacity: _opacity,
                child: DecoratedBox(
                  key: ButtonPlateLine.segmentKey,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusKnob,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lägger [ButtonPlateLine] i en knapps bakgrundslager, så att linjen följer
/// knappens nederkant och klipps av knappens form.
///
/// [under] är det lager knappen redan har, i appen fokusringen ur
/// knapptemat (button_themes.dart). Det behålls och läggs utanpå, så att en
/// upptagen knapp aldrig tappar sin fokusring.
abstract final class PlateLineButton {
  /// [own] är knappens egen stil, [theme] temats stil för samma knapptyp.
  static ButtonStyle busyStyle(ButtonStyle? own, ButtonStyle? theme) {
    final under = own?.backgroundBuilder ?? theme?.backgroundBuilder;
    return (own ?? const ButtonStyle()).copyWith(
      backgroundBuilder: (context, states, child) {
        final layered = Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: ButtonPlateLine(),
            ),
          ],
        );
        return under == null ? layered : under(context, states, layered);
      },
    );
  }

  /// Gör ingenting. En upptagen knapp får inte vara avstängd, för då byter
  /// den till den avstängda ytan (Komponentark v1:365: laddning och disabled
  /// är två olika lägen). Den behåller sin tryckfunktion men gör inget.
  static void ignore() {}
}

/// En upptagen knapps semantik: en enda nod med knappens namn.
///
/// Etiketten är [busyLabel] när knappen säger vad den gör ("Sparar …",
/// content-style-guide.md:63), annars knappens eget namn [name]
/// (produktregler.md:902, "Låsningen behåller knappens namn"). Utan
/// [busyLabel] bär värdet att knappen arbetar (a11yLoading), så att läget
/// finns maskinläsbart (Komponentark v1:365, "levereras även som
/// maskinläsbart tillstånd"). Knappen är inte aktiverbar medan den arbetar.
class BusyButtonSemantics extends StatelessWidget {
  const BusyButtonSemantics({
    required this.busy,
    required this.name,
    required this.child,
    this.busyLabel,
    super.key,
  });

  /// Om knappen arbetar.
  final bool busy;

  /// Knappens eget namn.
  final String name;

  /// Vad knappen gör medan den arbetar, eller null.
  final String? busyLabel;

  /// Knappen.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!busy) return child;
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return Semantics(
      container: true,
      button: true,
      enabled: false,
      label: busyLabel ?? name,
      value: busyLabel == null ? l10n?.a11yLoading : null,
      child: ExcludeSemantics(child: AbsorbPointer(child: child)),
    );
  }
}

/// Tallrikslinjen med sin text: "tallrikslinje + text" (produktregler.md:163,
/// :304; B-18). Texten säger vad som hämtas, linjen bara att något pågår.
///
/// Texten står ovanför linjen och läses inte upp för sig: linjen bär den som
/// sin etikett, så att beskedet läses en gång. Linjen är högst [maxWidth]
/// bred, ritningens 300 px (Komponentark v1:304).
class PlateLineMessage extends StatelessWidget {
  const PlateLineMessage({
    required this.message,
    this.value,
    this.textAlign = TextAlign.center,
    super.key,
  });

  /// Vad som hämtas eller görs, till exempel "Hämtar din profil …".
  final String message;

  /// 0–1 när arbetet går att mäta, annars null.
  final double? value;

  /// Textens justering.
  final TextAlign textAlign;

  /// Ritningens bredd (Komponentark v1:304, `width:300px`).
  static const double maxWidth = 300;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Text(
              message,
              textAlign: textAlign,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          PlateLine(value: value, semanticLabel: message),
        ],
      ),
    );
  }
}

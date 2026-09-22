// lib/widgets/common/indicators/loading_semantics.dart
//
// Laddningens semantik, utlyft oförändrad ur LoadingIndicator (BUT-895,
// BUT-1173) så att tallrikslinjen kan bära den.
//
// Butlery tillganglighetshandoff.dc.html:179 — Tallrikslinje-progress:
// roll progressbar, etikett "= vad som laddas", tillstånd "värde eller
// obestämd".

import 'package:flutter/widgets.dart';
import 'package:butlery/l10n/app_localizations.dart';

/// Lägger laddningens semantik runt [child].
///
/// Bestämd ([value] satt): procentvärdet som live-region. [ExcludeSemantics]
/// stänger av barnets eget automatiska värde så att det finns en enda,
/// korrekt nod. Obestämd: etiketten ([semanticLabel], annars `a11yLoading`)
/// som live-region.
class LoadingSemantics extends StatelessWidget {
  const LoadingSemantics({
    required this.child,
    this.value,
    this.semanticLabel,
    super.key,
  });

  /// Indikatorn som semantiken beskriver.
  final Widget child;

  /// 0–1 när arbetet går att mäta, annars null.
  final double? value;

  /// Vad som laddas. Null ger `a11yLoading`.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // `Localizations.of<AppLocalizations>` i stället för den kastande
    // `AppLocalizations.of`, så att widgetprov utan delegates inte kraschar.
    // Reserven 'Loading' är den engelska a11yLoading-strängen.
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (value != null) {
      return Semantics(
        value: '${(value! * 100).round()}%',
        label: semanticLabel,
        liveRegion: true,
        child: ExcludeSemantics(child: child),
      );
    }
    return Semantics(
      label: semanticLabel ?? l10n?.a11yLoading ?? 'Loading',
      liveRegion: true,
      child: child,
    );
  }
}

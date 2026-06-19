import 'package:butlery/l10n/app_localizations.dart';

/// HOW a metric is explained to the operator — three localized accessors
/// (what it is / how it's calculated / why it matters). The info-dialog widget
/// (Phase 2) reads these. Held as l10n-key accessors, not raw strings, so the
/// prose stays in the ARB files (Swedish-first, English fallback) rather than
/// hardcoded in Dart.
class MetricExplanation {
  final String Function(AppLocalizations) whatIsIt;
  final String Function(AppLocalizations) howCalculated;
  final String Function(AppLocalizations) whyImportant;

  const MetricExplanation({
    required this.whatIsIt,
    required this.howCalculated,
    required this.whyImportant,
  });
}

import 'package:butlery/l10n/app_localizations.dart';

// Documents written before the label stopped being persisted still carry it,
// in the writer's language; matching every locale lets any reader treat those
// as unknown too.
final Set<String> _unknownLabels = _buildUnknownLabels();

Set<String> _buildUnknownLabels() {
  final labels = <String>{};
  for (final locale in AppLocalizations.supportedLocales) {
    final l10n = lookupAppLocalizations(locale);
    labels
      ..add(l10n.displayUnknownUser.trim().toLowerCase())
      ..add(l10n.shoppingUnknownUser.trim().toLowerCase());
  }
  return labels;
}

/// The stored name when it identifies somebody, else null (empty, blank, or
/// the "unknown user" label of any locale).
String? knownStoredName(String? stored) {
  final trimmed = stored?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (_unknownLabels.contains(trimmed.toLowerCase())) return null;
  return trimmed;
}

/// The stored name, or [fallback] resolved in the reader's own language.
String storedNameOr(String? stored, String fallback) =>
    knownStoredName(stored) ?? fallback;

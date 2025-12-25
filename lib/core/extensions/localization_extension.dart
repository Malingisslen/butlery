import 'package:flutter/widgets.dart';
import 'package:butlery/l10n/app_localizations.dart';

/// Extension to provide easy access to localized strings via BuildContext.
///
/// Usage:
/// ```dart
/// Text(context.l10n.commonSave)
/// Text(context.l10n.recipeFormatPortions(4))
/// ```
extension LocalizationExtension on BuildContext {
  /// Access the AppLocalizations instance for this context.
  AppLocalizations get l10n => AppLocalizations.of(this);
}

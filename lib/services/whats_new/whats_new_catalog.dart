import 'package:butlery/l10n/app_localizations.dart';

class WhatsNewItem {
  const WhatsNewItem({required this.title, required this.body, this.route});

  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) body;

  /// Named route opened when the item is tapped; null makes the item plain text.
  final String? route;
}

class WhatsNewRelease {
  const WhatsNewRelease({required this.version, required this.items});

  /// Display name as shown to the user, e.g. "1.4"; compared numerically.
  final String version;
  final List<WhatsNewItem> items;
}

/// Entries are added per release once the texts are approved.
const List<WhatsNewRelease> whatsNewReleases = [];

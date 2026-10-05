import 'package:butlery/core/constants/routes.dart';

/// `settings.arguments` for `Routes.smartImport` (BUT-2241). A plain String
/// argument still only prefills the field.
class SmartImportRouteArgs {
  const SmartImportRouteArgs(this.url, {this.autoStart = true});

  final String url;
  final bool autoStart;
}

/// Where a shared text lands, and with what.
typedef SharedImportRoute = ({String route, Object arguments});

final _link = RegExp(r'https?://[^\s<>"{}|\\^`\[\]]+');

// Sentence punctuation around a link in a caption ("(https://…).") is not
// part of it.
final _trailingPunctuation = RegExp(r'[.,;:!?)]+$');

/// The first http(s) link in [text], or null.
String? firstLinkIn(String text) =>
    _link.firstMatch(text)?.group(0)?.replaceFirst(_trailingPunctuation, '');

/// Any text without a link opens the text import with the text filled in.
/// Null for blank text.
SharedImportRoute? routeForSharedText(String text, {bool autoStart = true}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final link = firstLinkIn(trimmed);
  if (link != null) {
    return (
      route: Routes.smartImport,
      arguments: SmartImportRouteArgs(link, autoStart: autoStart),
    );
  }
  return (route: Routes.fromSocialMedia, arguments: trimmed);
}

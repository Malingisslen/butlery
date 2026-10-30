import 'package:butlery/core/constants/routes.dart';

/// `settings.arguments` for `Routes.smartImport` (BUT-2241). A plain String
/// argument still only prefills the field.
class SmartImportRouteArgs {
  const SmartImportRouteArgs(this.url, {this.autoStart = true});

  final String url;
  final bool autoStart;
}

/// `settings.arguments` for `Routes.fromSocialMedia` when a shared recipe text
/// carried a link: the text is the recipe, the link is where it came from.
class SharedTextImportArgs {
  const SharedTextImportArgs(this.text, {required this.sourceUrl});

  final String text;
  final String sourceUrl;
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

/// A link with a blurb around it ("Kolla in det här! https://…", a caption
/// with hashtags) starts Smart import on the link, which knows TikTok,
/// Instagram and YouTube. When the words around the link run to several lines
/// they are the recipe itself, so the text import opens with the link kept as
/// the source. Text without a link opens the text import too. Null for blank
/// text.
SharedImportRoute? routeForSharedText(String text, {bool autoStart = true}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final link = firstLinkIn(trimmed);
  if (link == null) return (route: Routes.fromSocialMedia, arguments: trimmed);
  if (_linesAround(trimmed) >= _recipeLines) {
    return (
      route: Routes.fromSocialMedia,
      arguments: SharedTextImportArgs(trimmed, sourceUrl: link),
    );
  }
  return (
    route: Routes.smartImport,
    arguments: SmartImportRouteArgs(link, autoStart: autoStart),
  );
}

// A title, an ingredient and a step. A share blurb or a caption, hashtags and
// all, is one or two lines.
const _recipeLines = 3;

int _linesAround(String text) => text
    .replaceAll(_link, ' ')
    .split('\n')
    .where((line) => line.trim().isNotEmpty)
    .length;

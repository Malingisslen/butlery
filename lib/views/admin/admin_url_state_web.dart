import 'package:web/web.dart' as web;

/// Reflect the selected admin tab into the URL (`?tab=<index>`) without
/// navigating, so the view is shareable/bookmarkable. Replaces (not pushes) so
/// the back button isn't cluttered with tab switches.
void writeTabParam(int index) {
  final uri = Uri.base.replace(queryParameters: {'tab': '$index'});
  web.window.history.replaceState(null, '', uri.toString());
}

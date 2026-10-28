/// Short links (`https://butlery.se/s/<code>`, BUT-2462) and the long link a
/// code stands for.
///
/// Any signed-in account can write a `deep_links` document with any
/// `longUrl`, so the long link is a stranger's input: only a link back to our
/// own share paths is followed.
library;

import 'package:butlery/services/deep_link_service.dart';

const _hosts = {'butlery.se', 'www.butlery.se'};

// `FirebaseDeepLinkRepository` mints eight alphanumerics.
final _code = RegExp(r'^[A-Za-z0-9]{8}$');

/// The code in a short link, or null when [uri] is not one.
String? shortCodeOf(Uri uri) {
  if (uri.scheme != 'https' || !_hosts.contains(uri.host)) return null;
  final segments = uri.pathSegments;
  if (segments.length != 2 || segments.first != 's') return null;
  return _code.hasMatch(segments.last) ? segments.last : null;
}

/// Whether a resolved long link may be routed: https on our own host, and not
/// another short link, so a code cannot point at itself.
bool isRoutableTarget(String longUrl) {
  final uri = Uri.tryParse(longUrl);
  if (uri == null) return false;
  if (uri.scheme != 'https' || !_hosts.contains(uri.host)) return false;
  return uri.pathSegments.firstOrNull != 's';
}

/// The long link behind short link [uri], or null when [uri] is not a short
/// link, the code is unknown, or the long link may not be routed.
Future<String?> resolveShortLink(
  Uri uri, {
  Future<String?> Function(String code) resolve =
      DeepLinkService.resolveShortUrl,
}) async {
  final code = shortCodeOf(uri);
  if (code == null) return null;
  final longUrl = await resolve(code);
  if (longUrl == null || !isRoutableTarget(longUrl)) return null;
  return longUrl;
}

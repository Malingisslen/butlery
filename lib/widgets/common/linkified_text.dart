/// BUT-962: small regex-based linkifier for user-generated text.
///
/// Detects HTTP/HTTPS URLs in [text] and renders them as tappable spans
/// styled per the host app (default: primary colour + underline). All
/// non-URL chunks stay plain. Tap → opens the OS browser via
/// `url_launcher` in external-application mode.
///
/// **No HTML, no markdown.** This is a defensive surface-only pass:
/// regex matches a conservative HTTP/HTTPS pattern and nothing else.
/// New characters / mention syntax / markdown won't be interpreted,
/// which keeps the rendering predictable for user input.
///
/// Usage:
/// ```dart
/// LinkifiedText.from(
///   comment.text,
///   style: AppTextStyles.bodyLarge,
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/external_link.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

class LinkifiedText {
  const LinkifiedText._();

  /// Matches http:// or https:// URLs followed by non-whitespace, ending
  /// before common trailing punctuation that's usually a sentence terminator
  /// rather than part of the URL (`.`, `,`, `;`, `:`, `!`, `?`, `)`, `]`).
  /// Tradeoff: misses URLs that legitimately end with one of those chars,
  /// but avoids false-including a trailing period that ends a sentence —
  /// the more common case in user-typed text.
  static final RegExp _urlRegex = RegExp(
    r'https?://[^\s<>"]+?(?=[.,;:!?)\]]?(?:\s|$))',
  );

  /// Build a [Text.rich] widget with the URL spans tappable. Pass the
  /// plain [text] and the base [style] you'd normally hand to `Text(...)`.
  /// [linkStyle] defaults to the theme primary colour + underline.
  static Widget from(
    String text, {
    TextStyle? style,
    TextStyle? linkStyle,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final effectiveLinkStyle =
            linkStyle ??
            (style ?? const TextStyle()).copyWith(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            );

        final matches = _urlRegex.allMatches(text).toList();
        if (matches.isEmpty) {
          // Fast path: nothing to linkify, return a plain Text so screen
          // readers don't see a TextSpan tree where they expected one
          // string. Cheaper layout too.
          return Text(text, style: style);
        }

        final spans = <InlineSpan>[];
        var cursor = 0;
        for (final match in matches) {
          if (match.start > cursor) {
            spans.add(TextSpan(text: text.substring(cursor, match.start)));
          }
          final url = match.group(0)!;
          // BUT-1446: render the link as a WidgetSpan wrapping a
          // Semantics(link:) node so screen readers announce it as a link
          // with a name. An inline TapGestureRecognizer TextSpan carries no
          // link role. (It is NOT invisible to `audit_unwrapped_tap_targets.dart`,
          // as this comment claimed until 2026-08-10 — that tool has matched
          // `TapGestureRecognizer(` since BUT-1426, which shipped before this
          // sentence was written.)
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Semantics(
                link: true,
                label: context.l10n.a11yLinkTo(url),
                child: GestureDetector(
                  onTap: () => _openUrl(url),
                  child: Text(url, style: effectiveLinkStyle),
                ),
              ),
            ),
          );
          cursor = match.end;
        }
        if (cursor < text.length) {
          spans.add(TextSpan(text: text.substring(cursor)));
        }

        return Text.rich(TextSpan(style: style, children: spans));
      },
    );
  }

  static Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // externalApplication hands off to the OS browser — safer for user-
    // posted links than an in-app WebView (no in-app credential context).
    //
    // BUT-1819: `openExternalLink` is DEFENCE IN DEPTH here, not a fix —
    // `_urlRegex` above already matches only `https?://`, so this can never
    // receive another scheme. Routed through the shared helper anyway so the
    // rule lives in one place and a future regex change cannot quietly widen
    // what this opens.
    //
    // The reroute is inert only because the helper's calls were DIFFED against
    // the line it replaced. A first version was not: the helper then also asked
    // `canLaunchUrl`, which the old line never did, and comment links stopped
    // opening. That pre-check is gone; what remains is `launchUrl` with the
    // same mode, behind a scheme check this site cannot fail.
    //
    // Wrapped because this is fire-and-forget from an `onTap`: `launchUrl` can
    // throw a `PlatformException` even after `canLaunchUrl` said yes, and an
    // unhandled async error from a tap handler is worse than a link that does
    // nothing. The sibling `launchSourceUrl` has always caught here.
    try {
      await openExternalLink(uri);
    } catch (_) {
      // Deliberately silent, and NOT because no context is reachable — the
      // `Builder`'s context is in scope at the tap site. `_openUrl` is static,
      // and a block of text can hold many links, so a snackbar per failed tap
      // would be noise. The single source link on a recipe is the opposite
      // case and does report; see `launchSourceUrl`.
    }
  }
}

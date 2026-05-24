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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
        final effectiveLinkStyle = linkStyle ??
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
          spans.add(
            TextSpan(
              text: url,
              style: effectiveLinkStyle,
              recognizer: TapGestureRecognizer()..onTap = () => _openUrl(url),
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
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

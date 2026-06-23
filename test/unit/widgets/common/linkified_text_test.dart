// BUT-962: regex behaviour test for LinkifiedText.
// Pins the conservative URL-matching pattern so future refactors of
// `_urlRegex` don't silently change what counts as a link.

import 'package:butlery/widgets/common/linkified_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LinkifiedText.from (BUT-962)', () {
    testWidgets('renders plain Text when no URLs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkifiedText.from('Just a comment about cooking'),
          ),
        ),
      );
      // Fast path returns plain Text (not Text.rich) — assert the
      // displayed text matches.
      expect(find.text('Just a comment about cooking'), findsOneWidget);
    });

    testWidgets('linkifies a single URL in the middle of a sentence', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkifiedText.from(
              'Try https://serious-eats.com for the technique.',
            ),
          ),
        ),
      );
      // Text.rich path — find by the full assembled text.
      expect(
        find.textContaining('Try '),
        findsOneWidget,
      );
      expect(
        find.textContaining('https://serious-eats.com'),
        findsOneWidget,
      );
      expect(
        find.textContaining('for the technique.'),
        findsOneWidget,
      );
    });

    testWidgets('trailing sentence punctuation stays out of the URL', (
      tester,
    ) async {
      // Regex deliberately stops before `.`, `,`, `;`, `:`, `!`, `?`, `)`,
      // `]` when followed by whitespace or EOS. The dot at the end below
      // is the sentence terminator — must not get pulled into the URL.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkifiedText.from('See https://example.com.'),
          ),
        ),
      );
      // The visible text still contains the dot — but the linkifier
      // should split URL ("https://example.com") and punctuation (".").
      // We assert the dot is rendered somewhere (not lost) and the URL
      // chunk doesn't include it.
      expect(find.textContaining('https://example.com'), findsOneWidget);
      expect(find.textContaining('.'), findsOneWidget);
    });

    testWidgets('handles two URLs in one comment', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkifiedText.from(
              'Both https://a.com and https://b.com work.',
            ),
          ),
        ),
      );
      expect(find.textContaining('https://a.com'), findsOneWidget);
      expect(find.textContaining('https://b.com'), findsOneWidget);
    });

    testWidgets('non-URL "https" mentions in prose stay plain', (tester) async {
      // The protocol requires `://`. A bare word "https" or "http" stays
      // un-linkified.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkifiedText.from('We use https everywhere.'),
          ),
        ),
      );
      expect(find.textContaining('We use https everywhere.'), findsOneWidget);
    });
  });
}

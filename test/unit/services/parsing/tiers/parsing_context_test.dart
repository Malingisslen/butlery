/// Direct unit tests for [ParsingContext] + [ParsedRecipePartial] (BUT-1149
/// coverage burndown — previously zero direct coverage).
///
/// Covers the context factories (fromUrl/fromText — source wiring, www-stripped
/// domain extraction, 16-char content hash, default normalizedUrl), the
/// isOcrSource/hasUrl/isSecure getters, the clock-driven elapsed timer (pinned
/// with withClock), and ParsedRecipePartial.shouldEnhance.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';

void main() {
  group('ParsingContext.fromUrl', () {
    test(
      'wires the url source, strips www from the domain, hashes content',
      () {
        final ctx = ParsingContext.fromUrl(
          url: 'https://www.ica.se/recept/kottbullar',
          htmlContent: '<html><body>recept</body></html>',
          userId: 'u1',
          parserVersion: '1.0',
        );
        expect(ctx.source, ImportSource.url);
        expect(ctx.domain, 'ica.se'); // www. stripped
        expect(ctx.hasUrl, isTrue);
        expect(ctx.normalizedUrl, 'https://www.ica.se/recept/kottbullar');
        expect(ctx.contentHash, hasLength(16));
        expect(ctx.isOcrSource, isFalse);
      },
    );
  });

  group('ParsingContext.fromText', () {
    test('text source: not OCR, no url, benign content is secure', () {
      final ctx = ParsingContext.fromText(
        text: 'Koka pasta. Servera med sås.',
        source: ImportSource.text,
        userId: 'u1',
        parserVersion: '1.0',
      );
      expect(ctx.source, ImportSource.text);
      expect(ctx.isOcrSource, isFalse);
      expect(ctx.hasUrl, isFalse);
      expect(ctx.isSecure, isTrue);
    });

    test('photo source is flagged as an OCR source', () {
      final ctx = ParsingContext.fromText(
        text: 'scanned recipe text',
        source: ImportSource.photo,
        userId: 'u1',
        parserVersion: '1.0',
      );
      expect(ctx.isOcrSource, isTrue);
    });
  });

  group('parseStructureCachedAsync — captureSubHeadings cache key', () {
    const grouped = '''
Kanelbullar

Ingredienser:
Deg:
5 dl vetemjöl
25 g jäst

Gör så här:
Baka.
''';

    test('the same text parsed ON then OFF on ONE context does NOT return a '
        'stale ON result — the flag is part of the cache key', () async {
      final ctx = ParsingContext.fromText(
        text: grouped,
        source: ImportSource.text,
        userId: 'u1',
        parserVersion: '1.0',
      );

      final on = await ctx.parseStructureCachedAsync(grouped);
      expect(
        on.ingredients,
        isNot(contains('Deg:')),
        reason: 'capture ON drops the heading line',
      );

      // Second call, SAME text, flag flipped. If the cache keyed on text only
      // it would hand back the ON structure (heading dropped) — the collision
      // this fix prevents.
      final off = await ctx.parseStructureCachedAsync(
        grouped,
        captureSubHeadings: false,
      );
      expect(
        off.ingredients,
        contains('Deg:'),
        reason: 'capture OFF must recompute and retain the heading line',
      );
    });
  });

  group('elapsed (clock-driven)', () {
    test('measures time since construction', () {
      final t0 = DateTime.utc(2026, 1, 1);
      late ParsingContext ctx;
      withClock(Clock.fixed(t0), () {
        ctx = ParsingContext.fromText(
          text: 'x',
          source: ImportSource.text,
          userId: 'u1',
          parserVersion: '1.0',
        );
      });
      withClock(Clock.fixed(t0.add(const Duration(seconds: 7))), () {
        expect(ctx.elapsed, const Duration(seconds: 7));
      });
    });
  });

  group('ParsedRecipePartial.shouldEnhance', () {
    test('true with few weak fields and at least one good field', () {
      const p = ParsedRecipePartial(
        goodFields: {'title': 'Pasta'},
        weakFields: ['portions', 'time'],
      );
      expect(p.shouldEnhance, isTrue);
    });

    test('false when there are more than two weak fields', () {
      const p = ParsedRecipePartial(
        goodFields: {'title': 'Pasta'},
        weakFields: ['a', 'b', 'c'],
      );
      expect(p.shouldEnhance, isFalse);
    });

    test('false when there are no good fields to keep', () {
      const p = ParsedRecipePartial(goodFields: {}, weakFields: ['a']);
      expect(p.shouldEnhance, isFalse);
    });
  });
}

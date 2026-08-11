/// BUT-1819: the predicate that decides whether a stored `sourceUrl` is drawn
/// as a link at all.
///
/// The cases are not hypothetical — every "text" string below is a real value
/// some writer in `lib/` puts in `sourceUrl`. They are here so that a future
/// change to `isSafeExternalUrl` has to confront the actual corpus of stored
/// values, not an idealised one.
library;

import 'package:butlery/core/utils/external_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSafeExternalUrl', () {
    test('accepts http and https with a host', () {
      expect(isSafeExternalUrl('https://ica.se/recept/pannkakor'), isTrue);
      expect(isSafeExternalUrl('http://example.com'), isTrue);
    });

    test('rejects the schemes HtmlSanitizer blocks', () {
      // The security case. Any of these stored before the repository
      // chokepoint landed is still in Firestore today.
      expect(isSafeExternalUrl('javascript:alert(1)'), isFalse);
      expect(isSafeExternalUrl('JavaScript:alert(1)'), isFalse);
      expect(isSafeExternalUrl('data:text/html,<script>x</script>'), isFalse);
      expect(isSafeExternalUrl('vbscript:msgbox'), isFalse);
    });

    test('rejects other schemes, including ones that would otherwise open', () {
      expect(isSafeExternalUrl('file:///etc/passwd'), isFalse);
      expect(isSafeExternalUrl('mailto:hej@example.com'), isFalse);
      expect(isSafeExternalUrl('ftp://example.com'), isFalse);
    });

    test('rejects the provenance sentences real writers store', () {
      // `Uri.parse` ACCEPTS these — it yields an empty scheme AND an empty
      // host — so they die on the SCHEME line, not the host line. (The same
      // sentence in `external_link.dart` credited the host check; run and
      // corrected 2026-08-10. The host line's own cases are in the next test.)
      expect(isSafeExternalUrl('Butlerys receptsamling'), isFalse);
      // The English string BUT-1819 replaced. Still stored on every account
      // seeded before it, so it stays covered.
      expect(isSafeExternalUrl('Butlery recipe collection'), isFalse);
      expect(isSafeExternalUrl('Från Butlerys arkiv'), isFalse);

      // These make `tryParse` return null — but NOT because of the colon.
      // `'Recept: 4 portioner'` parses fine with `scheme == 'recept'`. What
      // breaks these is the SPACE before the colon, an illegal scheme
      // character. `recipeCopiedFrom` produces exactly this shape.
      expect(isSafeExternalUrl('Kopierat från: Pannkakor'), isFalse);
      expect(isSafeExternalUrl('Importerat från: https://ica.se'), isFalse);
    });

    test('rejects a scheme with no host', () {
      // THE host line's reason for existing: these parse with a real http/https
      // scheme and an empty host, so a scheme-only predicate would wave them
      // through. Nothing else in this file reaches that line.
      expect(isSafeExternalUrl('https://'), isFalse);
      expect(isSafeExternalUrl('http:'), isFalse);
    });

    test('rejects null and empty', () {
      expect(isSafeExternalUrl(null), isFalse);
      expect(isSafeExternalUrl(''), isFalse);
    });
  });

  group('openExternalLink', () {
    test('refuses an unsafe scheme without touching the launcher', () async {
      // Returns false rather than throwing, and returns it BEFORE
      // the launcher at all — which is why this passes with no platform
      // channel bound. If the guard were removed this would reach url_launcher from a
      // plain `test()` with no widget binding and fail loudly; the exact
      // exception is not worth predicting here, only that it is loud.
      expect(await openExternalLink(Uri.parse('javascript:alert(1)')), isFalse);
      expect(await openExternalLink(Uri.parse('file:///tmp/x')), isFalse);
      // No `'Kopierat från: …'` case here on purpose: `Uri.parse` THROWS on it
      // (the colon starts an illegal scheme), so it cannot be constructed and
      // can never reach this function. That string is the render guard's
      // problem, and `isSafeExternalUrl` above covers it via `tryParse`.
      expect(await openExternalLink(Uri.parse('https://')), isFalse);
    });
  });
}

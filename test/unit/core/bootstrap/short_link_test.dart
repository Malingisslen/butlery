/// BUT-2462: a short link is only followed when it is ours, and what it
/// resolves to is a stranger's input (any signed-in account can write a
/// `deep_links` document), so it is only routed when it points back at our own
/// share paths.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/bootstrap/handlers/short_link.dart';

void main() {
  group('shortCodeOf', () {
    test('returns the code of an https butlery.se short link', () {
      expect(
        shortCodeOf(Uri.parse('https://butlery.se/s/Ab3dE5gH')),
        'Ab3dE5gH',
      );
    });

    test('accepts www.butlery.se', () {
      expect(
        shortCodeOf(Uri.parse('https://www.butlery.se/s/Ab3dE5gH')),
        'Ab3dE5gH',
      );
    });

    for (final code in ['Ab3dE5g', 'Ab3dE5gHj']) {
      test('rejects a code of ${code.length} characters', () {
        expect(shortCodeOf(Uri.parse('https://butlery.se/s/$code')), isNull);
      });
    }

    test('rejects a code with a non-alphanumeric character', () {
      expect(shortCodeOf(Uri.parse('https://butlery.se/s/Ab3dE5g-')), isNull);
      expect(shortCodeOf(Uri.parse('https://butlery.se/s/Ab3dE5g%2F')), isNull);
    });

    test('rejects other hosts, http and the custom scheme', () {
      for (final link in [
        'https://butlery.app/s/Ab3dE5gH',
        'https://evil.example/s/Ab3dE5gH',
        'http://butlery.se/s/Ab3dE5gH',
        'butlery://butlery.se/s/Ab3dE5gH',
      ]) {
        expect(shortCodeOf(Uri.parse(link)), isNull, reason: link);
      }
    });

    test('rejects a path that is not exactly /s/<code>', () {
      for (final link in [
        'https://butlery.se/s/Ab3dE5gH/extra',
        'https://butlery.se/s',
        'https://butlery.se/s/',
        'https://butlery.se/x/Ab3dE5gH',
        'https://butlery.se/recipe?id=Ab3dE5gH',
      ]) {
        expect(shortCodeOf(Uri.parse(link)), isNull, reason: link);
      }
    });
  });

  group('isRoutableTarget', () {
    test('accepts a share link on our own host', () {
      expect(
        isRoutableTarget('https://butlery.se/recipe?id=abc&timestamp=1'),
        isTrue,
      );
      expect(isRoutableTarget('https://www.butlery.se/menu?id=abc'), isTrue);
    });

    test('rejects an external host', () {
      expect(isRoutableTarget('https://evil.example/recipe?id=abc'), isFalse);
      expect(
        isRoutableTarget('https://butlery.se.evil.example/recipe?id=abc'),
        isFalse,
      );
    });

    test('rejects an old butlery.app target', () {
      expect(isRoutableTarget('https://butlery.app/recipe?id=abc'), isFalse);
    });

    test('rejects http and script schemes', () {
      expect(isRoutableTarget('http://butlery.se/recipe?id=abc'), isFalse);
      expect(isRoutableTarget('javascript:alert(1)'), isFalse);
      expect(isRoutableTarget('butlery://butlery.se/recipe?id=abc'), isFalse);
    });

    test('rejects another short link so a code cannot point at itself', () {
      expect(isRoutableTarget('https://butlery.se/s/Ab3dE5gH'), isFalse);
    });

    test('rejects text that is not a URL', () {
      expect(isRoutableTarget(''), isFalse);
      expect(isRoutableTarget('not a url'), isFalse);
    });
  });

  group('resolveShortLink', () {
    final shortLink = Uri.parse('https://butlery.se/s/Ab3dE5gH');

    test('returns the long link the resolver finds for the code', () async {
      String? asked;
      final result = await resolveShortLink(
        shortLink,
        resolve: (code) async {
          asked = code;
          return 'https://butlery.se/recipe?id=abc';
        },
      );

      expect(asked, 'Ab3dE5gH');
      expect(result, 'https://butlery.se/recipe?id=abc');
    });

    test('returns null for an unknown code', () async {
      expect(
        await resolveShortLink(shortLink, resolve: (_) async => null),
        isNull,
      );
    });

    test('returns null when the long link points outside butlery.se', () async {
      var asked = false;
      final result = await resolveShortLink(
        shortLink,
        resolve: (_) async {
          asked = true;
          return 'https://evil.example/phish';
        },
      );

      expect(asked, isTrue, reason: 'premise: the resolver did answer');
      expect(result, isNull);
    });

    test(
      'does not ask the resolver about a link that is not a short link',
      () async {
        var asked = false;
        final result = await resolveShortLink(
          Uri.parse('https://butlery.se/recipe?id=abc'),
          resolve: (_) async {
            asked = true;
            return 'https://butlery.se/recipe?id=abc';
          },
        );

        expect(result, isNull);
        expect(asked, isFalse);
      },
    );
  });
}

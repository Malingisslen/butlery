/// Unit tests for UrlNormalizer.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/cache/url_normalizer.dart';

void main() {
  final n = UrlNormalizer();

  group('normalize', () {
    test('returns null for empty / whitespace input', () {
      expect(n.normalize(''), isNull);
      expect(n.normalize('   '), isNull);
    });

    test('returns null for non-http(s) schemes', () {
      expect(n.normalize('ftp://example.com'), isNull);
      expect(n.normalize('file:///etc/hosts'), isNull);
      expect(n.normalize('javascript:alert(1)'), isNull);
    });

    test('returns null when host is empty', () {
      expect(n.normalize('http://'), isNull);
    });

    test('converts http to https for consistency', () {
      expect(n.normalize('http://example.com'), startsWith('https://'));
    });

    test('strips www. prefix and lowercases host', () {
      expect(n.normalize('https://WWW.Example.COM'), 'https://example.com');
    });

    test('strips tracking params (utm_*, fbclid, gclid, etc.)', () {
      final r = n.normalize(
        'https://example.com/r?id=42&utm_source=ig&fbclid=abc&gclid=xyz',
      );
      expect(r, 'https://example.com/r?id=42');
    });

    test('tracking-param stripping is case-insensitive on the key', () {
      expect(
        n.normalize('https://example.com/x?UTM_SOURCE=ig&keep=1'),
        'https://example.com/x?keep=1',
      );
    });

    test('sorts query parameters alphabetically by key', () {
      expect(
        n.normalize('https://example.com/x?b=2&a=1&c=3'),
        'https://example.com/x?a=1&b=2&c=3',
      );
    });

    test('removes trailing slash from non-root paths', () {
      expect(
        n.normalize('https://example.com/path/'),
        'https://example.com/path',
      );
      expect(
        n.normalize('https://example.com/a/b/'),
        'https://example.com/a/b',
      );
    });

    test('root-only path is preserved as "/" by Uri canonicalization', () {
      // The impl's path.length > 1 guard keeps the root /; Uri's
      // toString then emits the trailing slash for empty/root paths.
      expect(n.normalize('https://example.com/'), 'https://example.com/');
    });

    test('drops URL fragment', () {
      expect(
        n.normalize('https://example.com/x#section'),
        'https://example.com/x',
      );
    });

    test('all-tracking-params produces no query string', () {
      expect(
        n.normalize('https://example.com/x?utm_source=a&fbclid=b'),
        'https://example.com/x',
      );
    });

    test('idempotent: re-normalizing the output yields the same value', () {
      const url = 'http://WWW.Example.COM/path/?b=2&a=1&utm_source=x#frag';
      final once = n.normalize(url);
      final twice = n.normalize(once!);
      expect(twice, once);
    });
  });

  group('hash', () {
    test('SHA-256 hex output for valid URL', () {
      final h = n.hash('https://example.com');
      expect(h, isNotNull);
      expect(h, hasLength(64));
    });

    test('null for invalid URL', () {
      expect(n.hash('not a url'), isNull);
    });

    test('two equivalent URLs produce the same hash', () {
      expect(
        n.hash('https://www.example.com/x?utm_source=a&b=1'),
        n.hash('http://example.com/x?b=1'),
      );
    });

    test('different paths → different hashes', () {
      expect(
        n.hash('https://example.com/a'),
        isNot(n.hash('https://example.com/b')),
      );
    });
  });

  group('looksLikeUrl', () {
    test('explicit scheme matches', () {
      expect(n.looksLikeUrl('https://example.com'), isTrue);
      expect(n.looksLikeUrl('http://x.io'), isTrue);
    });

    test('domain-like patterns match', () {
      expect(n.looksLikeUrl('ica.se/recept/pasta'), isTrue);
      expect(n.looksLikeUrl('example.com'), isTrue);
    });

    test('plain text does not match', () {
      expect(n.looksLikeUrl('this is text'), isFalse);
      expect(n.looksLikeUrl('hello'), isFalse);
      expect(n.looksLikeUrl(''), isFalse);
    });

    test('trims whitespace before checking', () {
      expect(n.looksLikeUrl('  https://x.com  '), isTrue);
    });
  });

  group('extractDomain', () {
    test('strips www. and lowercases', () {
      expect(n.extractDomain('https://WWW.Example.COM/path'), 'example.com');
    });

    test('preserves subdomains other than www', () {
      expect(n.extractDomain('https://blog.example.com/x'), 'blog.example.com');
    });

    test('returns null for invalid URL', () {
      expect(n.extractDomain('  '), isNull);
      expect(n.extractDomain('http://'), isNull);
    });

    test('trims whitespace', () {
      expect(n.extractDomain('  https://example.com/x  '), 'example.com');
    });
  });
}

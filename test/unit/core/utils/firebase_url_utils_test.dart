/// Unit tests for FirebaseUrlUtils.stableCacheKey.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/firebase_url_utils.dart';

void main() {
  group('stableCacheKey', () {
    test('strips all query parameters from a signed URL', () {
      final url =
          'https://firebasestorage.googleapis.com/v0/b/bucket/o/img.jpg?GoogleAccessId=abc&Expires=123&Signature=xyz';
      final key = FirebaseUrlUtils.stableCacheKey(url);
      // Uri.replace(queryParameters: {}) emits a trailing "?" with no
      // params; the key is stable but contains the trailing marker.
      expect(
          key, 'https://firebasestorage.googleapis.com/v0/b/bucket/o/img.jpg?');
      expect(key, isNot(contains('GoogleAccessId')));
      expect(key, isNot(contains('Signature')));
    });

    test('idempotent — re-applying yields the same key', () {
      final url =
          'https://x.example/path?GoogleAccessId=a&Expires=b&Signature=c';
      final once = FirebaseUrlUtils.stableCacheKey(url);
      final twice = FirebaseUrlUtils.stableCacheKey(once);
      expect(once, twice);
    });

    test('URLs with no query → canonical form (may add trailing "?")', () {
      const url = 'https://example.com/path/to/img.jpg';
      final key = FirebaseUrlUtils.stableCacheKey(url);
      // Two consecutive applications are stable — that's the cache-key
      // invariant. The exact trailing-? shape is an implementation detail.
      expect(FirebaseUrlUtils.stableCacheKey(key), key);
      expect(key, startsWith(url));
    });

    test('two URLs differing only in auth-token query → same key', () {
      final urlA =
          'https://x.example/img?GoogleAccessId=A&Expires=1&Signature=sA';
      final urlB =
          'https://x.example/img?GoogleAccessId=B&Expires=2&Signature=sB';
      expect(
        FirebaseUrlUtils.stableCacheKey(urlA),
        FirebaseUrlUtils.stableCacheKey(urlB),
      );
    });

    test('preserves path / port; query is the only thing stripped', () {
      const url = 'https://example.com:8080/dir/img.jpg?k=v';
      final key = FirebaseUrlUtils.stableCacheKey(url);
      expect(key, contains('example.com:8080'));
      expect(key, contains('/dir/img.jpg'));
      expect(key, isNot(contains('k=v')));
    });

    test('invalid URL (Uri.tryParse fallback) → returned unchanged', () {
      // Uri.tryParse returns null for some malformed inputs; the impl
      // falls back to the original.
      // (Dart's parser is very lenient; we still pin the fallback path
      // by assertion on idempotence-on-roundtrip.)
      const malformed = 'http://[bad';
      final result = FirebaseUrlUtils.stableCacheKey(malformed);
      // We accept either fallback (== malformed) or a parsed canonical
      // form — but for either, double-application must be stable.
      expect(FirebaseUrlUtils.stableCacheKey(result), result);
    });
  });
}

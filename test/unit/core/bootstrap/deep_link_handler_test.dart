/// BUT-1411: the custom-scheme host guard dropped `butlery://import?url=...`
/// (web Share-Target import link) before it could reach the import branch,
/// silently breaking the primary import funnel. These tests pin the guard
/// predicate: recognised hosts (butlery.app, import) pass; unknown hosts are
/// blocked. The guard itself is the only thing that was preventing the
/// already-correct import branch from routing to Smart Import.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/bootstrap/handlers/deep_link_handler.dart';

void main() {
  group('DeepLinkHandler.isBlockedCustomSchemeHost (BUT-1411)', () {
    test('does NOT block the import share-target host (the fix)', () {
      final uri = Uri.parse(
        'butlery://import?url=https%3A%2F%2Frecipes.com%2Fx',
      );
      expect(DeepLinkHandler.isBlockedCustomSchemeHost(uri), isFalse);
      // Sanity: this really is host=import (the shape the share target builds).
      expect(uri.host, 'import');
    });

    test('does NOT block the canonical butlery.app host', () {
      final uri = Uri.parse('butlery://butlery.app/recipe?id=1');
      expect(DeepLinkHandler.isBlockedCustomSchemeHost(uri), isFalse);
    });

    test(
      'does NOT block a host-less custom link (path routing handles it)',
      () {
        final uri = Uri.parse('butlery:/import');
        expect(uri.host, isEmpty);
        expect(DeepLinkHandler.isBlockedCustomSchemeHost(uri), isFalse);
      },
    );

    test('BLOCKS an unrecognised butlery:// host', () {
      final uri = Uri.parse('butlery://evil.example.com/steal');
      expect(DeepLinkHandler.isBlockedCustomSchemeHost(uri), isTrue);
    });

    test('does NOT block non-butlery schemes (handled elsewhere)', () {
      final uri = Uri.parse('https://butlery.app/recipe?id=1');
      expect(DeepLinkHandler.isBlockedCustomSchemeHost(uri), isFalse);
    });
  });

  // BUT-1587: expiry is gated once at the processDeepLink dispatch point via
  // this predicate, covering recipe/menu/shopping links (extends BUT-1540's
  // recipe-only rule). These pin which links expire and the fail-open contract.
  group('DeepLinkHandler.isExpiredShareLink (BUT-1587)', () {
    // Production compares link age to clock.now() (deep_link_service.dart:478),
    // so drive time with a fixed clock instead of the real wall clock:
    // deterministic (no real-time-guard flakiness) and lets us pin the exact
    // 7-day boundary BUT-1540 fixed (> Duration(days: 7), not truncated days).
    final fixedNow = DateTime.utc(2026, 7, 11, 12);
    String tsAged(Duration age) =>
        fixedNow.subtract(age).millisecondsSinceEpoch.toString();
    R atFixedNow<R>(R Function() body) =>
        withClock(Clock.fixed(fixedNow), body);

    final staleTs = tsAged(const Duration(days: 8));

    for (final path in ['/recipe', '/menu', '/shopping']) {
      test('$path link older than 7 days is expired', () {
        final uri = Uri.parse(
          'https://butlery.app$path?id=x&timestamp=$staleTs',
        );
        expect(
          atFixedNow(() => DeepLinkHandler.isExpiredShareLink(uri)),
          isTrue,
        );
      });

      test('$path link with a fresh timestamp is not expired', () {
        final uri = Uri.parse(
          'https://butlery.app$path?id=x&timestamp=${tsAged(const Duration(hours: 1))}',
        );
        expect(
          atFixedNow(() => DeepLinkHandler.isExpiredShareLink(uri)),
          isFalse,
        );
      });
    }

    // Pin the exact boundary (protects BUT-1540's > Duration(days: 7)): a link
    // just past 7 days expires, one just under does not — a truncated-day
    // comparison would get one of these wrong.
    test('a link 1 minute past 7 days is expired', () {
      final uri = Uri.parse(
        'https://butlery.app/recipe?id=x'
        '&timestamp=${tsAged(const Duration(days: 7, minutes: 1))}',
      );
      expect(atFixedNow(() => DeepLinkHandler.isExpiredShareLink(uri)), isTrue);
    });

    test('a link 1 minute under 7 days is not expired', () {
      final uri = Uri.parse(
        'https://butlery.app/recipe?id=x'
        '&timestamp=${tsAged(const Duration(days: 7) - const Duration(minutes: 1))}',
      );
      expect(
        atFixedNow(() => DeepLinkHandler.isExpiredShareLink(uri)),
        isFalse,
      );
    });

    test('fails open when the timestamp is absent (legacy link)', () {
      final uri = Uri.parse('https://butlery.app/recipe?id=x');
      expect(
        atFixedNow(() => DeepLinkHandler.isExpiredShareLink(uri)),
        isFalse,
      );
    });

    test('fails open when the timestamp is non-numeric', () {
      final uri = Uri.parse('https://butlery.app/menu?id=x&timestamp=abc');
      expect(
        atFixedNow(() => DeepLinkHandler.isExpiredShareLink(uri)),
        isFalse,
      );
    });

    test('non-expiring paths (invite/profile) are never expired here', () {
      final invite = Uri.parse(
        'https://butlery.app/invite?id=x&timestamp=$staleTs',
      );
      final profile = Uri.parse('https://butlery.app/profile?id=x');
      expect(
        atFixedNow(() => DeepLinkHandler.isExpiredShareLink(invite)),
        isFalse,
      );
      expect(
        atFixedNow(() => DeepLinkHandler.isExpiredShareLink(profile)),
        isFalse,
      );
    });
  });
}

/// BUT-1411: the custom-scheme host guard dropped `butlery://import?url=...`
/// (web Share-Target import link) before it could reach the import branch,
/// silently breaking the primary import funnel. These tests pin the guard
/// predicate: recognised hosts (butlery.app, import) pass; unknown hosts are
/// blocked. The guard itself is the only thing that was preventing the
/// already-correct import branch from routing to Smart Import.
library;

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
}

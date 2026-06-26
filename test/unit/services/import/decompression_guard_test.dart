import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/decompression_guard.dart';

/// Proves the decompression-bomb caps that protect the `.xlsx` / `.paprikarecipes`
/// import paths (BUT-1370): an entry is rejected on its declared header size
/// BEFORE it inflates, again on its actual materialised size (a header that lies
/// low), and once the running archive total is exceeded.
void main() {
  group('DecompressionGuard', () {
    ArchiveFile entry(String name, int declaredSize, int contentLen) =>
        ArchiveFile(name, declaredSize, Uint8List(contentLen));

    test(
      'returns content and accumulates the running total for a normal entry',
      () {
        final guard = DecompressionGuard(
          maxEntryBytes: 1000,
          maxTotalBytes: 5000,
        );

        final out = guard.read(entry('a.xml', 100, 100));

        expect(out, hasLength(100));
        expect(guard.totalBytes, 100);
      },
    );

    test(
      'rejects an entry whose declared header size exceeds the per-entry cap '
      '— without inflating it',
      () {
        final guard = DecompressionGuard(
          maxEntryBytes: 1000,
          maxTotalBytes: 5000,
        );

        // Declares 2000 uncompressed bytes but holds only 1: the header claim
        // alone is enough to reject, so a real bomb never gets materialised.
        expect(
          () => guard.read(entry('bomb.xml', 2000, 1)),
          throwsA(isA<DecompressionBombException>()),
        );
        expect(guard.totalBytes, 0);
      },
    );

    test('rejects an entry that inflates past the cap despite a small declared '
        'size (lying header)', () {
      final guard = DecompressionGuard(
        maxEntryBytes: 1000,
        maxTotalBytes: 5000,
      );

      // Header understates the size (10) but the actual content is 2000 bytes —
      // the post-materialisation check catches it.
      expect(
        () => guard.read(entry('liar.xml', 10, 2000)),
        throwsA(isA<DecompressionBombException>()),
      );
    });

    test('rejects once the running total would exceed the archive cap', () {
      final guard = DecompressionGuard(
        maxEntryBytes: 1000,
        maxTotalBytes: 1500,
      );

      guard.read(entry('a', 900, 900));
      expect(guard.totalBytes, 900);

      // The second entry is fine on its own but blows the 1500 archive total.
      expect(
        () => guard.read(entry('b', 900, 900)),
        throwsA(isA<DecompressionBombException>()),
      );
    });

    test(
      'rejects on the declared-total pre-check before inflating (isolates the '
      'pre-materialisation total guard)',
      () {
        final guard = DecompressionGuard(
          maxEntryBytes: 1000,
          maxTotalBytes: 1500,
        );
        guard.read(entry('a', 900, 900));

        // 'b' declares 700 (within the per-entry cap) so 900+700=1600 > 1500
        // trips the declared-total branch. Its content is only 1 byte: if that
        // branch were removed, the actual total would reach just 901 and the
        // post-materialisation check would NOT fire — so this passes only while
        // the pre-inflation declared-total guard exists.
        expect(
          () => guard.read(entry('b', 700, 1)),
          throwsA(isA<DecompressionBombException>()),
        );
        expect(
          guard.totalBytes,
          900,
          reason: 'a rejected entry must not count toward the total',
        );
      },
    );

    test(
      'accept() validates an externally-decompressed blob (inner gzip output)',
      () {
        final guard = DecompressionGuard(
          maxEntryBytes: 1000,
          maxTotalBytes: 5000,
        );

        expect(
          () => guard.accept('recipe (gunzipped)', Uint8List(2000)),
          throwsA(isA<DecompressionBombException>()),
        );
      },
    );

    test('allows an entry sitting exactly on the caps', () {
      final guard = DecompressionGuard(
        maxEntryBytes: 1000,
        maxTotalBytes: 1000,
      );

      final out = guard.read(entry('edge', 1000, 1000));

      expect(out, hasLength(1000));
      expect(guard.totalBytes, 1000);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/search/search_result.dart';

void main() {
  group('SearchResult', () {
    test('default constructor sets all fields', () {
      const r = SearchResult<String>(
        hits: ['a', 'b'],
        totalHits: 12,
        page: 1,
        totalPages: 3,
        processingTimeMs: 42,
        queryId: 'q1',
      );
      expect(r.hits, ['a', 'b']);
      expect(r.totalHits, 12);
      expect(r.page, 1);
      expect(r.totalPages, 3);
      expect(r.processingTimeMs, 42);
      expect(r.queryId, 'q1');
    });

    test('map transforms hits and preserves metadata', () {
      const r = SearchResult<int>(
        hits: [1, 2, 3],
        totalHits: 99,
        page: 4,
        totalPages: 7,
        processingTimeMs: 8,
        queryId: 'qq',
      );

      final mapped = r.map<String>((v) => 'x$v');

      expect(mapped.hits, ['x1', 'x2', 'x3']);
      expect(mapped.totalHits, 99);
      expect(mapped.page, 4);
      expect(mapped.totalPages, 7);
      expect(mapped.processingTimeMs, 8);
      expect(mapped.queryId, 'qq');
    });

    test('default constructor leaves failed=false (BUT-1416)', () {
      const r = SearchResult<String>(
        hits: [],
        totalHits: 0,
        page: 0,
        totalPages: 0,
        processingTimeMs: 0,
      );
      // A legitimate empty success must not look like a failure.
      expect(r.failed, isFalse);
      expect(r.isEmpty, isTrue);
    });

    test('failure() builds an empty result flagged failed (BUT-1416)', () {
      const r = SearchResult<String>.failure(page: 2);
      expect(r.failed, isTrue);
      expect(r.hits, isEmpty);
      expect(r.totalHits, 0);
      expect(r.page, 2);
      expect(r.isEmpty, isTrue);
    });

    test('map propagates the failed flag (BUT-1416)', () {
      const failed = SearchResult<int>.failure();
      final mapped = failed.map<String>((v) => '$v');
      expect(mapped.failed, isTrue);

      const ok = SearchResult<int>(
        hits: [1],
        totalHits: 1,
        page: 0,
        totalPages: 1,
        processingTimeMs: 1,
      );
      expect(ok.map<String>((v) => '$v').failed, isFalse);
    });
  });
}

/// Tests for ChunkExtension. Pin the contract every Firestore whereIn /
/// batch-write call site depends on.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/extensions/iterable_extensions.dart';

void main() {
  group('Iterable.chunked', () {
    test('empty input yields no chunks', () {
      expect(<int>[].chunked(30), isEmpty);
    });

    test('input shorter than size yields a single chunk', () {
      expect(
          [1, 2, 3].chunked(30),
          equals([
            [1, 2, 3]
          ]));
    });

    test('input exactly at size boundary yields one full chunk', () {
      final input = List.generate(30, (i) => i);
      final chunks = input.chunked(30);
      expect(chunks.length, equals(1));
      expect(chunks.first, equals(input));
    });

    test('size + 1 yields two chunks (full + remainder)', () {
      final chunks = List.generate(31, (i) => i).chunked(30);
      expect(chunks, hasLength(2));
      expect(chunks[0], hasLength(30));
      expect(chunks[1], equals([30]));
    });

    test('35 items at size 30 yields 30 + 5 with no element loss', () {
      final input = List.generate(35, (i) => 'item-$i');
      final chunks = input.chunked(30);
      expect(chunks, hasLength(2));
      expect([...chunks[0], ...chunks[1]], equals(input));
    });

    test('exactly 2x size yields two equal chunks', () {
      final chunks = List.generate(60, (i) => i).chunked(30);
      expect(chunks, hasLength(2));
      expect(chunks[0], hasLength(30));
      expect(chunks[1], hasLength(30));
    });

    test('size = 1 yields one chunk per element', () {
      expect(
          [1, 2, 3].chunked(1),
          equals([
            [1],
            [2],
            [3]
          ]));
    });

    test('size <= 0 throws ArgumentError', () {
      expect(() => [1, 2, 3].chunked(0), throwsA(isA<ArgumentError>()));
      expect(() => [1, 2, 3].chunked(-1), throwsA(isA<ArgumentError>()));
    });

    test('works on non-List Iterable (Set)', () {
      // Set iteration order is insertion order in Dart; pin both batches.
      final chunks = {1, 2, 3, 4, 5}.chunked(2);
      expect(chunks, hasLength(3));
      expect(chunks[0], equals([1, 2]));
      expect(chunks[1], equals([3, 4]));
      expect(chunks[2], equals([5]));
    });
  });

  group('Firestore limit constants', () {
    test('kFirestoreWhereInLimit pins to 30', () {
      // Firestore raised this from 10 → 30 in mid-2023; any change is a
      // Firestore API surface migration, not a Butlery decision.
      expect(kFirestoreWhereInLimit, equals(30));
    });

    test('kFirestoreBatchOpLimit pins to 500', () {
      expect(kFirestoreBatchOpLimit, equals(500));
    });
  });
}

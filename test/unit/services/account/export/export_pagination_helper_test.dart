/// Direct unit tests for the export helpers (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Covers the two pure pieces that don't need a live Firestore: [sanitizeForJson]
/// (turns Firestore-native types into JSON-safe values for GDPR exports) and
/// ExportPaginationHelper.getLimitForType (per-content-type export caps). The
/// cursor-pagination methods (paginatedQuery etc.) drive real Query/get() calls
/// and are out of scope here — they belong in an emulator-backed test.
library;

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/account/export/export_pagination_helper.dart';

void main() {
  group('sanitizeForJson', () {
    test('passes primitives and null through unchanged', () {
      expect(sanitizeForJson(null), isNull);
      expect(sanitizeForJson('text'), 'text');
      expect(sanitizeForJson(42), 42);
      expect(sanitizeForJson(3.5), 3.5);
      expect(sanitizeForJson(true), true);
    });

    test('converts a UTC DateTime to an ISO-8601 string', () {
      expect(
        sanitizeForJson(DateTime.utc(2026, 1, 1)),
        '2026-01-01T00:00:00.000Z',
      );
    });

    test('converts a Timestamp to a string', () {
      final result = sanitizeForJson(Timestamp.fromDate(DateTime.utc(2026)));
      expect(result, isA<String>());
    });

    test('converts a GeoPoint to a lat/long map', () {
      expect(sanitizeForJson(const GeoPoint(59.3, 18.0)), {
        'latitude': 59.3,
        'longitude': 18.0,
      });
    });

    test('converts a DocumentReference to its path', () {
      final ref = FakeFirebaseFirestore().collection('recipes').doc('r1');
      expect(sanitizeForJson(ref), 'recipes/r1');
    });

    test('converts a Blob to a byte-count placeholder', () {
      final blob = Blob(Uint8List.fromList([1, 2, 3]));
      expect(sanitizeForJson(blob), '[binary data: 3 bytes]');
    });

    test('recurses into maps, stringifying keys and sanitizing values', () {
      final result = sanitizeForJson({
        1: 'one',
        'when': DateTime.utc(2026, 1, 2),
      });
      expect(result, {
        '1': 'one',
        'when': '2026-01-02T00:00:00.000Z',
      });
    });

    test('recurses into lists', () {
      final result = sanitizeForJson([1, DateTime.utc(2026, 1, 3), 'x']);
      expect(result, [1, '2026-01-03T00:00:00.000Z', 'x']);
    });
  });

  group('getLimitForType', () {
    test('returns the configured limit for a known type', () {
      expect(ExportPaginationHelper.getLimitForType('recipes'), 2000);
      expect(ExportPaginationHelper.getLimitForType('shopping_lists'), 500);
    });

    test('falls back to the default batch size for an unknown type', () {
      expect(
        ExportPaginationHelper.getLimitForType('not_a_type'),
        ExportPaginationHelper.defaultBatchSize,
      );
    });
  });
}

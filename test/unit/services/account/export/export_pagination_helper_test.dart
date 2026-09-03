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

    test('GDPR completeness (PR #211, criterion 15): a nested ingredient '
        'section survives the recipe export — no field allowlist drops it', () {
      // The recipe export dumps the whole document through sanitizeForJson;
      // there is no field allowlist, so structuredIngredients[].section is
      // included (Art. 15 completeness).
      final recipeData = {
        'title': 'Kanelbullar',
        'ingredients': ['5 dl vetemjöl', '75 g smör'],
        'structuredIngredients': [
          {'name': 'vetemjöl', 'raw': '5 dl vetemjöl', 'section': 'Deg'},
          {'name': 'smör', 'raw': '75 g smör', 'section': 'Fyllning'},
        ],
      };
      final exported = sanitizeForJson(recipeData) as Map<String, dynamic>;
      final structured = exported['structuredIngredients'] as List<dynamic>;
      expect((structured[0] as Map)['section'], 'Deg');
      expect((structured[1] as Map)['section'], 'Fyllning');
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

    // BUT-2003. The account-subcollection tests derive their expected cap from
    // `getLimitForType`, so both sides of every assertion there move together:
    // deleting one of these entries makes the type unknown, the cap silently
    // becomes `defaultBatchSize`, and every one of those tests stays green
    // while `onboarding` and `acquisition` widen from 50 to 500. The literal
    // has to be pinned somewhere, and this is the file that owns the map.
    test('the account-subcollection caps are declared, not fallen back to', () {
      expect(ExportPaginationHelper.getLimitForType('user_ingredients'), 500);
      expect(ExportPaginationHelper.getLimitForType('user_onboarding'), 50);
      expect(ExportPaginationHelper.getLimitForType('user_acquisition'), 50);
      expect(ExportPaginationHelper.getLimitForType('user_settings'), 50);
      // The two 50s would also pass if the entry were missing and the fallback
      // happened to be 50, so the fallback is asserted to be something else.
      expect(ExportPaginationHelper.defaultBatchSize, isNot(50));
    });
  });

  // BUT-1662: fetchCapped is the single primitive every GDPR export section
  // now routes its capped read through, so its boundary contract is asserted
  // here once rather than re-proved per section. The dangerous direction is a
  // clipped bundle that does NOT declare itself truncated — the user believes
  // the Art. 15 export is complete — so both sides of the flip point are
  // pinned, plus the trim of the probe row.
  group('fetchCapped (BUT-1662)', () {
    // 'personal_tag_groups' == 100: small enough to build fixtures for, and
    // derived (never hardcoded) so re-tuning the cap can't fail this suite.
    const type = 'personal_tag_groups';
    final cap = ExportPaginationHelper.getLimitForType(type);

    /// Records the requested size and echoes exactly [available] rows, so the
    /// test drives "how many rows the source holds" independently of what the
    /// helper asked for.
    ({Future<List<int>> Function(int) fetch, List<int> requested}) source(
      int available,
    ) {
      final requested = <int>[];
      return (
        fetch: (max) async {
          requested.add(max);
          return List<int>.generate(available, (i) => i);
        },
        requested: requested,
      );
    }

    test(
      'probes one past the cap so "exactly cap" stays distinguishable',
      () async {
        // If the helper asked for `cap`, a full source and a clipped source
        // both return `cap` rows and the truncation flag becomes a coin flip.
        expect(cap, greaterThan(0), reason: 'fixture premise');
        final s = source(0);
        await ExportPaginationHelper.fetchCapped<int>(
          type: type,
          fetch: s.fetch,
        );
        expect(s.requested, [cap + 1]);
      },
    );

    test('an unknown type probes one past the default batch size', () async {
      final s = source(0);
      await ExportPaginationHelper.fetchCapped<int>(
        type: 'not_a_type',
        fetch: s.fetch,
      );
      expect(s.requested, [ExportPaginationHelper.defaultBatchSize + 1]);
    });

    test('below the cap: every row kept, not truncated', () async {
      final result = await ExportPaginationHelper.fetchCapped<int>(
        type: type,
        fetch: source(3).fetch,
      );
      expect(result.items, hasLength(3));
      expect(result.length, 3);
      expect(result.truncated, isFalse);
    });

    test('exactly at the cap: complete, so NOT truncated', () async {
      // The flip point. `length >= cap` would stamp this complete export as
      // truncated — a false incompleteness claim on a GDPR bundle (BUT-1562).
      final result = await ExportPaginationHelper.fetchCapped<int>(
        type: type,
        fetch: source(cap).fetch,
      );
      expect(result.items, hasLength(cap));
      expect(result.truncated, isFalse);
    });

    test('one past the cap: truncated, and the probe row is trimmed', () async {
      final result = await ExportPaginationHelper.fetchCapped<int>(
        type: type,
        fetch: source(cap + 1).fetch,
      );
      expect(result.truncated, isTrue);
      expect(result.items, hasLength(cap));
      // The trimmed row is the last one — the retained rows are the leading
      // `cap`, which for ordered queries (e.g. notification_history's
      // sentAt-desc) means the most recent are what survive.
      expect(result.items.last, cap - 1);
    });

    test('propagates a source failure instead of reporting an empty '
        'complete export', () async {
      // A swallowed read error here would surface as `total_count: 0` with no
      // truncation flag — an export that looks complete and empty. The callers
      // own the try/catch that turns this into a section-level {'error': ...}.
      await expectLater(
        ExportPaginationHelper.fetchCapped<int>(
          type: type,
          fetch: (_) async => throw StateError('permission-denied'),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

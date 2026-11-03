library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/models/tagging/ingredient_column.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';

IngredientData _row({DateTime? updatedAt}) => IngredientData(
  id: 'milk',
  swedish: 'mjölk',
  english: 'milk',
  group: 'protein/dairy',
  properties: const {'dairy', 'animal-product'},
  // Source data with mixed separators: kept verbatim as the old value.
  aliasesSv: const ['standardmjölk', 'lättmjölk 0,5%', 'a;b'],
  seasonAvailability: const ['jan', 'feb'],
  priceCategory: 'standard',
  avgPriceSek: 12.5,
  updatedAt: updatedAt,
);

void main() {
  group('old value per column type', () {
    test(
      'text is empty string when absent, lists are lists, price numeric',
      () {
        final i = _row();
        expect(IngredientColumn.notesSv.oldValueOf(i), '');
        expect(IngredientColumn.carbonFootprintCategory.oldValueOf(i), '');
        expect(IngredientColumn.swedish.oldValueOf(i), 'mjölk');
        expect(IngredientColumn.properties.oldValueOf(i), [
          'animal-product',
          'dairy',
        ]);
        expect(IngredientColumn.aliasesSv.oldValueOf(i), [
          'standardmjölk',
          'lättmjölk 0,5%',
          'a;b',
        ]);
        expect(IngredientColumn.avgPriceSek.oldValueOf(i), 12.5);
        expect(
          IngredientColumn.avgPriceSek.oldValueOf(
            IngredientData(
              id: 'x',
              swedish: 'x',
              english: 'x',
              group: 'other',
              properties: const {},
            ),
          ),
          isNull,
        );
      },
    );

    test('every column maps to exactly one csv name', () {
      final names = IngredientColumn.values.map((c) => c.csvName).toSet();
      expect(names.length, 16);
      for (final c in IngredientColumn.values) {
        expect(IngredientColumn.fromCsvName(c.csvName), c);
      }
    });
  });

  group('valuesEqual', () {
    test('lists ignore order but not content or duplicates', () {
      const c = IngredientColumn.aliasesSv;
      expect(c.valuesEqual(['a', 'b'], ['b', 'a']), isTrue);
      expect(c.valuesEqual(['a', 'b'], ['a', 'c']), isFalse);
      expect(c.valuesEqual(['a', 'a', 'b'], ['a', 'b', 'b']), isFalse);
    });

    test('price compares numerically', () {
      const c = IngredientColumn.avgPriceSek;
      expect(c.valuesEqual(12, 12.0), isTrue);
      expect(c.valuesEqual(null, 0), isFalse);
    });

    test('text trims', () {
      expect(IngredientColumn.swedish.valuesEqual(' mjölk ', 'mjölk'), isTrue);
    });
  });

  group('toFirestore', () {
    test('creation key set is exactly the contract, with optionals', () {
      final request = IngredientChangeRequest(
        ingredientId: 'milk',
        ingredientUpdatedAt: DateTime.utc(2026, 10, 1),
        note: 'rätta',
        batchId: 'b1',
        createdBy: 'admin-1',
        changes: [
          IngredientFieldChange.from(_row(), IngredientColumn.status, 'draft'),
        ],
      );
      final data = request.toFirestore();
      expect(data.keys.toSet(), {
        'ingredientId',
        'changes',
        'ingredientUpdatedAt',
        'note',
        'batchId',
        'status',
        'createdBy',
        'createdAt',
      });
      expect(data['status'], 'pending');
      expect(data['createdAt'], isA<FieldValue>());
      expect(data['ingredientUpdatedAt'], isA<Timestamp>());
      expect(data['changes'], {
        'status': {'old': 'verified', 'new': 'draft'},
      });
    });

    test('optional keys are omitted, not written empty', () {
      final data = IngredientChangeRequest(
        ingredientId: 'milk',
        createdBy: 'a',
        changes: [
          IngredientFieldChange.from(_row(), IngredientColumn.english, 'Milk'),
        ],
      ).toFirestore();
      expect(data.keys.toSet(), {
        'ingredientId',
        'changes',
        'status',
        'createdBy',
        'createdAt',
      });
    });

    test('change maps carry both old and new even for null price', () {
      final c = IngredientFieldChange(
        column: IngredientColumn.avgPriceSek,
        oldValue: null,
        newValue: 9.0,
      );
      expect(c.toMap(), {'old': null, 'new': 9.0});
    });
  });

  group('fromFirestore', () {
    Future<IngredientChangeRequest> read(Map<String, dynamic> data) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('ingredient_change_requests').doc('r1').set(data);
      return IngredientChangeRequest.fromFirestore(
        await fs.collection('ingredient_change_requests').doc('r1').get(),
      );
    }

    test('reads every status and the later server-set fields', () async {
      for (final s in IngredientChangeStatus.values) {
        final r = await read({
          'ingredientId': 'milk',
          'changes': {
            'status': {'old': 'draft', 'new': 'verified'},
          },
          'status': s.wireName,
          'createdBy': 'u',
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1)),
          'withdrawnAt': Timestamp.fromDate(DateTime.utc(2026, 11, 2)),
          'withdrawnBy': 'u2',
          'expireAt': Timestamp.fromDate(DateTime.utc(2027, 11, 2)),
        });
        expect(r.status, s);
        expect(r.withdrawnBy, 'u2');
        expect(r.expireAt!.toUtc(), DateTime.utc(2027, 11, 2));
        expect(r.createdAt!.toUtc(), DateTime.utc(2026, 11, 1));
      }
    });

    test('reads typed changes, tolerates missing optionals and junk', () async {
      final r = await read({
        'ingredientId': 'milk',
        'changes': {
          'avg_price_sek': {'old': null, 'new': 3},
          'aliases_sv': {
            'old': ['a;b'],
            'new': ['a', 'b'],
          },
          'notes_sv': {'old': '', 'new': 'x'},
          'not_a_column': {'old': 1, 'new': 2},
        },
        'status': 'something-new',
      });
      expect(r.status, IngredientChangeStatus.pending);
      expect(r.note, '');
      expect(r.batchId, isNull);
      expect(r.createdAt, isNull);
      expect(r.changes.map((c) => c.column), [
        IngredientColumn.aliasesSv,
        IngredientColumn.notesSv,
        IngredientColumn.avgPriceSek,
      ]);
      expect(r.changeFor(IngredientColumn.avgPriceSek)!.newValue, 3.0);
      expect(r.changeFor(IngredientColumn.aliasesSv)!.oldValue, ['a;b']);
    });

    test(
      'reads prNumber, reason, csvValue and kind; absent kind is an ingredient',
      () async {
        final plain = await read({
          'ingredientId': 'milk',
          'changes': {
            'status': {'old': 'draft', 'new': 'verified'},
          },
          'status': 'pending',
        });
        expect(plain.kind, IngredientChangeRequest.kIngredientKind);
        expect(plain.prNumber, isNull);
        expect(plain.reason, isNull);
        expect(plain.csvValue, isNull);

        final conflict = await read({
          'ingredientId': 'milk',
          'changes': {
            'status': {'old': 'draft', 'new': 'verified'},
          },
          'status': 'conflict',
          'reason': 'csv-mismatch',
          'csvValue': {'status': 'review'},
          'prNumber': 12,
          'kind': 'occasionList',
        });
        expect(conflict.status, IngredientChangeStatus.conflict);
        expect(conflict.reason, 'csv-mismatch');
        expect(conflict.csvValue, {'status': 'review'});
        expect(conflict.prNumber, 12);
        expect(conflict.kind, 'occasionList');

        final inReview = await read({
          'ingredientId': 'milk',
          'changes': <String, dynamic>{},
          'status': 'inReview',
          'prNumber': 7,
        });
        expect(inReview.status, IngredientChangeStatus.inReview);
        expect(IngredientChangeStatus.inReview.wireName, 'inReview');
      },
    );

    test('withIdentity keeps the server-written fields', () async {
      final r = (await read({
        'ingredientId': 'milk',
        'changes': <String, dynamic>{},
        'status': 'inReview',
        'prNumber': 7,
        'reason': 'x',
        'csvValue': {'a': 1},
      })).withIdentity(id: 'n', createdBy: 'u');
      expect(r.prNumber, 7);
      expect(r.reason, 'x');
      expect(r.csvValue, {'a': 1});
    });

    test('affectsAllergens follows the property change', () async {
      final r = await read({
        'ingredientId': 'milk',
        'changes': {
          'properties': {
            'old': ['dairy', 'animal-product'],
            'new': ['animal-product'],
          },
        },
        'status': 'pending',
      });
      expect(r.affectsAllergens, isTrue);
    });
  });
}

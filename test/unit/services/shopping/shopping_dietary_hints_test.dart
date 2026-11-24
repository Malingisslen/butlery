import 'dart:convert';
import 'dart:io';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/firebase/firebase_ingredient_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/shopping/shopping_dietary_hints.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/viewmodels/shopping/shopping_dietary_hints_controller.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

const _free = ShoppingDietaryHintKind.chooseFreeVariant;
const _check = ShoppingDietaryHintKind.checkContents;

List<ShoppingDietaryHint> _hints(
  String name,
  Set<String>? props,
  Set<String> choices,
) => ShoppingDietaryHints.forItem(
  itemName: name,
  properties: props,
  householdChoices: choices,
);

ShoppingDietaryHint _h(String key, ShoppingDietaryHintKind kind) =>
    ShoppingDietaryHint(choiceKey: key, kind: kind);

void main() {
  group('ShoppingDietaryHints.forItem', () {
    test('a lactose-free household gets a free-variant box on butter', () {
      expect(
        _hints('Smör', {'contains-lactose', 'dairy'}, {'laktos'}),
        [_h('laktos', _free)],
      );
    });

    test('an item the ingredient data does not know gets no box', () {
      expect(_hints('Konstig vara', null, {'laktos', 'gluten'}), isEmpty);
    });

    test('a known item without the property gets no box', () {
      expect(_hints('Ris', {'plant-based'}, {'laktos', 'gluten'}), isEmpty);
    });

    test('no household choices means no box', () {
      expect(_hints('Smör', {'contains-lactose'}, const {}), isEmpty);
    });

    test('"laktosfri" in the name silences lactose, per choice', () {
      expect(
        _hints('Mjölk laktosfri', {'contains-lactose', 'dairy'}, {'laktos'}),
        isEmpty,
      );
      // "glutenfri" says nothing about lactose.
      expect(
        _hints(
          'Glutenfri pannkaksmix',
          {'contains-lactose', 'contains-gluten'},
          {'laktos', 'gluten'},
        ),
        [_h('laktos', _free)],
      );
    });

    test('milk allergy is not lactose: lactose-free milk still warns', () {
      expect(
        _hints('Laktosfri mjölk', {'dairy'}, {'mjölk', 'laktos'}),
        [_h('mjölk', _check)],
      );
    });

    test('milk outranks lactose so nobody is pointed at lactose-free', () {
      expect(
        _hints('Smör', {'contains-lactose', 'dairy'}, {'mjölk', 'laktos'}),
        [_h('mjölk', _check)],
      );
    });

    test('allergies without a free variant say "check the contents"', () {
      expect(_hints('Jordnötssmör', {'peanut'}, {'nötter'}), [
        _h('nötter', _check),
      ]);
      expect(_hints('Lax', {'fish', 'seafood'}, {'fisk'}), [
        _h('fisk', _check),
      ]);
    });

    test('a narrower hit replaces the combined one on the same item', () {
      expect(
        _hints('Jordnötter', {'peanut'}, {'nötter', 'jordnötter'}),
        [_h('jordnötter', _check)],
      );
    });

    test('lifestyle choices never get a box', () {
      expect(
        _hints('Fläskfilé', {'meat', 'pork'}, {'kött', 'fläsk', 'nötkött'}),
        isEmpty,
      );
    });

    test('gluten gets the free-variant box on pasta and oats', () {
      expect(_hints('Pasta', {'contains-gluten'}, {'gluten'}), [
        _h('gluten', _free),
      ]);
      expect(
        _hints('Glutenfri pasta', {'contains-gluten'}, {'gluten'}),
        isEmpty,
      );
    });
  });

  // The real lookup path (compound variations, brand strip) over the
  // committed snapshot of the global ingredient data: a box on oat drink
  // would hit exactly the households this exists for.
  group('through the real ingredient lookup', () {
    late IngredientLookupService lookup;

    setUpAll(() async {
      lookup = await _snapshotLookup();
    });

    Future<Map<String, List<ShoppingDietaryHint>>> run(
      List<String> names,
      Set<String> choices,
    ) async {
      final properties = await ShoppingDietaryHintsController.lookupProperties(
        lookup,
        names,
      );
      return {
        for (var i = 0; i < names.length; i++)
          names[i]: _hints(names[i], properties[i], choices),
      };
    }

    test('a line the data only partly knows gets no box', () async {
      // Premise: the lookup does find shrimp in the line, it just does not
      // call the whole line known.
      const name = 'Räkor och qwzx';
      final line = (await lookup.lookupFromRaw([name])).lines.single;
      expect(line.known, isFalse);
      expect(
        line.ingredients.expand((d) => d.properties),
        contains('crustacean'),
      );

      final out = await run([name], {'skaldjur'});
      expect(out[name], isEmpty);
    });

    test('no lookup service means no properties for any name', () async {
      expect(
        await ShoppingDietaryHintsController.lookupProperties(null, [
          'Smör',
          'Pasta',
        ]),
        [null, null],
      );
    });

    test(
      'the mockup household (lactose, gluten) gets the mockup boxes',
      () async {
        final out = await run(
          [
            'Crème fraiche',
            'Mjölk laktosfri',
            'Smör',
            'Pasta',
            'Ris',
            'Havregryn',
          ],
          {'laktos', 'gluten'},
        );
        expect(out, {
          'Crème fraiche': [_h('laktos', _free)],
          'Mjölk laktosfri': isEmpty,
          'Smör': [_h('laktos', _free)],
          'Pasta': [_h('gluten', _free)],
          'Ris': isEmpty,
          'Havregryn': [_h('gluten', _free)],
        });
      },
    );

    test('plant drinks and look-alikes get no lactose box', () async {
      final out = await run(
        [
          'Havredryck',
          'Kokosmjölk',
          'Mandelmjölk',
          'Sojadryck',
          'Kokosgrädde',
          'Margarin',
          'Vegansk ost',
          'Smörgåsgurka',
        ],
        {'laktos'},
      );
      for (final entry in out.entries) {
        expect(entry.value, isEmpty, reason: entry.key);
      }
    });

    test(
      'brands, compounds and milk protein resolve as a shopper expects',
      () async {
        final out = await run(
          [
            'Arla mellanmjölk 1,5%',
            'Laktosfri grädde',
            'Mjölkchoklad',
            'Mandelmjölk',
            'Jordnötssmör',
            'Glutenfri pasta',
          ],
          {'mjölk', 'nötter', 'gluten'},
        );
        expect(out, {
          'Arla mellanmjölk 1,5%': [_h('mjölk', _check)],
          'Laktosfri grädde': [_h('mjölk', _check)],
          'Mjölkchoklad': [_h('mjölk', _check)],
          'Mandelmjölk': [_h('nötter', _check)],
          'Jordnötssmör': [_h('nötter', _check)],
          'Glutenfri pasta': isEmpty,
        });
      },
    );
  });
}

Future<IngredientLookupService> _snapshotLookup() async {
  final raw =
      jsonDecode(
            File(
              'scripts/crf/data/firebase_ingredients.json',
            ).readAsStringSync(),
          )
          as List;
  final firestore = FakeFirebaseFirestore();
  for (final record in raw.whereType<Map>()) {
    final map = record.cast<String, dynamic>();
    final id = map['id']?.toString();
    if (id == null || id.isEmpty) continue;
    await firestore
        .collection(FirestoreCollections.ingredients)
        .doc(id)
        .set(map);
  }
  final repo = FirebaseIngredientRepository(firestore: firestore);
  await repo.initialize();
  return IngredientLookupService(
    ingredientRepository: repo,
    userIngredientRepository: _NoUserIngredients(),
  );
}

class _NoUserIngredients implements UserIngredientRepository {
  @override
  Future<IngredientData?> findByName(String userId, String name) async => null;
  @override
  Future<IngredientData?> getById(String userId, String ingredientId) async =>
      null;
  @override
  Future<List<IngredientData>> getAll(String userId) async => const [];
  @override
  Future<IngredientData> create(
    String userId,
    IngredientData ingredient,
  ) async => ingredient;
  @override
  Future<void> update(String userId, IngredientData ingredient) async {}
  @override
  Future<void> delete(String userId, String ingredientId) async {}
  @override
  Stream<List<IngredientData>> watchAll(String userId) =>
      Stream.value(const []);
}

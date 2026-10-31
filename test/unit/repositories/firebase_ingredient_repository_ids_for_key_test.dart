/// Intent: `idsForKey` reports EVERY ingredient that owns a name or alias
/// key, so the id resolver can refuse an ambiguous name ("bringa" is beef and
/// lamb) that `findByAlias` would silently resolve to whichever doc loaded
/// last.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_ingredient_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirebaseIngredientRepository repo;

  Future<void> seed(
    String id, {
    required String swedish,
    List<String> aliasesSv = const [],
  }) async {
    await firestore.collection(FirestoreCollections.ingredients).doc(id).set({
      'id': id,
      'swedish': swedish,
      'english': id,
      'group': 'protein/meat',
      'properties': <String>[],
      'aliasesSv': aliasesSv,
      'aliasesEn': <String>[],
    });
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await seed('beef-brisket', swedish: 'Oxbringa', aliasesSv: ['bringa']);
    await seed('lamb-brisket', swedish: 'Lammbringa', aliasesSv: ['bringa']);
    await seed('onion', swedish: 'Lök', aliasesSv: ['gul lök']);
    repo = FirebaseIngredientRepository(firestore: firestore);
  });

  test('an alias two ingredients share yields both ids', () async {
    expect(await repo.idsForKey('bringa'), {'beef-brisket', 'lamb-brisket'});
  });

  test('a unique name yields its one id, diacritics folded', () async {
    expect(await repo.idsForKey('lok'), {'onion'});
    expect(await repo.idsForKey('Lök'), {'onion'});
  });

  test('an alias yields the id of the ingredient that owns it', () async {
    expect(await repo.idsForKey('gul lok'), {'onion'});
  });

  test('an unknown name yields an empty set', () async {
    expect(await repo.idsForKey('zaatar'), isEmpty);
  });

  test('the returned set is a copy the caller cannot corrupt', () async {
    (await repo.idsForKey('bringa')).add('intruder');
    expect(await repo.idsForKey('bringa'), {'beef-brisket', 'lamb-brisket'});
  });
}

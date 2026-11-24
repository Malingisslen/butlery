/// BUT-2486 part 5: the fridge and freezer boxes under
/// `users/{uid}/meal_boxes`. FakeFirebaseFirestore; `serverTimestamp` and
/// `FieldValue.delete` inside `update` are what the fake models, atomicity is
/// not claimed here.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/repositories/firebase/firebase_meal_box_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _uid = 'user-alice';

FirebaseMealBoxRepository _repo(FakeFirebaseFirestore firestore) {
  final auth = FakeAuthRepository();
  auth.setAuthState(
    user: FakeUser(uid: _uid),
    userId: _uid,
    isAuthenticated: true,
  );
  return FirebaseMealBoxRepository(firestore: firestore, authRepository: auth);
}

CollectionReference<Map<String, dynamic>> _boxes(FakeFirebaseFirestore f) =>
    f.collection('users').doc(_uid).collection('meal_boxes');

MealBox _box({
  String id = 'ignored',
  int count = 4,
  Map<String, int> takes = const {},
  String? recipeId = 'r1',
}) => MealBox(
  id: id,
  recipeId: recipeId,
  recipeTitle: 'Köttbullar',
  location: MealBoxLocation.freezer,
  storedOn: DateTime(2026, 1, 2),
  count: count,
  takes: takes,
);

void main() {
  late FakeFirebaseFirestore firestore;
  late FirebaseMealBoxRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = _repo(firestore);
  });

  group('add and list', () {
    test(
      'add writes the box under the user\'s meal_boxes and returns its id',
      () async {
        final id = await repo.add(_box());

        final doc = await _boxes(firestore).doc(id).get();
        expect(doc.exists, isTrue);
        final data = doc.data()!;
        expect(data['recipeId'], 'r1');
        expect(data['recipeTitle'], 'Köttbullar');
        expect(data['location'], 'freezer');
        expect(data['count'], 4);
        expect((data['storedOn'] as Timestamp).toDate(), DateTime(2026, 1, 2));
        expect(data.containsKey('updatedAt'), isTrue);
        expect(data.containsKey('takes'), isFalse);
      },
    );

    test('add clamps a count above the ceiling', () async {
      final id = await repo.add(_box(count: 500));

      expect((await _boxes(firestore).doc(id).get()).data()!['count'], 99);
    });

    test('a box with no recipe stores no recipeId', () async {
      final id = await repo.add(_box(recipeId: null));

      expect(
        (await _boxes(firestore).doc(id).get()).data()!.containsKey('recipeId'),
        isFalse,
      );
    });

    test('list returns the boxes that were added, with their ids', () async {
      final a = await repo.add(_box(count: 2));
      final b = await repo.add(_box(count: 3));

      final boxes = await repo.list();

      expect({for (final box in boxes) box.id: box.count}, {a: 2, b: 3});
    });

    test('list does not return another user\'s boxes', () async {
      await firestore
          .collection('users')
          .doc('user-bob')
          .collection('meal_boxes')
          .doc('bobs')
          .set({'recipeTitle': 'x', 'storedOn': Timestamp.now(), 'count': 1});
      final mine = await repo.add(_box());

      expect((await repo.list()).map((b) => b.id), [mine]);
    });
  });

  group('setCount', () {
    test('clamps to 0..99', () async {
      final id = await repo.add(_box());

      await repo.setCount(id, 150);
      expect((await _boxes(firestore).doc(id).get()).data()!['count'], 99);

      await repo.setCount(id, -4);
      expect((await _boxes(firestore).doc(id).get()).data()!['count'], 0);

      await repo.setCount(id, 7);
      expect((await _boxes(firestore).doc(id).get()).data()!['count'], 7);
    });
  });

  group('foldTakes', () {
    Future<String> seed() async {
      final doc = _boxes(firestore).doc('box1');
      await doc.set({
        'recipeTitle': 'Köttbullar',
        'location': 'fridge',
        'storedOn': Timestamp.fromDate(DateTime(2026, 1, 2)),
        'count': 5,
        'takes': {'2026-01-05': 2, '2026-01-06': 1, '2026-01-20': 1},
      });
      return 'box1';
    }

    test(
      'subtracts the eaten portions and removes exactly those keys',
      () async {
        final id = await seed();
        final box = MealBox.fromMap(
          id,
          (await _boxes(firestore).doc(id).get()).data()!,
        );

        await repo.foldTakes(box, ['2026-01-05', '2026-01-06']);

        final data = (await _boxes(firestore).doc(id).get()).data()!;
        expect(data['count'], 2);
        expect(data['takes'], {'2026-01-20': 1});
      },
    );

    test('a key the box does not hold is ignored and writes nothing', () async {
      final id = await seed();
      final box = MealBox.fromMap(
        id,
        (await _boxes(firestore).doc(id).get()).data()!,
      );
      final before = (await _boxes(firestore).doc(id).get()).data()!;

      await repo.foldTakes(box, ['2026-02-01']);

      expect((await _boxes(firestore).doc(id).get()).data(), before);
    });

    test('the count never goes below 0', () async {
      final id = await seed();
      final box = MealBox.fromMap(id, {
        'recipeTitle': 'x',
        'storedOn': Timestamp.now(),
        'count': 1,
        'takes': {'2026-01-05': 2},
      });

      await repo.foldTakes(box, ['2026-01-05']);

      expect((await _boxes(firestore).doc(id).get()).data()!['count'], 0);
    });
  });

  test('delete removes the box', () async {
    final id = await repo.add(_box());

    await repo.delete(id);

    expect((await _boxes(firestore).doc(id).get()).exists, isFalse);
  });

  test(
    'an id that is not a plain document id is refused',
    () async {
      await expectLater(
        () async => repo.setCount('a/b', 1),
        throwsArgumentError,
      );
      await expectLater(() async => repo.delete(''), throwsArgumentError);
      await expectLater(
        () async => repo.foldTakes(
          _box(id: 'a/b', takes: {'2026-01-05': 1}),
          ['2026-01-05'],
        ),
        throwsArgumentError,
      );
    },
  );

  group('takeWriteMap', () {
    final take = MealBoxTake(
      boxId: 'box1',
      key: '2026-01-07',
      portions: 2,
      recipeId: 'r1',
      recipeTitle: 'Köttbullar',
      location: MealBoxLocation.freezer,
      storedOn: DateTime(2026, 1, 2),
    );

    test('names the box in full but never writes a count', () {
      final map = FirebaseMealBoxRepository.takeWriteMap(take);

      expect(map.keys.toSet(), {
        'recipeId',
        'recipeTitle',
        'location',
        'storedOn',
        'takes',
        'updatedAt',
      });
      expect(map['takes'], {'2026-01-07': 2});
    });

    test('leaves recipeId out for a box with no recipe', () {
      final map = FirebaseMealBoxRepository.takeWriteMap(
        MealBoxTake(
          boxId: 'box1',
          key: '2026-01-07',
          portions: 1,
          recipeId: null,
          recipeTitle: 'x',
          location: MealBoxLocation.fridge,
          storedOn: DateTime(2026, 1, 2),
        ),
      );

      expect(map.containsKey('recipeId'), isFalse);
      expect(map.containsKey('count'), isFalse);
    });

    test('a give-back carries the delete sentinel under its key', () {
      final map = FirebaseMealBoxRepository.takeWriteMap(
        MealBoxTake(
          boxId: 'box1',
          key: '2026-01-07',
          portions: null,
          recipeId: 'r1',
          recipeTitle: 'x',
          location: MealBoxLocation.fridge,
          storedOn: DateTime(2026, 1, 2),
        ),
      );

      expect((map['takes'] as Map)['2026-01-07'], isA<FieldValue>());
    });

    test('takeRef refuses an unsafe box id', () {
      expect(
        () => FirebaseMealBoxRepository.takeRef(
          firestore,
          _uid,
          MealBoxTake(
            boxId: 'a/b',
            key: '2026-01-07',
            portions: 1,
            recipeId: null,
            recipeTitle: 'x',
            location: MealBoxLocation.fridge,
            storedOn: DateTime(2026, 1, 2),
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}

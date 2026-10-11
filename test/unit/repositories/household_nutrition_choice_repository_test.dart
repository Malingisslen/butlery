/// BUT-643: `FirebaseHouseholdRepository.setNutritionFoodChoice` writes ONE
/// key of the household's `nutritionFoodChoices` map per call, as an edit or
/// admin member, and nothing else of the household.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/household.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/repositories/firebase/firebase_household_repository.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/fake_field_value_platform.dart';

const _admin = 'user-admin';
const _editor = 'user-editor';
const _viewer = 'user-viewer';
const _stranger = 'user-stranger';
const _hid = 'hh-1';

FirebaseHouseholdRepository _repo(
  FakeFirebaseFirestore firestore,
  String authedUserId, {
  FirebaseAuditRepository? auditRepository,
}) {
  final auth = FakeAuthRepository();
  auth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return FirebaseHouseholdRepository(
    firestore: firestore,
    authRepository: auth,
    auditRepository: auditRepository,
  );
}

Household _household() => Household(
  id: _hid,
  name: 'Familjen',
  members: [
    for (final (uid, permission) in [
      (_admin, SharedListPermission.admin),
      (_editor, SharedListPermission.edit),
      (_viewer, SharedListPermission.view),
    ])
      HouseholdMember(
        userId: uid,
        permission: permission,
        addedAt: DateTime.utc(2026, 1, 1),
      ),
  ],
  createdBy: _admin,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

Future<void> _seed(
  FakeFirebaseFirestore fs, {
  Map<String, int>? choices = const {'smör': 29, 'gul_lök': 344},
}) => fs.collection('households').doc(_hid).set({
  ..._household().toFirestore(),
  'nutritionFoodChoices': ?choices,
});

Future<Map<String, dynamic>> _doc(FakeFirebaseFirestore fs) async =>
    (await fs.collection('households').doc(_hid).get()).data()!;

void main() {
  late FakeFirebaseFirestore fs;

  setUp(() async {
    installFakeFieldValuePlatform();
    fs = FakeFirebaseFirestore();
  });

  group('who may write', () {
    test(
      'an edit member sets a key; other choices and fields are untouched',
      () async {
        await _seed(fs);
        final before = await _doc(fs);

        await _repo(fs, _editor).setNutritionFoodChoice(
          householdId: _hid,
          key: 'mjölk',
          foodId: 123,
        );

        final after = await _doc(fs);
        expect(after['nutritionFoodChoices'], {
          'mjölk': 123,
          'smör': 29,
          'gul_lök': 344,
        });
        expect(after['nutritionChoiceKey'], 'mjölk');
        for (final field in [
          'name',
          'members',
          'memberUserIds',
          'memberPermissions',
          'createdBy',
          'createdAt',
          'schemaVersion',
        ]) {
          expect(after[field], before[field], reason: field);
        }
        expect(after['updatedAt'], isNot(before['updatedAt']));
      },
    );

    test('an admin can set a key too', () async {
      await _seed(fs);
      await _repo(fs, _admin).setNutritionFoodChoice(
        householdId: _hid,
        key: 'mjölk',
        foodId: 123,
      );
      expect((await _doc(fs))['nutritionFoodChoices']['mjölk'], 123);
    });

    test('a view member is refused and nothing is written', () async {
      await _seed(fs);
      final before = await _doc(fs);

      await expectLater(
        _repo(fs, _viewer).setNutritionFoodChoice(
          householdId: _hid,
          key: 'mjölk',
          foodId: 123,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _doc(fs), before);
    });

    test('a non-member is refused and nothing is written', () async {
      await _seed(fs);
      final before = await _doc(fs);

      await expectLater(
        _repo(fs, _stranger).setNutritionFoodChoice(
          householdId: _hid,
          key: 'mjölk',
          foodId: 123,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _doc(fs), before);
    });

    test(
      'a household that does not exist is refused and not created',
      () async {
        await expectLater(
          _repo(fs, _admin).setNutritionFoodChoice(
            householdId: 'ghost',
            key: 'mjölk',
            foodId: 123,
          ),
          throwsA(isA<StateError>()),
        );
        expect(
          (await fs.collection('households').doc('ghost').get()).exists,
          isFalse,
        );
      },
    );
  });

  group('permission audit trail', () {
    Future<List<Map<String, dynamic>>> auditRows() async =>
        (await fs.collection('audit_logs').get()).docs
            .map((d) => d.data())
            .toList();

    test('a refused write leaves a granted:false row naming the user and '
        'household', () async {
      await _seed(fs);
      final repo = _repo(
        fs,
        _viewer,
        auditRepository: FirebaseAuditRepository(fs),
      );

      await expectLater(
        repo.setNutritionFoodChoice(
          householdId: _hid,
          key: 'mjölk',
          foodId: 123,
        ),
        throwsA(isA<StateError>()),
      );

      final rows = await auditRows();
      expect(rows, hasLength(1));
      expect(rows.single['granted'], isFalse);
      expect(rows.single['userId'], _viewer);
      expect(rows.single['operation'], 'update');
      expect(rows.single['resourceType'], 'Household');
      expect(rows.single['resourceId'], _hid);
    });

    test('an allowed write leaves a granted:true row', () async {
      await _seed(fs);
      final repo = _repo(
        fs,
        _editor,
        auditRepository: FirebaseAuditRepository(fs),
      );

      await repo.setNutritionFoodChoice(
        householdId: _hid,
        key: 'mjölk',
        foodId: 123,
      );

      final rows = await auditRows();
      expect(rows, hasLength(1));
      expect(rows.single['granted'], isTrue);
      expect(rows.single['userId'], _editor);
      expect(rows.single['resourceId'], _hid);
    });

    test(
      'a bad key is rejected before any permission decision is logged',
      () async {
        await _seed(fs);
        final repo = _repo(
          fs,
          _editor,
          auditRepository: FirebaseAuditRepository(fs),
        );

        await expectLater(
          repo.setNutritionFoodChoice(
            householdId: _hid,
            key: 'Mjölk',
            foodId: 123,
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(await auditRows(), isEmpty);
      },
    );
  });

  group('clearing and replacing', () {
    test('null clears just that key and still names it', () async {
      await _seed(fs);

      await _repo(fs, _editor).setNutritionFoodChoice(
        householdId: _hid,
        key: 'smör',
        foodId: null,
      );

      final after = await _doc(fs);
      expect(after['nutritionFoodChoices'], {'gul_lök': 344});
      expect(after['nutritionChoiceKey'], 'smör');
    });

    test(
      'a new pick for a key replaces the old one and leaves the rest',
      () async {
        await _seed(fs);

        await _repo(fs, _editor).setNutritionFoodChoice(
          householdId: _hid,
          key: 'smör',
          foodId: 30,
        );

        expect((await _doc(fs))['nutritionFoodChoices'], {
          'smör': 30,
          'gul_lök': 344,
        });
      },
    );

    test('the first choice ever creates the map', () async {
      await _seed(fs, choices: null);
      expect((await _doc(fs)).containsKey('nutritionFoodChoices'), isFalse);

      await _repo(fs, _editor).setNutritionFoodChoice(
        householdId: _hid,
        key: 'mjölk',
        foodId: 123,
      );

      expect((await _doc(fs))['nutritionFoodChoices'], {'mjölk': 123});
    });

    test('the written household reads back through the model', () async {
      await _seed(fs);
      await _repo(fs, _editor).setNutritionFoodChoice(
        householdId: _hid,
        key: 'kycklingfile',
        foodId: 1173,
      );

      final household = await _repo(fs, _editor).getActiveForUser(_editor);
      expect(household!.nutritionFoodChoices['kycklingfile'], 1173);
      expect(household.nutritionFoodChoices['smör'], 29);
    });
  });

  group('validation happens before any write', () {
    test('a key outside the allowed shape throws ArgumentError', () async {
      await _seed(fs);
      final before = await _doc(fs);
      final badKeys = [
        '',
        'Mjölk',
        'gul lök',
        'gul-lök',
        'mjölk.x',
        'a/b',
        'x' * 61,
        'cremé',
        '1,5',
      ];
      for (final key in badKeys) {
        await expectLater(
          _repo(fs, _editor).setNutritionFoodChoice(
            householdId: _hid,
            key: key,
            foodId: 123,
          ),
          throwsA(isA<ArgumentError>()),
          reason: '"$key"',
        );
      }
      expect(await _doc(fs), before);
    });

    test('a bad key is rejected even for a caller who may not write', () async {
      await _seed(fs);
      await expectLater(
        _repo(fs, _viewer).setNutritionFoodChoice(
          householdId: _hid,
          key: 'Mjölk',
          foodId: 123,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('keys at the edge of the shape are accepted', () async {
      await _seed(fs);
      final repo = _repo(fs, _editor);
      for (final key in ['a', 'åäö_09', 'x' * 60]) {
        await repo.setNutritionFoodChoice(
          householdId: _hid,
          key: key,
          foodId: 5,
        );
      }
      final choices = (await _doc(fs))['nutritionFoodChoices'] as Map;
      expect(choices.keys, containsAll(['a', 'åäö_09', 'x' * 60]));
    });

    test(
      'a non-positive food id throws ArgumentError and writes nothing',
      () async {
        await _seed(fs);
        final before = await _doc(fs);
        for (final id in [0, -1, -123]) {
          await expectLater(
            _repo(fs, _editor).setNutritionFoodChoice(
              householdId: _hid,
              key: 'mjölk',
              foodId: id,
            ),
            throwsA(isA<ArgumentError>()),
            reason: '$id',
          );
        }
        expect(await _doc(fs), before);
      },
    );
  });
}

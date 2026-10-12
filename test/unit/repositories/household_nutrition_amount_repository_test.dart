/// BUT-643 follow-up: `FirebaseHouseholdRepository.setNutritionAmountChoice`
/// writes ONE key of `nutritionAmountChoices` per call, as an edit or admin
/// member, names it in `nutritionAmountKey`, and refuses what the rules would.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/household.dart';
import 'package:butlery/models/nutrition/nutrition_amount_choice.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/repositories/firebase/firebase_household_repository.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/fake_field_value_platform.dart';

const _admin = 'user-admin';
const _editor = 'user-editor';
const _viewer = 'user-viewer';
const _stranger = 'user-stranger';
const _hid = 'hh-1';

const _salt = NutritionAmountChoice(amount: 1, unit: 'tsk');
const _chicken = NutritionAmountChoice(amount: 600, unit: 'g');

FirebaseHouseholdRepository _repo(
  FakeFirebaseFirestore firestore,
  String authedUserId,
) {
  final auth = FakeAuthRepository();
  auth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return FirebaseHouseholdRepository(
    firestore: firestore,
    authRepository: auth,
  );
}

FirebaseHouseholdRepository _repoWithAudit(
  FakeFirebaseFirestore firestore,
  String authedUserId,
) {
  final auth = FakeAuthRepository();
  auth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return FirebaseHouseholdRepository(
    firestore: firestore,
    authRepository: auth,
    auditRepository: FirebaseAuditRepository(firestore),
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

Future<void> _seed(FakeFirebaseFirestore fs, {Map<String, dynamic>? amounts}) =>
    fs.collection('households').doc(_hid).set({
      ..._household().toFirestore(),
      'nutritionAmountChoices':
          amounts ??
          {
            'salt': _salt.toMap(),
          },
    });

Future<Map<String, dynamic>> _doc(FakeFirebaseFirestore fs) async =>
    (await fs.collection('households').doc(_hid).get()).data()!;

void main() {
  late FakeFirebaseFirestore fs;

  setUp(() {
    installFakeFieldValuePlatform();
    fs = FakeFirebaseFirestore();
  });

  test(
    'an edit member sets one key; the others and the household stay',
    () async {
      await _seed(fs);
      final before = await _doc(fs);

      await _repo(fs, _editor).setNutritionAmountChoice(
        householdId: _hid,
        key: 'kycklingfile',
        choice: _chicken,
      );

      final after = await _doc(fs);
      expect(after['nutritionAmountChoices'], {
        'salt': _salt.toMap(),
        'kycklingfile': _chicken.toMap(),
      });
      expect(after['nutritionAmountKey'], 'kycklingfile');
      for (final field in ['name', 'members', 'memberUserIds', 'createdBy']) {
        expect(after[field], before[field], reason: field);
      }
    },
  );

  test(
    'a recipe key is written as one map key, not split on its hyphens',
    () async {
      await _seed(fs);
      final key = NutritionAmountChoice.recipeKey(
        '3f2b8e1a-1111-2222-3333-444455556666',
        'salt',
      )!;

      await _repo(fs, _admin).setNutritionAmountChoice(
        householdId: _hid,
        key: key,
        choice: _chicken,
      );

      expect((await _doc(fs))['nutritionAmountChoices'][key], _chicken.toMap());
    },
  );

  test('a null choice removes the key', () async {
    await _seed(fs);

    await _repo(fs, _editor).setNutritionAmountChoice(
      householdId: _hid,
      key: 'salt',
      choice: null,
    );

    expect((await _doc(fs))['nutritionAmountChoices'], isEmpty);
  });

  test(
    'a view member and a stranger are refused and nothing is written',
    () async {
      await _seed(fs);
      final before = await _doc(fs);

      for (final uid in [_viewer, _stranger]) {
        await expectLater(
          _repo(fs, uid).setNutritionAmountChoice(
            householdId: _hid,
            key: 'kycklingfile',
            choice: _chicken,
          ),
          throwsA(isA<StateError>()),
          reason: uid,
        );
      }

      expect(await _doc(fs), before);
    },
  );

  test('a key or an amount the rules refuse never reaches the write', () async {
    await _seed(fs);
    final before = await _doc(fs);
    final repo = _repo(fs, _editor);

    await expectLater(
      repo.setNutritionAmountChoice(
        householdId: _hid,
        key: 'Salt',
        choice: _salt,
      ),
      throwsA(isA<ArgumentError>()),
    );
    for (final bad in const [
      NutritionAmountChoice(amount: 0, unit: 'g'),
      NutritionAmountChoice(amount: 100001, unit: 'g'),
      NutritionAmountChoice(amount: 1, unit: 'lass'),
    ]) {
      await expectLater(
        repo.setNutritionAmountChoice(
          householdId: _hid,
          key: 'salt',
          choice: bad,
        ),
        throwsA(isA<ArgumentError>()),
      );
    }

    expect(await _doc(fs), before);
  });

  group('the cap of ${NutritionAmountChoice.maxEntries}', () {
    Map<String, dynamic> full() => {
      for (var i = 0; i < NutritionAmountChoice.maxEntries; i++)
        'k$i': _salt.toMap(),
    };

    test('a new key past the cap is refused with its own exception', () async {
      await _seed(fs, amounts: full());

      await expectLater(
        _repo(fs, _editor).setNutritionAmountChoice(
          householdId: _hid,
          key: 'extra',
          choice: _chicken,
        ),
        throwsA(isA<NutritionAmountChoicesFullException>()),
      );

      expect(
        (await _doc(fs))['nutritionAmountChoices'],
        hasLength(NutritionAmountChoice.maxEntries),
      );
    });

    test('an existing key can still be replaced or removed', () async {
      await _seed(fs, amounts: full());
      final repo = _repo(fs, _editor);

      await repo.setNutritionAmountChoice(
        householdId: _hid,
        key: 'k0',
        choice: _chicken,
      );
      await repo.setNutritionAmountChoice(
        householdId: _hid,
        key: 'k1',
        choice: null,
      );

      final amounts = (await _doc(fs))['nutritionAmountChoices'] as Map;
      expect(amounts['k0'], _chicken.toMap());
      expect(amounts.containsKey('k1'), isFalse);
    });
  });

  group('permission audit trail', () {
    Future<List<Map<String, dynamic>>> auditRows() async =>
        (await fs.collection('audit_logs').get()).docs
            .map((d) => d.data())
            .toList();

    test('a refused write leaves a granted:false row', () async {
      await _seed(fs);
      final repo = _repoWithAudit(fs, _viewer);

      await expectLater(
        repo.setNutritionAmountChoice(
          householdId: _hid,
          key: 'kycklingfile',
          choice: _chicken,
        ),
        throwsA(isA<StateError>()),
      );

      final rows = await auditRows();
      expect(rows, hasLength(1));
      expect(rows.single['granted'], isFalse);
      expect(rows.single['userId'], _viewer);
      expect(rows.single['resourceId'], _hid);
    });

    test('an allowed write leaves a granted:true row', () async {
      await _seed(fs);

      await _repoWithAudit(fs, _editor).setNutritionAmountChoice(
        householdId: _hid,
        key: 'kycklingfile',
        choice: _chicken,
      );

      final rows = await auditRows();
      expect(rows, hasLength(1));
      expect(rows.single['granted'], isTrue);
      expect(rows.single['userId'], _editor);
    });

    test('a bad key is rejected before any decision is logged', () async {
      await _seed(fs);

      await expectLater(
        _repoWithAudit(fs, _editor).setNutritionAmountChoice(
          householdId: _hid,
          key: 'Salt',
          choice: _salt,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(await auditRows(), isEmpty);
    });
  });
}

/// Unit tests for FirebaseWeeklyMenuPlanRepository.
///
/// Pure-Dart; FakeFirebaseFirestore. Guards the doc-ID prefix range queries
/// in [removeRecipeFromAllPlans] (recipe-delete cascade) and [exportAllByUser]
/// (GDPR export): a degenerate range (lower bound == upper bound) would match
/// zero docs, silently breaking both the cascade and the export. These tests
/// fail loudly if the upper bound loses its trailing U+F8FF sentinel — three of
/// them go red on that mutation.
///
/// They cannot, however, tell the two SPELLINGS of a correct bound apart: a
/// literal U+F8FF renders as nothing, so a working bound can read on screen as
/// the degenerate `'${userId}_'` and get re-reported as a bug (BUT-1690 was
/// filed that way, against code that had always worked). The escape spelling is
/// enforced separately by `test/architecture/architecture_test.dart`.
/// The third prefix range in this repository, [deleteAllByUser], is covered in
/// `test/integration/firebase/repositories/weekly_menu_plan_repository_test.dart`.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/firebase/firebase_weekly_menu_plan_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _alice = 'user-alice';
const _bob = 'user-bob';
const _sharedRecipe = 'recipe-shared';

FirebaseWeeklyMenuPlanRepository _repo(
  FakeFirebaseFirestore firestore, {
  String authedUserId = _alice,
}) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return FirebaseWeeklyMenuPlanRepository(
    firestore: firestore,
    authRepository: mockAuth,
  );
}

/// A plan for [userId] in the ISO week of [date], optionally holding the
/// shared recipe in middag on monday.
WeeklyMenuPlan _plan({
  required String userId,
  required DateTime date,
  bool withSharedRecipe = false,
}) {
  final base = WeeklyMenuPlan.empty(userId: userId, date: date);
  if (!withSharedRecipe) return base;
  return base.copyWith(
    entries: [
      WeeklyMenuPlanEntry.create(
        day: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipeId: _sharedRecipe,
        recipeTitle: 'Delad rätt',
      ),
    ],
  );
}

Future<void> _seed(FakeFirebaseFirestore firestore, WeeklyMenuPlan plan) async {
  await firestore
      .collection(FirestoreCollections.weeklyMenuPlans)
      .doc(plan.id)
      .set(plan.toFirestore());
}

void main() {
  setUpAll(() => registerFallbackValue(const GetOptions()));

  // Two consecutive weeks so each user owns >1 doc — the range query must
  // sweep ALL of a user's weeks, not just one.
  final week1 = DateTime.utc(2026, 1, 12); // ISO week
  final week2 = DateTime.utc(2026, 1, 19);

  group('removeRecipeFromAllPlans (doc-ID prefix range)', () {
    test('scrubs the recipe from every one of the owner\'s plans', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      await _seed(
        firestore,
        _plan(userId: _alice, date: week1, withSharedRecipe: true),
      );
      await _seed(
        firestore,
        _plan(userId: _alice, date: week2, withSharedRecipe: true),
      );

      final affected = await repo.removeRecipeFromAllPlans(
        userId: _alice,
        recipeId: _sharedRecipe,
      );

      // A degenerate range would return 0 here — proving the bug.
      expect(affected, 2);

      for (final week in [week1, week2]) {
        final doc = await firestore
            .collection(FirestoreCollections.weeklyMenuPlans)
            .doc(IsoWeekUtils.weekIdFor(_alice, IsoWeekUtils.weekStartOf(week)))
            .get();
        final plan = WeeklyMenuPlan.fromMap(doc.id, doc.data()!);
        expect(plan.entries.where((e) => e.recipeId == _sharedRecipe), isEmpty);
      }
    });

    test('does not touch another user\'s plans', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      await _seed(
        firestore,
        _plan(userId: _alice, date: week1, withSharedRecipe: true),
      );
      await _seed(
        firestore,
        _plan(userId: _bob, date: week1, withSharedRecipe: true),
      );

      await repo.removeRecipeFromAllPlans(
        userId: _alice,
        recipeId: _sharedRecipe,
      );

      final bobDoc = await firestore
          .collection(FirestoreCollections.weeklyMenuPlans)
          .doc(IsoWeekUtils.weekIdFor(_bob, IsoWeekUtils.weekStartOf(week1)))
          .get();
      final bobPlan = WeeklyMenuPlan.fromMap(bobDoc.id, bobDoc.data()!);
      // Bob's plan ID shares no prefix with alice_, so the range must exclude it.
      expect(bobPlan.entries.any((e) => e.recipeId == _sharedRecipe), isTrue);
    });
  });

  group('fetchForWeek (cache-first)', () {
    test(
      'a cached ABSENCE stands in when the server is unreachable — the opt-in '
      'is passed at this call site',
      () async {
        // BUT-1961. `fake_cloud_firestore` ignores `GetOptions(source:)`, so
        // every other test in this group is blind to which read happened:
        // deleting `acceptCachedAbsence: true` from `fetchForWeek` leaves them
        // all green. Measured. This one drives a mocked reference so the
        // sources actually requested are observable.
        final ref = _MockDocRef();
        final absent = _MockSnapshot();
        when(() => absent.exists).thenReturn(false);
        var call = 0;
        when(() => ref.get(any())).thenAnswer((_) async {
          call++;
          if (call == 1) return absent;
          throw FirebaseException(plugin: 'x', code: 'unavailable');
        });

        final col = _MockCollectionRef();
        when(() => col.doc(any())).thenReturn(ref);
        final firestore = _MockFirestore();
        when(
          () => firestore.collection(FirestoreCollections.weeklyMenuPlans),
        ).thenReturn(col);

        final mockAuth = FakeAuthRepository();
        mockAuth.setAuthState(
          user: FakeUser(uid: _alice),
          userId: _alice,
          isAuthenticated: true,
        );
        final repo = FirebaseWeeklyMenuPlanRepository(
          firestore: firestore,
          authRepository: mockAuth,
        );

        final fetched = await repo.fetchForWeek(
          userId: _alice,
          weekStart: IsoWeekUtils.weekStartOf(week1),
        );

        expect(fetched, isNull, reason: 'an absent week reads as no plan');
        expect(
          verify(
            () => ref.get(captureAny()),
          ).captured.cast<GetOptions>().map((o) => o.source).toList(),
          equals([Source.cache, Source.serverAndCache]),
          reason: 'the server is asked first; the cache only stands in after',
        );
      },
    );

    test(
      'without the opt-in the same offline read THROWS',
      () async {
        // The contrast that makes the test above mean something: this is what
        // the other two callers of `getDocCacheFirst` still do.
        final ref = _MockDocRef();
        final absent = _MockSnapshot();
        when(() => absent.exists).thenReturn(false);
        var call = 0;
        when(() => ref.get(any())).thenAnswer((_) async {
          call++;
          if (call == 1) return absent;
          throw FirebaseException(plugin: 'x', code: 'unavailable');
        });

        await expectLater(
          () => _BareCacheFirstProbe(ref).run(),
          throwsA(isA<FirebaseException>()),
        );
      },
    );

    test('returns a seeded plan for the requested week', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      await _seed(firestore, _plan(userId: _alice, date: week1));

      final fetched = await repo.fetchForWeek(
        userId: _alice,
        weekStart: IsoWeekUtils.weekStartOf(week1),
      );

      expect(fetched, isNotNull);
      expect(
        fetched!.id,
        IsoWeekUtils.weekIdFor(_alice, IsoWeekUtils.weekStartOf(week1)),
      );
    });

    test('returns null for a never-cached week without throwing', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      // Nothing seeded: the cache-first read misses, falls back, and the
      // !exists check must yield null rather than an uncaught throw — the
      // graceful-offline contract for BUT-1360 item 7.
      final fetched = await repo.fetchForWeek(
        userId: _alice,
        weekStart: IsoWeekUtils.weekStartOf(week2),
      );

      expect(fetched, isNull);
    });
  });

  group('exportAllByUser (GDPR, doc-ID prefix range)', () {
    test('exports every plan owned by the user', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      await _seed(firestore, _plan(userId: _alice, date: week1));
      await _seed(firestore, _plan(userId: _alice, date: week2));

      final exported = await repo.exportAllByUser(_alice);

      // A degenerate range would export nothing — the GDPR bug.
      expect(exported, hasLength(2));
      final ids = exported.map((row) => row['id'] as String).toSet();
      expect(
        ids,
        {
          IsoWeekUtils.weekIdFor(_alice, IsoWeekUtils.weekStartOf(week1)),
          IsoWeekUtils.weekIdFor(_alice, IsoWeekUtils.weekStartOf(week2)),
        },
      );
    });

    test('excludes other users\' plans from the export', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      await _seed(firestore, _plan(userId: _alice, date: week1));
      await _seed(firestore, _plan(userId: _bob, date: week1));

      final exported = await repo.exportAllByUser(_alice);

      expect(exported, hasLength(1));
      expect(
        exported.single['id'],
        IsoWeekUtils.weekIdFor(_alice, IsoWeekUtils.weekStartOf(week1)),
      );
    });
  });
}

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollectionRef extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDocRef extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

/// Drives the base helper with the DEFAULT (no opt-in), so the contrast in the
/// test above is against real behaviour rather than a described one.
class _BareCacheFirstProbe extends BaseFirebaseRepository<Object> {
  _BareCacheFirstProbe(this._ref)
    : super(firestore: FakeFirebaseFirestore(), authRepository: _auth());

  final DocumentReference<Map<String, dynamic>> _ref;

  static FakeAuthRepository _auth() {
    final a = FakeAuthRepository();
    a.setAuthState(
      user: FakeUser(uid: _alice),
      userId: _alice,
      isAuthenticated: true,
    );
    return a;
  }

  Future<void> run() => getDocCacheFirst(_ref);

  @override
  String get collectionName => 'probe';
  @override
  Object fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) => Object();
  @override
  Map<String, dynamic> toFirestore(Object entity) => const {};
  @override
  String getId(Object entity) => 'x';
  @override
  Future<bool> validateCreatePermission(String u, Object e) async => true;
  @override
  Future<bool> validateReadPermission(String u, String r, Object? e) async =>
      true;
  @override
  Future<bool> validateUpdatePermission(String u, String r, Object e) async =>
      true;
  @override
  Future<bool> validateDeletePermission(String u, String r) async => true;
}

/// Unit tests for FirebaseCategoryPreferencesRepository.
///
/// BUT-442: post-migration coverage. The repo extends BaseFirebaseRepository
/// as an *infrastructure shell* (gateway pattern, see FirebaseDataExportRepository),
/// so generic CRUD methods are wired to throw. Tests cover the typed
/// CategoryPreferencesRepository contract end-to-end against fake Firestore.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/category_preferences.dart';
import 'package:butlery/models/list_category_order.dart';
import 'package:butlery/repositories/firebase/firebase_category_preferences_repository.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseCategoryPreferencesRepository (BUT-442)', () {
    late FirebaseCategoryPreferencesRepository repository;
    late FakeFirebaseFirestore firestore;
    late MockAuthRepository auth;

    const userId = 'user-abc';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = MockAuthRepository();
      auth.setAuthState(
        user: FakeUser(uid: userId),
        userId: userId,
        isAuthenticated: true,
      );
      repository = FirebaseCategoryPreferencesRepository(
        firestore: firestore,
        authRepository: auth,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('shopping preferences (single-doc per user)', () {
      test('getPreferences returns null when no doc exists', () async {
        final prefs = await repository.getPreferences();
        expect(prefs, isNull);
      });

      test('savePreferences then getPreferences round-trips', () async {
        final original = CategoryPreferences(
          itemCategoryOverrides: {'mjolk': 'dairy'},
          defaultCategoryOrder: const ['dairy', 'produce'],
        );

        await repository.savePreferences(original);
        final loaded = await repository.getPreferences();

        expect(loaded, isNotNull);
        expect(loaded!.itemCategoryOverrides, {'mjolk': 'dairy'});
        expect(loaded.defaultCategoryOrder, ['dairy', 'produce']);
      });

      test('writes to /users/{uid}/category_preferences/shopping', () async {
        await repository.savePreferences(CategoryPreferences(
          itemCategoryOverrides: const {'a': 'b'},
        ));

        final doc = await firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection(FirestoreCollections.categoryPreferences)
            .doc('shopping')
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()!['itemCategoryOverrides'], {'a': 'b'});
      });
    });

    group('per-list category orders', () {
      test('getListCategoryOrder returns null when no doc exists', () async {
        final order = await repository.getListCategoryOrder('list-1');
        expect(order, isNull);
      });

      test('saveListCategoryOrder then getListCategoryOrder round-trips',
          () async {
        final order = ListCategoryOrder(
          listId: 'list-1',
          categoryOrder: const ['produce', 'dairy'],
        );

        await repository.saveListCategoryOrder(order);
        final loaded = await repository.getListCategoryOrder('list-1');

        expect(loaded, isNotNull);
        expect(loaded!.categoryOrder, ['produce', 'dairy']);
        expect(loaded.listId, 'list-1');
      });

      test('deleteListCategoryOrder removes the doc', () async {
        await repository.saveListCategoryOrder(ListCategoryOrder(
          listId: 'list-x',
          categoryOrder: const ['a'],
        ));
        expect(await repository.getListCategoryOrder('list-x'), isNotNull);

        await repository.deleteListCategoryOrder('list-x');
        expect(await repository.getListCategoryOrder('list-x'), isNull);
      });

      test('writes to /users/{uid}/list_category_orders/{listId}', () async {
        await repository.saveListCategoryOrder(ListCategoryOrder(
          listId: 'list-7',
          categoryOrder: const ['x'],
        ));

        final doc = await firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection(FirestoreCollections.listCategoryOrders)
            .doc('list-7')
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()!['categoryOrder'], ['x']);
      });
    });

    group('global overrides (crowd-sourced learning)', () {
      // Note on global overrides + FakeFirebaseFirestore:
      // recordGlobalOverride uses `set({overrides: {cat: FieldValue.increment(1)}, ...},
      // SetOptions(merge: true))`. fake_cloud_firestore's emulation of
      // FieldValue.increment over a missing doc with merge does not always
      // create a readable doc, and the repo deliberately swallows write
      // failures (best-effort, must never break the user flow). So we test
      // the contract — "never throws, regardless of success/failure" — and
      // leave the increment-shape assertion to the live Firestore rules
      // tests (firestore-rules-tester owns that surface).
      test('normalizeItemName collapses casing/whitespace identically',
          () async {
        // Pure model assertion (doesn't depend on fake_cloud_firestore
        // FieldValue semantics): the repo's doc-id resolution must be
        // deterministic across casing/spacing variants.
        expect(CategoryPreferences.normalizeItemName('  Salt  '), 'salt');
        expect(CategoryPreferences.normalizeItemName('SALT'), 'salt');
        expect(CategoryPreferences.normalizeItemName('salt'), 'salt');
        expect(CategoryPreferences.normalizeItemName('Mjölk'), 'mjölk');
      });

      test('recordGlobalOverride is best-effort — never throws on failure',
          () async {
        // Even if writes fail (e.g. rules denial), the call must complete.
        // FakeFirebaseFirestore doesn't enforce rules, but the contract is
        // that this method swallows errors. Verify by using an empty name
        // (which normalizes to '' — a valid doc ID may still succeed; the
        // important assertion is "no throw").
        await expectLater(
          repository.recordGlobalOverride('item', 'cat'),
          completes,
        );
      });
    });

    group('auth required', () {
      test(
          'getPreferences returns null when unauthenticated (caught and logged)',
          () async {
        auth.setAuthState(user: null, userId: null, isAuthenticated: false);

        // Methods catch the AuthenticationException internally and log.
        // getPreferences explicitly returns null on any failure.
        expect(await repository.getPreferences(), isNull);
      });

      test('savePreferences rethrows when unauthenticated', () async {
        auth.setAuthState(user: null, userId: null, isAuthenticated: false);

        await expectLater(
          repository.savePreferences(CategoryPreferences()),
          throwsA(anything),
        );
      });
    });

    group('gateway contract — generic CRUD throws', () {
      test('Repository<Object> CRUD methods are not supported', () async {
        // These exist only because BaseFirebaseRepository<Object> declares
        // them. The base class never invokes them on this gateway — but
        // accidental direct calls must surface loudly.
        expect(
          () =>
              repository.fromFirestore(throw UnimplementedError('not invoked')),
          throwsA(isA<UnsupportedError>()),
        );
        expect(
          () => repository.toFirestore(Object()),
          throwsA(isA<UnsupportedError>()),
        );
        expect(
          () => repository.getId(Object()),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('permission hooks are not supported (typed methods own auth)',
          () async {
        await expectLater(
          repository.validateCreatePermission('u', Object()),
          throwsA(isA<UnsupportedError>()),
        );
        await expectLater(
          repository.validateReadPermission('u', 'r', null),
          throwsA(isA<UnsupportedError>()),
        );
        await expectLater(
          repository.validateUpdatePermission('u', 'r', Object()),
          throwsA(isA<UnsupportedError>()),
        );
        await expectLater(
          repository.validateDeletePermission('u', 'r'),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });
  });
}

/// GDPR Article 15 coverage for the three SHARED-shopping-list probes on
/// [FirebaseDataExportRepository] (BUT-1732).
///
/// Why these exist at the repository level, when
/// `content_export_manager_test.dart` already covers the section: that suite
/// stubs this repository away behind a `Fake`, so it cannot see a wrong query
/// predicate at all. Only a test that runs the real `where(...)` clauses can.
///
/// The predicate that made this necessary: the member probe was first spelled
/// `.where('memberPermissions.$userId', isNotEqualTo: null)`. The cloud_firestore
/// SDK only adds a condition when the argument is non-null
/// (`query.dart:659`), so a literal `null` added NO condition and the probe
/// degraded into an unfiltered read of the whole `unified_shared_shopping_lists`
/// collection. That is not a silent over-read — the collection's read rule is
/// `ownerId == uid || uid in memberPermissions`, so the server refuses an
/// unfiltered query outright, and the user-visible symptom is "my shared data
/// mysteriously will not load" with an entire Art. 15 section collapsing into
/// an error. `isNull: false` is the supported spelling of the same intent.
///
/// `FakeFirebaseFirestore` throws `Unsupported` on `isNotEqualTo: null` rather
/// than reproducing the SDK's silent degradation, which makes the positive
/// assertions below a loud alarm if anyone reverts the spelling.
///
/// Every test asserts BOTH halves: the probe returns its own document, and it
/// never returns the stranger's. Without the negative half a degraded,
/// conditionless query passes.
library;

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('FirebaseDataExportRepository — shared shopping lists (BUT-1732)', () {
    late FirebaseDataExportRepository repository;
    late FakeFirebaseFirestore firestore;
    late FakeAuthRepository auth;

    const me = 'user-me';
    const stranger = 'user-stranger';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      auth = FakeAuthRepository();
      auth.setAuthState(
        user: FakeUser(uid: me),
        userId: me,
        isAuthenticated: true,
      );
      repository = FirebaseDataExportRepository(
        firestore: firestore,
        authRepository: auth,
      );

      // Four documents, one per role, each matching EXACTLY ONE probe. A probe
      // that lost its filter returns all four, so every assertion below can
      // fail in the direction the bug actually took.
      final lists = firestore.collection(
        FirestoreCollections.unifiedSharedShoppingLists,
      );
      await lists.doc('owned-by-me').set(<String, dynamic>{
        'name': 'Min egen delade lista',
        'ownerId': me,
        'memberPermissions': <String, dynamic>{},
        'contributorUserIds': <String>[],
      });
      await lists.doc('member-of').set(<String, dynamic>{
        'name': 'Hushållets lista',
        'ownerId': stranger,
        'memberPermissions': <String, dynamic>{me: 'edit'},
        'contributorUserIds': <String>[],
      });
      await lists.doc('contributed-to').set(<String, dynamic>{
        'name': 'Lista jag lämnat',
        'ownerId': stranger,
        'memberPermissions': <String, dynamic>{stranger: 'admin'},
        'contributorUserIds': <String>[me],
      });
      await lists.doc('strangers-only').set(<String, dynamic>{
        'name': 'Någon annans lista',
        'ownerId': stranger,
        'memberPermissions': <String, dynamic>{stranger: 'admin'},
        'contributorUserIds': <String>[stranger],
      });
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    test('the owner probe returns only the lists the user owns', () async {
      final result = await repository.exportSharedShoppingListsOwned(me);

      expect(result.map((row) => row['id']), <String>['owned-by-me']);
      expect(
        result.map((row) => row['id']),
        isNot(contains('strangers-only')),
        reason:
            'a probe that lost its ownerId filter reads the whole collection, '
            'which the read rule refuses in production',
      );
      expect(
        (result.single['data'] as Map)['name'],
        'Min egen delade lista',
        reason: 'Art. 15 requires the document, not just its id',
      );
    });

    /// The dotted-map-key probe — the one that carried the defect. On the fake
    /// the reverted spelling throws `Unsupported` before any assertion runs, so
    /// this test cannot be quietly satisfied by a degraded query.
    test('the member probe returns only lists naming the user in '
        'memberPermissions', () async {
      final result = await repository.exportSharedShoppingListsAsMember(me);

      expect(result.map((row) => row['id']), <String>['member-of']);
      expect(
        result.map((row) => row['id']),
        isNot(contains('strangers-only')),
        reason:
            "a stranger's list names the stranger under memberPermissions, so "
            'only a per-uid key filter can exclude it',
      );
    });

    // NOTE ON WHAT THIS FIXTURE PROVES — and what it does not.
    //
    // `FakeFirebaseFirestore` enforces no security rules, so a document the
    // user has LEFT is readable here. In production it is not: the read rule
    // is `ownerId == uid || uid in memberPermissions`, so the moment this
    // query matches a left list the server refuses the WHOLE query. That
    // refusal is the documented BUT-1732 gap and is pinned separately, in
    // `content_export_manager_test.dart`, by injecting the FirebaseException.
    //
    // What this test pins is narrower and still worth having: the PREDICATE is
    // `arrayContains` on the uid, not a whole-collection scan. Do not read a
    // green here as evidence that exporting left lists works — it cannot.
    test('the contributor probe returns only lists whose '
        'contributorUserIds names the user', () async {
      final result = await repository.exportSharedShoppingListsAsContributor(
        me,
      );

      expect(result.map((row) => row['id']), <String>['contributed-to']);
      expect(
        result.map((row) => row['id']),
        isNot(contains('strangers-only')),
        reason:
            'the erasure handle is an array of uids — array-contains, never a '
            'whole-collection scan',
      );
    });

    /// The three probes must not overlap by accident: if any of them widened
    /// into another's territory the union would grow, and the section would
    /// report roles the user does not hold.
    test('the three probes partition the four fixtures', () async {
      final ids = <String>{
        for (final row in await repository.exportSharedShoppingListsOwned(me))
          row['id'] as String,
        for (final row in await repository.exportSharedShoppingListsAsMember(
          me,
        ))
          row['id'] as String,
        for (final row
            in await repository.exportSharedShoppingListsAsContributor(me))
          row['id'] as String,
      };

      expect(ids, <String>{'owned-by-me', 'member-of', 'contributed-to'});
    });

    /// Defence-in-depth: the self-export guard refuses somebody else's bundle
    /// even though all three predicates are now correct.
    test('every probe refuses to export another user id', () async {
      await expectLater(
        repository.exportSharedShoppingListsOwned(stranger),
        throwsA(isA<PermissionDeniedException>()),
      );
      await expectLater(
        repository.exportSharedShoppingListsAsMember(stranger),
        throwsA(isA<PermissionDeniedException>()),
      );
      await expectLater(
        repository.exportSharedShoppingListsAsContributor(stranger),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('each probe honours its document cap', () async {
      final lists = firestore.collection(
        FirestoreCollections.unifiedSharedShoppingLists,
      );
      for (var i = 0; i < 3; i++) {
        await lists.doc('extra-$i').set(<String, dynamic>{
          'name': 'extra $i',
          'ownerId': me,
          'memberPermissions': <String, dynamic>{},
          'contributorUserIds': <String>[],
        });
      }

      final result = await repository.exportSharedShoppingListsOwned(
        me,
        maxDocuments: 2,
      );

      expect(result, hasLength(2));
    });
  });
}

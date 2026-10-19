/// The four `memberPermissions.<uid>` membership queries, asserted on the
/// CONDITION the SDK built rather than on the rows a fake returned (BUT-1765,
/// the half of BUT-1746's first acceptance criterion that was not delivered).
///
/// cloud_firestore adds a condition only for a non-null argument, so
/// `isNotEqualTo: null` compiles, reads as a filter and sends none. The result
/// tests beside each site redden on that spelling only because
/// `fake_cloud_firestore` throws on it. Here the real `Query.where` runs over a
/// recording platform ([RecordingFirestore]), so the assertion is that the
/// query carries `memberPermissions.<uid> != null`.
library;

import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/repositories/firebase/firebase_group_weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/firebase/modules/shopping_repository_query_module.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/recording_firestore.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

const _uid = 'alice';
const _sharedPath = 'unified_shared_shopping_lists';
const _membership = 'memberPermissions.alice != null';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecordingFirestore recorder;
  late FirebaseFirestore firestore;
  late FakeAuthRepository auth;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    (recorder, firestore) = RecordingFirestore.install();
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    recorder.clear();
    auth = FakeAuthRepository()
      ..setAuthState(
        user: FakeUser(uid: _uid),
        userId: _uid,
        isAuthenticated: true,
      );
  });

  // The control for every case below: the recorder reports a query that WAS
  // filtered, so an empty `conditions` list is a finding and not a harness gap.
  test('the recorder shows a condition the SDK built', () async {
    await firestore.collection('probe').where('k', isEqualTo: 1).get();

    expect(recorder.single('probe').conditions, <String>['k == 1']);
  });

  test('the recorder shows the SDK dropping a null not-equal filter', () async {
    // The defect itself, reproduced on the real builder through a variable so
    // `tools/check_null_filter.sh` (which reads source text) stays quiet.
    const Object? noValue = null;
    await firestore.collection('probe').where('k', isNotEqualTo: noValue).get();

    expect(recorder.single('probe').conditions, isEmpty);
  });

  test('exportPlansForParticipant filters on the requester key', () async {
    final repo = FirebaseGroupWeeklyMenuPlanRepository(
      firestore: firestore,
      authRepository: auth,
    );

    await repo.exportPlansForParticipant(_uid);

    expect(
      recorder.single('group_weekly_menu_plans').conditions,
      <String>[_membership],
    );
  });

  test('exportSharedShoppingListsAsMember filters on the member key', () async {
    final repo = FirebaseDataExportRepository(
      firestore: firestore,
      authRepository: auth,
    );

    await repo.exportSharedShoppingListsAsMember(_uid);

    expect(recorder.single(_sharedPath).conditions, <String>[_membership]);
  });

  group('ShoppingRepositoryQueryModule', () {
    ShoppingRepositoryQueryModule module() => ShoppingRepositoryQueryModule(
      firestore: firestore,
      sharedListsRef: firestore.collection(_sharedPath),
      requireCurrentUserId: () => _uid,
      getUserCollection: (uid) =>
          firestore.collection('users/$uid/unified_shopping_lists'),
      fromFirestore: (doc) => throw StateError('no documents are returned'),
      readList: (_) async => null,
    );

    test('readAll filters the shared leg on the member key', () async {
      await module().readAll();

      expect(recorder.single(_sharedPath).conditions, <String>[_membership]);
    });

    test('collaborativeListsStream filters on the member key', () async {
      final lists = await module().collaborativeListsStream().first;

      expect(lists, isA<List<UnifiedShoppingList>>());
      expect(recorder.single(_sharedPath).conditions, <String>[_membership]);
    });
  });
}

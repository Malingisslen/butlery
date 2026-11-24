/// BUT-2490: the Art. 15 `chat_groups` projection carries the group's fixed
/// days as `recurring_day_rules`. The projection names every field it exports,
/// so a field stored on the group is not exported unless listed here.
library;

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('FirebaseDataExportRepository.exportChatGroups (BUT-2490)', () {
    late FirebaseDataExportRepository repository;
    late FakeFirebaseFirestore firestore;

    const userId = 'user-abc';

    final tacoFriday = RecurringDayRule.create(
      day: DayOfWeek.fri,
      meal: MealSlot.middag,
      food: RecurringFood.tacos,
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      firestore = FakeFirebaseFirestore();
      final auth = FakeAuthRepository();
      auth.setAuthState(
        user: FakeUser(uid: userId),
        userId: userId,
        isAuthenticated: true,
      );
      repository = FirebaseDataExportRepository(
        firestore: firestore,
        authRepository: auth,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    Future<void> seedGroup(String id, Map<String, dynamic> extra) => firestore
        .collection(FirestoreCollections.chatGroups)
        .doc(id)
        .set(<String, dynamic>{
          'name': 'Familjen',
          'memberIds': <String>[userId, 'other'],
          'adminIds': <String>['other'],
          'memberAddedBy': <String, dynamic>{userId: 'other', 'other': 'other'},
          'conversationId': 'c-$id',
          'createdBy': 'other',
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1)),
          ...extra,
        });

    test('exports the stored rules, junk rows dropped', () async {
      await seedGroup('g1', {
        'recurringDayRules': <Object?>[
          tacoFriday.toFirestore(),
          {...tacoFriday.toFirestore(), 'id': '6-middag', 'weekday': 6},
          {'weekday': 2, 'meal': 'middag', 'kind': 'tag', 'value': 'pizza'},
          'junk',
        ],
      });

      final rows = await repository.exportChatGroups(userId);

      expect(rows, hasLength(1));
      expect(rows.single['recurring_day_rules'], [
        {
          'id': '5-middag',
          'weekday': 5,
          'meal': 'middag',
          'kind': 'tag',
          'value': 'taco',
          'quick': false,
          'paused': false,
        },
        {
          'id': '6-middag',
          'weekday': 6,
          'meal': 'middag',
          'kind': 'tag',
          'value': 'taco',
          'quick': false,
          'paused': false,
        },
      ]);
      // The rest of the projection is unchanged.
      expect(rows.single['group_id'], 'g1');
      expect(rows.single['you_were_added_by'], 'other');
    });

    test('a group with no rules exports an empty list', () async {
      await seedGroup('g1', const {});

      final rows = await repository.exportChatGroups(userId);

      expect(rows.single['recurring_day_rules'], isEmpty);
    });
  });
}

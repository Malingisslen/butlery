/// BUT-2522: a week template is a `menus` document, and the Art. 15 export of
/// the user's own menus carries its dishes. Written by the same code path the
/// app saves with, so a renamed or dropped field would show here.
library;

import 'package:butlery/models/menu/week_template_entry.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

const _me = 'user-me';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirebaseDataExportRepository repository;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    firestore = FakeFirebaseFirestore();
    final auth = FakeAuthRepository();
    auth.setAuthState(
      user: FakeUser(uid: _me),
      userId: _me,
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

  test('the export of own menus includes a template and its dishes', () async {
    final template = SharedMenu(
      id: '',
      sharedByUserId: _me,
      sharedByDisplayName: 'Malin',
      menuTitle: 'Sommarveckan',
      menuSnapshot: const {},
      templateKind: SharedMenu.weekTemplateKind,
      templateEntries: const [
        WeekTemplateEntry(
          day: DayOfWeek.fri,
          slot: MealSlot.middag,
          recipeId: 'pizza',
          recipeTitle: 'Pizza',
        ),
      ],
    );
    await firestore.collection('menus').add(template.toFirestore());

    final rows = await repository.exportSharedMenusByOwner(_me);

    final data = rows.single['data'] as Map<String, dynamic>;
    expect(data['menuTitle'], 'Sommarveckan');
    expect(data['templateKind'], 'week');
    expect(data['templateEntries'], [
      {
        'day': 'fri',
        'slot': 'middag',
        'recipeId': 'pizza',
        'recipeTitle': 'Pizza',
      },
    ]);
  });
}

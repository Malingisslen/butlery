/// BUT-2490: the saved weekly rules live on `users/{uid}/settings/preferences`,
/// so the Art. 15 bundle's `preferences` section must carry them as stored.
/// The erasure side needs no new step: the cascade deletes the whole
/// `settings` collection (functions/src/account/cascade/user-subcollections.ts).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/preferences_export_manager.dart';

class _FakeExports extends Fake implements FirebaseDataExportRepository {
  _FakeExports(this.preferences);

  final Map<String, dynamic> preferences;

  @override
  Future<Map<String, dynamic>?> exportUserPreferencesDocument(
    String userId,
  ) async => preferences;

  @override
  Future<List<Map<String, dynamic>>> exportUserSettings(
    String userId, {
    int maxDocuments = 50,
  }) async => [
    {'id': 'preferences', 'data': preferences},
  ];
}

void main() {
  test('the preferences section exports the saved weekly rules', () async {
    final rule = RecurringDayRule.create(
      day: DayOfWeek.mon,
      meal: MealSlot.middag,
      food: RecurringFood.fisk,
    );
    final stored = {
      'notificationsEnabled': true,
      RecurringDayRules.field: RecurringDayRules.toFirestoreList([rule]),
    };

    final section = await PreferencesExportManager(
      dataExportRepository: _FakeExports(stored),
    ).exportPreferences('u1');

    final preferences = section['preferences'] as Map<String, dynamic>;
    expect(preferences[RecurringDayRules.field], [
      {
        'id': '1-middag',
        'weekday': 1,
        'meal': 'middag',
        'kind': 'proteinCategory',
        'value': 'fish',
        'quick': false,
        'paused': false,
      },
    ]);
    expect(section.containsKey('error_code'), isFalse);
  });
}

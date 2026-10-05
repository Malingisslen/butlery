import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/production_mocks.dart';

/// Stubs the signed-in user's own allergen and dietary preferences the way
/// the MENU reads them: from `currentUserProfile.allergenPreferences` with
/// the settings read marked done (`menu_generator.dart`, `_ownPrefs`,
/// BUT-2085). `UserService.allergenPreferences` is stubbed too, for the
/// callers that still read it.
///
/// Both sources agree here, so a generator that reads the getter again stays
/// green in every suite using this helper; that mutant is pinned by
/// menu_generator_undeclared_user_test.dart on a REAL UserService, which
/// must stay off this helper.
void stubOwnPreferences(
  MockUserService userService,
  UserAllergenPreferences prefs, {
  String uid = 'u1',
  bool useHouseholdAllergens = true,
}) {
  when(() => userService.allergenPreferences).thenReturn(prefs);
  when(() => userService.currentUserProfile).thenReturn(
    UserProfile(
      uid: uid,
      displayName: 'Test',
      email: 'test@example.com',
      joinedAt: DateTime(2026),
      lastActiveAt: DateTime(2026),
      allergenPreferences: prefs,
      useHouseholdAllergens: useHouseholdAllergens,
      settingsMerged: true,
    ),
  );
}

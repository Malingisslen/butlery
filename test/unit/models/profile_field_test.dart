// BUT-2513: every key a profile save can write belongs to exactly one
// ProfileField, so a new model field cannot be left out of the list (and
// with it, out of the per-field test in
// profile_save_keeps_newer_fields_test.dart).

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/profile_field.dart';
import 'package:butlery/models/user_profile.dart';

void main() {
  final profile = UserProfile(
    uid: 'u1',
    displayName: 'Alice',
    email: 'a@example.com',
    joinedAt: DateTime.utc(2026, 1, 1),
    lastActiveAt: DateTime.utc(2026, 1, 1),
  );

  List<String> listed(Iterable<String> Function(ProfileField) keys) => [
    for (final field in ProfileField.values) ...keys(field),
  ];

  test('the profile document keys are each listed once', () {
    final keys = {
      ...profile.toFirestoreEditable().keys,
      'displayNameLower',
    }..removeAll(ProfileField.alwaysWrittenPublicKeys);
    final named = listed((f) => f.publicKeys);
    expect(named.toSet(), equals(keys));
    expect(named.length, keys.length, reason: 'a key listed twice');
  });

  test('the settings document keys are each listed once', () {
    final keys = profile.toPrivateSettings().keys.toSet();
    final named = listed((f) => f.settingsKeys);
    expect(named.toSet(), equals(keys));
    expect(named.length, keys.length, reason: 'a key listed twice');
  });

  test('an empty field set writes only the always-written keys', () {
    expect(
      ProfileField.publicPart(profile.toFirestoreEditable(), const {}).keys,
      unorderedEquals(ProfileField.alwaysWrittenPublicKeys),
    );
    expect(
      ProfileField.settingsPart(profile.toPrivateSettings(), const {}),
      isEmpty,
    );
  });
}

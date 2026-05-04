/// BUT-659: client-side mirror of the `isAccountMatured()` Firestore rule.
///
/// Pure logic test — verifies the predicate matches the rule's contract
/// (verified-email always passes, otherwise 60min after `joinedAt`).
library;

import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/auth/account_maturity_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockUser extends Mock implements User {}

UserProfile _profile({
  required DateTime joinedAt,
}) =>
    UserProfile(
      uid: 'user1',
      displayName: 'Anna',
      email: 'anna@example.com',
      joinedAt: joinedAt,
      lastActiveAt: joinedAt,
    );

void main() {
  late _MockUser user;

  setUp(() {
    user = _MockUser();
    when(() => user.emailVerified).thenReturn(false);
  });

  group('AccountMaturityHelper.isMatured', () {
    test('email-verified user passes immediately, ignoring joinedAt', () {
      when(() => user.emailVerified).thenReturn(true);
      final helper = AccountMaturityHelper(
        now: () => DateTime.utc(2026, 5, 4, 12, 0),
      );
      expect(
        helper.isMatured(
          profile: _profile(joinedAt: DateTime.utc(2026, 5, 4, 11, 59)),
          firebaseUser: user,
        ),
        isTrue,
      );
    });

    test('unverified user passes after 60 min', () {
      final helper = AccountMaturityHelper(
        now: () => DateTime.utc(2026, 5, 4, 13, 0),
      );
      expect(
        helper.isMatured(
          profile: _profile(joinedAt: DateTime.utc(2026, 5, 4, 12, 0)),
          firebaseUser: user,
        ),
        isTrue,
      );
    });

    test('unverified user fails before 60 min', () {
      final helper = AccountMaturityHelper(
        now: () => DateTime.utc(2026, 5, 4, 12, 30),
      );
      expect(
        helper.isMatured(
          profile: _profile(joinedAt: DateTime.utc(2026, 5, 4, 12, 0)),
          firebaseUser: user,
        ),
        isFalse,
      );
    });

    test('null profile is not matured', () {
      final helper = AccountMaturityHelper();
      expect(
        helper.isMatured(profile: null, firebaseUser: user),
        isFalse,
      );
    });

    test('null Firebase user with old profile still passes by age', () {
      // The maturity gate should not require a Firebase user instance —
      // anonymous-but-old accounts (e.g. local cache replay) shouldn't
      // be locked out.
      final helper = AccountMaturityHelper(
        now: () => DateTime.utc(2026, 5, 4, 14, 0),
      );
      expect(
        helper.isMatured(
          profile: _profile(joinedAt: DateTime.utc(2026, 5, 4, 12, 0)),
          firebaseUser: null,
        ),
        isTrue,
      );
    });

    test('custom window honored', () {
      final helper = AccountMaturityHelper(
        window: const Duration(minutes: 5),
        now: () => DateTime.utc(2026, 5, 4, 12, 6),
      );
      expect(
        helper.isMatured(
          profile: _profile(joinedAt: DateTime.utc(2026, 5, 4, 12, 0)),
          firebaseUser: user,
        ),
        isTrue,
      );
    });
  });
}

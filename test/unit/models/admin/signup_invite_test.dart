/// The guest-list entry and its repository (BUT-2452): what is read back from
/// `signup_allowlist/{email}`, and that a write carries exactly the three
/// fields the rules accept, with an expiry inside their 30-day bound.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/signup_invite.dart';
import 'package:butlery/repositories/firebase/firebase_signup_allowlist_repository.dart';
import 'package:butlery/repositories/interfaces/signup_allowlist_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _admin = 'admin-uid';

FirebaseSignupAllowlistRepository _repo(FakeFirebaseFirestore db) {
  final auth = FakeAuthRepository();
  auth.setAuthState(
    user: FakeUser(uid: _admin, displayName: 'M'),
    userId: _admin,
    isAuthenticated: true,
  );
  return FirebaseSignupAllowlistRepository(firestore: db, authRepository: auth);
}

void main() {
  group('SignupInvite.fromFirestore', () {
    test('reads the id as the address and both timestamps', () {
      final at = DateTime.utc(2026, 10, 24, 9);
      final invite = SignupInvite.fromFirestore('anna@example.com', {
        'invitedAt': Timestamp.fromDate(at),
        'invitedBy': _admin,
        'expireAt': Timestamp.fromDate(at.add(const Duration(days: 30))),
      });
      expect(invite.email, 'anna@example.com');
      expect(invite.invitedAt!.isAtSameMomentAs(at), isTrue);
      expect(invite.isExpiredAt(at), isFalse);
      expect(invite.isExpiredAt(at.add(const Duration(days: 30))), isTrue);
    });

    test('missing fields read as null and count as expired', () {
      final invite = SignupInvite.fromFirestore('anna@example.com', {});
      expect(invite.invitedAt, isNull);
      expect(invite.expireAt, isNull);
      expect(invite.isExpiredAt(DateTime.utc(2026)), isTrue);
    });
  });

  group('normalizeInviteEmail', () {
    test('matches the blocking function: trim and lower-case only', () {
      expect(
        normalizeInviteEmail('  Anna.B+Test@Example.COM '),
        'anna.b+test@example.com',
      );
    });
  });

  group('FirebaseSignupAllowlistRepository', () {
    test(
      'invite writes exactly invitedAt, invitedBy and an expiry inside 30 days',
      () async {
        final db = FakeFirebaseFirestore();
        final now = DateTime.utc(2026, 10, 24, 12);
        await withClock(
          Clock.fixed(now),
          () => _repo(db).invite('anna@example.com'),
        );

        final doc = await db
            .collection('signup_allowlist')
            .doc('anna@example.com')
            .get();
        final data = doc.data()!;
        expect(data.keys.toSet(), {'invitedAt', 'invitedBy', 'expireAt'});
        expect(data['invitedBy'], _admin);
        final expire = (data['expireAt'] as Timestamp).toDate();
        expect(expire.isAfter(now.add(const Duration(days: 29))), isTrue);
        expect(expire.isBefore(now.add(const Duration(days: 30))), isTrue);
      },
    );

    test(
      'a second invite for the same address throws and leaves the first',
      () async {
        final db = FakeFirebaseFirestore();
        final repo = _repo(db);
        await repo.invite('anna@example.com');
        await expectLater(
          repo.invite('anna@example.com'),
          throwsA(isA<SignupInviteExistsException>()),
        );
        expect(
          (await db.collection('signup_allowlist').get()).docs,
          hasLength(1),
        );
      },
    );

    test('remove deletes the entry; list returns what is stored', () async {
      final db = FakeFirebaseFirestore();
      final repo = _repo(db);
      await repo.invite('anna@example.com');
      await repo.invite('bo@example.com');
      await repo.remove('anna@example.com');
      final list = await repo.listInvites();
      expect(list.map((i) => i.email), ['bo@example.com']);
    });
  });
}

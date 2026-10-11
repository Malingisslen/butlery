/// Emulator-lane integration tests for [FirebaseUserRepository].
///
/// The fake Firestore cannot resolve server timestamps, `FieldValue.delete`
/// or atomic increments the way the backend does, and profile persistence
/// depends on all three, so these run against the emulator.
///
/// The emulator runs without security rules, so rules-level denials are not
/// asserted here; the repository's own client-side permission checks are.
@Tags(['integration', 'firebase'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_user_repository.dart';

import '../../../infrastructure/builders/user_builder.dart';
import '../../../test_support/emulator_lane.dart';

void main() {
  group('Firebase User Repository Integration', () {
    late FirebaseFirestore firestore;
    late FirebaseUserRepository repository;

    const testUserId = 'test-user-123';

    const server = GetOptions(source: Source.server);

    DocumentReference<Map<String, dynamic>> publicDoc(String uid) =>
        firestore.collection('public_profiles').doc(uid);

    DocumentReference<Map<String, dynamic>> settingsDoc(String uid) => firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('preferences');

    Future<Map<String, dynamic>?> publicData(String uid) async =>
        (await publicDoc(uid).get(server)).data();

    Future<void> seedPublicProfile(
      String uid, {
      String? displayName,
      bool isSearchable = true,
      bool? isHidden,
      Map<String, dynamic> extra = const {},
    }) {
      final name = displayName ?? 'User $uid';
      return publicDoc(uid).set({
        'displayName': name,
        'displayNameLower': name.toLowerCase(),
        'isSearchable': isSearchable,
        'isHidden': ?isHidden,
        'joinedAt': Timestamp.now(),
        'lastActiveAt': Timestamp.now(),
        ...extra,
      });
    }

    setUp(() async {
      firestore = await firestoreForLane();
      await clearLane();

      final mockAuth = MockFirebaseAuth(
        mockUser: MockUser(
          uid: testUserId,
          email: 'test@example.com',
          displayName: 'Test User',
        ),
        signedIn: true,
      );
      repository = FirebaseUserRepository(
        firestore: firestore,
        authRepository: FirebaseAuthRepository(firebaseAuth: mockAuth),
      );
    });

    group('saveProfile', () {
      test('writes the public profile and the private settings document '
          'separately', () async {
        final profile = UserBuilder()
            .withId(testUserId)
            .withName('Test User')
            .build();

        await repository.saveProfile(profile);

        final pub = await publicData(testUserId);
        expect(pub?['displayName'], 'Test User');
        expect(pub?['displayNameLower'], 'test user');
        expect(pub?.containsKey('fcmToken'), isFalse);
        final settings = (await settingsDoc(testUserId).get(server)).data();
        expect(settings, isNotNull);
        expect(settings!['notificationsEnabled'], isTrue);
      });

      test('removes an email an older save left on the public document, '
          'and never writes one', () async {
        await seedPublicProfile(
          testUserId,
          extra: {'email': 'old-leak@example.com'},
        );

        await repository.saveProfile(
          UserBuilder()
              .withId(testUserId)
              .withName('Test User')
              .withEmail('test@example.com')
              .build(),
        );

        expect((await publicData(testUserId))?.containsKey('email'), isFalse);
      });

      test('a stale profile does not overwrite server-owned friendsCount or '
          'the moderation flag', () async {
        await seedPublicProfile(
          testUserId,
          isHidden: true,
          extra: {'friendsCount': 7},
        );

        await repository.saveProfile(
          UserBuilder()
              .withId(testUserId)
              .withName('Renamed')
              .withFriendCount(0)
              .build(),
        );

        final pub = await publicData(testUserId);
        expect(pub?['displayName'], 'Renamed');
        expect(pub?['friendsCount'], 7);
        expect(pub?['isHidden'], isTrue);
      });

      test('refuses to save another user\'s profile', () async {
        final other = UserBuilder().withId('someone-else').build();

        await expectLater(
          repository.saveProfile(other),
          throwsA(isA<PermissionDeniedException>()),
        );
        expect((await publicDoc('someone-else').get(server)).exists, isFalse);
      });
    });

    group('Server-stamped fields', () {
      test(
        'updateOnlineStatus sets the flag and a server lastActiveAt',
        () async {
          await seedPublicProfile(
            testUserId,
            extra: {
              'lastActiveAt': Timestamp.fromDate(DateTime.utc(2020)),
              'isOnline': false,
            },
          );

          await repository.updateOnlineStatus(testUserId, true);

          final pub = await publicData(testUserId);
          expect(pub?['isOnline'], isTrue);
          final lastActive = (pub?['lastActiveAt'] as Timestamp).toDate();
          expect(lastActive.isAfter(DateTime.utc(2020)), isTrue);
        },
      );

      test('updateFCMToken stores the token and a timestamp in the private '
          'settings, not the public profile', () async {
        await seedPublicProfile(testUserId);

        await repository.updateFCMToken(testUserId, 'fcm-token-123');

        final settings = (await settingsDoc(testUserId).get(server)).data();
        expect(settings?['fcmToken'], 'fcm-token-123');
        expect(settings?['fcmTokenUpdatedAt'], isA<Timestamp>());
        expect(
          (await publicData(testUserId))?.containsKey('fcmToken'),
          isFalse,
        );
      });

      test('clearFCMToken clears the token and its timestamp', () async {
        await settingsDoc(testUserId).set({
          'fcmToken': 'old-token',
          'fcmTokenUpdatedAt': Timestamp.now(),
          'notificationsEnabled': true,
        });

        await repository.clearFCMToken(testUserId);

        final settings = (await settingsDoc(testUserId).get(server)).data();
        expect(settings?['fcmToken'], isNull);
        expect(settings?['fcmTokenUpdatedAt'], isNull);
        expect(settings?['notificationsEnabled'], isTrue);
      });

      test('ensureBaseUserDocument creates server timestamps and keeps '
          'existing fields', () async {
        await firestore.collection('users').doc(testUserId).set({
          'someExistingField': 'value',
        });

        await repository.ensureBaseUserDocument(testUserId);

        final data =
            (await firestore.collection('users').doc(testUserId).get(server))
                .data();
        expect(data?['uid'], testUserId);
        expect(data?['initialized'], isTrue);
        expect(data?['createdAt'], isA<Timestamp>());
        expect(data?['lastActiveAt'], isA<Timestamp>());
        expect(data?['someExistingField'], 'value');
      });

      test('recordTermsAcceptance stamps the server time and the version '
          'on the root user document', () async {
        await repository.recordTermsAcceptance(testUserId, '2026-01');

        final data =
            (await firestore.collection('users').doc(testUserId).get(server))
                .data();
        expect(data?['termsVersion'], '2026-01');
        expect(data?['termsAcceptedAt'], isA<Timestamp>());
      });
    });

    group('Counters', () {
      test('updateProfileStats overwrites the given counts only', () async {
        await seedPublicProfile(
          testUserId,
          extra: {'friendsCount': 5, 'publicRecipeCount': 10},
        );

        await repository.updateProfileStats(testUserId, friendsCount: 8);

        final pub = await publicData(testUserId);
        expect(pub?['friendsCount'], 8);
        expect(pub?['publicRecipeCount'], 10);
      });

      test('updateProfileStats refuses another user\'s profile', () async {
        await seedPublicProfile('someone-else', extra: {'friendsCount': 1});

        await expectLater(
          repository.updateProfileStats('someone-else', friendsCount: 99),
          throwsA(isA<PermissionDeniedException>()),
        );
        expect((await publicData('someone-else'))?['friendsCount'], 1);
      });

      test('concurrent recipe-count increments and a decrement are all '
          'applied', () async {
        await seedPublicProfile(testUserId, extra: {'publicRecipeCount': 0});

        await Future.wait([
          for (var i = 0; i < 5; i++)
            repository.incrementPublicRecipeCount(testUserId),
        ]);
        await repository.decrementPublicRecipeCount(testUserId);

        expect((await publicData(testUserId))?['publicRecipeCount'], 4);
      });
    });

    group('fetchProfiles', () {
      test('returns every profile when the ids span several whereIn '
          'batches', () async {
        final ids = [for (var i = 0; i < 65; i++) 'user-$i'];
        for (final id in ids) {
          await seedPublicProfile(id);
        }

        final profiles = await repository.fetchProfiles([
          ...ids,
          'does-not-exist',
        ]);

        expect(profiles.map((p) => p.uid), unorderedEquals(ids));
      });

      test('returns nothing for an empty id list', () async {
        expect(await repository.fetchProfiles([]), isEmpty);
      });
    });

    group('searchProfiles', () {
      test('matches the name prefix regardless of case and excludes the '
          'current user', () async {
        await seedPublicProfile('user-1', displayName: 'John Doe');
        await seedPublicProfile('user-2', displayName: 'Jane Smith');
        await seedPublicProfile('user-3', displayName: 'Johnny Walker');
        await seedPublicProfile(testUserId, displayName: 'John Test');

        final results = await repository.searchProfiles('JOHN');

        expect(
          results.map((p) => p.displayName),
          ['John Doe', 'Johnny Walker'],
        );
      });

      test('leaves out profiles that are not searchable or are hidden by '
          'moderation', () async {
        await seedPublicProfile(
          'private-user',
          displayName: 'Hidden Private',
          isSearchable: false,
        );
        await seedPublicProfile(
          'moderated-user',
          displayName: 'Hidden Moderated',
          isHidden: true,
        );
        await seedPublicProfile('visible-user', displayName: 'Hidden Visible');

        final results = await repository.searchProfiles('hidden');

        expect(results.map((p) => p.uid), ['visible-user']);
      });

      test('a blank query finds nothing', () async {
        await seedPublicProfile('user-1', displayName: 'John Doe');

        expect(await repository.searchProfiles('   '), isEmpty);
      });
    });

    group('isDisplayNameAvailable', () {
      test(
        'a name held by someone else is taken, an unused one is free',
        () async {
          await seedPublicProfile('existing-user', displayName: 'John Doe');

          expect(await repository.isDisplayNameAvailable('John Doe'), isFalse);
          expect(
            await repository.isDisplayNameAvailable('  John Doe '),
            isFalse,
          );
          expect(await repository.isDisplayNameAvailable('Jane Smith'), isTrue);
        },
      );

      test('the current user may keep their own name', () async {
        await seedPublicProfile(testUserId, displayName: 'Test User');

        expect(await repository.isDisplayNameAvailable('Test User'), isTrue);
      });
    });
  }, skip: emulatorOnlySkip);
}

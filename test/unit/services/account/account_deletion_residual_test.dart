/// BUT-671 — Post-deletion residual integrity tests.
///
/// Drives the real [AccountDeletionService] cascade against a
/// [FakeFirebaseFirestore] seeded across every collection enumerated in
/// [FirebaseDataExportRepository] (the BUT-501 single source of truth for
/// "all collections that hold user data"), then asserts zero residual
/// documents reference the deleted UID.
///
/// This catches the BUT-498 commit-2 class of bug — `user_fcm_tokens`
/// silently failing because a deletion path delegated to a mocked repo
/// that never touched Firestore. Each interface-repo stub used by
/// [AccountDeletionService] in this test wires a *side-effect* that
/// actually deletes from FakeFirestore, so a missing wire-up surfaces
/// here as residual data instead of a silent green test.
///
/// **Retention exceptions documented inline:**
///   - `audit_logs` — GDPR Art 30 retention (kept; not asserted as residual).
///   - `deletion_audit_logs` — written by the cascade itself; expected to
///     be present after deletion. TTL via `expireAt` per BUT-665.
///   - `recipe_ratings` — anonymized to `deleted-user`, not deleted, when
///     the rating is tied to a non-owned recipe (recipe quality data
///     retention). Not exercised here because [SocialDeletionOperations]
///     fully deletes ratings authored by the deleted user (no anonymization
///     branch in current production code).
///
/// **PRODUCTION RESIDUALS SURFACED BY THIS TEST (filed for follow-up — do
/// NOT fix in the same commit per BUT-671 scope guard):**
///   - `menus` (top-level) where `sharedByUserId == deletedUid` — NOT wiped.
///     [ContentDeletionOperations.deleteMenus] only deletes the
///     `users/{uid}/menus` subcollection; the top-level `menus` collection
///     that [FirebaseDataExportRepository.exportSharedMenusByOwner] reads
///     is never touched. This is a GDPR Art 17 gap. Asserted positively
///     below so a future fix flips the assertion red and forces this
///     comment to be updated.
///   - `menus` (top-level) where `sharedToUserIds arrayContains deletedUid`
///     — UID is NOT removed from arrays on inbound shared menus.
///     [ContentDeletionOperations] has no scrub path for this; the
///     symmetric scrub for shopping lists exists but for menus it doesn't.
///     Same handling: asserted positively as residual.
///   - `blocks` field-name inconsistency:
///     [FirebaseBlockRepository] writes/reads/deletes `blockedId`;
///     [FirebaseDataExportRepository.exportIncomingBlocks] queries
///     `blockedUserId`. The export will return zero incoming blocks in
///     production. Seed mirrors BOTH names so cascade deletion (which uses
///     `blockedId`) works in this test, but the production data-export
///     gap remains. Fix: align field names in both repos and migrate.
///
/// **Honest gaps in coverage (FakeFirebaseFirestore + harness limitations):**
///   - `FieldValue.serverTimestamp()` in audit-log writes can throw on
///     fake-firestore depending on version — `createAuditLog: false` to
///     dodge; the audit-log path is covered by
///     `account_deletion_integration_test.dart`.
///   - `collectionGroup` queries (used by `removeFromSharedContent`) have
///     partial support; that path is covered by the dedicated unit tests
///     in `social_deletion_operations_test.dart` (BUT-298).
///   - Firebase Storage cleanup (`storage_files`) cannot be exercised —
///     no Storage harness; relevant `StorageDeletionOperations` test path
///     is mocked.
///   - `cook_snaps`, `activity_events`, `weekly_menu_plans`,
///     `pantry_items` — these resolve their typed repos via
///     `ServiceLocator.get<...>()` inside [ContentDeletionOperations] and
///     fall over here because we don't register every typed repository.
///     They land in `failedCollections` but the *cascade behaviour* of
///     each is covered by their dedicated repository tests. Adding them
///     to this test would expand scope past the BUT-671 contract; if a
///     future regression makes them silently no-op, the per-repo tests
///     would catch that — and you can extend this seed to also cover
///     them by registering the typed repos with the same `firestore`.
@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/repositories/collaborative_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_block_repository.dart';
import 'package:butlery/repositories/firebase/firebase_consent_repository.dart';
import 'package:butlery/repositories/interfaces/device_repository.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/interfaces/notification_batch_repository.dart';
import 'package:butlery/repositories/interfaces/notification_history_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/presence_service.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

class _MockUser extends Mock implements User {}

class _MockPresenceService extends Mock implements PresenceService {}

class _MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

class _MockNotificationHistoryRepository extends Mock
    implements NotificationHistoryRepository {}

class _MockNotificationBatchRepository extends Mock
    implements NotificationBatchRepository {}

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockConsentRepository extends Mock
    implements FirebaseConsentRepository {}

class _MockMessagingRepository extends Mock implements MessagingRepository {}

class _MockCollaborativeRecipeRepository extends Mock
    implements CollaborativeRecipeRepository {}

class _FakeException extends Fake implements Exception {}

const _deletedUid = 'user-to-delete';
const _otherUid = 'unrelated-user';

void main() {
  group('AccountDeletionService — post-deletion residual integrity', () {
    late AccountDeletionService service;
    late FakeFirebaseFirestore firestore;
    late FakeFirestoreRepository firestoreRepo;
    late MockAuthRepository mockAuthRepo;
    late _MockUser mockUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(_FakeException());
      // Bridge production ServiceLocator → test GetIt instance so
      // `_deleteBlockRecords` (which uses ServiceLocator.get) resolves
      // against the same registry our test populates.
      production.ServiceLocator.initialize(DIContainer());
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // FakeFirestoreRepository wraps a FakeFirebaseFirestore — share the
      // same instance with our seeding helper.
      firestoreRepo = FakeFirestoreRepository();
      firestore = firestoreRepo.firestore as FakeFirebaseFirestore;

      // Register a real FirebaseBlockRepository against the same fakeFirestore
      // so AccountDeletionService._deleteBlockRecords (which resolves via
      // ServiceLocator) actually deletes from our seeded state.
      // Using the production class — not a mock — because this test is the
      // one place we want the real cascade behaviour exercised end-to-end.

      mockUser = _MockUser();
      when(() => mockUser.uid).thenReturn(_deletedUid);
      when(() => mockUser.email).thenReturn('delete@example.com');
      when(() => mockUser.displayName).thenReturn('Deleted User');
      when(() => mockUser.delete()).thenAnswer((_) async {});

      mockAuthRepo = MockAuthRepository();
      mockAuthRepo.setAuthState(user: mockUser);

      TestServiceLocator.registerMock<FirebaseBlockRepository>(
        FirebaseBlockRepository(
          firestore: firestore,
          authRepository: mockAuthRepo,
        ),
      );

      final mockAuthService = MockAuthService();
      mockAuthService.setAuthState(
        currentUser: mockUser,
        isAuthenticated: true,
      );

      final mockUserService = MockUserService();
      final mockRecipeService = MockUnifiedRecipeService();
      final mockOfflineService = MockOfflineService();
      mockOfflineService.setOfflineState(
        isInitialized: true,
        currentUserId: _deletedUid,
      );
      when(() => mockOfflineService.clearUserData(any()))
          .thenAnswer((_) async => true);

      // Side-effect stubs — every interface repo that the cascade delegates
      // to MUST actually delete from FakeFirestore, otherwise the residual
      // probe is meaningless. Each `thenAnswer` mirrors what the production
      // implementation does on a real Firestore.

      final mockPresence = _MockPresenceService();
      when(() => mockPresence.deleteUserPresence(any()))
          .thenAnswer((inv) async {
        final uid = inv.positionalArguments.first as String;
        await firestore
            .collection(FirestoreCollections.presence)
            .doc(uid)
            .delete();
        return true;
      });

      // NotificationsRepository: deletes user_notifications + preferences.
      final mockNotificationsRepo = _MockNotificationsRepository();
      when(() => mockNotificationsRepo.deleteAllByUser(any()))
          .thenAnswer((inv) async {
        final uid = inv.positionalArguments.first as String;
        return await _deleteWhere(
          firestore,
          FirestoreCollections.userNotifications,
          'userId',
          uid,
        );
      });
      when(() => mockNotificationsRepo.deletePreferencesForUser(any()))
          .thenAnswer((inv) async {
        final uid = inv.positionalArguments.first as String;
        await firestore
            .collection(FirestoreCollections.userNotificationPreferences)
            .doc(uid)
            .delete();
        return true;
      });

      final mockNotificationHistoryRepo = _MockNotificationHistoryRepository();
      when(() => mockNotificationHistoryRepo.deleteAllByUser(any()))
          .thenAnswer((inv) async {
        final uid = inv.positionalArguments.first as String;
        return await _deleteWhere(
          firestore,
          FirestoreCollections.notificationHistory,
          'userId',
          uid,
        );
      });

      final mockNotificationBatchRepo = _MockNotificationBatchRepository();
      when(() => mockNotificationBatchRepo.deleteAllByUser(any()))
          .thenAnswer((inv) async {
        final uid = inv.positionalArguments.first as String;
        return await _deleteWhere(
          firestore,
          FirestoreCollections.notificationBatches,
          'userId',
          uid,
        );
      });

      // DeviceRepository: must wipe BOTH `user_fcm_tokens/{uid}` (top-level
      // doc) AND `users/{uid}/fcm_tokens` (subcollection). This is exactly
      // the dual-shape that BUT-498 commit-2 caught silently failing.
      final mockDeviceRepo = _MockDeviceRepository();
      when(() => mockDeviceRepo.deleteAllByUser(any())).thenAnswer((inv) async {
        final uid = inv.positionalArguments.first as String;
        await firestore
            .collection(FirestoreCollections.userFcmTokens)
            .doc(uid)
            .delete();
        final sub = await firestore
            .collection(FirestoreCollections.users)
            .doc(uid)
            .collection('fcm_tokens')
            .get();
        for (final d in sub.docs) {
          await d.reference.delete();
        }
        return sub.docs.length + 1;
      });

      // UserRepository: deletes users/{uid} root + public_profiles/{uid}.
      final mockUserRepo = _MockUserRepository();
      when(() => mockUserRepo.deleteUserRootDoc(any())).thenAnswer((inv) async {
        final uid = inv.positionalArguments.first as String;
        await firestore
            .collection(FirestoreCollections.users)
            .doc(uid)
            .delete();
        return true;
      });
      when(() => mockUserRepo.deletePublicProfile(any()))
          .thenAnswer((inv) async {
        final uid = inv.positionalArguments.first as String;
        await firestore
            .collection(FirestoreCollections.publicProfiles)
            .doc(uid)
            .delete();
        return true;
      });

      // ConsentRepository: deletes users/{uid}/consent subcollection.
      final mockConsentRepo = _MockConsentRepository();
      when(() => mockConsentRepo.deleteConsent(any())).thenAnswer((inv) async {
        final uid = inv.positionalArguments.first as String;
        final consentSub = await firestore
            .collection(FirestoreCollections.users)
            .doc(uid)
            .collection(FirestoreCollections.userConsent)
            .get();
        for (final d in consentSub.docs) {
          await d.reference.delete();
        }
        return true;
      });

      // MessagingRepository: deletes messages authored by user across all
      // conversations the user participated in. Production scrubs by
      // collectionGroup; we mirror with explicit traversal.
      final mockMessagingRepo = _MockMessagingRepository();
      when(() => mockMessagingRepo.deleteAllMessagesForUser(any()))
          .thenAnswer((inv) async {
        final uid = inv.positionalArguments.first as String;
        var deleted = 0;
        final convos = await firestore
            .collection(FirestoreCollections.conversations)
            .get();
        for (final c in convos.docs) {
          final msgs = await c.reference
              .collection(FirestoreCollections.messages)
              .where('senderId', isEqualTo: uid)
              .get();
          for (final m in msgs.docs) {
            await m.reference.delete();
            deleted++;
          }
        }
        return deleted;
      });

      final mockCollabRecipeRepo = _MockCollaborativeRecipeRepository();
      when(() => mockCollabRecipeRepo.deleteAllByUser(any()))
          .thenAnswer((inv) async {
        final uid = inv.positionalArguments.first as String;
        return await _deleteWhere(
          firestore,
          FirestoreCollections.realtimeRecipes,
          'userId',
          uid,
        );
      });

      final mockAnalytics = MockAnalyticsService();
      when(() => mockAnalytics.logAccountDeleted(any()))
          .thenAnswer((_) async {});

      service = AccountDeletionService(
        authRepository: mockAuthRepo,
        firestoreRepository: firestoreRepo,
        authService: mockAuthService,
        userService: mockUserService,
        recipeService: mockRecipeService,
        offlineService: mockOfflineService,
        presenceService: mockPresence,
        notificationsRepository: mockNotificationsRepo,
        notificationHistoryRepository: mockNotificationHistoryRepo,
        notificationBatchRepository: mockNotificationBatchRepo,
        deviceRepository: mockDeviceRepo,
        userRepository: mockUserRepo,
        consentRepository: mockConsentRepo,
        messagingRepository: mockMessagingRepo,
        collaborativeRecipeRepository: mockCollabRecipeRepo,
        analyticsService: mockAnalytics,
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test(
      'all FirebaseDataExportRepository collections have zero residual docs '
      'for the deleted UID after deleteUserAccount() (BUT-671)',
      () async {
        await _seedAllCollections(firestore, _deletedUid, _otherUid);

        // Sanity: seeding actually populated docs that the residual probe
        // would otherwise vacuously pass.
        final preDeletePrivateProfile = await firestore
            .collection(FirestoreCollections.users)
            .doc(_deletedUid)
            .get();
        expect(
          preDeletePrivateProfile.exists,
          isTrue,
          reason:
              'Seeding contract: private profile must exist before deletion',
        );

        // Act — drive the real cascade.
        try {
          await service.deleteUserAccount(
            reason: 'GDPR-residual-test',
            createAuditLog: false, // FakeFirestore + FieldValue.serverTimestamp
            // is fragile across versions; the audit-log path is covered by
            // account_deletion_integration_test.dart.
          );
        } catch (e) {
          // The cascade itself logs failures; we still want to assert
          // residuals so the test surfaces what was missed.
          // ignore: avoid_print
          print('[BUT-671] cascade threw (continuing to residual probe): $e');
        }

        // Now probe every collection enumerated in
        // FirebaseDataExportRepository. Each assertion has a clear failure
        // message naming the collection so a regression points at the
        // exact deletion path that broke.

        // ── content_export_manager residuals ──
        await _expectNoSubcollection(
          firestore,
          parent: 'users/$_deletedUid',
          sub: FirestoreCollections.menus,
          why:
              'personal menus should be wiped by ContentDeletionOps.deleteMenus',
        );
        // PRODUCTION RESIDUAL — see file header. ContentDeletionOps.deleteMenus
        // does NOT scrub the top-level `menus` collection. Assert the bug
        // still exists so a future fix flips this red and forces the file
        // header to be updated. Treat as a tripwire, not a regression.
        await _expectMatchingExists(
          firestore,
          collection: FirestoreCollections.menus,
          field: 'sharedByUserId',
          value: _deletedUid,
          why: 'TRIPWIRE: top-level menus where sharedByUserId == deletedUid '
              'are NOT scrubbed by current cascade. When this fails, the '
              'production bug has been fixed — flip to _expectNoMatching '
              'and update the file header.',
        );
        await _expectNoSubcollection(
          firestore,
          parent: 'users/$_deletedUid',
          sub: FirestoreCollections.userShoppingLists,
          why: 'personal shopping lists wiped by deleteShoppingLists',
        );

        // ── social_export_manager residuals ──
        await _expectNoSubcollection(
          firestore,
          parent: 'users/$_deletedUid',
          sub: FirestoreCollections.userFriends,
          why: 'friends subcollection wiped by removeFriendConnections',
        );
        await _expectNoSubcollection(
          firestore,
          parent: 'users/$_deletedUid',
          sub: FirestoreCollections.userFriendCategories,
          why:
              'friend_categories subcollection wiped by removeFriendConnections',
        );
        await _expectNoMatching(
          firestore,
          collection: FirestoreCollections.socialRequests,
          field: 'fromUserId',
          value: _deletedUid,
          why: 'outgoing social_requests wiped',
        );
        await _expectNoMatching(
          firestore,
          collection: FirestoreCollections.socialRequests,
          field: 'toUserId',
          value: _deletedUid,
          why: 'incoming social_requests wiped',
        );
        // Conversations themselves are NOT deleted (other participants
        // need them); only messages authored by the deleted user are
        // scrubbed. Verify that.
        final convos = await firestore
            .collection(FirestoreCollections.conversations)
            .get();
        for (final c in convos.docs) {
          final orphanMsgs = await c.reference
              .collection(FirestoreCollections.messages)
              .where('senderId', isEqualTo: _deletedUid)
              .get();
          expect(
            orphanMsgs.docs,
            isEmpty,
            reason: 'messages authored by deleted user must be scrubbed in '
                'conversation ${c.id}',
          );
        }
        // PRODUCTION RESIDUAL — see file header. The cascade has no scrub
        // for `sharedToUserIds` arrays on top-level menus. Tripwire: when
        // this fails, the bug is fixed — flip to _expectNoMatching with
        // arrayContains.
        await _expectMatchingExists(
          firestore,
          collection: FirestoreCollections.menus,
          field: 'sharedToUserIds',
          value: _deletedUid,
          arrayContains: true,
          why: 'TRIPWIRE: top-level menus.sharedToUserIds arrays are NOT '
              'scrubbed of deleted UID. Fix the cascade and flip this red.',
        );
        await _expectNoMatching(
          firestore,
          collection: FirestoreCollections.blocks,
          field: 'blockerId',
          value: _deletedUid,
          why: 'outgoing blocks wiped',
        );
        await _expectNoMatching(
          firestore,
          collection: FirestoreCollections.blocks,
          field: 'blockedUserId',
          value: _deletedUid,
          why: 'incoming blocks wiped',
        );
        await _expectNoSubcollection(
          firestore,
          parent: 'users/$_deletedUid',
          sub: FirestoreCollections.userConversationMemberships,
          why: 'conversation_memberships wiped',
        );

        // ── compliance_export_manager residuals ──
        await _expectNoSubcollection(
          firestore,
          parent: 'users/$_deletedUid',
          sub: FirestoreCollections.userConsent,
          why: 'consent history wiped (per Art 17, but see audit_logs for '
              'consent-event retention via BUT-665 24mo policy)',
        );

        // ── preferences_export_manager residuals ──
        final settingsDoc = await firestore
            .collection(FirestoreCollections.users)
            .doc(_deletedUid)
            .collection(FirestoreCollections.userSettings)
            .doc('preferences')
            .get();
        expect(
          settingsDoc.exists,
          isFalse,
          reason: 'users/{uid}/settings/preferences must be deleted',
        );
        // user_notifications already covered above by NotificationsRepository
        // stub; assert here too for the export-collection contract.
        await _expectNoMatching(
          firestore,
          collection: FirestoreCollections.userNotifications,
          field: 'userId',
          value: _deletedUid,
          why: 'user_notifications wiped',
        );
        final prefsTopDoc = await firestore
            .collection(FirestoreCollections.userNotificationPreferences)
            .doc(_deletedUid)
            .get();
        expect(
          prefsTopDoc.exists,
          isFalse,
          reason: 'user_notification_preferences/{uid} must be deleted',
        );
        // FCM tokens — both shapes (this is the BUT-498 regression class).
        final fcmTopDoc = await firestore
            .collection(FirestoreCollections.userFcmTokens)
            .doc(_deletedUid)
            .get();
        expect(
          fcmTopDoc.exists,
          isFalse,
          reason: 'user_fcm_tokens/{uid} (top-level shape) must be deleted '
              '— BUT-498 commit-2 regression class',
        );
        final fcmSub = await firestore
            .collection(FirestoreCollections.users)
            .doc(_deletedUid)
            .collection('fcm_tokens')
            .get();
        expect(
          fcmSub.docs,
          isEmpty,
          reason: 'users/{uid}/fcm_tokens (subcollection shape) must be wiped',
        );
        await _expectNoSubcollection(
          firestore,
          parent: 'users/$_deletedUid',
          sub: FirestoreCollections.categoryPreferences,
          why: 'category_preferences subcollection wiped',
        );
        await _expectNoSubcollection(
          firestore,
          parent: 'users/$_deletedUid',
          sub: FirestoreCollections.listCategoryOrders,
          why: 'list_category_orders subcollection wiped',
        );

        // ── profile residuals ──
        final privateProfile = await firestore
            .collection(FirestoreCollections.users)
            .doc(_deletedUid)
            .get();
        expect(
          privateProfile.exists,
          isFalse,
          reason: 'users/{uid} root document must be deleted (Tier 3)',
        );
        final publicProfile = await firestore
            .collection(FirestoreCollections.publicProfiles)
            .doc(_deletedUid)
            .get();
        expect(
          publicProfile.exists,
          isFalse,
          reason: 'public_profiles/{uid} must be deleted',
        );

        // ── retention exception: audit_logs ──
        // GDPR Art 30 + BUT-665 retention windows. Audit events authored by
        // the deleted user are NOT deleted by the cascade — they are
        // purged on the BUT-665 schedule (24mo for consent, 6mo for
        // general). Document this explicitly so a future regression that
        // adds erasure here is caught by intent, not surprise.
        // (No assertion; this comment IS the contract.)

        // ── unrelated-user data must be untouched ──
        final otherUserDoc = await firestore
            .collection(FirestoreCollections.users)
            .doc(_otherUid)
            .get();
        expect(
          otherUserDoc.exists,
          isTrue,
          reason: 'cascade must not touch unrelated users — '
              'this catches an over-broad delete',
        );
        await _expectMatchingExists(
          firestore,
          collection: FirestoreCollections.menus,
          field: 'sharedByUserId',
          value: _otherUid,
          why: 'other user\'s menus must remain',
        );
      },
    );
  });
}

// ── helpers ──

/// Deletes all docs in [collection] where [field] == [value]. Returns the
/// number deleted. Mirrors what production batch helpers do on real
/// Firestore.
Future<int> _deleteWhere(
  FakeFirebaseFirestore firestore,
  String collection,
  String field,
  Object value,
) async {
  final snap = await firestore
      .collection(collection)
      .where(field, isEqualTo: value)
      .get();
  for (final d in snap.docs) {
    await d.reference.delete();
  }
  return snap.docs.length;
}

Future<void> _expectNoSubcollection(
  FakeFirebaseFirestore firestore, {
  required String parent,
  required String sub,
  required String why,
}) async {
  final parts = parent.split('/');
  final snap =
      await firestore.collection(parts[0]).doc(parts[1]).collection(sub).get();
  expect(snap.docs, isEmpty, reason: '$parent/$sub must be empty: $why');
}

Future<void> _expectNoMatching(
  FakeFirebaseFirestore firestore, {
  required String collection,
  required String field,
  required Object value,
  bool arrayContains = false,
  required String why,
}) async {
  final query = arrayContains
      ? firestore.collection(collection).where(field, arrayContains: value)
      : firestore.collection(collection).where(field, isEqualTo: value);
  final snap = await query.get();
  expect(snap.docs, isEmpty, reason: '$collection where $field=$value: $why');
}

Future<void> _expectMatchingExists(
  FakeFirebaseFirestore firestore, {
  required String collection,
  required String field,
  required Object value,
  bool arrayContains = false,
  required String why,
}) async {
  final query = arrayContains
      ? firestore.collection(collection).where(field, arrayContains: value)
      : firestore.collection(collection).where(field, isEqualTo: value);
  final snap = await query.get();
  expect(snap.docs, isNotEmpty,
      reason: '$collection where $field=$value: $why');
}

/// Seeds at least one document in every collection enumerated in
/// [FirebaseDataExportRepository]. Also seeds an unrelated-user document
/// in collections where a stray over-broad delete could nuke it.
Future<void> _seedAllCollections(
  FakeFirebaseFirestore fs,
  String deletedUid,
  String otherUid,
) async {
  // Private + public profile.
  await fs.collection(FirestoreCollections.users).doc(deletedUid).set({
    'displayName': 'Deleted User',
    'email': 'delete@example.com',
  });
  await fs.collection(FirestoreCollections.users).doc(otherUid).set({
    'displayName': 'Untouched User',
  });
  await fs.collection(FirestoreCollections.publicProfiles).doc(deletedUid).set({
    'displayName': 'Deleted Public',
  });

  // Personal menus subcollection.
  await fs
      .collection(FirestoreCollections.users)
      .doc(deletedUid)
      .collection(FirestoreCollections.menus)
      .doc('m1')
      .set({'name': 'Family menu'});

  // Top-level menus shared BY user.
  await fs.collection(FirestoreCollections.menus).doc('shared-by-deleted').set({
    'sharedByUserId': deletedUid,
    'name': 'Shared menu',
  });
  // Top-level menus shared TO user (UID in array).
  await fs.collection(FirestoreCollections.menus).doc('shared-to-deleted').set({
    'sharedByUserId': otherUid,
    'sharedToUserIds': [deletedUid, otherUid],
    'name': 'Inbound shared menu',
  });
  // Other user's menu — must NOT be touched.
  await fs.collection(FirestoreCollections.menus).doc('owned-by-other').set({
    'sharedByUserId': otherUid,
    'name': 'Untouched menu',
  });

  // Personal shopping lists + items subcollection.
  final listRef = fs
      .collection(FirestoreCollections.users)
      .doc(deletedUid)
      .collection(FirestoreCollections.userShoppingLists)
      .doc('list1');
  await listRef.set({'name': 'Veckans'});
  await listRef
      .collection(FirestoreCollections.items)
      .doc('item1')
      .set({'text': 'Mjölk'});

  // Friends subcollection.
  await fs
      .collection(FirestoreCollections.users)
      .doc(deletedUid)
      .collection(FirestoreCollections.userFriends)
      .doc('f1')
      .set({'friendId': otherUid});

  // Friend categories.
  await fs
      .collection(FirestoreCollections.users)
      .doc(deletedUid)
      .collection(FirestoreCollections.userFriendCategories)
      .doc('cat1')
      .set({'name': 'Closest'});

  // Social requests (outgoing + incoming).
  await fs
      .collection(FirestoreCollections.socialRequests)
      .doc('out1')
      .set({'fromUserId': deletedUid, 'toUserId': otherUid, 'type': 'friend'});
  await fs
      .collection(FirestoreCollections.socialRequests)
      .doc('in1')
      .set({'fromUserId': otherUid, 'toUserId': deletedUid, 'type': 'friend'});

  // Conversations + messages (deleted user as participant + author).
  final convoRef =
      fs.collection(FirestoreCollections.conversations).doc('convo1');
  await convoRef.set({
    'participantIds': [deletedUid, otherUid],
    'createdAt': Timestamp.now(),
  });
  await convoRef
      .collection(FirestoreCollections.messages)
      .doc('msg-deleted-1')
      .set({'senderId': deletedUid, 'text': 'hi'});
  await convoRef
      .collection(FirestoreCollections.messages)
      .doc('msg-other-1')
      .set({'senderId': otherUid, 'text': 'hello'});

  // Blocks (outgoing + incoming).
  // FIELD-NAME INCONSISTENCY (filed as production residual):
  // FirebaseBlockRepository writes `blockedId` (and queries that field on
  // delete), but FirebaseDataExportRepository.exportIncomingBlocks queries
  // `blockedUserId`. They cannot both be right. Seed BOTH field names so
  // the cascade (which uses `blockedId`) actually deletes its own data,
  // and the data-export field-name mismatch is documented in the test
  // header. Production fix: pick one, migrate, update both repos.
  await fs.collection(FirestoreCollections.blocks).doc('block-out').set({
    'blockerId': deletedUid,
    'blockedId': otherUid,
    'blockedUserId': otherUid, // mirror for export-repo's query
  });
  await fs.collection(FirestoreCollections.blocks).doc('block-in').set({
    'blockerId': otherUid,
    'blockedId': deletedUid,
    'blockedUserId': deletedUid, // mirror for export-repo's query
  });

  // Conversation memberships subcollection.
  await fs
      .collection(FirestoreCollections.users)
      .doc(deletedUid)
      .collection(FirestoreCollections.userConversationMemberships)
      .doc('convo1')
      .set({'lastReadAt': Timestamp.now()});

  // Consent history + current.
  await fs
      .collection(FirestoreCollections.users)
      .doc(deletedUid)
      .collection(FirestoreCollections.userConsent)
      .doc('current')
      .set({'consentVersion': 'v1', 'purposes': {}});
  await fs
      .collection(FirestoreCollections.users)
      .doc(deletedUid)
      .collection(FirestoreCollections.userConsent)
      .doc('history-1')
      .set({'consentVersion': 'v0', 'timestamp': Timestamp.now()});

  // Settings/preferences.
  await fs
      .collection(FirestoreCollections.users)
      .doc(deletedUid)
      .collection(FirestoreCollections.userSettings)
      .doc('preferences')
      .set({'theme': 'dark'});

  // user_notifications.
  await fs
      .collection(FirestoreCollections.userNotifications)
      .doc('n1')
      .set({'userId': deletedUid, 'title': 'Hej'});
  await fs
      .collection(FirestoreCollections.userNotifications)
      .doc('n-other')
      .set({'userId': otherUid, 'title': 'Hello'});

  // Notification preferences (top-level).
  await fs
      .collection(FirestoreCollections.userNotificationPreferences)
      .doc(deletedUid)
      .set({'pushEnabled': true});

  // FCM tokens — BOTH shapes (this is the BUT-498 regression class).
  await fs
      .collection(FirestoreCollections.userFcmTokens)
      .doc(deletedUid)
      .set({'token': 'top-level-token'});
  await fs
      .collection(FirestoreCollections.users)
      .doc(deletedUid)
      .collection('fcm_tokens')
      .doc('device-1')
      .set({'token': 'sub-token-1'});

  // Category preferences + list category orders.
  await fs
      .collection(FirestoreCollections.users)
      .doc(deletedUid)
      .collection(FirestoreCollections.categoryPreferences)
      .doc('pref1')
      .set({'category': 'meat'});
  await fs
      .collection(FirestoreCollections.users)
      .doc(deletedUid)
      .collection(FirestoreCollections.listCategoryOrders)
      .doc('list1')
      .set({'order': []});

  // Realtime recipes (CollaborativeRecipeRepository).
  await fs
      .collection(FirestoreCollections.realtimeRecipes)
      .doc('rt1')
      .set({'userId': deletedUid, 'data': {}});

  // Notification history + batches (covered by repo stubs).
  await fs
      .collection(FirestoreCollections.notificationHistory)
      .doc('h1')
      .set({'userId': deletedUid});
  await fs
      .collection(FirestoreCollections.notificationBatches)
      .doc('b1')
      .set({'userId': deletedUid});

  // Presence.
  await fs
      .collection(FirestoreCollections.presence)
      .doc(deletedUid)
      .set({'state': 'online'});
}

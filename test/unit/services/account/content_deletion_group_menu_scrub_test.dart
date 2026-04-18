/// Tests for the GDPR scrub path on group weekly menu plans (BUT-405).
///
/// When a user deletes their account, the existing personal
/// `weekly_menu_plans` are deleted outright. Group plans — collaborative
/// and collectively owned — must instead have the user scrubbed from the
/// `participants` / `participantUserIds` / `memberPermissions` fields.
/// If the scrub leaves zero participants, the plan is orphaned and gets
/// deleted; otherwise it persists for the remaining members.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/services/account/account_deletion/content_deletion_operations.dart';

const _groupPlansCollection = FirestoreCollections.groupWeeklyMenuPlans;
const _personalPlansCollection = FirestoreCollections.weeklyMenuPlans;

Future<void> _seedGroupPlan(
  FakeFirebaseFirestore firestore, {
  required String docId,
  required String groupId,
  required List<Map<String, dynamic>> participants,
}) async {
  final userIds =
      participants.map((p) => p['userId'] as String).toList(growable: false);
  final perms = <String, String>{
    for (final p in participants)
      (p['userId'] as String): p['permission'] as String,
  };
  await firestore.collection(_groupPlansCollection).doc(docId).set({
    'groupId': groupId,
    'weekStartDate': Timestamp.now(),
    'entries': <Map<String, dynamic>>[],
    'participants': participants,
    'participantUserIds': userIds,
    'memberPermissions': perms,
    'createdAt': Timestamp.now(),
    'lastModifiedAt': Timestamp.now(),
  });
}

void main() {
  group('ContentDeletionOperations — group weekly menu plan scrub', () {
    late FakeFirebaseFirestore firestore;
    late ContentDeletionOperations ops;

    const departingUser = 'user-leaving';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      ops = ContentDeletionOperations(firestore);
    });

    test(
        'should remove the departing user from participants, '
        'participantUserIds, and memberPermissions when other members remain',
        () async {
      await _seedGroupPlan(
        firestore,
        docId: 'fam-abc_2026-W15',
        groupId: 'fam-abc',
        participants: [
          {
            'userId': 'user-alpha',
            'permission': 'admin',
            'addedAt': Timestamp.now(),
          },
          {
            'userId': departingUser,
            'permission': 'edit',
            'addedAt': Timestamp.now(),
          },
          {
            'userId': 'user-gamma',
            'permission': 'view',
            'addedAt': Timestamp.now(),
          },
        ],
      );

      // Personal plans deletion path — must succeed even when there are
      // no personal docs for the user; this is the entry point that also
      // triggers the group scrub.
      final ok = await ops.deleteWeeklyMenuPlans(departingUser);
      expect(ok, isTrue);

      final doc = await firestore
          .collection(_groupPlansCollection)
          .doc('fam-abc_2026-W15')
          .get();
      expect(doc.exists, isTrue,
          reason: 'plan must persist when other participants remain');

      final data = doc.data()!;
      final userIds = (data['participantUserIds'] as List).cast<String>();
      expect(userIds, equals(['user-alpha', 'user-gamma']));

      final perms = Map<String, dynamic>.from(data['memberPermissions']);
      expect(perms.containsKey(departingUser), isFalse,
          reason: 'memberPermissions must drop the departing user');
      expect(perms['user-alpha'], 'admin');
      expect(perms['user-gamma'], 'view');

      final participants = (data['participants'] as List)
          .cast<Map<dynamic, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      expect(
        participants.any((p) => p['userId'] == departingUser),
        isFalse,
        reason: 'structured participants list must drop the departing user',
      );
      expect(participants, hasLength(2));
    });

    test(
        'should delete the plan when the departing user was the sole '
        'participant (orphaned-plan cleanup)', () async {
      await _seedGroupPlan(
        firestore,
        docId: 'solo-group_2026-W15',
        groupId: 'solo-group',
        participants: [
          {
            'userId': departingUser,
            'permission': 'admin',
            'addedAt': Timestamp.now(),
          },
        ],
      );

      final ok = await ops.deleteWeeklyMenuPlans(departingUser);
      expect(ok, isTrue);

      final doc = await firestore
          .collection(_groupPlansCollection)
          .doc('solo-group_2026-W15')
          .get();
      expect(doc.exists, isFalse,
          reason: 'orphaned plans (zero participants) must be deleted');
    });

    test(
        'should leave plans untouched when the departing user was not a '
        'participant', () async {
      await _seedGroupPlan(
        firestore,
        docId: 'other-fam_2026-W15',
        groupId: 'other-fam',
        participants: [
          {
            'userId': 'stranger-1',
            'permission': 'admin',
            'addedAt': Timestamp.now(),
          },
          {
            'userId': 'stranger-2',
            'permission': 'edit',
            'addedAt': Timestamp.now(),
          },
        ],
      );

      final ok = await ops.deleteWeeklyMenuPlans(departingUser);
      expect(ok, isTrue);

      final doc = await firestore
          .collection(_groupPlansCollection)
          .doc('other-fam_2026-W15')
          .get();
      expect(doc.exists, isTrue);
      final userIds =
          (doc.data()!['participantUserIds'] as List).cast<String>();
      expect(userIds, equals(['stranger-1', 'stranger-2']),
          reason: 'unrelated plan membership must be preserved verbatim');
    });

    test(
        'should still delete personal plans (existing contract) while ALSO '
        'performing the group scrub — the two paths coexist', () async {
      // Seed a personal plan + a group plan with the user on both.
      await firestore
          .collection(_personalPlansCollection)
          .doc('${departingUser}_2026-W15')
          .set({
        'userId': departingUser,
        'weekStartDate': Timestamp.now(),
        'entries': <Map<String, dynamic>>[],
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      await _seedGroupPlan(
        firestore,
        docId: 'fam-abc_2026-W15',
        groupId: 'fam-abc',
        participants: [
          {
            'userId': departingUser,
            'permission': 'edit',
            'addedAt': Timestamp.now(),
          },
          {
            'userId': 'user-remaining',
            'permission': 'admin',
            'addedAt': Timestamp.now(),
          },
        ],
      );

      final ok = await ops.deleteWeeklyMenuPlans(departingUser);
      expect(ok, isTrue);

      // Personal plan gone.
      final personal = await firestore
          .collection(_personalPlansCollection)
          .doc('${departingUser}_2026-W15')
          .get();
      expect(personal.exists, isFalse);

      // Group plan scrubbed, not deleted (one member remains).
      final group = await firestore
          .collection(_groupPlansCollection)
          .doc('fam-abc_2026-W15')
          .get();
      expect(group.exists, isTrue);
      expect(
        (group.data()!['participantUserIds'] as List).cast<String>(),
        equals(['user-remaining']),
      );
    });
  });
}

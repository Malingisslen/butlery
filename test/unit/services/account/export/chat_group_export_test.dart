/// GDPR Article-15 coverage for [ChatGroupExport] (BUT-1838).
///
/// The section exists for ONE fact that lives nowhere else in the bundle:
/// who added the requester to each chat group. Everything else about the
/// group is already in `conversation_info`, so this leg is a PROJECTION and
/// the review question is what it leaves out as much as what it carries.
///
/// Driven through the REAL [FirebaseDataExportRepository] over
/// `FakeFirebaseFirestore`, seeded with the shape the group callables write.
/// A hand-typed fixture handed to a repository `Fake` could not answer the
/// question this file exists for: `createdAt` has to be a genuine Firestore
/// `Timestamp` for the encode test to mean anything, and the ownership
/// filter has to be the repository's own `array-contains`. The one `Fake`
/// below is used only where the repository must FAIL.
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/chat_group_export.dart';

import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../test_support/base_unit_test.dart';

/// Only for the failure branch — the real repository cannot be made to throw
/// on demand, and that branch is the one a data subject feels.
class _ThrowingExportRepository extends Fake
    implements FirebaseDataExportRepository {
  @override
  Future<List<Map<String, dynamic>>> exportChatGroups(
    String userId, {
    int maxGroups = 100,
  }) async => throw FirebaseException(
    plugin: 'cloud_firestore',
    code: 'permission-denied',
    message: 'Missing or insufficient permissions',
  );
}

void main() {
  group('ChatGroupExport', () {
    late FirebaseDataExportRepository repository;
    late FakeFirebaseFirestore firestore;
    late FakeAuthRepository auth;

    const userId = 'user-requester';
    const otherUid = 'user-other';
    const inviterUid = 'user-inviter';
    const groupId = 'chat-group-1';

    // Distinct literals per field: no two values in the fixture are equal, so
    // a projection that read the wrong key cannot coincidentally pass.
    final createdAt = DateTime.utc(2026, 4, 5, 6, 7, 8);

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = FakeAuthRepository();
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

    /// Seeds a group document in the shape `createChatGroup` writes, including
    /// the uid-keyed maps the projection must NOT carry through.
    Future<void> seedGroup({
      String id = groupId,
      List<String> memberIds = const [userId, otherUid, inviterUid],
    }) async {
      await firestore.collection(FirestoreCollections.chatGroups).doc(id).set(
        <String, dynamic>{
          'name': 'Middagsgänget',
          'memberIds': memberIds,
          'adminIds': const [inviterUid],
          'conversationId': 'conv-for-$id',
          'createdBy': inviterUid,
          // A real Firestore Timestamp — the whole point of the encode test.
          'createdAt': Timestamp.fromDate(createdAt),
          'updatedAt': Timestamp.fromDate(createdAt),
          'memberAddedBy': <String, dynamic>{
            userId: inviterUid,
            // Third-party behaviour: who invited SOMEBODY ELSE.
            otherUid: 'user-someone-else-entirely',
          },
          'memberDisplayNames': <String, dynamic>{
            userId: 'Requester',
            otherUid: 'Other Person',
          },
          'memberAvatarUrls': <String, dynamic>{
            otherUid: 'https://cdn/other-persons-face.png',
          },
        },
      );
    }

    test('exports the projection, not the document', () async {
      await seedGroup();

      final section = await ChatGroupExport(repository).export(userId);
      final groups = (section['chat_groups'] as List)
          .cast<Map<String, dynamic>>();

      expect(groups, hasLength(1));
      final row = groups.single;

      expect(row['group_id'], groupId);
      expect(row['name'], 'Middagsgänget');
      expect(row['conversation_id'], 'conv-for-$groupId');
      expect(row['created_by'], inviterUid);
      expect(row['admin_ids'], [inviterUid]);

      // EXACT key set, not `contains`. The section is a projection by
      // decision, so widening it should have to be a deliberate edit here —
      // a new key silently appearing is how a projection becomes a dump.
      expect(row.keys.toSet(), {
        'group_id',
        'name',
        'conversation_id',
        'created_by',
        'created_at',
        'admin_ids',
        'you_were_added_by',
      });

      // The three uid-keyed maps `conversation_info` already covers.
      final encoded = json.encode(section);
      expect(encoded, isNot(contains('memberDisplayNames')));
      expect(encoded, isNot(contains('memberAvatarUrls')));
      expect(encoded, isNot(contains('https://cdn/other-persons-face.png')));
      expect(encoded, isNot(contains('memberIds')));
    });

    test(
      'the section is JSON-encodable — a raw Timestamp here would throw the '
      'WHOLE bundle at encode time',
      () async {
        // The failure this guards is not local. `jsonEncode` runs once, after
        // every section is gathered, so an unsanitised Timestamp in this leg
        // means the data subject receives NO FILE — not a degraded section.
        // No try/catch inside ChatGroupExport can catch that, which is why
        // the assertion has to be an encode rather than a type check.
        await seedGroup();

        final section = await ChatGroupExport(repository).export(userId);

        expect(() => json.encode(section), returnsNormally);

        final row =
            (section['chat_groups'] as List).first as Map<String, dynamic>;
        expect(
          row['created_at'],
          isA<String>(),
          reason: 'sanitizeForJson renders a Timestamp as ISO-8601',
        );
        // Compared as an INSTANT, not as a literal string.
        // `sanitizeForJson` renders `Timestamp.toDate()`, which comes back
        // LOCAL-flagged, so the text carries the runner's offset and no
        // fixed literal is portable. `isAtSameMomentAs` still pins the
        // VALUE — a projection reading `updatedAt`, or dropping the field,
        // fails it — while surviving a CI box in another timezone.
        expect(
          DateTime.parse(row['created_at'] as String).isAtSameMomentAs(
            createdAt,
          ),
          isTrue,
          reason:
              'created_at must survive sanitisation unchanged: '
              'got ${row['created_at']}, expected the instant $createdAt',
        );
        expect(
          row['created_at'],
          isNot(isA<Timestamp>()),
          reason: 'premise: the stored value really was a Timestamp',
        );
      },
    );

    test(
      'keeps the requester s own inviter and drops everyone else s',
      () async {
        // The single fact this section exists for, and the third-party
        // boundary around it. `memberAddedBy` is a uid-keyed map exactly like
        // the three the conversations section redacts.
        await seedGroup();

        final section = await ChatGroupExport(repository).export(userId);
        final row =
            (section['chat_groups'] as List).first as Map<String, dynamic>;

        expect(row['you_were_added_by'], inviterUid);
        expect(
          json.encode(section),
          isNot(contains('user-someone-else-entirely')),
          reason: 'who invited ANOTHER member is third-party behaviour',
        );
      },
    );

    test('a group the requester does not belong to is absent', () async {
      // Ownership-negative. The repository filters on
      // `memberIds array-contains`, so a group naming only other people must
      // not appear — with a positive control in the same fixture so an empty
      // result cannot pass for the wrong reason.
      await seedGroup();
      await seedGroup(
        id: 'chat-group-strangers',
        memberIds: const [otherUid, inviterUid],
      );

      final section = await ChatGroupExport(repository).export(userId);
      final ids = (section['chat_groups'] as List)
          .cast<Map<String, dynamic>>()
          .map((g) => g['group_id'])
          .toList();

      expect(ids, [groupId]);
      expect(ids, isNot(contains('chat-group-strangers')));
    });

    test('empty-safe — no groups is not an error', () async {
      final section = await ChatGroupExport(repository).export(userId);

      expect(section['chat_groups'], isEmpty);
      expect(
        section.containsKey('error_code'),
        isFalse,
        reason:
            'a user in no chat groups has a COMPLETE section; marking it '
            'failed would put a false warning in export_metadata',
      );
    });

    test(
      'a repository failure yields the error_code marker instead of throwing',
      () async {
        // The section must degrade rather than take the messages section —
        // the far larger Art. 15 obligation — down with it.
        final section = await ChatGroupExport(
          _ThrowingExportRepository(),
        ).export(userId);

        expect(section['chat_groups'], isEmpty);
        expect(section['error_code'], 'chat-groups-export-failed');
        // Still encodable: a degraded section must not break the bundle
        // either.
        expect(() => json.encode(section), returnsNormally);
      },
    );
  });
}

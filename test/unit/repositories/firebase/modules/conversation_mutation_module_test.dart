/// Unit tests for ConversationMutationModule.
///
/// The write module for direct-conversation creation, rename, deletion and
/// per-user settings. Since BUT-1838 it injects NO callbacks: the four seams it
/// used to take (`createFn`, `updateFn`, `readFn`, `sendMessageFn`) all
/// resolved through `UserScopedFirebaseRepository` to a path nothing writes for
/// a chat group, which is what broke group rename. Every assertion here
/// therefore reads Firestore back rather than capturing an invocation — and the
/// compiler now enforces what a "the seam was not consulted" test used to.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/firebase/modules/conversation_mutation_module.dart';

const _convoCollection = 'conversations';
void main() {
  group('createDirectConversation', () {
    test('uses deterministic id sorted by user id', () async {
      final firestore = FakeFirebaseFirestore();
      final module = ConversationMutationModule(
        firestore: firestore,
        collectionName: _convoCollection,
      );

      // Pass user-b first; output should still sort: direct_user-a_user-b
      final id = await module.createDirectConversation(
        user1Id: 'user-b',
        user1DisplayName: 'B',
        user2Id: 'user-a',
        user2DisplayName: 'A',
      );

      expect(id, equals('direct_user-a_user-b'));
    });

    test('returns existing conversation id without re-creating', () async {
      final firestore = FakeFirebaseFirestore();
      // Pre-seed the deterministic-id doc.
      await firestore
          .collection(_convoCollection)
          .doc('direct_user-a_user-b')
          .set({'title': 'preexisting'});

      final module = ConversationMutationModule(
        firestore: firestore,
        collectionName: _convoCollection,
      );

      final id = await module.createDirectConversation(
        user1Id: 'user-a',
        user1DisplayName: 'A',
        user2Id: 'user-b',
        user2DisplayName: 'B',
      );

      expect(id, equals('direct_user-a_user-b'));
      // The existing-doc short-circuit must fire, so the pre-existing payload
      // is untouched — a re-create would overwrite the title below.
      final doc = await firestore
          .collection(_convoCollection)
          .doc('direct_user-a_user-b')
          .get();
      expect(doc.data()?['title'], equals('preexisting'));
    });

    test('persists the new conversation when none exists', () async {
      final firestore = FakeFirebaseFirestore();
      final module = ConversationMutationModule(
        firestore: firestore,
        collectionName: _convoCollection,
      );

      await module.createDirectConversation(
        user1Id: 'user-a',
        user1DisplayName: 'A',
        user2Id: 'user-b',
        user2DisplayName: 'B',
      );

      final doc = await firestore
          .collection(_convoCollection)
          .doc('direct_user-a_user-b')
          .get();
      expect(doc.exists, isTrue);
      // Both participants seeded under participantDisplayNames map.
      final names = Map<String, dynamic>.from(
        doc.data()?['participantDisplayNames'] as Map,
      );
      expect(names['user-a'], equals('A'));
      expect(names['user-b'], equals('B'));
    });
  });

  // BUT-1838: createGroupConversation is deleted from this module (and from
  // MessagingRepository/FirebaseMessagingRepository) — group creation goes
  // through ChatGroupRepository.createGroup instead. See
  // create_group_conversation_viewmodel_test.dart for the replacement
  // coverage.

  group('updateConversation', () {
    test(
      'rejects missing conversation with ResourceNotFoundException',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = ConversationMutationModule(
          firestore: firestore,
          collectionName: _convoCollection,
          // Nothing is seeded at this id, so the throw can only come from the
          // TOP-LEVEL read. There is no injected seam left that could answer
          // instead — that is the point of this ticket, and the constructor
          // signature is now what proves it.
        );

        await expectLater(
          module.updateConversation(
            conversationId: 'missing',
            title: 'New Title',
          ),
          throwsA(isA<ResourceNotFoundException>()),
        );
      },
    );

    // BUT-1838: the contract CHANGED here, and both halves of the change are
    // load-bearing, so both are pinned.
    //
    // It used to read through `readFn` and write the whole document back
    // through `updateFn` — both of which `UserScopedFirebaseRepository`
    // rewrites to `users/{uid}/conversations/{id}`. A chat group's conversation
    // exists only at the TOP level, so renaming one threw "Conversation not
    // found" at its admin, every time.
    //
    // The write narrowed too: sending the whole document back re-sends
    // `participantIds` and `createdAt`, which the conversations update rule
    // denies on any diff (BUT-1831). A field-path update cannot trip it.
    test('renames the TOP-LEVEL document, not the user-scoped copy', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection(_convoCollection).doc('group-1').set({
        'title': 'Old Title',
        'participantIds': ['u1', 'u2', 'u3'],
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'groupId': 'group-1',
      });
      // The group document must exist, and the rename must reach it: the name
      // lives in TWO documents (the export reads `chat_groups.name`, the chat
      // list renders `conversations.title`) and the ADMIN-only rule is on the
      // group. Writing the group FIRST is what makes the server's answer the
      // gate — a non-admin fails before anything visible changes.
      await firestore.collection('chat_groups').doc('group-1').set({
        'name': 'Old Title',
        'adminIds': ['u1'],
      });
      final module = ConversationMutationModule(
        firestore: firestore,
        collectionName: _convoCollection,
        // No seams: the module can only reach the documents seeded above, so
        // every assertion below is about what is really stored rather than
        // about what a callback was handed.
      );

      await module.updateConversation(
        conversationId: 'group-1',
        title: 'New Title',
        metadata: const {'pinned': true},
      );

      final stored = await firestore
          .collection(_convoCollection)
          .doc('group-1')
          .get();
      expect(stored.data()!['title'], equals('New Title'));
      final storedGroup = await firestore
          .collection('chat_groups')
          .doc('group-1')
          .get();
      expect(
        storedGroup.data()!['name'],
        equals('New Title'),
        reason: 'the export reads this name; it must not drift from the title',
      );
      expect(stored.data()!['metadata']['pinned'], isTrue);
      // The two keys the update rule denies must be untouched by the write, not
      // merely unchanged in value — a whole-document write that happens to
      // round-trip them identically is the shape that breaks the day a
      // timestamp is re-stamped.
      expect(
        (stored.data()!['participantIds'] as List).length,
        equals(3),
        reason: 'membership is server-owned and must survive a rename',
      );
      // `isAtSameMomentAs`, not `equals`: Timestamp.toDate() returns a
      // LOCAL-flagged DateTime, so an equality assertion passes only on a
      // UTC machine and reddens on a CI box in another timezone.
      expect(
        (stored.data()!['createdAt'] as Timestamp).toDate().isAtSameMomentAs(
          DateTime.utc(2026, 1, 1),
        ),
        isTrue,
      );
    });
  });

  // BUT-1838: addParticipants and removeParticipant are deleted from this
  // module (and from MessagingRepository/FirebaseMessagingRepository) —
  // group membership changes go through ChatGroupRepository.addMembers/
  // removeMember instead. See group_detail_viewmodel_test.dart and
  // conversations_viewmodel_test.dart for the replacement coverage.

  group('deleteConversation', () {
    test(
      'removes the doc and every message tagged with the conversation id',
      () async {
        final firestore = FakeFirebaseFirestore();
        final messagesRef = firestore.collection('messages');
        await firestore.collection(_convoCollection).doc('group-1').set({
          'title': 'Squad',
        });
        // 3 messages tied to group-1, 1 to group-2 (must NOT be touched).
        await messagesRef.doc('m-1').set({
          'conversationId': 'group-1',
          'content': 'a',
        });
        await messagesRef.doc('m-2').set({
          'conversationId': 'group-1',
          'content': 'b',
        });
        await messagesRef.doc('m-3').set({
          'conversationId': 'group-1',
          'content': 'c',
        });
        await messagesRef.doc('m-4').set({
          'conversationId': 'group-2',
          'content': 'x',
        });

        final module = ConversationMutationModule(
          firestore: firestore,
          collectionName: _convoCollection,
        );

        await module.deleteConversation('group-1', messagesRef);

        // The convo doc is gone.
        final convoDoc = await firestore
            .collection(_convoCollection)
            .doc('group-1')
            .get();
        expect(convoDoc.exists, isFalse);
        // All group-1 messages gone, group-2 message survives.
        final remaining = await messagesRef.get();
        expect(remaining.docs.map((d) => d.id).toList(), equals(['m-4']));
      },
    );
  });

  group('updateConversationUserSettings', () {
    test('no-ops on empty settings map', () async {
      final firestore = FakeFirebaseFirestore();
      final module = ConversationMutationModule(
        firestore: firestore,
        collectionName: _convoCollection,
      );

      await module.updateConversationUserSettings(
        conversationId: 'group-1',
        userId: 'user-a',
        settings: const {},
      );

      // No doc should be touched.
      final doc = await firestore
          .collection(_convoCollection)
          .doc('group-1')
          .get();
      expect(doc.exists, isFalse);
    });

    test('merges per-user settings into the document', () async {
      final firestore = FakeFirebaseFirestore();
      final module = ConversationMutationModule(
        firestore: firestore,
        collectionName: _convoCollection,
      );

      await module.updateConversationUserSettings(
        conversationId: 'group-1',
        userId: 'user-a',
        settings: const {'pinned': true},
      );

      final doc = await firestore
          .collection(_convoCollection)
          .doc('group-1')
          .get();
      expect(doc.exists, isTrue);
      final perUser = Map<String, dynamic>.from(
        doc.data()?['perUserSettings'] as Map,
      );
      final userA = Map<String, dynamic>.from(perUser['user-a'] as Map);
      expect(userA['pinned'], isTrue);
    });

    test(
      'subsequent merge preserves other keys for the same user',
      skip:
          'fake_cloud_firestore does not honour dot-path mergeFields the way '
          'production Firestore does; the second set() overwrites the whole '
          'perUserSettings.<user> sub-map. The production code IS correct '
          '(see lib comment) — this contract is enforced by Firestore '
          'security rules in prod. Re-enable when an emulator-backed integration '
          'test is added.',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = ConversationMutationModule(
          firestore: firestore,
          collectionName: _convoCollection,
        );

        // First: pinned=true
        await module.updateConversationUserSettings(
          conversationId: 'group-1',
          userId: 'user-a',
          settings: const {'pinned': true},
        );
        // Then: archived=true (must NOT erase pinned)
        await module.updateConversationUserSettings(
          conversationId: 'group-1',
          userId: 'user-a',
          settings: const {'archived': true},
        );

        final doc = await firestore
            .collection(_convoCollection)
            .doc('group-1')
            .get();
        final userA = Map<String, dynamic>.from(
          (doc.data()?['perUserSettings'] as Map)['user-a'] as Map,
        );
        expect(
          userA['pinned'],
          isTrue,
          reason: 'pinned must survive the archived merge',
        );
        expect(userA['archived'], isTrue);
      },
    );
  });
}

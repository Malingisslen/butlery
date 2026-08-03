/// Unit tests for ConversationMutationModule.
///
/// 134-line write module that orchestrates direct/group conversation
/// lifecycle, participant changes, deletion, and per-user settings.
/// All dependencies are injected as callbacks/optional module, so the
/// tests verify the contract by capturing the callbacks invoked and
/// reading back Firestore state where applicable.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/repositories/firebase/modules/conversation_mutation_module.dart';

const _convoCollection = 'conversations';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

/// Fake instead of Mock — `HttpsCallableResult.data` reads from a private
/// backing field that `implements` can't see, so a Mock returns null.
class _FakeCallableResult extends Fake
    implements HttpsCallableResult<Map<String, dynamic>> {
  _FakeCallableResult(this._data);
  final Map<String, dynamic> _data;
  @override
  Map<String, dynamic> get data => _data;
}

Conversation _groupConvo({
  String id = 'group-1',
  String title = 'Squad',
  List<String> participants = const ['user-a', 'user-b'],
}) {
  return Conversation(
    id: id,
    participantIds: participants,
    participantDisplayNames: {for (final id in participants) id: id},
    participantAvatarUrls: const {},
    lastReadTimestamps: const {},
    isGroup: true,
    title: title,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group('createDirectConversation', () {
    test('uses deterministic id sorted by user id', () async {
      final firestore = FakeFirebaseFirestore();
      final module = ConversationMutationModule(
        firestore: firestore,
        collectionName: _convoCollection,
        createFn: (c) async => c,
        updateFn: (_) async {},
        readFn: (_) async => null,
        sendMessageFn: (_) async {},
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

      var createInvocations = 0;
      final module = ConversationMutationModule(
        firestore: firestore,
        collectionName: _convoCollection,
        createFn: (c) async {
          createInvocations++;
          return c;
        },
        updateFn: (_) async {},
        readFn: (_) async => null,
        sendMessageFn: (_) async {},
      );

      final id = await module.createDirectConversation(
        user1Id: 'user-a',
        user1DisplayName: 'A',
        user2Id: 'user-b',
        user2DisplayName: 'B',
      );

      expect(id, equals('direct_user-a_user-b'));
      // createFn is for group creation; direct uses .set() directly. Should
      // still be zero because the existing-doc short-circuit fires first.
      expect(createInvocations, equals(0));
      // And the pre-existing payload must be untouched.
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
        createFn: (c) async => c,
        updateFn: (_) async {},
        readFn: (_) async => null,
        sendMessageFn: (_) async {},
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

  // BUT-1788 twin, NOT a passing feature. Everything below asserts the
  // CLIENT-SIDE contract, and production refuses part of it: the
  // `Message.system` write carries `senderId: 'system'`, which
  // `firestore.rules:1562` (`request.auth.uid == request.resource.data.senderId`)
  // denies for every client. `createGroupConversation` rethrows after `createFn`
  // has already created the document, so the user sees a failure for a group
  // that exists. Green here means "the module calls sendMessageFn", never "the
  // system message lands" — the leave/remove twin only started landing once it
  // moved to the Admin SDK. See the KNOWN BROKEN doc comment on
  // `ConversationMutationModule.addParticipants`.
  group('createGroupConversation', () {
    test(
      'delegates to createFn and emits a system message via sendMessageFn',
      () async {
        Conversation? capturedCreate;
        final sent = <Message>[];

        final firestore = FakeFirebaseFirestore();
        final module = ConversationMutationModule(
          firestore: firestore,
          collectionName: _convoCollection,
          createFn: (c) async {
            capturedCreate = c;
            return c;
          },
          updateFn: (_) async {},
          readFn: (_) async => null,
          sendMessageFn: (m) async {
            sent.add(m);
          },
        );

        final newId = await module.createGroupConversation(
          participantIds: ['user-a', 'user-b', 'user-c'],
          participantDisplayNames: const {
            'user-a': 'A',
            'user-b': 'B',
            'user-c': 'C',
          },
          participantAvatarUrls: const {
            'user-a': null,
            'user-b': null,
            'user-c': null,
          },
          title: 'Team',
          creatorId: 'user-a',
        );

        expect(capturedCreate, isNotNull);
        expect(capturedCreate!.isGroup, isTrue);
        expect(capturedCreate!.title, equals('Team'));
        expect(newId, equals(capturedCreate!.id));
        expect(sent, hasLength(1));
        expect(sent.first.type, equals(MessageType.system));
      },
    );
  });

  group('updateConversation', () {
    test(
      'rejects missing conversation with ResourceNotFoundException',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = ConversationMutationModule(
          firestore: firestore,
          collectionName: _convoCollection,
          createFn: (c) async => c,
          updateFn: (_) async {},
          readFn: (_) async => null,
          sendMessageFn: (_) async {},
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

    test('writes new title + metadata via updateFn', () async {
      Conversation? capturedUpdate;
      final firestore = FakeFirebaseFirestore();
      final existing = _groupConvo();
      final module = ConversationMutationModule(
        firestore: firestore,
        collectionName: _convoCollection,
        createFn: (c) async => c,
        updateFn: (c) async {
          capturedUpdate = c;
        },
        readFn: (_) async => existing,
        sendMessageFn: (_) async {},
      );

      await module.updateConversation(
        conversationId: 'group-1',
        title: 'New Title',
        metadata: const {'pinned': true},
      );

      expect(capturedUpdate, isNotNull);
      expect(capturedUpdate!.title, equals('New Title'));
      expect(capturedUpdate!.metadata?['pinned'], isTrue);
    });
  });

  // BUT-1788 twin, KNOWN BROKEN in production — see the note above
  // `createGroupConversation`. `addParticipants` fails on BOTH counts: the
  // `updateFn` write rebuilds `participantIds`, which `firestore.rules:1533-1535`
  // denies outright, and the per-add `Message.system` is denied too. The two
  // "rejects ..." cases below are genuine (they short-circuit before any write);
  // the third pins only that the module ASSEMBLES the right payload, not that
  // "Lägg till medlemmar" works. Deliberately left client-side by BUT-1788:
  // adding needs its own authorization answer and its own minor-membership
  // gate, so it needs its own ticket.
  group('addParticipants', () {
    test('rejects missing conversation', () async {
      final firestore = FakeFirebaseFirestore();
      final module = ConversationMutationModule(
        firestore: firestore,
        collectionName: _convoCollection,
        createFn: (c) async => c,
        updateFn: (_) async {},
        readFn: (_) async => null,
        sendMessageFn: (_) async {},
      );

      await expectLater(
        module.addParticipants(
          conversationId: 'missing',
          participantIds: const ['user-x'],
          participantDisplayNames: const {'user-x': 'X'},
          participantAvatarUrls: const {'user-x': null},
        ),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });

    test('rejects direct conversations with ValidationException', () async {
      final firestore = FakeFirebaseFirestore();
      final direct = Conversation(
        id: 'direct-1',
        participantIds: const ['user-a', 'user-b'],
        participantDisplayNames: const {},
        participantAvatarUrls: const {},
        lastReadTimestamps: const {},
        isGroup: false,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      final module = ConversationMutationModule(
        firestore: firestore,
        collectionName: _convoCollection,
        createFn: (c) async => c,
        updateFn: (_) async {},
        readFn: (_) async => direct,
        sendMessageFn: (_) async {},
      );

      await expectLater(
        module.addParticipants(
          conversationId: 'direct-1',
          participantIds: const ['user-x'],
          participantDisplayNames: const {'user-x': 'X'},
          participantAvatarUrls: const {'user-x': null},
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'appends to participant lists and sends a system message per add',
      () async {
        Conversation? capturedUpdate;
        final sent = <Message>[];
        final firestore = FakeFirebaseFirestore();
        final module = ConversationMutationModule(
          firestore: firestore,
          collectionName: _convoCollection,
          createFn: (c) async => c,
          updateFn: (c) async {
            capturedUpdate = c;
          },
          readFn: (_) async => _groupConvo(),
          sendMessageFn: (m) async => sent.add(m),
        );

        await module.addParticipants(
          conversationId: 'group-1',
          participantIds: const ['user-c', 'user-d'],
          participantDisplayNames: const {'user-c': 'C', 'user-d': 'D'},
          participantAvatarUrls: const {'user-c': null, 'user-d': null},
        );

        expect(capturedUpdate, isNotNull);
        expect(
          capturedUpdate!.participantIds,
          containsAll(['user-a', 'user-b', 'user-c', 'user-d']),
        );
        expect(
          capturedUpdate!.lastReadTimestamps.keys,
          containsAll(['user-c', 'user-d']),
        );
        // One system message per added user.
        expect(sent, hasLength(2));
        expect(sent.every((m) => m.type == MessageType.system), isTrue);
      },
    );
  });

  // BUT-1788: the three tests this replaces asserted the OLD client-side
  // write — read the conversation, strip the uid from four maps, write the doc
  // back. That write has never once landed: `firestore.rules` denies any
  // client update whose diff touches `participantIds`, and the follow-up
  // system message (senderId "system") fails the messages create rule too. The
  // suite was green on a code path the backend refuses. The contract is now
  // "delegate to the `leaveGroupConversation` callable and write nothing
  // locally", and the authorization/idempotency assertions live server-side in
  // `functions/src/__tests__/leave-group-conversation.test.ts`.
  group('removeParticipant (server-side, BUT-1788)', () {
    late _MockFunctions functions;
    late _MockCallable callable;

    setUp(() {
      functions = _MockFunctions();
      callable = _MockCallable();
      when(() => functions.httpsCallable(any())).thenReturn(callable);
      // Mirror what `leaveGroupConversation` actually returns. The old fixture
      // was `{success: true}` alone, which predates the `removed` field and so
      // could not tell a real removal apart from the callable's no-op branch —
      // the shape BUT-1795 is about.
      when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _FakeCallableResult(const {
          'success': true,
          'removed': true,
          'remaining': 2,
        }),
      );
    });

    ConversationMutationModule buildModule({
      void Function(Conversation)? onUpdate,
      void Function(Message)? onSend,
    }) {
      return ConversationMutationModule(
        firestore: FakeFirebaseFirestore(),
        collectionName: _convoCollection,
        createFn: (c) async => c,
        updateFn: (c) async => onUpdate?.call(c),
        readFn: (_) async => _groupConvo(),
        sendMessageFn: (m) async => onSend?.call(m),
        functions: functions,
      );
    }

    test(
      'invokes leaveGroupConversation with the conversation and uid',
      () async {
        final module = buildModule();

        await module.removeParticipant(
          conversationId: 'group-1',
          participantId: 'user-b',
        );

        verify(
          () => functions.httpsCallable('leaveGroupConversation'),
        ).called(1);
        final captured =
            verify(
                  () => callable.call<Map<String, dynamic>>(captureAny()),
                ).captured.single
                as Map<String, dynamic>;
        expect(captured['conversationId'], equals('group-1'));
        expect(captured['participantId'], equals('user-b'));
      },
    );

    test(
      'writes nothing from the client — no doc update, no system message',
      () async {
        final updates = <Conversation>[];
        final sent = <Message>[];
        final module = buildModule(onUpdate: updates.add, onSend: sent.add);

        await module.removeParticipant(
          conversationId: 'group-1',
          participantId: 'user-b',
        );

        expect(updates, isEmpty);
        expect(sent, isEmpty);
      },
    );

    test('surfaces a denied removal to the caller', () async {
      when(() => callable.call<Map<String, dynamic>>(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'Only the group admin can remove other members.',
        ),
      );
      final module = buildModule();

      await expectLater(
        module.removeParticipant(
          conversationId: 'group-1',
          participantId: 'user-b',
        ),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });

    // BUT-1795. The callable answers a MISSING conversation with
    // `{removed: false, remaining: 0}` instead of throwing, so it does not leak
    // whether a conversation exists. That branch is reachable by construction:
    // groups are created at `users/{uid}/conversations/{id}` while the callable
    // reads top-level `conversations/{id}`. Discarding the reply is what made a
    // failed leave report success and fire a false `logGroupLeft`.
    test('a no-op reply is a FAILURE, not a silent success', () async {
      when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _FakeCallableResult(const {
          'success': true,
          'removed': false,
          'remaining': 0,
        }),
      );
      final module = buildModule();

      await expectLater(
        module.removeParticipant(
          conversationId: 'group-1',
          participantId: 'user-b',
        ),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });

    test('a reply with no `removed` field at all is also a failure', () async {
      // Fail closed: an older or unexpected payload must not read as success.
      when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _FakeCallableResult(const {'success': true}),
      );
      final module = buildModule();

      await expectLater(
        module.removeParticipant(
          conversationId: 'group-1',
          participantId: 'user-b',
        ),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });
  });

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
          createFn: (c) async => c,
          updateFn: (_) async {},
          readFn: (_) async => null,
          sendMessageFn: (_) async {},
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
        createFn: (c) async => c,
        updateFn: (_) async {},
        readFn: (_) async => null,
        sendMessageFn: (_) async {},
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
        createFn: (c) async => c,
        updateFn: (_) async {},
        readFn: (_) async => null,
        sendMessageFn: (_) async {},
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
          createFn: (c) async => c,
          updateFn: (_) async {},
          readFn: (_) async => null,
          sendMessageFn: (_) async {},
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

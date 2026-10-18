/// Profile and chat writes made without a connection (BUT-2290, BUT-2291).
///
/// Firestore applies a write to the device's cache at once but settles its
/// future only when the server answers. `FakeFirebaseFirestore` settles every
/// write instantly, so these tests hand the code writes that never answer and
/// check that the caller still gets its turn after `queuedWritePatience`.
library;

// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/firebase_user_repository.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/repositories/firebase/modules/conversation_mutation_module.dart';
import 'package:butlery/repositories/firebase/modules/message_mutation_module.dart';
import 'package:butlery/repositories/firebase/queued_write.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockBatch extends Mock implements WriteBatch {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _FakeDoc extends Fake
    implements DocumentReference<Map<String, dynamic>> {}

const _alice = 'user-alice';

class _Modules {
  _Modules(this.messages, this.conversations);
  final MessageMutationModule messages;
  final ConversationMutationModule conversations;
}

/// Elapses just past the patience and lets the queued microtasks run.
void _pastPatience(FakeAsync async) {
  async.elapse(queuedWritePatience + const Duration(milliseconds: 1));
  async.flushMicrotasks();
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDoc());
    registerFallbackValue(SetOptions(merge: true));
    registerFallbackValue(<String, dynamic>{});
  });

  group('profile writes without a connection', () {
    late _MockFirestore firestore;
    late _MockCollection collection;
    late _MockDoc doc;
    late Completer<void> serverAnswer;

    setUp(() {
      firestore = _MockFirestore();
      collection = _MockCollection();
      doc = _MockDoc();
      serverAnswer = Completer<void>();
      when(() => firestore.collection(any())).thenReturn(collection);
      when(() => collection.doc(any())).thenReturn(doc);
      when(() => doc.collection(any())).thenReturn(collection);
      when(() => doc.set(any(), any())).thenAnswer((_) => serverAnswer.future);
      when(() => doc.update(any())).thenAnswer((_) => serverAnswer.future);
    });

    FirebaseUserRepository repo() {
      final auth = FakeAuthRepository()
        ..setAuthState(
          user: FakeUser(uid: _alice),
          userId: _alice,
          isAuthenticated: true,
        );
      return FirebaseUserRepository(firestore: firestore, authRepository: auth);
    }

    test('saving the profile returns while the server does not answer', () {
      fakeAsync((async) {
        var saved = false;
        repo()
            .saveProfile(
              UserProfile(
                uid: _alice,
                displayName: 'Alice',
                email: 'alice@example.com',
                joinedAt: DateTime.utc(2026, 1, 1),
                lastActiveAt: DateTime.utc(2026, 1, 1),
              ),
            )
            .then((_) => saved = true);

        async.flushMicrotasks();
        expect(saved, isFalse);
        _pastPatience(async);
        expect(saved, isTrue);
        verify(() => doc.set(any(), any())).called(2);
      });
    });

    test('a minor\'s save keeps waiting: the searchability callable that '
        'follows must land after it', () {
      fakeAsync((async) {
        // Made inside the fake zone: a completer from setUp would complete its
        // listeners outside the zone this test flushes.
        final answer = Completer<void>();
        when(() => doc.set(any(), any())).thenAnswer((_) => answer.future);
        var saved = false;
        repo()
            .saveProfile(
              UserProfile(
                uid: _alice,
                displayName: 'Alice',
                email: 'alice@example.com',
                isMinor: true,
                joinedAt: DateTime.utc(2026, 1, 1),
                lastActiveAt: DateTime.utc(2026, 1, 1),
              ),
            )
            .then((_) => saved = true);

        _pastPatience(async);
        expect(saved, isFalse);
        verify(() => doc.set(any(), any())).called(2);
        answer.complete();
        async.flushMicrotasks();
        expect(saved, isTrue);
      });
    });

    // One row per write that gained the patience, so deleting the wrapper at
    // any single site reddens its row.
    final profileSites =
        <String, Future<void> Function(FirebaseUserRepository)>{
          'updateProfileStats': (r) =>
              r.updateProfileStats(_alice, friendsCount: 1),
          'updateNotificationSettings': (r) =>
              r.updateNotificationSettings(_alice, true),
          'updatePreferredLocale': (r) => r.updatePreferredLocale(_alice, 'sv'),
          'markActivityFeedHintSeen': (r) => r.markActivityFeedHintSeen(_alice),
          'setAutoAddBoughtToPantry': (r) =>
              r.setAutoAddBoughtToPantry(_alice, true),
          'setUseHouseholdAllergens': (r) =>
              r.setUseHouseholdAllergens(_alice, true),
          'setUseMealAllergenScope': (r) =>
              r.setUseMealAllergenScope(_alice, true),
          'setShowNutritionStrip': (r) => r.setShowNutritionStrip(_alice, true),
          'setShowNameOnSharedDishes': (r) =>
              r.setShowNameOnSharedDishes(_alice, true),
          'markPantryAutoAddPrompted': (r) =>
              r.markPantryAutoAddPrompted(_alice),
        };
    for (final site in profileSites.entries) {
      test('${site.key} returns while the server does not answer', () {
        fakeAsync((async) {
          var done = false;
          site.value(repo()).then((_) => done = true);
          async.flushMicrotasks();
          expect(done, isFalse);
          _pastPatience(async);
          expect(done, isTrue);
        });
      });
    }

    test('allergen preferences keep waiting: a late refusal of the household '
        'shares would drop the declaration itself', () {
      final batch = _MockBatch();
      when(() => firestore.batch()).thenReturn(batch);
      when(() => batch.commit()).thenAnswer((_) => serverAnswer.future);
      fakeAsync((async) {
        var done = false;
        repo()
            .updateAllergenPreferences(
              _alice,
              const UserAllergenPreferences(
                trackedAllergens: {},
                trackedDietary: {},
              ),
            )
            .then((_) => done = true);

        _pastPatience(async);
        verify(() => batch.commit()).called(1);
        expect(done, isFalse);
      });
    });

    test('a settings toggle returns while the server does not answer', () {
      fakeAsync((async) {
        var saved = false;
        repo().setShowNutritionStrip(_alice, true).then((_) => saved = true);

        async.flushMicrotasks();
        expect(saved, isFalse);
        _pastPatience(async);
        expect(saved, isTrue);
      });
    });

    test('a refusal while online still reaches the caller', () {
      when(
        () => doc.set(any(), any()),
      ).thenAnswer((_) => Future<void>.error(StateError('permission-denied')));
      fakeAsync((async) {
        Object? error;
        repo()
            .setShowNutritionStrip(_alice, true)
            .catchError((Object e) => error = e);

        async.flushMicrotasks();
        expect(error, isA<StateError>());
      });
    });
  });

  group('chat writes without a connection', () {
    late FakeFirebaseFirestore store;
    late _MockFirestore firestore;
    late _MockBatch batch;
    late Completer<void> serverAnswer;
    late Message message;

    setUp(() async {
      store = FakeFirebaseFirestore();
      firestore = _MockFirestore();
      batch = _MockBatch();
      serverAnswer = Completer<void>();
      message = Message.text(
        conversationId: 'conv-1',
        senderId: _alice,
        senderDisplayName: 'Alice',
        content: 'hej',
      );
      // The cache already holds the message and its conversation, as the
      // device's does after a write made offline.
      await store.collection('messages').doc(message.id).set({
        'status': MessageStatus.sending.name,
      });
      await store.collection('conversations').doc('conv-1').set({
        'lastMessage': {'status': MessageStatus.sending.name},
      });
      when(() => firestore.batch()).thenReturn(batch);
      when(
        () => firestore.collection(any()),
      ).thenAnswer((i) => store.collection(i.positionalArguments.first));
      when(() => batch.commit()).thenAnswer((_) => serverAnswer.future);
    });

    MessageMutationModule module() => MessageMutationModule(
      firestore: firestore,
      collectionName: 'conversations',
      messagesRef: store.collection('messages'),
      readConversation: (_) async => Conversation(
        id: 'conv-1',
        participantIds: const [_alice, 'user-b'],
        participantDisplayNames: const {_alice: 'Alice', 'user-b': 'B'},
        participantAvatarUrls: const {},
        lastReadTimestamps: const {},
        isGroup: false,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    Future<String?> statusOf() async {
      final doc = await store.collection('messages').doc(message.id).get();
      return doc.data()?['status'] as String?;
    }

    Future<Object?> lastMessageStatus() async =>
        ((await store.collection('conversations').doc('conv-1').get())
                .data()?['lastMessage']
            as Map<String, dynamic>?)?['status'];

    test('sending returns while the server does not answer, and the message '
        'is not marked sent before it does', () async {
      var returned = false;
      unawaited(module().sendMessage(message).then((_) => returned = true));

      await Future<void>.delayed(
        queuedWritePatience + const Duration(milliseconds: 200),
      );
      expect(returned, isTrue);
      expect(await statusOf(), MessageStatus.sending.name);
      expect(await lastMessageStatus(), MessageStatus.sending.name);

      serverAnswer.complete();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(await statusOf(), MessageStatus.sent.name);
      expect(await lastMessageStatus(), MessageStatus.sent.name);
    });

    test('a send the server refuses while the sender waits still fails', () {
      when(
        () => batch.commit(),
      ).thenAnswer((_) => Future<void>.error(StateError('permission-denied')));

      expect(module().sendMessage(message), throwsA(isA<StateError>()));
    });
  });

  group('other chat writes without a connection', () {
    late _MockFirestore firestore;
    late _MockCollection collection;
    late _MockDoc doc;

    setUp(() {
      firestore = _MockFirestore();
      collection = _MockCollection();
      doc = _MockDoc();
      when(() => firestore.collection(any())).thenReturn(collection);
      when(() => collection.doc(any())).thenReturn(doc);
      // Writes that the server never answers.
      when(() => doc.update(any())).thenAnswer((_) => Completer<void>().future);
      when(() => doc.delete()).thenAnswer((_) => Completer<void>().future);
      when(
        () => doc.set(any(), any()),
      ).thenAnswer((_) => Completer<void>().future);
    });

    MessageMutationModule messages() => MessageMutationModule(
      firestore: firestore,
      collectionName: 'conversations',
      messagesRef: collection,
      readConversation: (_) async => Conversation(
        id: 'conv-1',
        participantIds: const [_alice, 'user-b'],
        participantDisplayNames: const {_alice: 'Alice', 'user-b': 'B'},
        participantAvatarUrls: const {},
        lastReadTimestamps: const {},
        isGroup: false,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final sites = <String, Future<void> Function(_Modules)>{
      'edit': (m) =>
          m.messages.updateMessageContent(messageId: 'm1', newContent: 'ny'),
      'delete': (m) => m.messages.deleteMessage('m1'),
      'status': (m) => m.messages.updateMessageStatus(
        messageId: 'm1',
        status: MessageStatus.delivered,
      ),
      'read marker': (m) => m.messages.markConversationAsRead(
        conversationId: 'conv-1',
        userId: _alice,
      ),
      'conversation settings': (m) =>
          m.conversations.updateConversationUserSettings(
            conversationId: 'conv-1',
            userId: _alice,
            settings: const {'isPinned': true},
          ),
    };
    for (final site in sites.entries) {
      test('${site.key} returns while the server does not answer', () {
        fakeAsync((async) {
          var done = false;
          site
              .value(
                _Modules(
                  messages(),
                  ConversationMutationModule(
                    firestore: firestore,
                    collectionName: 'conversations',
                  ),
                ),
              )
              .then((_) => done = true);
          async.flushMicrotasks();
          expect(done, isFalse);
          _pastPatience(async);
          expect(done, isTrue);
        });
      });
    }
  });
}

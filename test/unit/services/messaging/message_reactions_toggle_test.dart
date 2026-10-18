/// A reaction is toggled without a transaction (BUT-2291), so one made offline
/// is kept; the emulator lane (`offline_writes_integration_test.dart`) proves
/// it against a real client without a connection.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/messaging/message_reactions_service.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

// ignore_for_file: subtype_of_sealed_class

const _alice = 'user-alice';

class _NoTransactionFirestore extends Mock implements FirebaseFirestore {}

void main() {
  group('reactions', () {
    late FakeFirebaseFirestore store;
    late MessageReactionsService service;

    setUp(() async {
      store = FakeFirebaseFirestore();
      await store.collection('messages').doc('m1').set({'content': 'hej'});
      final auth = FakeAuthRepository()
        ..setAuthState(
          user: FakeUser(uid: _alice),
          userId: _alice,
          isAuthenticated: true,
        );
      service = MessageReactionsService(
        firestoreRepository: FirestoreRepository(firestore: store),
        authRepository: auth,
      );
    });

    Future<Object?> reactionsOnM1() async =>
        (await store.collection('messages').doc('m1').get())
            .data()?['reactions'];

    Future<void> toggle() => service.toggleReaction(
      messageId: 'm1',
      conversationId: 'conv-1',
      userId: _alice,
      emoji: '👍',
    );

    test('a second toggle by the same user takes the reaction back', () async {
      await toggle();
      expect(await reactionsOnM1(), {
        '👍': [_alice],
      });

      await toggle();
      expect(await reactionsOnM1(), {'👍': <String>[]});
    });

    test('works where a transaction cannot run, as without a connection', () {
      final firestore = _NoTransactionFirestore();
      when(
        () => firestore.collection(any()),
      ).thenAnswer((i) => store.collection(i.positionalArguments.first));
      when(
        () => firestore.runTransaction<void>(any()),
      ).thenThrow(StateError('a transaction needs a connection'));
      final auth = FakeAuthRepository()
        ..setAuthState(
          user: FakeUser(uid: _alice),
          userId: _alice,
          isAuthenticated: true,
        );
      final offline = MessageReactionsService(
        firestoreRepository: FirestoreRepository(firestore: firestore),
        authRepository: auth,
      );

      return offline
          .toggleReaction(
            messageId: 'm1',
            conversationId: 'conv-1',
            userId: _alice,
            emoji: '👍',
          )
          .then((_) async {
            expect(await reactionsOnM1(), {
              '👍': [_alice],
            });
          });
    });
  });
}

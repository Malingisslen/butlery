/// Unit tests for ConversationParticipantModule.
///
/// Targets the subcollection repo. Every public method short-circuits when the
/// enableSubcollectionParticipants feature flag is false, so each happy-path
/// test enables the flag and the disabled-path test is a single batch.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/messaging/conversation_participant.dart';
import 'package:butlery/repositories/firebase/modules/conversation_participant_module.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';

class _MockFeatureFlags extends Mock implements FeatureFlagService {}

void _enableFlag(_MockFeatureFlags flags, {int maxInline = 50}) {
  when(
    () => flags.isEnabled(FeatureFlags.enableSubcollectionParticipants),
  ).thenReturn(true);
  when(
    () => flags.getInt(FeatureFlags.maxInlineParticipants),
  ).thenReturn(maxInline);
}

void _disableFlag(_MockFeatureFlags flags) {
  when(
    () => flags.isEnabled(FeatureFlags.enableSubcollectionParticipants),
  ).thenReturn(false);
  when(() => flags.getInt(FeatureFlags.maxInlineParticipants)).thenReturn(50);
}

void main() {
  group('ConversationParticipantModule', () {
    late FakeFirebaseFirestore firestore;
    late _MockFeatureFlags flags;
    late ConversationParticipantModule module;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      flags = _MockFeatureFlags();
      _enableFlag(flags);
      module = ConversationParticipantModule(
        firestore: firestore,
        featureFlags: flags,
      );
    });

    group('addParticipant', () {
      test(
        'writes the participant row',
        () async {
          await module.addParticipant(
            conversationId: 'conv-1',
            participantId: 'user-a',
            displayName: 'User A',
            avatarUrl: 'https://x/a.png',
          );

          final pDoc = await firestore
              .collection('conversations')
              .doc('conv-1')
              .collection('participants')
              .doc('user-a')
              .get();
          expect(pDoc.exists, isTrue);
          expect(pDoc.data()?['displayName'], equals('User A'));
        },
      );

      test('is a no-op when flag is disabled', () async {
        _disableFlag(flags);

        await module.addParticipant(
          conversationId: 'conv-1',
          participantId: 'user-a',
          displayName: 'User A',
        );

        final pDoc = await firestore
            .collection('conversations')
            .doc('conv-1')
            .collection('participants')
            .doc('user-a')
            .get();
        expect(pDoc.exists, isFalse);
      });
    });

    group('addParticipants', () {
      test('batch-writes all participants', () async {
        await module.addParticipants(
          conversationId: 'conv-1',
          participantDisplayNames: const {
            'user-a': 'User A',
            'user-b': 'User B',
            'user-c': 'User C',
          },
          participantAvatarUrls: const {
            'user-a': 'https://x/a.png',
            'user-b': null,
            'user-c': 'https://x/c.png',
          },
          ownerId: 'user-a',
        );

        final ps = await firestore
            .collection('conversations')
            .doc('conv-1')
            .collection('participants')
            .get();
        expect(ps.docs, hasLength(3));

        final ownerDoc = ps.docs.firstWhere((d) => d.id == 'user-a');
        expect(ownerDoc.data()['role'], equals(ParticipantRole.owner.name));

        final memberDoc = ps.docs.firstWhere((d) => d.id == 'user-b');
        expect(memberDoc.data()['role'], equals(ParticipantRole.member.name));
      });

      test('is a no-op when flag is disabled', () async {
        _disableFlag(flags);

        await module.addParticipants(
          conversationId: 'conv-1',
          participantDisplayNames: const {'user-a': 'A'},
          participantAvatarUrls: const {'user-a': null},
        );

        final ps = await firestore
            .collection('conversations')
            .doc('conv-1')
            .collection('participants')
            .get();
        expect(ps.docs, isEmpty);
      });
    });

    group('removeParticipant', () {
      test('deletes the participant row', () async {
        await module.addParticipant(
          conversationId: 'conv-1',
          participantId: 'user-a',
          displayName: 'A',
        );

        await module.removeParticipant(
          conversationId: 'conv-1',
          participantId: 'user-a',
        );

        final pDoc = await firestore
            .collection('conversations')
            .doc('conv-1')
            .collection('participants')
            .doc('user-a')
            .get();
        expect(pDoc.exists, isFalse);
      });

      test('is a no-op when flag is disabled', () async {
        _disableFlag(flags);
        // Doesn't touch firestore even if the docs don't exist.
        await expectLater(
          module.removeParticipant(
            conversationId: 'conv-1',
            participantId: 'user-a',
          ),
          completes,
        );
      });
    });

    group('updateLastRead', () {
      test(
        'updates lastReadAt on the participant row',
        () async {
          await module.addParticipant(
            conversationId: 'conv-1',
            participantId: 'user-a',
            displayName: 'A',
          );

          await module.updateLastRead(
            conversationId: 'conv-1',
            participantId: 'user-a',
          );

          final pDoc = await firestore
              .collection('conversations')
              .doc('conv-1')
              .collection('participants')
              .doc('user-a')
              .get();
          expect(pDoc.data()?['lastReadAt'], isNotNull);
        },
      );

      test('is a no-op when flag is disabled', () async {
        _disableFlag(flags);
        await expectLater(
          module.updateLastRead(
            conversationId: 'conv-1',
            participantId: 'user-a',
          ),
          completes,
        );
      });
    });

    group('getParticipants', () {
      test('returns all participant docs as models', () async {
        await module.addParticipants(
          conversationId: 'conv-1',
          participantDisplayNames: const {'u-1': 'One', 'u-2': 'Two'},
          participantAvatarUrls: const {'u-1': null, 'u-2': null},
        );

        final ps = await module.getParticipants('conv-1');

        expect(ps, hasLength(2));
        expect(ps.map((p) => p.participantId), containsAll(['u-1', 'u-2']));
      });

      test('returns [] when flag disabled', () async {
        _disableFlag(flags);
        final ps = await module.getParticipants('conv-1');
        expect(ps, isEmpty);
      });
    });

    group('watchParticipants', () {
      test('emits the current participant set on subscription', () async {
        await module.addParticipant(
          conversationId: 'conv-1',
          participantId: 'u-1',
          displayName: 'One',
        );

        final stream = module.watchParticipants('conv-1');
        final first = await stream.first;
        expect(first, hasLength(1));
        expect(first.first.participantId, equals('u-1'));
      });

      test('emits the const empty stream when flag disabled', () async {
        _disableFlag(flags);
        final stream = module.watchParticipants('conv-1');
        await expectLater(stream, emitsDone);
      });
    });

    group('isParticipant', () {
      test('true when participant exists', () async {
        await module.addParticipant(
          conversationId: 'conv-1',
          participantId: 'u-1',
          displayName: 'One',
        );

        final result = await module.isParticipant(
          conversationId: 'conv-1',
          userId: 'u-1',
        );

        expect(result, isTrue);
      });

      test('false when participant does not exist', () async {
        final result = await module.isParticipant(
          conversationId: 'conv-1',
          userId: 'u-missing',
        );

        expect(result, isFalse);
      });

      test('false when flag disabled', () async {
        _disableFlag(flags);
        final result = await module.isParticipant(
          conversationId: 'conv-1',
          userId: 'u-1',
        );
        expect(result, isFalse);
      });
    });

    group('migrateToSubcollection', () {
      test('creates participant entries for each user and flips '
          'usesSubcollectionParticipants flag', () async {
        // Seed the conversation doc so the .update inside migrate succeeds.
        await firestore.collection('conversations').doc('conv-1').set({
          'usesSubcollectionParticipants': false,
        });

        final now = DateTime.utc(2026, 1, 1);
        await module.migrateToSubcollection(
          conversationId: 'conv-1',
          participantIds: const ['u-1', 'u-2', 'u-3'],
          displayNames: const {'u-1': 'One', 'u-2': 'Two', 'u-3': 'Three'},
          avatarUrls: const {'u-1': null, 'u-2': null, 'u-3': null},
          lastReadTimestamps: {'u-1': now, 'u-2': now, 'u-3': now},
          ownerId: 'u-1',
        );

        final ps = await firestore
            .collection('conversations')
            .doc('conv-1')
            .collection('participants')
            .get();
        expect(ps.docs, hasLength(3));
        final owner = ps.docs.firstWhere((d) => d.id == 'u-1');
        expect(owner.data()['role'], equals(ParticipantRole.owner.name));

        final convDoc = await firestore
            .collection('conversations')
            .doc('conv-1')
            .get();
        expect(convDoc.data()?['usesSubcollectionParticipants'], isTrue);
      });

      test('is a no-op when flag disabled', () async {
        _disableFlag(flags);
        await expectLater(
          module.migrateToSubcollection(
            conversationId: 'conv-1',
            participantIds: const ['u-1'],
            displayNames: const {'u-1': 'One'},
            avatarUrls: const {'u-1': null},
            lastReadTimestamps: {'u-1': DateTime.utc(2026)},
          ),
          completes,
        );
      });
    });

    group('shouldUseSubcollection', () {
      test('true when above threshold and flag enabled', () {
        _enableFlag(flags, maxInline: 50);
        expect(module.shouldUseSubcollection(100), isTrue);
      });

      test('false when at or below threshold', () {
        _enableFlag(flags, maxInline: 50);
        expect(module.shouldUseSubcollection(50), isFalse);
        expect(module.shouldUseSubcollection(10), isFalse);
      });

      test('false when flag disabled', () {
        _disableFlag(flags);
        expect(module.shouldUseSubcollection(100), isFalse);
      });
    });
  });
}

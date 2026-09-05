/// Unit tests for FirebaseBlockRepository.
///
/// Tests permission validation, block CRUD operations, and edge cases
/// for the user blocking system using composite-key documents.
library;

// `Query` and `CollectionReference` are sealed in cloud_firestore, and the
// group below has to mock them to see which `GetOptions` reach `get()` —
// `fake_cloud_firestore` ignores the option entirely, so there is nothing to
// observe through it. Same exemption several suites under `test/` already take.
// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/repositories/firebase/firebase_block_repository.dart';
import 'package:butlery/models/block_record.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseBlockRepository', () {
    late FirebaseBlockRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuthRepo;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepo = FakeAuthRepository();
      mockAuthRepo.setAuthState(
        user: FakeUser(uid: 'user-123'),
        userId: 'user-123',
        isAuthenticated: true,
      );
      repository = FirebaseBlockRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Permission Validation', () {
      test(
        'should grant create permission when blockerId matches userId',
        () async {
          // Arrange
          final record = BlockRecord.create(
            blockerId: 'user-123',
            blockedId: 'target-456',
          );

          // Act
          final result = await repository.validateCreatePermission(
            'user-123',
            record,
          );

          // Assert
          expect(result, isTrue);
        },
      );

      test(
        'should reject create permission when blockerId does not match userId',
        () async {
          // Arrange
          final record = BlockRecord.create(
            blockerId: 'other-user',
            blockedId: 'target-456',
          );

          // Act
          final result = await repository.validateCreatePermission(
            'user-123',
            record,
          );

          // Assert
          expect(result, isFalse);
        },
      );

      test('should always return false for update permission', () async {
        // Arrange
        final record = BlockRecord.create(
          blockerId: 'user-123',
          blockedId: 'target-456',
        );

        // Act
        final result = await repository.validateUpdatePermission(
          'user-123',
          record.id,
          record,
        );

        // Assert
        expect(result, isFalse);
      });

      test(
        'should grant delete permission when blockerId matches in composite ID',
        () async {
          // Arrange
          final compositeId = BlockRecord.compositeId('user-123', 'target-456');

          // Act
          final result = await repository.validateDeletePermission(
            'user-123',
            compositeId,
          );

          // Assert
          expect(result, isTrue);
        },
      );

      test(
        'should reject delete permission when blockerId does not match in composite ID',
        () async {
          // Arrange
          final compositeId = BlockRecord.compositeId(
            'other-user',
            'target-456',
          );

          // Act
          final result = await repository.validateDeletePermission(
            'user-123',
            compositeId,
          );

          // Assert
          expect(result, isFalse);
        },
      );
    });

    group('Block CRUD Operations', () {
      test(
        'should create doc with composite ID when blocking a user',
        () async {
          // Act
          await repository.blockUser('target-456');

          // Assert
          final expectedId = BlockRecord.compositeId('user-123', 'target-456');
          final doc = await fakeFirestore
              .collection('blocks')
              .doc(expectedId)
              .get();
          expect(doc.exists, isTrue);
        },
      );

      test('should store correct fields when blocking a user', () async {
        // Act
        await repository.blockUser('target-456');

        // Assert
        final expectedId = BlockRecord.compositeId('user-123', 'target-456');
        final doc = await fakeFirestore
            .collection('blocks')
            .doc(expectedId)
            .get();
        final data = doc.data()!;

        expect(data['blockerId'], equals('user-123'));
        expect(data['blockedId'], equals('target-456'));
        expect(data['blockedAt'], isNotNull);
      });

      test('should delete the block doc when unblocking a user', () async {
        // Arrange
        await repository.blockUser('target-456');
        final expectedId = BlockRecord.compositeId('user-123', 'target-456');

        // Verify block exists
        var doc = await fakeFirestore
            .collection('blocks')
            .doc(expectedId)
            .get();
        expect(doc.exists, isTrue);

        // Act
        await repository.unblockUser('target-456');

        // Assert
        doc = await fakeFirestore.collection('blocks').doc(expectedId).get();
        expect(doc.exists, isFalse);
      });

      test(
        'should return true for blocked user and false for unblocked',
        () async {
          // Arrange
          await repository.blockUser('target-456');

          // Act & Assert
          expect(await repository.isBlocked('target-456'), isTrue);
          expect(await repository.isBlocked('other-user'), isFalse);
        },
      );

      test(
        'should return true for isBlockedBy when reverse block exists',
        () async {
          // Arrange - create a block record where target blocks current user
          final reverseId = BlockRecord.compositeId('target-456', 'user-123');
          await fakeFirestore.collection('blocks').doc(reverseId).set({
            'blockerId': 'target-456',
            'blockedId': 'user-123',
            'blockedAt': DateTime.now().toIso8601String(),
          });

          // Act & Assert
          expect(await repository.isBlockedBy('target-456'), isTrue);
          expect(await repository.isBlockedBy('other-user'), isFalse);
        },
      );

      test('should return correct set of blocked user IDs', () async {
        // Arrange
        await repository.blockUser('target-1');
        await repository.blockUser('target-2');
        await repository.blockUser('target-3');

        // Act
        final blockedIds = await repository.getBlockedUserIds();

        // Assert
        expect(blockedIds, equals({'target-1', 'target-2', 'target-3'}));
      });
    });

    group('Edge Cases', () {
      test(
        'should throw AuthenticationException when blocking while unauthenticated',
        () async {
          // Arrange
          mockAuthRepo.setAuthState(
            user: null,
            userId: null,
            isAuthenticated: false,
          );

          // Act & Assert
          expect(
            () => repository.blockUser('target-456'),
            throwsA(isA<AuthenticationException>()),
          );
        },
      );

      // BUT-1917: `deleteAllBlocksForUser` and its two tests are GONE. Why the
      // method could not have worked is stated on the tombstone in
      // `firebase_block_repository.dart` — repeating the argument here would be
      // another copy of one explanation, free to drift apart.
      //
      // What belongs here is the trap rather than an accident:
      // `fake_cloud_firestore` enforces no rules, so a client-side erasure of
      // other people's documents will always pass there — and it is not
      // something a client may do.

      test(
        'should return empty set stream when unauthenticated for watchBlockedUserIds',
        () async {
          // Arrange
          mockAuthRepo.setAuthState(
            user: null,
            userId: null,
            isAuthenticated: false,
          );

          // Act
          final stream = repository.watchBlockedUserIds();

          // Assert
          expect(stream, emits(isEmpty));
        },
      );
    });

    // BUT-1922. `fake_cloud_firestore` IGNORES `GetOptions(source:)` (recorded
    // in the testing digest), so no fake-backed test can tell the decision
    // path's server read from an ordinary one — both answer the same way and
    // neither throws. Without this the `const GetOptions(source: Source.server)`
    // could be dropped and every suite would stay green while the offline hole
    // it closes reopens: a plain `get()` answers from the local cache with no
    // error, so a block made on the user's OTHER device stops reaching
    // `closePoll` and the ballot it should have removed decides the week.
    //
    // What survives the fake is WHICH OPTIONS ARE HANDED TO `get`, so the query
    // is driven through mocks that record them.
    group('read sources are part of the contract', () {
      late _MockFirestore firestore;
      late _MockCollection collectionRef;
      late _MockQuery query;
      late _MockQuerySnapshot snapshot;
      late FirebaseBlockRepository repo;

      setUpAll(() {
        registerFallbackValue(const GetOptions());
      });

      setUp(() {
        firestore = _MockFirestore();
        collectionRef = _MockCollection();
        query = _MockQuery();
        snapshot = _MockQuerySnapshot();

        when(() => firestore.collection(any())).thenReturn(collectionRef);
        when(
          () => collectionRef.where(any(), isEqualTo: any(named: 'isEqualTo')),
        ).thenReturn(query);
        when(() => snapshot.docs).thenReturn([]);
        when(() => query.get(any())).thenAnswer((_) async => snapshot);
        when(() => query.get()).thenAnswer((_) async => snapshot);

        repo = FirebaseBlockRepository(
          firestore: firestore,
          authRepository: mockAuthRepo,
        );
      });

      test('the DECISION read demands the server', () async {
        await repo.getBlockedUserIdsFromServer();

        final options = verify(
          () => query.get(captureAny()),
        ).captured.cast<GetOptions?>();
        expect(options, hasLength(1));
        expect(
          options.single?.source,
          Source.server,
          reason:
              'a cache-served answer here is indistinguishable from a current '
              'one, which is the whole defect BUT-1922 closes',
        );
      });

      test('the DISPLAY read does NOT demand the server', () async {
        // The other half, and it must stay green for the opposite reason: a
        // server-only read on this path throws offline, the fail-open catch
        // above it swallows that, and the chat is then served unfiltered.
        await repo.getBlockedUserIds();

        final options = verify(
          () => query.get(captureAny()),
        ).captured.cast<GetOptions?>();
        expect(
          options.single?.source,
          isNot(Source.server),
          reason: 'the display path may answer from the local cache',
        );
      });
    });
  });
}

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

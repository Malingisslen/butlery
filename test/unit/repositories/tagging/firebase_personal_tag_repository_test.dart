/// Unit tests for FirebasePersonalTagRepository batch operations.
///
/// Tests the repository methods that were identified in issue #9:
/// - getByIds(): Get multiple tags efficiently
/// - reorder(): Batch update sort orders
/// - clearGroupFromTags(): Clear groupId from all tags in a group
/// - addClearGroupToBatch(): Add clear operations to external batch (#7)
/// - newWriteBatch(): Create batch for atomic operations (#7)
library;

// Firestore classes are sealed but need to be mocked for unit tests
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';

import '../../../infrastructure/builders/personal_tag_builder.dart';

// Mocks
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockWriteBatch extends Mock implements WriteBatch {}

class MockAuthRepository extends Mock implements AuthRepository {}

// Fakes for fallback values
class FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockAuthRepository mockAuthRepository;
  late FirebasePersonalTagRepository repository;

  setUpAll(() {
    registerFallbackValue(PersonalTagBuilder().build());
    registerFallbackValue(FakeDocumentReference());
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockAuthRepository = MockAuthRepository();

    // Stub auth to return a user ID
    when(() => mockAuthRepository.currentUserId).thenReturn('test-user-123');

    // Create repository with mocked dependencies
    repository = FirebasePersonalTagRepository(
      firestore: mockFirestore,
      authRepository: mockAuthRepository,
    );

    // Stub collection access - repository uses user subcollection
    final mockUsersCollection = MockCollectionReference();
    final mockUserDoc = MockDocumentReference();

    when(() => mockFirestore.collection('users'))
        .thenReturn(mockUsersCollection);
    when(() => mockUsersCollection.doc('test-user-123'))
        .thenReturn(mockUserDoc);
    when(() => mockUserDoc.collection('personalTagIds'))
        .thenReturn(mockCollection);
  });

  group('#9: FirebasePersonalTagRepository batch operations', () {
    group('getByIds', () {
      // Real code uses whereIn batch queries, not per-doc .get().
      // These tests mock the actual query chain for fidelity.

      test('returns tags for valid IDs', () async {
        // Arrange: mock the whereIn query chain
        final tag1 =
            PersonalTagBuilder().withId('tag-1').withName('Tag One').build();
        final tag2 =
            PersonalTagBuilder().withId('tag-2').withName('Tag Two').build();

        final mockQuery = MockQuery();
        final mockQuerySnapshot = MockQuerySnapshot();
        final mockQDoc1 = MockQueryDocumentSnapshot();
        final mockQDoc2 = MockQueryDocumentSnapshot();

        when(() => mockCollection.where(any(), whereIn: any(named: 'whereIn')))
            .thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(() => mockQuerySnapshot.docs).thenReturn([mockQDoc1, mockQDoc2]);

        when(() => mockQDoc1.id).thenReturn('tag-1');
        when(() => mockQDoc1.data()).thenReturn(tag1.toFirestore());
        when(() => mockQDoc2.id).thenReturn('tag-2');
        when(() => mockQDoc2.data()).thenReturn(tag2.toFirestore());

        // Act
        final result = await repository.getByIds(['tag-1', 'tag-2']);

        // Assert
        expect(result.length, 2);
        expect(result.any((t) => t.id == 'tag-1'), isTrue);
        expect(result.any((t) => t.id == 'tag-2'), isTrue);
      });

      test('returns empty list for empty IDs', () async {
        // Act
        final result = await repository.getByIds([]);

        // Assert
        expect(result, isEmpty);
      });

      test('ignores missing IDs silently', () async {
        // Arrange: whereIn only returns docs that exist — missing IDs
        // are simply absent from the result (Firestore behavior).
        final tag1 =
            PersonalTagBuilder().withId('tag-1').withName('Tag One').build();

        final mockQuery = MockQuery();
        final mockQuerySnapshot = MockQuerySnapshot();
        final mockQDoc1 = MockQueryDocumentSnapshot();

        when(() => mockCollection.where(any(), whereIn: any(named: 'whereIn')))
            .thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        // Only tag-1 exists; 'missing-tag' simply not in results
        when(() => mockQuerySnapshot.docs).thenReturn([mockQDoc1]);

        when(() => mockQDoc1.id).thenReturn('tag-1');
        when(() => mockQDoc1.data()).thenReturn(tag1.toFirestore());

        // Act
        final result = await repository.getByIds(['tag-1', 'missing-tag']);

        // Assert: Only existing tag returned
        expect(result.length, 1);
        expect(result.first.id, 'tag-1');
      });
    });

    group('reorder', () {
      test('updates sortOrder for all tags', () async {
        // Arrange
        final mockBatch = MockWriteBatch();
        when(() => mockFirestore.batch()).thenReturn(mockBatch);

        final mockDocRef1 = MockDocumentReference();
        final mockDocRef2 = MockDocumentReference();
        final mockDocRef3 = MockDocumentReference();

        when(() => mockCollection.doc('tag-1')).thenReturn(mockDocRef1);
        when(() => mockCollection.doc('tag-2')).thenReturn(mockDocRef2);
        when(() => mockCollection.doc('tag-3')).thenReturn(mockDocRef3);

        when(() => mockBatch.update(any(), any())).thenReturn(null);
        when(() => mockBatch.commit()).thenAnswer((_) async {});

        // Act
        await repository.reorder(['tag-1', 'tag-2', 'tag-3']);

        // Assert
        verify(() => mockBatch.update(
            mockDocRef1,
            any(
              that: containsPair('sortOrder', 0),
            ))).called(1);
        verify(() => mockBatch.update(
            mockDocRef2,
            any(
              that: containsPair('sortOrder', 1),
            ))).called(1);
        verify(() => mockBatch.update(
            mockDocRef3,
            any(
              that: containsPair('sortOrder', 2),
            ))).called(1);
        verify(() => mockBatch.commit()).called(1);
      });

      test('handles empty list', () async {
        // Arrange
        final mockBatch = MockWriteBatch();
        when(() => mockFirestore.batch()).thenReturn(mockBatch);
        when(() => mockBatch.commit()).thenAnswer((_) async {});

        // Act
        await repository.reorder([]);

        // Assert: Batch still committed (even if empty)
        verify(() => mockBatch.commit()).called(1);
      });
    });

    group('clearGroupFromTags', () {
      test('clears groupId from all tags in group', () async {
        // Arrange
        final tag1 =
            PersonalTagBuilder().withId('tag-1').withGroupId('group-1').build();
        final tag2 =
            PersonalTagBuilder().withId('tag-2').withGroupId('group-1').build();

        // Mock query for tags in group
        final mockQuery = MockQuery();
        final mockQuerySnapshot = MockQuerySnapshot();
        final mockQDoc1 = MockQueryDocumentSnapshot();
        final mockQDoc2 = MockQueryDocumentSnapshot();

        when(() => mockCollection.where('groupId', isEqualTo: 'group-1'))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy('sortOrder')).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(() => mockQuerySnapshot.docs).thenReturn([mockQDoc1, mockQDoc2]);

        when(() => mockQDoc1.id).thenReturn('tag-1');
        when(() => mockQDoc1.data()).thenReturn(tag1.toFirestore());
        when(() => mockQDoc2.id).thenReturn('tag-2');
        when(() => mockQDoc2.data()).thenReturn(tag2.toFirestore());

        // Mock batch operations
        final mockBatch = MockWriteBatch();
        when(() => mockFirestore.batch()).thenReturn(mockBatch);

        final mockDocRef1 = MockDocumentReference();
        final mockDocRef2 = MockDocumentReference();

        when(() => mockCollection.doc('tag-1')).thenReturn(mockDocRef1);
        when(() => mockCollection.doc('tag-2')).thenReturn(mockDocRef2);

        when(() => mockBatch.update(any(), any())).thenReturn(null);
        when(() => mockBatch.commit()).thenAnswer((_) async {});

        // Act
        final count = await repository.clearGroupFromTags('group-1');

        // Assert
        expect(count, 2);
        verify(() => mockBatch.update(mockDocRef1, any())).called(1);
        verify(() => mockBatch.update(mockDocRef2, any())).called(1);
        verify(() => mockBatch.commit()).called(1);
      });

      test('returns 0 for empty group', () async {
        // Arrange
        final mockQuery = MockQuery();
        final mockQuerySnapshot = MockQuerySnapshot();

        when(() => mockCollection.where('groupId', isEqualTo: 'empty-group'))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy('sortOrder')).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(() => mockQuerySnapshot.docs).thenReturn([]);

        // Act
        final count = await repository.clearGroupFromTags('empty-group');

        // Assert
        expect(count, 0);
        verifyNever(() => mockFirestore.batch());
      });
    });

    group('#7: addClearGroupToBatch', () {
      test('adds update operations to external batch', () async {
        // Arrange
        final tag1 =
            PersonalTagBuilder().withId('tag-1').withGroupId('group-1').build();

        // Mock query
        final mockQuery = MockQuery();
        final mockQuerySnapshot = MockQuerySnapshot();
        final mockQDoc = MockQueryDocumentSnapshot();

        when(() => mockCollection.where('groupId', isEqualTo: 'group-1'))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy('sortOrder')).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(() => mockQuerySnapshot.docs).thenReturn([mockQDoc]);

        when(() => mockQDoc.id).thenReturn('tag-1');
        when(() => mockQDoc.data()).thenReturn(tag1.toFirestore());

        // External batch
        final externalBatch = MockWriteBatch();
        final mockDocRef = MockDocumentReference();

        when(() => mockCollection.doc('tag-1')).thenReturn(mockDocRef);
        when(() => externalBatch.update(any(), any())).thenReturn(null);

        // Act
        final count =
            await repository.addClearGroupToBatch(externalBatch, 'group-1');

        // Assert: Operations added to external batch, not committed
        expect(count, 1);
        verify(() => externalBatch.update(mockDocRef, any())).called(1);
        verifyNever(() => externalBatch.commit()); // Caller commits
      });

      test('returns 0 and adds nothing for empty group', () async {
        // Arrange
        final mockQuery = MockQuery();
        final mockQuerySnapshot = MockQuerySnapshot();

        when(() => mockCollection.where('groupId', isEqualTo: 'empty-group'))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy('sortOrder')).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(() => mockQuerySnapshot.docs).thenReturn([]);

        final externalBatch = MockWriteBatch();

        // Act
        final count =
            await repository.addClearGroupToBatch(externalBatch, 'empty-group');

        // Assert
        expect(count, 0);
        verifyNever(() => externalBatch.update(any(), any()));
      });
    });

    group('#7: newWriteBatch', () {
      test('creates new WriteBatch from firestore', () {
        // Arrange
        final mockBatch = MockWriteBatch();
        when(() => mockFirestore.batch()).thenReturn(mockBatch);

        // Act
        final batch = repository.newWriteBatch();

        // Assert
        expect(batch, mockBatch);
        verify(() => mockFirestore.batch()).called(1);
      });
    });
  });
}

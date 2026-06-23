/// Unit tests for FirebasePersonalTagRepository batch operations.
///
/// Tests the repository methods that were identified in issue #9:
/// - getByIds(): Get multiple tags efficiently
/// - reorder(): Batch update sort orders
/// - clearGroupFromTags(): Clear groupId from all tags in a group
/// - addClearGroupToBatch(): Add clear operations to external batch (#7)
/// - newWriteBatch(): Create batch for atomic operations (#7)
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';

import '../../../infrastructure/builders/personal_tag_builder.dart';

// Only project-interface mocks are kept — SDK shapes come from FakeFirebaseFirestore.
class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockAuthRepository mockAuthRepository;
  late FirebasePersonalTagRepository repository;

  const testUserId = 'test-user-123';

  // Convenience for the user subcollection the repo writes into:
  // users/{uid}/personal_tags
  CollectionReference<Map<String, dynamic>> tagsRef() => fakeFirestore
      .collection('users')
      .doc(testUserId)
      .collection('personal_tags');

  setUpAll(() {
    registerFallbackValue(PersonalTagBuilder().build());
  });

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuthRepository = MockAuthRepository();

    when(() => mockAuthRepository.currentUserId).thenReturn(testUserId);

    repository = FirebasePersonalTagRepository(
      firestore: fakeFirestore,
      authRepository: mockAuthRepository,
    );
  });

  group('#9: FirebasePersonalTagRepository batch operations', () {
    group('getByIds', () {
      test('returns tags for valid IDs', () async {
        // Arrange: seed two tags in the user subcollection.
        final tag1 = PersonalTagBuilder()
            .withId('tag-1')
            .withName('Tag One')
            .build();
        final tag2 = PersonalTagBuilder()
            .withId('tag-2')
            .withName('Tag Two')
            .build();
        await tagsRef().doc('tag-1').set(tag1.toFirestore());
        await tagsRef().doc('tag-2').set(tag2.toFirestore());

        // Act
        final result = await repository.getByIds(['tag-1', 'tag-2']);

        // Assert
        expect(result.length, 2);
        expect(result.any((t) => t.id == 'tag-1'), isTrue);
        expect(result.any((t) => t.id == 'tag-2'), isTrue);
      });

      test('returns empty list for empty IDs', () async {
        final result = await repository.getByIds([]);
        expect(result, isEmpty);
      });

      test('ignores missing IDs silently', () async {
        // Arrange: only tag-1 exists.
        final tag1 = PersonalTagBuilder()
            .withId('tag-1')
            .withName('Tag One')
            .build();
        await tagsRef().doc('tag-1').set(tag1.toFirestore());

        // Act: request one existing + one missing.
        final result = await repository.getByIds(['tag-1', 'missing-tag']);

        // Assert: missing IDs are simply absent.
        expect(result.length, 1);
        expect(result.first.id, 'tag-1');
      });
    });

    group('reorder', () {
      test('updates sortOrder for all tags', () async {
        // Arrange: seed three tags with arbitrary sort orders.
        for (final id in ['tag-1', 'tag-2', 'tag-3']) {
          await tagsRef()
              .doc(id)
              .set(
                PersonalTagBuilder()
                    .withId(id)
                    .withName(id)
                    .build()
                    .toFirestore(),
              );
        }

        // Act
        await repository.reorder(['tag-1', 'tag-2', 'tag-3']);

        // Assert: sortOrder matches position in list.
        final doc1 = await tagsRef().doc('tag-1').get();
        final doc2 = await tagsRef().doc('tag-2').get();
        final doc3 = await tagsRef().doc('tag-3').get();
        expect(doc1.data()!['sortOrder'], 0);
        expect(doc2.data()!['sortOrder'], 1);
        expect(doc3.data()!['sortOrder'], 2);
      });

      test('handles empty list', () async {
        // Act & assert: no documents to reorder, no exception.
        await expectLater(repository.reorder([]), completes);
      });
    });

    group('clearGroupFromTags', () {
      test('clears groupId from all tags in group', () async {
        // Arrange: two tags in group-1, one in a different group.
        await tagsRef()
            .doc('tag-1')
            .set(
              PersonalTagBuilder()
                  .withId('tag-1')
                  .withGroupId('group-1')
                  .build()
                  .toFirestore(),
            );
        await tagsRef()
            .doc('tag-2')
            .set(
              PersonalTagBuilder()
                  .withId('tag-2')
                  .withGroupId('group-1')
                  .build()
                  .toFirestore(),
            );
        await tagsRef()
            .doc('tag-3')
            .set(
              PersonalTagBuilder()
                  .withId('tag-3')
                  .withGroupId('group-other')
                  .build()
                  .toFirestore(),
            );

        // Act
        final count = await repository.clearGroupFromTags('group-1');

        // Assert
        expect(count, 2);
        final doc1 = await tagsRef().doc('tag-1').get();
        final doc2 = await tagsRef().doc('tag-2').get();
        final doc3 = await tagsRef().doc('tag-3').get();
        // FieldValue.delete removes the field entirely.
        expect(doc1.data()!.containsKey('groupId'), isFalse);
        expect(doc2.data()!.containsKey('groupId'), isFalse);
        // Untouched tag keeps its group.
        expect(doc3.data()!['groupId'], 'group-other');
      });

      test('returns 0 for empty group', () async {
        final count = await repository.clearGroupFromTags('empty-group');
        expect(count, 0);
      });
    });

    group('#7: addClearGroupToBatch', () {
      test('adds update operations to external batch', () async {
        // Arrange: one tag in group-1.
        await tagsRef()
            .doc('tag-1')
            .set(
              PersonalTagBuilder()
                  .withId('tag-1')
                  .withGroupId('group-1')
                  .build()
                  .toFirestore(),
            );

        final externalBatch = fakeFirestore.batch();

        // Act
        final count = await repository.addClearGroupToBatch(
          externalBatch,
          'group-1',
        );

        // Assert: operation added but NOT committed yet.
        expect(count, 1);
        var doc = await tagsRef().doc('tag-1').get();
        expect(
          doc.data()!['groupId'],
          'group-1',
          reason: 'caller must commit the external batch',
        );

        // Once caller commits, the update lands.
        await externalBatch.commit();
        doc = await tagsRef().doc('tag-1').get();
        expect(doc.data()!.containsKey('groupId'), isFalse);
      });

      test('returns 0 and adds nothing for empty group', () async {
        final externalBatch = fakeFirestore.batch();
        final count = await repository.addClearGroupToBatch(
          externalBatch,
          'empty-group',
        );
        expect(count, 0);
        // Committing an empty batch is a no-op.
        await expectLater(externalBatch.commit(), completes);
      });
    });

    group('#7: newWriteBatch', () {
      test('creates a WriteBatch from firestore', () {
        final batch = repository.newWriteBatch();
        expect(batch, isA<WriteBatch>());
      });
    });
  });
}

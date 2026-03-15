/// Unit tests for FirebaseSharedPersonalTagRepository permission validation.
///
/// Tests the permission methods that control shared tag access:
/// - validateCreatePermission: only creator can create
/// - validateReadPermission: any authenticated user can read
/// - validateUpdatePermission: only creator can update
/// - validateDeletePermission: only creator can delete (fetch + check)
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/shared_personal_tag.dart';
import 'package:butlery/repositories/firebase/firebase_shared_personal_tag_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockAuthRepository extends Mock implements AuthRepository {}

SharedPersonalTag _createTag({
  String id = 'tag-1',
  String sharedByUserId = 'user-1',
}) {
  return SharedPersonalTag(
    id: id,
    tagName: 'Test Tag',
    sharedByUserId: sharedByUserId,
    sharedByDisplayName: 'Test User',
    sharedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDocRef;
  late MockAuthRepository mockAuthRepository;
  late FirebaseSharedPersonalTagRepository repository;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockDocRef = MockDocumentReference();
    mockAuthRepository = MockAuthRepository();

    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
    when(() => mockAuthRepository.currentUserId).thenReturn('user-1');

    repository = FirebaseSharedPersonalTagRepository(
      firestore: mockFirestore,
      authRepository: mockAuthRepository,
    );
  });

  group('validateCreatePermission', () {
    test('allows creation when user is the sharer', () async {
      final tag = _createTag(sharedByUserId: 'user-1');
      final result = await repository.validateCreatePermission('user-1', tag);
      expect(result, isTrue);
    });

    test('denies creation when user is not the sharer', () async {
      final tag = _createTag(sharedByUserId: 'other-user');
      final result = await repository.validateCreatePermission('user-1', tag);
      expect(result, isFalse);
    });
  });

  group('validateReadPermission', () {
    test('allows read for any authenticated user', () async {
      final result =
          await repository.validateReadPermission('user-1', 'tag-1', null);
      expect(result, isTrue);
    });

    test('allows read for non-owner user', () async {
      final tag = _createTag(sharedByUserId: 'other-user');
      final result =
          await repository.validateReadPermission('user-1', 'tag-1', tag);
      expect(result, isTrue);
    });
  });

  group('validateUpdatePermission', () {
    test('allows update when user is the sharer', () async {
      final tag = _createTag(sharedByUserId: 'user-1');
      final result =
          await repository.validateUpdatePermission('user-1', 'tag-1', tag);
      expect(result, isTrue);
    });

    test('denies update when user is not the sharer', () async {
      final tag = _createTag(sharedByUserId: 'other-user');
      final result =
          await repository.validateUpdatePermission('user-1', 'tag-1', tag);
      expect(result, isFalse);
    });
  });

  group('validateDeletePermission', () {
    test('allows delete when user is the sharer', () async {
      final mockSnapshot = MockDocumentSnapshot();
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.id).thenReturn('tag-1');
      when(() => mockSnapshot.data()).thenReturn({
        'tagName': 'Test Tag',
        'sharedByUserId': 'user-1',
        'sharedByDisplayName': 'Test User',
        'sharedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);

      final result =
          await repository.validateDeletePermission('user-1', 'tag-1');
      expect(result, isTrue);
    });

    test('denies delete when user is not the sharer', () async {
      final mockSnapshot = MockDocumentSnapshot();
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.id).thenReturn('tag-1');
      when(() => mockSnapshot.data()).thenReturn({
        'tagName': 'Test Tag',
        'sharedByUserId': 'other-user',
        'sharedByDisplayName': 'Other User',
        'sharedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);

      final result =
          await repository.validateDeletePermission('user-1', 'tag-1');
      expect(result, isFalse);
    });

    test('denies delete when document does not exist', () async {
      final mockSnapshot = MockDocumentSnapshot();
      when(() => mockSnapshot.exists).thenReturn(false);

      when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);

      final result =
          await repository.validateDeletePermission('user-1', 'tag-1');
      expect(result, isFalse);
    });
  });
}

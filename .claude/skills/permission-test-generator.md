---
description: >
  Generates standard permission validation tests for Firebase repositories.
  Use when creating tests for any repository, adding CRUD operations, or
  verifying permission checks (create/read/update/delete for own vs other user).
---

# Permission Test Generator

> Generate standard permission tests for repositories.

## Standard Permission Tests

Varje repository MÅSTE ha dessa tester:

```dart
group('Permission Validation', () {
  late Firebase{Entity}Repository repository;
  late MockAuthRepository mockAuthRepository;
  late FakeFirebaseFirestore fakeFirestore;

  const testUserId = 'test-user-123';
  const otherUserId = 'other-user-456';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuthRepository = MockAuthRepository();
    repository = Firebase{Entity}Repository(
      firestore: fakeFirestore,
      authRepository: mockAuthRepository,
    );
  });

  group('Create Permission', () {
    test('should allow user to create their own {entity}', () async {
      when(() => mockAuthRepository.currentUserId).thenReturn(testUserId);

      final entity = {Entity}(id: 'e1', ownerId: testUserId, ...);

      final result = await repository.create(entity);

      expect(result.id, 'e1');
    });

    test('should reject user creating {entity} for another user', () async {
      when(() => mockAuthRepository.currentUserId).thenReturn(testUserId);

      final entity = {Entity}(id: 'e1', ownerId: otherUserId, ...);

      expect(
        () => repository.create(entity),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('should reject unauthenticated user', () async {
      when(() => mockAuthRepository.currentUserId).thenReturn(null);

      final entity = {Entity}(id: 'e1', ownerId: testUserId, ...);

      expect(
        () => repository.create(entity),
        throwsA(isA<AuthenticationException>()),
      );
    });
  });

  group('Read Permission', () {
    test('should allow user to read their own {entity}', () async {
      when(() => mockAuthRepository.currentUserId).thenReturn(testUserId);

      // Setup: create entity first
      await fakeFirestore.collection('users').doc(testUserId)
          .collection('{entities}').doc('e1')
          .set({'ownerId': testUserId, ...});

      final result = await repository.getById('e1');

      expect(result, isNotNull);
    });

    test('should reject user reading another user\'s {entity}', () async {
      when(() => mockAuthRepository.currentUserId).thenReturn(testUserId);

      // Setup: entity owned by other user
      await fakeFirestore.collection('users').doc(otherUserId)
          .collection('{entities}').doc('e1')
          .set({'ownerId': otherUserId, ...});

      expect(
        () => repository.getById('e1'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('Update Permission', () {
    test('should allow user to update their own {entity}', () async {
      when(() => mockAuthRepository.currentUserId).thenReturn(testUserId);

      final entity = {Entity}(id: 'e1', ownerId: testUserId, ...);
      await repository.create(entity);

      final updated = entity.copyWith(title: 'Updated');
      final result = await repository.update(updated);

      expect(result.title, 'Updated');
    });

    test('should reject user updating another user\'s {entity}', () async {
      when(() => mockAuthRepository.currentUserId).thenReturn(testUserId);

      final entity = {Entity}(id: 'e1', ownerId: otherUserId, ...);

      expect(
        () => repository.update(entity),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('Delete Permission', () {
    test('should allow user to delete their own {entity}', () async {
      when(() => mockAuthRepository.currentUserId).thenReturn(testUserId);

      final entity = {Entity}(id: 'e1', ownerId: testUserId, ...);
      await repository.create(entity);

      await repository.delete('e1');

      final result = await repository.getById('e1');
      expect(result, isNull);
    });

    test('should reject user deleting another user\'s {entity}', () async {
      when(() => mockAuthRepository.currentUserId).thenReturn(testUserId);

      expect(
        () => repository.delete('e1'), // owned by other
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });
});
```

## Imports

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/firebase/firebase_{entity}_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
```

## Checklista (8-10 tester)

- [ ] Create: egen entity ✅
- [ ] Create: annan användares entity ❌
- [ ] Create: ej autentiserad ❌
- [ ] Read: egen entity ✅
- [ ] Read: annan användares entity ❌
- [ ] Update: egen entity ✅
- [ ] Update: annan användares entity ❌
- [ ] Delete: egen entity ✅
- [ ] Delete: annan användares entity ❌

## Nyckelfilar

- `test/unit/repositories/firebase_shared_recipe_repository_test.dart` - Exemplar
- `lib/core/exceptions/permission_exceptions.dart`

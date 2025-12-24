/// Unit tests for BaseFirebaseRepository
///
/// Tests the base Firebase repository that provides unified CRUD operations
/// and permission validation for all Firebase collections in the application.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Test model for concrete implementation
class TestModel {
  final String id;
  final String title;
  final String? ownerId;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  TestModel({
    required this.id,
    required this.title,
    this.ownerId,
    DateTime? createdAt,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'title': title,
        'ownerId': ownerId,
        'createdAt': Timestamp.fromDate(createdAt),
        'metadata': metadata,
      };

  factory TestModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TestModel(
      id: data['id'] as String,
      title: data['title'] as String,
      ownerId: data['ownerId'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }
}

// Concrete implementation for testing
class TestFirebaseRepository extends BaseFirebaseRepository<TestModel> {
  TestFirebaseRepository({
    required super.authRepository,
    super.firestore,
  });

  @override
  String get collectionName => 'test_collection';

  @override
  TestModel fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TestModel.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore(TestModel entity) {
    return entity.toFirestore();
  }

  @override
  String getId(TestModel entity) => entity.id;

  // ===== PERMISSION VALIDATION STUBS FOR TESTING =====

  @override
  Future<bool> validateCreatePermission(String userId, TestModel entity) async {
    // For tests: allow creation if ownerId matches or is null
    return entity.ownerId == null || entity.ownerId == userId;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, TestModel? entity) async {
    // For tests: allow all reads
    return true;
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, TestModel entity) async {
    // For tests: allow update if ownerId matches
    return entity.ownerId == null || entity.ownerId == userId;
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    // For tests: allow all deletes
    return true;
  }
}

// User-scoped test repository
class UserScopedTestRepository extends BaseFirebaseRepository<TestModel> {
  UserScopedTestRepository({
    required super.authRepository,
    super.firestore,
  });

  @override
  String get collectionName => 'user_test_items';

  @override
  TestModel fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TestModel.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore(TestModel entity) {
    return entity.toFirestore();
  }

  @override
  String getId(TestModel entity) => entity.id;

  // ===== PERMISSION VALIDATION STUBS FOR TESTING =====

  @override
  Future<bool> validateCreatePermission(String userId, TestModel entity) async {
    // For tests: allow creation if ownerId matches or is null
    return entity.ownerId == null || entity.ownerId == userId;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, TestModel? entity) async {
    // For tests: allow all reads
    return true;
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, TestModel entity) async {
    // For tests: allow update if ownerId matches
    return entity.ownerId == null || entity.ownerId == userId;
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    // For tests: allow all deletes
    return true;
  }

  // Override to use user-scoped collection
  @override
  CollectionReference<Map<String, dynamic>> getCollectionRef() {
    return getUserCollection(null); // Uses current user
  }
}

void main() {
  group('BaseFirebaseRepository', () {
    late TestFirebaseRepository repository;
    late UserScopedTestRepository userScopedRepository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepository;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(TestModel(id: 'fallback', title: 'Fallback'));
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Setup fake Firestore and mock auth
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepository = MockAuthRepository();

      // Configure auth state
      mockAuthRepository.setAuthState(userId: 'test_user_123');

      // Create repositories
      repository = TestFirebaseRepository(
        authRepository: mockAuthRepository,
        firestore: fakeFirestore,
      );

      userScopedRepository = UserScopedTestRepository(
        authRepository: mockAuthRepository,
        firestore: fakeFirestore,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Authentication Checks', () {
      test('should require authenticated user for write operations', () {
        // Arrange
        mockAuthRepository.setAuthState(userId: null); // No authenticated user

        // Act & Assert
        expect(
          () => repository.requireCurrentUserId(),
          throwsA(isA<AuthenticationException>()),
        );
      });

      test('should allow operations with authenticated user', () {
        // Arrange
        mockAuthRepository.setAuthState(userId: 'user_123');

        // Act & Assert
        expect(
          () => repository.requireCurrentUserId(),
          returnsNormally,
        );
        expect(repository.requireCurrentUserId(), equals('user_123'));
      });

      test('should return null for optional auth check when not authenticated',
          () {
        // Arrange
        mockAuthRepository.setAuthState(userId: null);

        // Act
        final userId = repository.currentUserId;

        // Assert
        expect(userId, isNull);
      });
    });

    group('Collection References', () {
      test('should provide global collection reference', () {
        // Act
        final collection = repository.collection;

        // Assert
        expect(collection, isNotNull);
        expect(collection.path, equals('test_collection'));
      });

      test('should provide user-scoped collection reference', () {
        // Arrange
        mockAuthRepository.setAuthState(userId: 'user_456');

        // Act
        final userCollection = repository.getUserCollection(null);

        // Assert
        expect(userCollection, isNotNull);
        expect(userCollection.path, equals('users/user_456/test_collection'));
      });

      test('should use provided userId for user collection', () {
        // Act
        final userCollection = repository.getUserCollection('specific_user');

        // Assert
        expect(
            userCollection.path, equals('users/specific_user/test_collection'));
      });
    });

    group('CRUD Operations', () {
      test('should create entity with authentication', () async {
        // Arrange
        final model = TestModel(
          id: 'test_123',
          title: 'Swedish Meatballs',
          ownerId: 'test_user_123',
        );

        // Act
        final result = await repository.create(model);

        // Assert
        expect(result, equals(model));

        // Verify in Firestore
        final doc = await fakeFirestore
            .collection('test_collection')
            .doc('test_123')
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['title'], equals('Swedish Meatballs'));
      });

      test('should read entity by id', () async {
        // Arrange
        final model = TestModel(
          id: 'test_456',
          title: 'Köttbullar',
          metadata: {'cuisine': 'Swedish'},
        );

        // Create test data
        await fakeFirestore
            .collection('test_collection')
            .doc('test_456')
            .set(model.toFirestore());

        // Act
        final result = await repository.read('test_456');

        // Assert
        expect(result, isNotNull);
        expect(result!.id, equals('test_456'));
        expect(result.title, equals('Köttbullar'));
        expect(result.metadata?['cuisine'], equals('Swedish'));
      });

      test('should return null for non-existent entity', () async {
        // Act
        final result = await repository.read('non_existent');

        // Assert
        expect(result, isNull);
      });

      test('should read all entities', () async {
        // Arrange
        final models = [
          TestModel(id: '1', title: 'First'),
          TestModel(id: '2', title: 'Second'),
          TestModel(id: '3', title: 'Third'),
        ];

        for (final model in models) {
          await fakeFirestore
              .collection('test_collection')
              .doc(model.id)
              .set(model.toFirestore());
        }

        // Act
        final results = await repository.readAll();

        // Assert
        expect(results.length, equals(3));
        expect(results.map((m) => m.title),
            containsAll(['First', 'Second', 'Third']));
      });

      test('should update entity with authentication', () async {
        // Arrange
        final original = TestModel(id: 'update_test', title: 'Original');
        await fakeFirestore
            .collection('test_collection')
            .doc('update_test')
            .set(original.toFirestore());

        final updated = TestModel(id: 'update_test', title: 'Updated');

        // Act
        await repository.update(updated);

        // Assert
        final doc = await fakeFirestore
            .collection('test_collection')
            .doc('update_test')
            .get();
        expect(doc.data()?['title'], equals('Updated'));
      });

      test('should delete entity with authentication', () async {
        // Arrange
        final model = TestModel(id: 'delete_test', title: 'To Delete');
        await fakeFirestore
            .collection('test_collection')
            .doc('delete_test')
            .set(model.toFirestore());

        // Act
        await repository.delete('delete_test');

        // Assert
        final doc = await fakeFirestore
            .collection('test_collection')
            .doc('delete_test')
            .get();
        expect(doc.exists, isFalse);
      });
    });

    group('Batch Operations', () {
      test('should create multiple entities in batch', () async {
        // Arrange
        final models = [
          TestModel(id: 'batch_1', title: 'Batch Item 1'),
          TestModel(id: 'batch_2', title: 'Batch Item 2'),
          TestModel(id: 'batch_3', title: 'Batch Item 3'),
        ];

        // Act
        await repository.createBatch(models);

        // Assert
        for (final model in models) {
          final doc = await fakeFirestore
              .collection('test_collection')
              .doc(model.id)
              .get();
          expect(doc.exists, isTrue);
          expect(doc.data()?['title'], equals(model.title));
        }
      });
    });

    group('Stream Operations', () {
      test('should watch all entities with real-time updates', () async {
        // Arrange
        final models = [
          TestModel(id: 'stream_1', title: 'Stream Item 1'),
          TestModel(id: 'stream_2', title: 'Stream Item 2'),
        ];

        for (final model in models) {
          await fakeFirestore
              .collection('test_collection')
              .doc(model.id)
              .set(model.toFirestore());
        }

        // Act
        final stream = repository.watchAll();

        // Assert
        final items = await stream.first;
        expect(items.length, equals(2));
        expect(items.map((m) => m.title),
            containsAll(['Stream Item 1', 'Stream Item 2']));
      });

      test('should support ordered streaming', () async {
        // Arrange
        final now = DateTime.now();
        final models = [
          TestModel(
              id: '1', title: 'C Item', createdAt: now.add(Duration(days: 2))),
          TestModel(id: '2', title: 'A Item', createdAt: now),
          TestModel(
              id: '3', title: 'B Item', createdAt: now.add(Duration(days: 1))),
        ];

        for (final model in models) {
          await fakeFirestore
              .collection('test_collection')
              .doc(model.id)
              .set(model.toFirestore());
        }

        // Act
        final stream =
            repository.watchAll(orderBy: 'createdAt', descending: false);

        // Assert
        final items = await stream.first;
        expect(items.map((m) => m.title).toList(),
            equals(['A Item', 'B Item', 'C Item']));
      });
    });

    group('Utility Methods', () {
      test('should check if entity exists', () async {
        // Arrange
        final model = TestModel(id: 'exists_test', title: 'Existing');
        await fakeFirestore
            .collection('test_collection')
            .doc('exists_test')
            .set(model.toFirestore());

        // Act
        final exists = await repository.exists('exists_test');
        final notExists = await repository.exists('non_existent');

        // Assert
        expect(exists, isTrue);
        expect(notExists, isFalse);
      });

      test('should count entities in collection', () async {
        // Arrange
        for (int i = 0; i < 5; i++) {
          final model = TestModel(id: 'count_$i', title: 'Item $i');
          await fakeFirestore
              .collection('test_collection')
              .doc(model.id)
              .set(model.toFirestore());
        }

        // Act
        final count = await repository.count();

        // Assert
        expect(count, equals(5));
      });
    });

    group('User-Scoped Repository', () {
      test('should use user-scoped collection for all operations', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: 'scoped_user');
        final model = TestModel(
          id: 'user_item_1',
          title: 'User Scoped Item',
          ownerId: 'scoped_user',
        );

        // Act
        await userScopedRepository.create(model);

        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc('scoped_user')
            .collection('user_test_items')
            .doc('user_item_1')
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['title'], equals('User Scoped Item'));
      });

      test('should read from user-scoped collection', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: 'reader_user');
        final model = TestModel(
          id: 'read_item',
          title: 'User Read Item',
          ownerId: 'reader_user',
        );

        await fakeFirestore
            .collection('users')
            .doc('reader_user')
            .collection('user_test_items')
            .doc('read_item')
            .set(model.toFirestore());

        // Act
        final result = await userScopedRepository.read('read_item');

        // Assert
        expect(result, isNotNull);
        expect(result!.title, equals('User Read Item'));
      });
    });

    group('Error Handling', () {
      test('should throw exception when not authenticated', () {
        // Arrange
        mockAuthRepository.setAuthState(userId: null);
        final model = TestModel(id: 'auth_test', title: 'Auth Test');

        // Act & Assert
        // BaseFirebaseRepository wraps AuthenticationException in a generic Exception
        expect(
          () async => await repository.create(model),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('AuthenticationException'),
            ),
          ),
        );

        expect(
          () async => await repository.update(model),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('AuthenticationException'),
            ),
          ),
        );

        expect(
          () async => await repository.delete('auth_test'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('AuthenticationException'),
            ),
          ),
        );
      });

      test('should return null for empty id reads', () async {
        // FakeFirebaseFirestore handles empty doc IDs gracefully
        // and returns a non-existent document

        // Act
        final result = await repository.read('');

        // Assert
        expect(result, isNull);
      });
    });
  });
}

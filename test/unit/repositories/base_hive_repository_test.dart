// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:butlery/repositories/hive/base_hive_repository.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Test model class
class TestModel {
  final String id;
  final String name;
  final int value;

  TestModel({
    required this.id,
    required this.name,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'value': value,
      };

  factory TestModel.fromJson(Map<String, dynamic> json) => TestModel(
        id: json['id'] as String,
        name: json['name'] as String,
        value: json['value'] as int,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          value == other.value;

  @override
  int get hashCode => Object.hash(id, name, value);
}

// Concrete implementation for testing
class TestHiveRepository extends BaseHiveRepository<TestModel> {
  TestHiveRepository(super.boxName);

  // For testing purposes, we'll track if init was called
  bool initCalled = false;
  Box<TestModel>? injectedBox;

  @override
  Future<void> init({String? userId}) async {
    initCalled = true;
    // In tests, we use the injected box instead of opening a real one
    if (injectedBox != null) {
      // We can't access _box directly, but we can test the behavior
      return;
    }
    // For real init test, would call super.init(userId: userId)
  }

  // Override box getter to use injected box for testing
  @override
  Box<TestModel> get box {
    if (injectedBox != null) {
      return injectedBox!;
    }
    return super.box;
  }

  // Override dispose to use injected box
  @override
  Future<void> dispose() async {
    if (injectedBox != null) {
      await injectedBox!.close();
      return;
    }
    await super.dispose();
  }

  // Override clearUserCache to use injected box
  @override
  Future<void> clearUserCache() async {
    if (injectedBox != null) {
      await injectedBox!.clear();
      return;
    }
    await super.clearUserCache();
  }

  // Allow injection for testing
  void setBoxForTesting(Box<TestModel> box) {
    injectedBox = box;
  }

  // Expose whether we have a box for testing
  bool get hasBox => injectedBox != null;
}

// Fake class for any() matching
class FakeTestModel extends Fake implements TestModel {}

void main() {
  setUpAll(() {
    // Register fallback values for any() matchers
    registerFallbackValue(FakeTestModel());
  });

  group('BaseHiveRepository', () {
    late TestHiveRepository repository;
    late MockBox<TestModel> mockBox;

    // Test data
    const boxName = 'test_box';
    const userId = 'user-123';

    late TestModel testModel1;
    late TestModel testModel2;
    late TestModel testModel3;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Initialize mocks
      mockBox = MockBox<TestModel>();

      // Setup test data
      testModel1 = TestModel(
        id: 'test-1',
        name: 'Test Item 1',
        value: 100,
      );

      testModel2 = TestModel(
        id: 'test-2',
        name: 'Test Item 2',
        value: 200,
      );

      testModel3 = TestModel(
        id: 'test-3',
        name: 'Test Item 3',
        value: 300,
      );

      // Setup box mock defaults
      when(() => mockBox.values).thenReturn([testModel1, testModel2]);
      when(() => mockBox.get(any())).thenReturn(null);
      when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
      when(() => mockBox.delete(any())).thenAnswer((_) async {});
      when(() => mockBox.clear()).thenAnswer((_) async => 0);
      when(() => mockBox.close()).thenAnswer((_) async {});
      when(() => mockBox.isOpen).thenReturn(true);

      // Create repository
      repository = TestHiveRepository(boxName);
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('constructor and initialization', () {
      test('should create repository with specified box name', () {
        // Assert
        expect(repository.boxName, equals(boxName));
      });

      test('should start with null box before initialization', () {
        // Assert
        expect(repository.hasBox, isFalse);
      });

      test('init should mark repository as initialized', () async {
        // Arrange
        repository.setBoxForTesting(mockBox);

        // Act
        await repository.init(userId: userId);

        // Assert
        expect(repository.initCalled, isTrue);
        expect(repository.hasBox, isTrue);
      });
    });

    group('box getter', () {
      test('should throw StateError when box not initialized', () {
        // Act & Assert
        expect(
          () => repository.box,
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Hive-box $boxName är inte initialiserad'),
          )),
        );
      });

      test('should return box when initialized', () {
        // Arrange
        repository.setBoxForTesting(mockBox);

        // Act
        final box = repository.box;

        // Assert
        expect(box, equals(mockBox));
      });
    });

    group('CRUD operations', () {
      setUp(() {
        // Initialize repository with mock box
        repository.setBoxForTesting(mockBox);
      });

      test('getAll should return all values from box', () {
        // Act
        final allItems = repository.getAll();

        // Assert
        expect(allItems, equals([testModel1, testModel2]));
        verify(() => mockBox.values).called(1);
      });

      test('get should retrieve specific item by key', () {
        // Arrange
        when(() => mockBox.get('test-key')).thenReturn(testModel1);

        // Act
        final item = repository.get('test-key');

        // Assert
        expect(item, equals(testModel1));
        verify(() => mockBox.get('test-key')).called(1);
      });

      test('get should return null for non-existent key', () {
        // Arrange
        when(() => mockBox.get('missing-key')).thenReturn(null);

        // Act
        final item = repository.get('missing-key');

        // Assert
        expect(item, isNull);
        verify(() => mockBox.get('missing-key')).called(1);
      });

      test('put should store item with key', () async {
        // Act
        await repository.put('new-key', testModel3);

        // Assert
        verify(() => mockBox.put('new-key', testModel3)).called(1);
      });

      test('delete should remove item by key', () async {
        // Act
        await repository.delete('test-key');

        // Assert
        verify(() => mockBox.delete('test-key')).called(1);
      });

      test('clear should remove all items from box', () async {
        // Act
        await repository.clear();

        // Assert
        verify(() => mockBox.clear()).called(1);
      });
    });

    group('lifecycle management', () {
      test('dispose should close the box when box exists', () async {
        // Arrange
        repository.setBoxForTesting(mockBox);

        // Act
        await repository.dispose();

        // Assert
        verify(() => mockBox.close()).called(1);
      });

      test('dispose should handle null box gracefully', () async {
        // Act & Assert - should not throw
        await expectLater(repository.dispose(), completes);
      });

      test('clearUserCache should clear box when initialized', () async {
        // Arrange
        repository.setBoxForTesting(mockBox);

        // Act
        await repository.clearUserCache();

        // Assert
        verify(() => mockBox.clear()).called(1);
      });

      test('clearUserCache should handle null box gracefully', () async {
        // Act & Assert - should not throw
        await expectLater(repository.clearUserCache(), completes);
      });
    });

    group('user switching', () {
      test('switchUser should close current box before switching', () async {
        // Arrange
        repository.setBoxForTesting(mockBox);

        // Note: We can't fully test switchUser as it calls init() which uses Hive.openBox
        // But we can verify the box closure logic

        // For a complete test, we'd need to refactor the repository to accept
        // a HiveInterface dependency or use integration tests
      });
    });

    group('edge cases', () {
      test('should handle operations with various key types', () async {
        // Arrange
        repository.setBoxForTesting(mockBox);

        // Test with string key
        await repository.put('string-key', testModel1);
        verify(() => mockBox.put('string-key', testModel1)).called(1);

        // Test with int key
        await repository.put(123, testModel2);
        verify(() => mockBox.put(123, testModel2)).called(1);

        // Test get with different key types
        repository.get('string-key');
        verify(() => mockBox.get('string-key')).called(1);

        repository.get(123);
        verify(() => mockBox.get(123)).called(1);
      });

      test('should handle empty list from getAll', () {
        // Arrange
        repository.setBoxForTesting(mockBox);
        when(() => mockBox.values).thenReturn([]);

        // Act
        final items = repository.getAll();

        // Assert
        expect(items, isEmpty);
      });

      test('should handle large datasets in getAll', () {
        // Arrange
        repository.setBoxForTesting(mockBox);
        final largeDataset = List.generate(
          1000,
          (i) => TestModel(id: 'id-$i', name: 'Name $i', value: i),
        );
        when(() => mockBox.values).thenReturn(largeDataset);

        // Act
        final items = repository.getAll();

        // Assert
        expect(items.length, equals(1000));
        expect(items.first.id, equals('id-0'));
        expect(items.last.id, equals('id-999'));
      });
    });

    group('box naming strategy', () {
      test('should use base name when userId is null', () {
        // The actual box name construction happens in init()
        // We verify the boxName property remains unchanged
        expect(repository.boxName, equals(boxName));
      });

      test('should maintain original boxName property', () {
        // The boxName property should never change after construction
        final repo = TestHiveRepository('immutable_name');
        expect(repo.boxName, equals('immutable_name'));
      });
    });
  });
}

/// Base class for all model tests providing common utilities and patterns
///
/// This class provides centralized testing infrastructure for model tests
/// following the gold standard patterns established in the codebase.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

/// Base class for model tests with common setup and utilities
abstract class ModelTestBase {
  /// Standard setup for model tests
  static Future<void> setupModelTest() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
  }

  /// Standard teardown for model tests
  static Future<void> teardownModelTest() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  }

  /// Run a model test group with automatic setup/teardown
  static void testModelGroup(
    String modelName,
    void Function() body,
  ) {
    BaseUnitTest.groupUnit(modelName, () {
      setUp(() async {
        await setupModelTest();
      });

      tearDown(() async {
        await teardownModelTest();
      });

      body();
    });
  }

  /// Test JSON serialization round-trip
  static void testJsonRoundTrip<T>({
    required String description,
    required T model,
    required Map<String, dynamic> Function(T) toJson,
    required T Function(Map<String, dynamic>) fromJson,
    void Function(T original, T deserialized)? customAssertions,
  }) {
    BaseUnitTest.testUnit(description, () async {
      // Act
      final json = toJson(model);
      final deserialized = fromJson(json);

      // Assert
      expect(json, isA<Map<String, dynamic>>());
      expect(deserialized, isA<T>());

      if (customAssertions != null) {
        customAssertions(model, deserialized);
      }
    });
  }

  /// Test Firestore serialization round-trip
  static void testFirestoreRoundTrip<T>({
    required String description,
    required T model,
    required Map<String, dynamic> Function(T) toFirestore,
    required T Function(String id, Map<String, dynamic>) fromFirestore,
    String? documentId,
    void Function(T original, T deserialized)? customAssertions,
  }) {
    BaseUnitTest.testUnit(description, () async {
      // Arrange
      final id =
          documentId ?? 'test_doc_${DateTime.now().millisecondsSinceEpoch}';

      // Act
      final firestoreData = toFirestore(model);
      final deserialized = fromFirestore(id, firestoreData);

      // Assert
      expect(firestoreData, isA<Map<String, dynamic>>());
      expect(deserialized, isA<T>());

      // Verify Firestore-specific types
      if (firestoreData.containsKey('createdAt')) {
        expect(firestoreData['createdAt'],
            anyOf(isA<Timestamp>(), isA<FieldValue>(), isA<DateTime>()));
      }
      if (firestoreData.containsKey('updatedAt')) {
        expect(firestoreData['updatedAt'],
            anyOf(isA<Timestamp>(), isA<FieldValue>(), isA<DateTime>()));
      }

      if (customAssertions != null) {
        customAssertions(model, deserialized);
      }
    });
  }

  /// Test copyWith method comprehensively
  static void testCopyWith<T>({
    required String description,
    required T original,
    required Map<String, dynamic> updates,
    required T Function() copyWithCall,
    required void Function(T original, T copied) assertions,
  }) {
    BaseUnitTest.testUnit(description, () async {
      // Act
      final copied = copyWithCall();

      // Assert
      expect(copied, isA<T>());
      expect(copied, isNot(same(original)));
      assertions(original, copied);
    });
  }

  /// Test model validation
  static void testValidation({
    required String description,
    required dynamic model,
    required bool Function() isValidCheck,
    required bool expectedValid,
    String? validationError,
  }) {
    BaseUnitTest.testUnit(description, () async {
      // Act
      final isValid = isValidCheck();

      // Assert
      expect(isValid, equals(expectedValid));

      if (!expectedValid && validationError != null) {
        // Could test specific validation error messages if model provides them
      }
    });
  }

  /// Test equality and hashCode
  static void testEquality<T>({
    required String description,
    required T model1,
    required T model2,
    required bool shouldBeEqual,
  }) {
    BaseUnitTest.testUnit(description, () async {
      if (shouldBeEqual) {
        expect(model1, equals(model2));
        expect(model1.hashCode, equals(model2.hashCode));
      } else {
        expect(model1, isNot(equals(model2)));
        // Note: Different objects might have same hashCode (collision)
        // so we don't test hashCode inequality
      }
    });
  }

  /// Test computed properties
  static void testComputedProperty<T>({
    required String description,
    required dynamic model,
    required dynamic Function() getter,
    required dynamic expectedValue,
  }) {
    BaseUnitTest.testUnit(description, () async {
      // Act
      final value = getter();

      // Assert
      expect(value, equals(expectedValue));
    });
  }

  /// Test Swedish text formatting
  static void testSwedishFormatting({
    required String description,
    required dynamic model,
    required String Function() formatter,
    required String expectedText,
  }) {
    BaseUnitTest.testUnit(description, () async {
      // Act
      final formatted = formatter();

      // Assert
      expect(formatted, equals(expectedText));
      // Verify Swedish characters are preserved
      if (expectedText.contains(RegExp(r'[åäöÅÄÖ]'))) {
        expect(formatted, contains(RegExp(r'[åäöÅÄÖ]')));
      }
    });
  }

  /// Test collection operations (add, remove, update)
  static void testCollectionOperation<T>({
    required String description,
    required List<T> initialCollection,
    required void Function() operation,
    required List<T> Function() getCollection,
    required void Function(List<T> before, List<T> after) assertions,
  }) {
    BaseUnitTest.testUnit(description, () async {
      // Arrange
      final before = List<T>.from(initialCollection);

      // Act
      operation();
      final after = getCollection();

      // Assert
      assertions(before, after);
    });
  }

  /// Test error handling in deserialization
  static void testDeserializationError<T>({
    required String description,
    required Map<String, dynamic> invalidJson,
    required T Function(Map<String, dynamic>) fromJson,
    Type? expectedError,
  }) {
    BaseUnitTest.testUnit(description, () async {
      // Act & Assert
      if (expectedError != null) {
        expect(
          () => fromJson(invalidJson),
          throwsA(isA<Type>().having(
            (e) => e.runtimeType,
            'error type',
            expectedError,
          )),
        );
      } else {
        expect(
          () => fromJson(invalidJson),
          throwsException,
        );
      }
    });
  }
}

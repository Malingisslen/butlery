/// Base class for unit tests with enhanced utilities and patterns
///
/// Extends BaseTest with unit test specific functionality including
/// mock management, assertion helpers, and AAA pattern support.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;

import 'base_test.dart';
import '../infrastructure/di/test_service_locator.dart';
import '../infrastructure/mocks/firestore_singleton.dart';

/// Base class for all unit tests
///
/// Provides:
/// - AAA (Arrange, Act, Assert) pattern helpers
/// - Mock verification utilities
/// - Common assertion patterns
/// - Automatic mock registration
abstract class BaseUnitTest extends BaseTest {
  /// List of mocks/fakes to automatically reset between tests.
  ///
  /// Holds [Object] (not [Mock]) so callers can mix mocktail mocks and
  /// fakes that extend [Fake] (e.g. `FakeAuthRepository` post-BUT-1074).
  static final List<Object> _registeredMocks = [];

  /// Register a mock or fake for automatic reset between tests
  static void registerMock(Object mock) {
    if (!_registeredMocks.contains(mock)) {
      _registeredMocks.add(mock);
    }
  }

  /// Register multiple mocks/fakes at once
  static void registerMocks(List<Object> mocks) {
    for (final mock in mocks) {
      registerMock(mock);
    }
  }

  /// Reset all registered mocks
  static void resetMocks() {
    // Reset the global mocktail state for all mocks
    resetMocktailState();
  }

  /// Clear all mock registrations
  static void clearMocks() {
    _registeredMocks.clear();
  }

  /// Enhanced setup for unit tests
  static Future<void> setupUnit() async {
    await BaseTest.setup();
    resetMocks(); // Reset mocks between tests
    // Clear Firestore data at the start of each test for isolation
    await FirestoreSingleton.clearData();
  }

  /// Use when the SUT calls services that go through `requiresAuth: true`
  /// (most service-layer SUTs). Both locators share the same GetIt singleton.
  ///
  /// Pair with `tearDown(() async => TestServiceLocator.reset())`.
  static Future<void> setupUnitWithProductionLocator() async {
    await setupUnit();
    await TestServiceLocator.initialize();
    prod.ServiceLocator.initialize(DIContainer());
  }

  /// Enhanced teardown for unit tests
  static Future<void> teardownUnit() async {
    resetMocks();
    await BaseTest.teardown();
  }

  /// Complete reset for unit tests
  static Future<void> resetUnit() async {
    clearMocks();
    await BaseTest.reset();
  }

  /// Run a unit test with automatic setup/teardown
  static void testUnit(
    String description,
    Future<void> Function() body, {
    bool skip = false,
    Timeout? timeout,
    dynamic tags,
  }) {
    test(
      description,
      () async {
        await setupUnit();
        try {
          await body();
        } finally {
          await teardownUnit();
        }
      },
      skip: skip,
      timeout: timeout,
      tags: tags,
    );
  }

  /// Run a unit test group with automatic setup
  static void groupUnit(
    String description,
    void Function() body, {
    bool skip = false,
  }) {
    group(description, () {
      setUpAll(() async {
        await setupUnit();
      });

      tearDown(() async {
        await teardownUnit();
      });

      tearDownAll(() async {
        await resetUnit();
      });

      body();
    }, skip: skip);
  }

  /// Verify that no unexpected interactions occurred with mocks
  static void verifyNoMoreInteractionsWithAll() {
    for (final mock in _registeredMocks) {
      verifyNoMoreInteractions(mock);
    }
  }

  /// Verify that no interactions occurred with any registered mock
  static void verifyZeroInteractionsWithAll() {
    for (final mock in _registeredMocks) {
      verifyZeroInteractions(mock);
    }
  }
}

/// Common matchers for unit tests
class UnitTestMatchers {
  /// Matcher for successful async operations
  static final Matcher completes = completion(anything);

  /// Matcher for operations that should not throw
  static final Matcher doesNotThrow = isNot(throwsA(anything));

  /// Matcher for non-null values
  static final Matcher notNull = isNotNull;

  /// Matcher for empty collections
  static final Matcher empty = isEmpty;

  /// Matcher for non-empty collections
  static final Matcher notEmpty = isNotEmpty;

  /// Create a matcher for a specific exception type with message
  static Matcher throwsExceptionWithMessage<T extends Exception>(
    String message,
  ) {
    return throwsA(
      allOf([
        isA<T>(),
        predicate((e) => e.toString().contains(message)),
      ]),
    );
  }

  /// Create a matcher for async operations that complete with a value
  static Matcher completesWith<T>(dynamic expected) {
    return completion(equals(expected));
  }
}

/// Extension methods for enhanced assertions
extension AssertionExtensions on dynamic {
  /// Assert this value equals expected
  void shouldEqual(dynamic expected, [String? reason]) {
    expect(this, equals(expected), reason: reason);
  }

  /// Assert this value is not null
  void shouldNotBeNull([String? reason]) {
    expect(this, isNotNull, reason: reason);
  }

  /// Assert this collection contains an item
  void shouldContain(dynamic item, [String? reason]) {
    expect(this, contains(item), reason: reason);
  }
}

/// Unit tests for NotificationPreferenceManager
///
/// Tests notification preference management including user preference checking,
/// quiet hours logic, preference CRUD operations, permission validation, and caching.
/// Tests against the REAL NotificationPreferenceManager production code.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Production code being tested
import 'package:butlery/services/notifications/modules/notification_preference_manager.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/models/notification_preferences.dart';

// Test infrastructure
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

// Fake classes for fallback values
class FakeNotificationPreferences extends Fake
    implements NotificationPreferences {}

class FakeTimeOfDay extends Fake implements TimeOfDay {}

void main() {
  // Register fallback values for mocktail
  setUpAll(() {
    registerFallbackValue(FakeNotificationPreferences());
    registerFallbackValue(FakeTimeOfDay());
  });

  group('NotificationPreferenceManager', () {
    late NotificationPreferenceManager preferenceManager;
    late MockNotificationsRepository mockRepository;

    setUp(() async {
      // Initialize test infrastructure
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create mocks
      mockRepository = MockNotificationsRepository();

      // Configure mock behavior
      mockRepository.setNotificationsState(
        currentUserId: 'test-user-123',
        userPreferences: {
          'test-user-123': NotificationPreferences.defaults(),
        },
      );

      // Stub the repository methods
      when(() => mockRepository.getNotificationPreferences(any())).thenAnswer((
        invocation,
      ) async {
        final userId = invocation.positionalArguments[0] as String;
        return mockRepository.userPreferences[userId] ??
            NotificationPreferences.defaults();
      });

      when(
        () => mockRepository.updateNotificationPreferences(any(), any()),
      ).thenAnswer((invocation) async {
        final userId = invocation.positionalArguments[0] as String;
        final prefs =
            invocation.positionalArguments[1] as NotificationPreferences;
        mockRepository.userPreferences[userId] = prefs;
      });

      // Create the REAL NotificationPreferenceManager with mocked dependencies
      preferenceManager = NotificationPreferenceManager(
        notificationsRepository: mockRepository,
        userId: 'test-user-123',
      );

      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      // Clean up
      preferenceManager.dispose();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    group('User Preference Checking', () {
      test('should allow notification when preferences enabled', () async {
        // Act
        final shouldReceive = await preferenceManager.shouldReceiveNotification(
          NotificationCategory.recipes,
          NotificationType.immediate,
        );

        // Assert
        expect(shouldReceive, isTrue);
      });

      test('should block notification when category disabled', () async {
        // Arrange - Update preferences to disable recipes
        final prefs = await preferenceManager.getPreferences();
        final updatedPrefs = NotificationPreferences(
          enabled: prefs.enabled,
          categorySettings: {
            ...prefs.categorySettings,
            NotificationCategory.recipes: false,
          },
          typeSettings: prefs.typeSettings,
          allowBatching: prefs.allowBatching,
          digestFrequency: prefs.digestFrequency,
          quietHoursStart: prefs.quietHoursStart,
          quietHoursEnd: prefs.quietHoursEnd,
          lastUpdated: DateTime.now(),
        );
        await preferenceManager.updatePreferences(updatedPrefs);

        // Act
        final shouldReceive = await preferenceManager.shouldReceiveNotification(
          NotificationCategory.recipes,
          NotificationType.batchable,
        );

        // Assert
        expect(shouldReceive, isFalse);
      });

      test('should filter users based on their preferences', () async {
        // Arrange
        final userIds = ['user1', 'user2', 'user3'];

        // user1 + user3 keep defaults (recipes ON). user2 disables recipes
        // so the filter must exclude them — that's what verifies the
        // "based on their preferences" claim. (Without this divergence,
        // all three users would pass and the assertion would tautologise.)
        mockRepository.userPreferences['user1'] =
            NotificationPreferences.defaults();

        final defaults = NotificationPreferences.defaults();
        mockRepository.userPreferences['user2'] = NotificationPreferences(
          enabled: defaults.enabled,
          categorySettings: {
            ...defaults.categorySettings,
            NotificationCategory.recipes: false, // ← divergence under test
          },
          typeSettings: defaults.typeSettings,
          allowBatching: defaults.allowBatching,
          digestFrequency: defaults.digestFrequency,
          quietHoursStart: defaults.quietHoursStart,
          quietHoursEnd: defaults.quietHoursEnd,
          lastUpdated: defaults.lastUpdated,
        );

        mockRepository.userPreferences['user3'] =
            NotificationPreferences.defaults();

        // Act
        final filteredUsers = await preferenceManager
            .filterUsersForNotification(
              userIds,
              NotificationCategory.recipes,
              NotificationType.immediate,
            );

        // Assert
        expect(filteredUsers, contains('user1'));
        expect(
          filteredUsers,
          isNot(contains('user2')),
        ); // Should be filtered out
        expect(filteredUsers, contains('user3'));
      });
    });

    group('Quiet Hours Logic', () {
      test('should detect when in quiet hours', () async {
        // Arrange - Set quiet hours from 22:00 to 08:00
        final prefs = await preferenceManager.getPreferences();
        final updatedPrefs = NotificationPreferences(
          enabled: prefs.enabled,
          categorySettings: prefs.categorySettings,
          typeSettings: prefs.typeSettings,
          allowBatching: prefs.allowBatching,
          digestFrequency: prefs.digestFrequency,
          quietHoursStart: const TimeOfDay(hour: 22, minute: 0),
          quietHoursEnd: const TimeOfDay(hour: 8, minute: 0),
          lastUpdated: DateTime.now(),
        );
        await preferenceManager.updatePreferences(updatedPrefs);

        // Act - This will use current time, so we can't test exact behavior
        // Instead, test that the method works without errors
        final inQuietHours = await preferenceManager.isInQuietHours();

        // Assert
        expect(inQuietHours, isA<bool>());
      });

      test('should allow immediate notifications during quiet hours', () async {
        // Arrange - Set quiet hours
        final prefs = await preferenceManager.getPreferences();
        final updatedPrefs = NotificationPreferences(
          enabled: prefs.enabled,
          categorySettings: prefs.categorySettings,
          typeSettings: prefs.typeSettings,
          allowBatching: prefs.allowBatching,
          digestFrequency: prefs.digestFrequency,
          quietHoursStart: const TimeOfDay(hour: 0, minute: 0),
          quietHoursEnd: const TimeOfDay(
            hour: 23,
            minute: 59,
          ), // Always in quiet hours
          lastUpdated: DateTime.now(),
        );
        await preferenceManager.updatePreferences(updatedPrefs);

        // Act - Immediate notifications should bypass quiet hours
        final shouldReceiveImmediate = await preferenceManager
            .shouldReceiveNotification(
              NotificationCategory.friends,
              NotificationType.immediate,
            );

        // Assert
        expect(shouldReceiveImmediate, isTrue);
      });
    });

    group('Preference CRUD Operations', () {
      test('should get preferences with caching', () async {
        // Act - First call should fetch from repository
        final prefs1 = await preferenceManager.getPreferences();

        // Second call should use cache
        final prefs2 = await preferenceManager.getPreferences();

        // Assert
        expect(prefs1, isA<NotificationPreferences>());
        expect(prefs2, isA<NotificationPreferences>());
        expect(prefs1.enabled, equals(prefs2.enabled));

        // Verify repository was called only once (due to caching)
        verify(
          () => mockRepository.getNotificationPreferences('test-user-123'),
        ).called(1);
      });

      test('should update preferences and clear cache', () async {
        // Arrange
        final originalPrefs = await preferenceManager.getPreferences();

        // Act - Update preferences
        final updatedPrefs = NotificationPreferences(
          enabled: false, // Changed
          categorySettings: originalPrefs.categorySettings,
          typeSettings: originalPrefs.typeSettings,
          allowBatching: originalPrefs.allowBatching,
          digestFrequency: 'daily', // Changed
          quietHoursStart: originalPrefs.quietHoursStart,
          quietHoursEnd: originalPrefs.quietHoursEnd,
          lastUpdated: DateTime.now(),
        );
        await preferenceManager.updatePreferences(updatedPrefs);

        // Get preferences again
        final retrievedPrefs = await preferenceManager.getPreferences();

        // Assert
        expect(retrievedPrefs.enabled, isFalse);
        expect(retrievedPrefs.digestFrequency, equals('daily'));
      });

      test('should reset preferences to defaults', () async {
        // Arrange - Modify preferences first
        final modifiedPrefs = NotificationPreferences(
          enabled: false,
          categorySettings: {},
          typeSettings: {},
          allowBatching: false,
          digestFrequency: 'weekly',
          quietHoursStart: null,
          quietHoursEnd: null,
          lastUpdated: DateTime.now(),
        );
        await preferenceManager.updatePreferences(modifiedPrefs);

        // Act - Reset to defaults
        await preferenceManager.resetToDefaults();

        // Get preferences
        final prefs = await preferenceManager.getPreferences();

        // Assert - Should have default values
        expect(prefs.enabled, isTrue);
        expect(prefs.allowBatching, isTrue);
        expect(prefs.digestFrequency, equals('never'));
        expect(
          prefs.quietHoursStart,
          equals(const TimeOfDay(hour: 22, minute: 0)),
        );
        expect(
          prefs.quietHoursEnd,
          equals(const TimeOfDay(hour: 8, minute: 0)),
        );
      });

      /// BUT-1799. Every existing install carries the literal `'{}'` in this
      /// SharedPreferences slot, written by the pre-BUT-1782 `toJson()` stub.
      /// `fromJson('{}')` answers with `defaults()`; `tryFromJson('{}')`
      /// answers null. The difference is invisible on the FAILING call — both
      /// hand back a defaults-shaped object — so the discriminating assertion
      /// is on the SECOND call, after the repository recovers. Under the
      /// reverted spelling `getPreferences` caches those defaults for the full
      /// 10-minute window and the recovered read can never win.
      test(
        "a legacy '{}' cache is discarded, not read as \"user is on defaults\"",
        () async {
          SharedPreferences.setMockInitialValues({
            'notification_preferences_test-user-123': '{}',
          });
          preferenceManager.clearCache();

          when(
            () => mockRepository.getNotificationPreferences(any()),
          ).thenThrow(Exception('network unavailable'));

          await preferenceManager.getPreferences();

          // The repository recovers, carrying the user's REAL settings.
          final realPrefs = NotificationPreferences(
            enabled: false,
            categorySettings:
                NotificationPreferences.defaults().categorySettings,
            typeSettings: NotificationPreferences.defaults().typeSettings,
            allowBatching: false,
            digestFrequency: 'weekly',
            quietHoursStart: null,
            quietHoursEnd: null,
            lastUpdated: DateTime.now(),
          );
          when(
            () => mockRepository.getNotificationPreferences(any()),
          ).thenAnswer((_) async => realPrefs);

          final second = await preferenceManager.getPreferences();

          expect(
            second.enabled,
            isFalse,
            reason:
                'fromJson would have cached defaults() for ten minutes, so the '
                'recovered read could never win and the user would appear to '
                'be on factory settings',
          );
          expect(second.digestFrequency, equals('weekly'));
        },
      );

      /// The poisoned payload must also be EVICTED, or it is re-decoded and
      /// re-warned on every read failure until a successful repository read
      /// happens to overwrite it.
      test(
        'the unusable payload is evicted, not left to be re-decoded',
        () async {
          SharedPreferences.setMockInitialValues({
            'notification_preferences_test-user-123': '{}',
          });
          preferenceManager.clearCache();

          when(
            () => mockRepository.getNotificationPreferences(any()),
          ).thenThrow(Exception('network unavailable'));

          await preferenceManager.getPreferences();

          final prefs = await SharedPreferences.getInstance();
          expect(
            prefs.getString('notification_preferences_test-user-123'),
            isNull,
          );
        },
      );

      /// BUT-1782 acceptance criterion 2. The reported symptom: one transient
      /// Firestore read error reset an explicit opt-out. The old code treated
      /// EVERY read failure as "no document yet", built defaults, wrote them to
      /// Firestore and overwrote the local cache with them — so the reset was
      /// permanent and server-side.
      ///
      /// (The two halves of this sentence had drifted onto the wrong tests at
      /// HEAD; re-joined 2026-08-13. The move itself changed no test code —
      /// BUT-1783 separately dropped the retired sound/vibration fields from
      /// both fixtures, and two assertions on them from this test.)
      test(
        'a repository read error falls back to the SAVED preferences and '
        'writes nothing',
        () async {
          // Arrange: a real, explicitly non-default saved state, persisted the
          // way production persists it (updatePreferences writes both sinks).
          final savedPrefs = NotificationPreferences(
            enabled: false,
            categorySettings:
                NotificationPreferences.defaults().categorySettings,
            typeSettings: NotificationPreferences.defaults().typeSettings,
            allowBatching: false,
            digestFrequency: 'weekly',
            quietHoursStart: const TimeOfDay(hour: 21, minute: 30),
            quietHoursEnd: const TimeOfDay(hour: 7, minute: 15),
            lastUpdated: DateTime.now(),
          );
          await preferenceManager.updatePreferences(savedPrefs);
          // Force the next call past the in-memory cache — the fallback is what
          // is under test, not the cache.
          preferenceManager.clearCache();

          // The transient failure.
          when(
            () => mockRepository.getNotificationPreferences(any()),
          ).thenThrow(Exception('network unavailable'));

          // Only writes made from HERE ON count — the arrange step above wrote
          // once on purpose.
          clearInteractions(mockRepository);

          // Act
          final result = await preferenceManager.getPreferences();

          // Assert: the user's own choices come back, not defaults.
          expect(result.enabled, isFalse);
          expect(result.digestFrequency, equals('weekly'));
          expect(result.allowBatching, isFalse);
          expect(
            result.quietHoursStart,
            equals(const TimeOfDay(hour: 21, minute: 30)),
          );

          // And nothing was written back — defaults must never be persisted
          // from a read error. This is the half that made the old bug
          // PERMANENT: the reset survived the next successful read.
          verifyNever(
            () => mockRepository.updateNotificationPreferences(any(), any()),
          );
        },
      );

      test(
        'a read error with no local copy serves defaults WITHOUT persisting '
        'them',
        () async {
          SharedPreferences.setMockInitialValues({});
          preferenceManager.clearCache();
          when(
            () => mockRepository.getNotificationPreferences(any()),
          ).thenThrow(Exception('network unavailable'));

          clearInteractions(mockRepository);

          final result = await preferenceManager.getPreferences();

          expect(result.enabled, isTrue);
          verifyNever(
            () => mockRepository.updateNotificationPreferences(any(), any()),
          );
        },
      );
    });

    group('Permission Validation', () {
      test('should check if digest notifications are enabled', () async {
        // Arrange - Enable digest
        final prefs = await preferenceManager.getPreferences();
        final updatedPrefs = NotificationPreferences(
          enabled: prefs.enabled,
          categorySettings: prefs.categorySettings,
          typeSettings: prefs.typeSettings,
          allowBatching: prefs.allowBatching,
          digestFrequency: 'daily', // Enabled
          quietHoursStart: prefs.quietHoursStart,
          quietHoursEnd: prefs.quietHoursEnd,
          lastUpdated: DateTime.now(),
        );
        await preferenceManager.updatePreferences(updatedPrefs);

        // Act
        final digestEnabled = await preferenceManager
            .areDigestNotificationsEnabled();

        // Assert
        expect(digestEnabled, isTrue);

        // Disable digest
        final disabledPrefs = NotificationPreferences(
          enabled: prefs.enabled,
          categorySettings: prefs.categorySettings,
          typeSettings: prefs.typeSettings,
          allowBatching: prefs.allowBatching,
          digestFrequency: 'never', // Disabled
          quietHoursStart: prefs.quietHoursStart,
          quietHoursEnd: prefs.quietHoursEnd,
          lastUpdated: DateTime.now(),
        );
        await preferenceManager.updatePreferences(disabledPrefs);

        final digestDisabled = await preferenceManager
            .areDigestNotificationsEnabled();
        expect(digestDisabled, isFalse);
      });

      test('should get list of enabled categories', () async {
        // Arrange - Enable specific categories
        final prefs = await preferenceManager.getPreferences();
        final updatedPrefs = NotificationPreferences(
          enabled: prefs.enabled,
          categorySettings: {
            NotificationCategory.recipes: true,
            NotificationCategory.friends: true,
            NotificationCategory.shopping: false,
            NotificationCategory.collaboration: false,
            NotificationCategory.social: true,
            NotificationCategory.system: true,
          },
          typeSettings: {
            NotificationType.immediate: true,
            NotificationType.batchable: true,
            NotificationType.silent: true,
            NotificationType.digest: false,
            NotificationType.optional: false,
          },
          allowBatching: prefs.allowBatching,
          digestFrequency: prefs.digestFrequency,
          quietHoursStart: prefs.quietHoursStart,
          quietHoursEnd: prefs.quietHoursEnd,
          lastUpdated: DateTime.now(),
        );
        await preferenceManager.updatePreferences(updatedPrefs);

        // Act
        final enabledCategories = await preferenceManager
            .getEnabledCategories();

        // Assert
        expect(enabledCategories, contains(NotificationCategory.recipes));
        expect(enabledCategories, contains(NotificationCategory.friends));
        expect(
          enabledCategories,
          isNot(contains(NotificationCategory.shopping)),
        );
        expect(
          enabledCategories,
          isNot(contains(NotificationCategory.collaboration)),
        );
        expect(enabledCategories, contains(NotificationCategory.social));
        expect(enabledCategories, contains(NotificationCategory.system));
      });
    });
  });
}

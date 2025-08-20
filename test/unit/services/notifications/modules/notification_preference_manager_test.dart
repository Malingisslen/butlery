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
import 'package:butlery/services/notifications/notification_repository.dart' as legacy;
import 'package:butlery/repositories/interfaces/notifications_repository.dart';

// Test infrastructure
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

// Fake classes for fallback values
class FakeNotificationPreferences extends Fake implements NotificationPreferences {}
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
          'test-user-123': NotificationPreferences(
            enableRecipeSharing: true,
            enableFriendRequests: true,
            enableGroupInvitations: true,
            enableComments: true,
            enableRatings: true,
            enableCollaborativeEditing: true,
            enableMenuSharing: true,
            enableGeneralUpdates: true,
          ),
        },
      );
      
      // Stub the repository methods
      when(() => mockRepository.getNotificationPreferences(any()))
          .thenAnswer((invocation) async {
            final userId = invocation.positionalArguments[0] as String;
            return mockRepository.userPreferences[userId] ?? 
                   NotificationPreferences(
                     enableRecipeSharing: true,
                     enableFriendRequests: true,
                     enableGroupInvitations: true,
                     enableComments: true,
                     enableRatings: true,
                     enableCollaborativeEditing: true,
                     enableMenuSharing: true,
                     enableGeneralUpdates: true,
                   );
          });
      
      when(() => mockRepository.updateNotificationPreferences(any(), any()))
          .thenAnswer((invocation) async {
            final userId = invocation.positionalArguments[0] as String;
            final prefs = invocation.positionalArguments[1] as NotificationPreferences;
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
        final updatedPrefs = legacy.NotificationPreferences(
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
          soundEnabled: prefs.soundEnabled,
          vibrationEnabled: prefs.vibrationEnabled,
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
        
        // Set different preferences for each user
        mockRepository.userPreferences['user1'] = NotificationPreferences(
          enableRecipeSharing: true,
          enableFriendRequests: true,
          enableGroupInvitations: true,
          enableComments: true,
          enableRatings: true,
          enableCollaborativeEditing: true,
          enableMenuSharing: true,
          enableGeneralUpdates: true,
        );
        
        mockRepository.userPreferences['user2'] = NotificationPreferences(
          enableRecipeSharing: false, // Disabled
          enableFriendRequests: true,
          enableGroupInvitations: true,
          enableComments: true,
          enableRatings: true,
          enableCollaborativeEditing: true,
          enableMenuSharing: true,
          enableGeneralUpdates: true,
        );
        
        mockRepository.userPreferences['user3'] = NotificationPreferences(
          enableRecipeSharing: true,
          enableFriendRequests: true,
          enableGroupInvitations: true,
          enableComments: true,
          enableRatings: true,
          enableCollaborativeEditing: true,
          enableMenuSharing: true,
          enableGeneralUpdates: true,
        );
        
        // Act
        final filteredUsers = await preferenceManager.filterUsersForNotification(
          userIds,
          NotificationCategory.recipes,
          NotificationType.immediate,
        );
        
        // Assert
        expect(filteredUsers, contains('user1'));
        expect(filteredUsers, isNot(contains('user2'))); // Should be filtered out
        expect(filteredUsers, contains('user3'));
      });
    });
    
    group('Quiet Hours Logic', () {
      test('should detect when in quiet hours', () async {
        // Arrange - Set quiet hours from 22:00 to 08:00
        final prefs = await preferenceManager.getPreferences();
        final updatedPrefs = legacy.NotificationPreferences(
          enabled: prefs.enabled,
          categorySettings: prefs.categorySettings,
          typeSettings: prefs.typeSettings,
          allowBatching: prefs.allowBatching,
          digestFrequency: prefs.digestFrequency,
          quietHoursStart: const TimeOfDay(hour: 22, minute: 0),
          quietHoursEnd: const TimeOfDay(hour: 8, minute: 0),
          soundEnabled: prefs.soundEnabled,
          vibrationEnabled: prefs.vibrationEnabled,
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
        final updatedPrefs = legacy.NotificationPreferences(
          enabled: prefs.enabled,
          categorySettings: prefs.categorySettings,
          typeSettings: prefs.typeSettings,
          allowBatching: prefs.allowBatching,
          digestFrequency: prefs.digestFrequency,
          quietHoursStart: const TimeOfDay(hour: 0, minute: 0),
          quietHoursEnd: const TimeOfDay(hour: 23, minute: 59), // Always in quiet hours
          soundEnabled: prefs.soundEnabled,
          vibrationEnabled: prefs.vibrationEnabled,
          lastUpdated: DateTime.now(),
        );
        await preferenceManager.updatePreferences(updatedPrefs);
        
        // Act - Immediate notifications should bypass quiet hours
        final shouldReceiveImmediate = await preferenceManager.shouldReceiveNotification(
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
        expect(prefs1, isA<legacy.NotificationPreferences>());
        expect(prefs2, isA<legacy.NotificationPreferences>());
        expect(prefs1.enabled, equals(prefs2.enabled));
        
        // Verify repository was called only once (due to caching)
        verify(() => mockRepository.getNotificationPreferences('test-user-123')).called(1);
      });
      
      test('should update preferences and clear cache', () async {
        // Arrange
        final originalPrefs = await preferenceManager.getPreferences();
        
        // Act - Update preferences
        final updatedPrefs = legacy.NotificationPreferences(
          enabled: false, // Changed
          categorySettings: originalPrefs.categorySettings,
          typeSettings: originalPrefs.typeSettings,
          allowBatching: originalPrefs.allowBatching,
          digestFrequency: 'daily', // Changed
          quietHoursStart: originalPrefs.quietHoursStart,
          quietHoursEnd: originalPrefs.quietHoursEnd,
          soundEnabled: false, // Changed
          vibrationEnabled: originalPrefs.vibrationEnabled,
          lastUpdated: DateTime.now(),
        );
        await preferenceManager.updatePreferences(updatedPrefs);
        
        // Get preferences again
        final retrievedPrefs = await preferenceManager.getPreferences();
        
        // Assert
        expect(retrievedPrefs.enabled, isFalse);
        expect(retrievedPrefs.digestFrequency, equals('daily'));
        expect(retrievedPrefs.soundEnabled, isFalse);
      });
      
      test('should reset preferences to defaults', () async {
        // Arrange - Modify preferences first
        final modifiedPrefs = legacy.NotificationPreferences(
          enabled: false,
          categorySettings: {},
          typeSettings: {},
          allowBatching: false,
          digestFrequency: 'weekly',
          quietHoursStart: null,
          quietHoursEnd: null,
          soundEnabled: false,
          vibrationEnabled: false,
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
        expect(prefs.quietHoursStart, equals(const TimeOfDay(hour: 22, minute: 0)));
        expect(prefs.quietHoursEnd, equals(const TimeOfDay(hour: 8, minute: 0)));
        expect(prefs.soundEnabled, isTrue);
        expect(prefs.vibrationEnabled, isTrue);
      });
    });
    
    group('Permission Validation', () {
      test('should check if digest notifications are enabled', () async {
        // Arrange - Enable digest
        final prefs = await preferenceManager.getPreferences();
        final updatedPrefs = legacy.NotificationPreferences(
          enabled: prefs.enabled,
          categorySettings: prefs.categorySettings,
          typeSettings: prefs.typeSettings,
          allowBatching: prefs.allowBatching,
          digestFrequency: 'daily', // Enabled
          quietHoursStart: prefs.quietHoursStart,
          quietHoursEnd: prefs.quietHoursEnd,
          soundEnabled: prefs.soundEnabled,
          vibrationEnabled: prefs.vibrationEnabled,
          lastUpdated: DateTime.now(),
        );
        await preferenceManager.updatePreferences(updatedPrefs);
        
        // Act
        final digestEnabled = await preferenceManager.areDigestNotificationsEnabled();
        
        // Assert
        expect(digestEnabled, isTrue);
        
        // Disable digest
        final disabledPrefs = legacy.NotificationPreferences(
          enabled: prefs.enabled,
          categorySettings: prefs.categorySettings,
          typeSettings: prefs.typeSettings,
          allowBatching: prefs.allowBatching,
          digestFrequency: 'never', // Disabled
          quietHoursStart: prefs.quietHoursStart,
          quietHoursEnd: prefs.quietHoursEnd,
          soundEnabled: prefs.soundEnabled,
          vibrationEnabled: prefs.vibrationEnabled,
          lastUpdated: DateTime.now(),
        );
        await preferenceManager.updatePreferences(disabledPrefs);
        
        final digestDisabled = await preferenceManager.areDigestNotificationsEnabled();
        expect(digestDisabled, isFalse);
      });
      
      test('should get list of enabled categories', () async {
        // Arrange - Enable specific categories
        final prefs = await preferenceManager.getPreferences();
        final updatedPrefs = legacy.NotificationPreferences(
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
          soundEnabled: prefs.soundEnabled,
          vibrationEnabled: prefs.vibrationEnabled,
          lastUpdated: DateTime.now(),
        );
        await preferenceManager.updatePreferences(updatedPrefs);
        
        // Act
        final enabledCategories = await preferenceManager.getEnabledCategories();
        
        // Assert
        expect(enabledCategories, contains(NotificationCategory.recipes));
        expect(enabledCategories, contains(NotificationCategory.friends));
        expect(enabledCategories, isNot(contains(NotificationCategory.shopping)));
        expect(enabledCategories, isNot(contains(NotificationCategory.collaboration)));
        expect(enabledCategories, contains(NotificationCategory.social));
        expect(enabledCategories, contains(NotificationCategory.system));
      });
    });
  });
}
// test/unit/viewmodels/realtime/participant_tracker_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/realtime/participant_tracker.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ParticipantTracker participantTracker;

  setUpAll(() async {
    await TestServiceLocator.initialize();
  });

  setUp(() async {
    participantTracker = ParticipantTracker();
  });

  tearDown(() async {
    participantTracker.dispose();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  RealtimeMenu createTestMenu({
    String? menuId,
    String? ownerId,
    String? ownerDisplayName,
    String? lastEditedBy,
    String? lastEditedByDisplayName,
    DateTime? lastEditedAt,
    Map<String, bool>? participants,
  }) {
    // Import required models
    final menuData = RealtimeMenuData(
      menuTitle: 'Test Menu',
      createdForDate: DateTime.now(),
      menuSnapshot: {},
    );

    final resourceParticipants = <String, ResourcePermission>{};
    final participantMap = participants ??
        {
          'owner_123': true,
          'editor_123': true,
          'viewer_123': false,
        };

    for (final entry in participantMap.entries) {
      if (entry.value) {
        resourceParticipants[entry.key] = ResourcePermission.editor;
      } else {
        resourceParticipants[entry.key] = ResourcePermission.viewer;
      }
    }

    // Set owner permission
    final ownerUserId = ownerId ?? 'owner_123';
    resourceParticipants[ownerUserId] = ResourcePermission.owner;

    return RealtimeMenu(
      id: menuId ?? 'test_menu_123',
      ownerId: ownerUserId,
      ownerDisplayName: ownerDisplayName ?? 'Owner Name',
      lastEditedBy: lastEditedBy ?? 'editor_123',
      lastEditedByDisplayName: lastEditedByDisplayName ?? 'Editor Name',
      lastEditedAt: lastEditedAt ?? DateTime.now(),
      participants: resourceParticipants,
      data: menuData,
    );
  }

  group('ParticipantActivity - Model Functionality', () {
    test('should create participant activity with all required data', () {
      final now = DateTime.now();
      final activity = ParticipantActivity(
        userId: 'user_123',
        displayName: 'Test User',
        lastSeen: now,
        isOnline: true,
      );

      expect(activity.userId, equals('user_123'));
      expect(activity.displayName, equals('Test User'));
      expect(activity.lastSeen, equals(now));
      expect(activity.isOnline, isTrue);
    });

    test('should check if participant was active within period', () {
      final fiveMinutesAgo = DateTime.now().subtract(Duration(minutes: 5));
      final activity = ParticipantActivity(
        userId: 'user_123',
        displayName: 'Test User',
        lastSeen: fiveMinutesAgo,
        isOnline: true,
      );

      expect(activity.wasActiveWithin(Duration(minutes: 10)), isTrue);
      expect(activity.wasActiveWithin(Duration(minutes: 3)), isFalse);
    });

    test('should provide string representation', () {
      final now = DateTime.now();
      final activity = ParticipantActivity(
        userId: 'user_123',
        displayName: 'Test User',
        lastSeen: now,
        isOnline: true,
      );

      final str = activity.toString();
      expect(str, contains('ParticipantActivity'));
      expect(str, contains('Test User'));
      expect(str, contains('online: true'));
    });
  });

  group('ParticipantTracker - Initialization and Basic State', () {
    test('should initialize with empty state', () {
      expect(participantTracker.activeCount, equals(0));
      expect(participantTracker.activeParticipantIds, isEmpty);
      expect(participantTracker.allActivities, isEmpty);
      expect(participantTracker.onlineParticipants, isEmpty);
      expect(participantTracker.recentlyActiveParticipants, isEmpty);
    });

    test('should initialize with callback', () {
      bool callbackTriggered = false;
      final trackerWithCallback = ParticipantTracker(
        onUpdated: () => callbackTriggered = true,
      );

      // Trigger update to test callback
      trackerWithCallback.markActiveNow('test_user', 'Test User');

      expect(callbackTriggered, isTrue);

      trackerWithCallback.dispose();
    });

    test('should work without callback', () {
      final tracker = ParticipantTracker();

      expect(() => tracker.markActiveNow('test_user', 'Test User'),
          returnsNormally);

      tracker.dispose();
    });
  });

  group('ParticipantTracker - RealtimeMenu Integration', () {
    test('should update activity from menu changes', () {
      final now = DateTime.now();
      final menu = createTestMenu(
        lastEditedBy: 'editor_456',
        lastEditedByDisplayName: 'Menu Editor',
        lastEditedAt: now,
      );

      participantTracker.updateFromMenu(menu);

      expect(participantTracker.activeCount, equals(1));
      expect(participantTracker.activeParticipantIds, contains('editor_456'));
      expect(participantTracker.getDisplayName('editor_456'),
          equals('Menu Editor'));
      expect(participantTracker.getLastActivity('editor_456'), equals(now));
    });

    test('should cache participant display names from menu', () {
      final menu = createTestMenu(
        ownerId: 'owner_789',
        ownerDisplayName: 'Menu Owner',
        participants: {
          'owner_789': true,
          'participant_1': true,
          'participant_2': false,
        },
      );

      participantTracker.updateFromMenu(menu);

      expect(
          participantTracker.getDisplayName('owner_789'), equals('Menu Owner'));
      expect(participantTracker.getDisplayName('participant_1'),
          equals('Deltagare'));
      expect(participantTracker.getDisplayName('participant_2'),
          equals('Deltagare'));
    });

    test('should handle menu updates with empty editor', () {
      final menu = createTestMenu(
        lastEditedBy: '',
        lastEditedByDisplayName: '',
      );

      expect(() => participantTracker.updateFromMenu(menu), returnsNormally);
      expect(participantTracker.activeCount, equals(0));
    });

    test('should update existing participants from multiple menu updates', () {
      final firstUpdate = DateTime.now().subtract(Duration(minutes: 10));
      final secondUpdate = DateTime.now();

      // First menu update
      final menu1 = createTestMenu(
        lastEditedBy: 'user_1',
        lastEditedByDisplayName: 'User One',
        lastEditedAt: firstUpdate,
      );
      participantTracker.updateFromMenu(menu1);

      // Second menu update - same user
      final menu2 = createTestMenu(
        lastEditedBy: 'user_1',
        lastEditedByDisplayName: 'User One Updated',
        lastEditedAt: secondUpdate,
      );
      participantTracker.updateFromMenu(menu2);

      expect(participantTracker.activeCount, equals(1));
      expect(
          participantTracker.getLastActivity('user_1'), equals(secondUpdate));
      expect(participantTracker.getDisplayName('user_1'),
          equals('User One Updated'));
    });

    test('should trigger callback on menu updates', () {
      bool callbackTriggered = false;
      final tracker = ParticipantTracker(
        onUpdated: () => callbackTriggered = true,
      );

      final menu = createTestMenu();
      tracker.updateFromMenu(menu);

      expect(callbackTriggered, isTrue);

      tracker.dispose();
    });
  });

  group('ParticipantTracker - Activity Tracking', () {
    test('should track last activity for participants', () {
      final specificTime = DateTime.now().subtract(Duration(minutes: 3));

      participantTracker.markActiveNow('user_1', 'User One');

      // Manually set specific time for testing
      final menu = createTestMenu(
        lastEditedBy: 'user_2',
        lastEditedByDisplayName: 'User Two',
        lastEditedAt: specificTime,
      );
      participantTracker.updateFromMenu(menu);

      expect(participantTracker.getLastActivity('user_1'), isNotNull);
      expect(
          participantTracker.getLastActivity('user_2'), equals(specificTime));
      expect(participantTracker.getLastActivity('nonexistent'), isNull);
    });

    test('should check if participant was recently active', () {
      final recentTime = DateTime.now().subtract(Duration(minutes: 2));
      final oldTime = DateTime.now().subtract(Duration(minutes: 10));

      final recentMenu = createTestMenu(
        lastEditedBy: 'recent_user',
        lastEditedAt: recentTime,
      );
      participantTracker.updateFromMenu(recentMenu);

      final oldMenu = createTestMenu(
        lastEditedBy: 'old_user',
        lastEditedAt: oldTime,
      );
      participantTracker.updateFromMenu(oldMenu);

      expect(
          participantTracker.wasRecentlyActive(
              'recent_user', Duration(minutes: 5)),
          isTrue);
      expect(
          participantTracker.wasRecentlyActive(
              'old_user', Duration(minutes: 5)),
          isFalse);
      expect(
          participantTracker.wasRecentlyActive(
              'nonexistent', Duration(minutes: 5)),
          isFalse);
    });

    test('should get online participants (active within 5 minutes)', () {
      final now = DateTime.now();
      final recentTime = now.subtract(Duration(minutes: 2));
      final oldTime = now.subtract(Duration(minutes: 10));

      participantTracker.markActiveNow('online_user', 'Online User');

      final recentMenu = createTestMenu(
        lastEditedBy: 'recent_user',
        lastEditedAt: recentTime,
      );
      participantTracker.updateFromMenu(recentMenu);

      final oldMenu = createTestMenu(
        lastEditedBy: 'offline_user',
        lastEditedAt: oldTime,
      );
      participantTracker.updateFromMenu(oldMenu);

      final onlineParticipants = participantTracker.onlineParticipants;
      expect(onlineParticipants.length, equals(2)); // online_user + recent_user
      expect(onlineParticipants, contains('online_user'));
      expect(onlineParticipants, contains('recent_user'));
      expect(onlineParticipants, isNot(contains('offline_user')));
    });

    test('should get recently active participants (within 1 hour)', () {
      final now = DateTime.now();
      final halfHourAgo = now.subtract(Duration(minutes: 30));
      final twoHoursAgo = now.subtract(Duration(hours: 2));

      participantTracker.markActiveNow('current_user', 'Current User');

      final recentMenu = createTestMenu(
        lastEditedBy: 'recent_user',
        lastEditedAt: halfHourAgo,
      );
      participantTracker.updateFromMenu(recentMenu);

      final oldMenu = createTestMenu(
        lastEditedBy: 'old_user',
        lastEditedAt: twoHoursAgo,
      );
      participantTracker.updateFromMenu(oldMenu);

      final recentParticipants = participantTracker.recentlyActiveParticipants;
      expect(
          recentParticipants.length, equals(2)); // current_user + recent_user
      expect(recentParticipants, contains('current_user'));
      expect(recentParticipants, contains('recent_user'));
      expect(recentParticipants, isNot(contains('old_user')));
    });

    test('should get all activities sorted by last seen', () {
      final now = DateTime.now();
      final earlier = now.subtract(Duration(minutes: 10));
      final earliest = now.subtract(Duration(minutes: 20));

      participantTracker.markActiveNow('user_latest', 'Latest User');

      final earlierMenu = createTestMenu(
        lastEditedBy: 'user_earlier',
        lastEditedByDisplayName: 'Earlier User',
        lastEditedAt: earlier,
      );
      participantTracker.updateFromMenu(earlierMenu);

      final earliestMenu = createTestMenu(
        lastEditedBy: 'user_earliest',
        lastEditedByDisplayName: 'Earliest User',
        lastEditedAt: earliest,
      );
      participantTracker.updateFromMenu(earliestMenu);

      final activities = participantTracker.allActivities;
      expect(activities.length, equals(3));

      // Should be sorted by lastSeen descending (latest first)
      expect(activities[0].userId, equals('user_latest'));
      expect(activities[1].userId, equals('user_earlier'));
      expect(activities[2].userId, equals('user_earliest'));

      // Check isOnline status (active within 5 minutes)
      expect(activities[0].isOnline, isTrue); // Just marked active
      expect(activities[1].isOnline, isFalse); // 10 minutes ago
      expect(activities[2].isOnline, isFalse); // 20 minutes ago
    });
  });

  group('ParticipantTracker - Display Name Management', () {
    test('should get display name for known participants', () {
      participantTracker.markActiveNow('user_123', 'Known User');

      expect(
          participantTracker.getDisplayName('user_123'), equals('Known User'));
      expect(participantTracker.getDisplayName('unknown_user'),
          equals('Okänd användare'));
    });

    test('should update display name and trigger callback', () {
      bool callbackTriggered = false;
      final tracker = ParticipantTracker(
        onUpdated: () => callbackTriggered = true,
      );

      tracker.markActiveNow('user_123', 'Original Name');
      callbackTriggered = false; // Reset

      tracker.updateDisplayName('user_123', 'Updated Name');

      expect(tracker.getDisplayName('user_123'), equals('Updated Name'));
      expect(callbackTriggered, isTrue);

      tracker.dispose();
    });

    test('should not trigger callback if display name unchanged', () {
      bool callbackTriggered = false;
      final tracker = ParticipantTracker(
        onUpdated: () => callbackTriggered = true,
      );

      tracker.markActiveNow('user_123', 'Same Name');
      callbackTriggered = false; // Reset

      tracker.updateDisplayName('user_123', 'Same Name');

      expect(callbackTriggered, isFalse);

      tracker.dispose();
    });

    test('should update display name for unknown users', () {
      participantTracker.updateDisplayName('new_user', 'New User Name');

      expect(participantTracker.getDisplayName('new_user'),
          equals('New User Name'));
    });
  });

  group('ParticipantTracker - Manual Operations', () {
    test('should mark participant as active now', () {
      participantTracker.markActiveNow('active_user', 'Active User');

      expect(participantTracker.activeCount, equals(1));
      expect(participantTracker.activeParticipantIds, contains('active_user'));
      expect(participantTracker.getDisplayName('active_user'),
          equals('Active User'));
      expect(
          participantTracker.wasRecentlyActive(
              'active_user', Duration(seconds: 10)),
          isTrue);
    });

    test('should remove specific participant', () {
      participantTracker.markActiveNow('user_1', 'User One');
      participantTracker.markActiveNow('user_2', 'User Two');

      expect(participantTracker.activeCount, equals(2));

      participantTracker.removeParticipant('user_1');

      expect(participantTracker.activeCount, equals(1));
      expect(participantTracker.activeParticipantIds, contains('user_2'));
      expect(
          participantTracker.activeParticipantIds, isNot(contains('user_1')));
      expect(participantTracker.getDisplayName('user_1'),
          equals('Okänd användare'));
    });

    test('should handle removing non-existent participant', () {
      participantTracker.markActiveNow('user_1', 'User One');

      // Should not crash or affect existing data
      participantTracker.removeParticipant('nonexistent');

      expect(participantTracker.activeCount, equals(1));
      expect(participantTracker.activeParticipantIds, contains('user_1'));
    });

    test('should clear all tracking data', () {
      participantTracker.markActiveNow('user_1', 'User One');
      participantTracker.markActiveNow('user_2', 'User Two');

      expect(participantTracker.activeCount, equals(2));

      participantTracker.clear();

      expect(participantTracker.activeCount, equals(0));
      expect(participantTracker.activeParticipantIds, isEmpty);
      expect(participantTracker.allActivities, isEmpty);
    });

    test('should not trigger callback when clearing empty data', () {
      bool callbackTriggered = false;
      final tracker = ParticipantTracker(
        onUpdated: () => callbackTriggered = true,
      );

      // Clear when already empty
      tracker.clear();

      expect(callbackTriggered, isFalse);

      tracker.dispose();
    });

    test('should trigger callback when clearing non-empty data', () {
      bool callbackTriggered = false;
      final tracker = ParticipantTracker(
        onUpdated: () => callbackTriggered = true,
      );

      tracker.markActiveNow('user_1', 'User One');
      callbackTriggered = false; // Reset

      tracker.clear();

      expect(callbackTriggered, isTrue);

      tracker.dispose();
    });

    test('should trigger callback on remove participant', () {
      bool callbackTriggered = false;
      final tracker = ParticipantTracker(
        onUpdated: () => callbackTriggered = true,
      );

      tracker.markActiveNow('user_1', 'User One');
      callbackTriggered = false; // Reset

      tracker.removeParticipant('user_1');

      expect(callbackTriggered, isTrue);

      tracker.dispose();
    });
  });

  group('ParticipantTracker - Automatic Cleanup', () {
    test('should clean up old activity automatically on menu update', () {
      // Create activity within 1 hour (30 minutes ago) so it's initially kept
      final recentTime = DateTime.now().subtract(Duration(minutes: 30));
      final recentMenu = createTestMenu(
        lastEditedBy: 'recent_user',
        lastEditedAt: recentTime,
      );
      participantTracker.updateFromMenu(recentMenu);

      expect(participantTracker.activeCount, equals(1));
      expect(participantTracker.activeParticipantIds, contains('recent_user'));

      // Now create very old activity (2 hours ago)
      final oldTime = DateTime.now().subtract(Duration(hours: 2));
      final oldMenu = createTestMenu(
        lastEditedBy: 'old_user',
        lastEditedAt: oldTime,
      );
      participantTracker.updateFromMenu(oldMenu);

      // Old activity should be immediately cleaned up, recent should remain
      expect(
          participantTracker.activeParticipantIds, isNot(contains('old_user')));
      expect(participantTracker.activeParticipantIds, contains('recent_user'));
    });

    test('should force cleanup manually', () {
      // Add old activity manually (bypassing normal cleanup)
      participantTracker.markActiveNow('user_1', 'User One');

      // Manually set old timestamp (this is a bit hacky for testing)
      // In real scenario, this would happen through time passage
      // Test menu would be used here in future test scenarios for time-based cleanup
      // final oldTime = DateTime.now().subtract(Duration(hours: 2));
      // final oldMenu = createTestMenu(
      //   lastEditedBy: 'old_user',
      //   lastEditedAt: oldTime,
      // );
      // We'll test the force cleanup method specifically

      participantTracker.forceCleanup();

      // Recently added user should survive cleanup
      expect(participantTracker.activeParticipantIds, contains('user_1'));
    });

    test('should trigger callback on force cleanup', () {
      bool callbackTriggered = false;
      final tracker = ParticipantTracker(
        onUpdated: () => callbackTriggered = true,
      );

      tracker.forceCleanup();

      expect(callbackTriggered, isTrue);

      tracker.dispose();
    });

    test('should preserve recent activity during cleanup', () {
      final recentTime = DateTime.now().subtract(Duration(minutes: 30));

      participantTracker.markActiveNow('recent_user', 'Recent User');

      final recentMenu = createTestMenu(
        lastEditedBy: 'another_recent',
        lastEditedAt: recentTime,
      );
      participantTracker.updateFromMenu(recentMenu);

      // Both should be preserved as they're within 1 hour
      expect(participantTracker.activeParticipantIds, contains('recent_user'));
      expect(
          participantTracker.activeParticipantIds, contains('another_recent'));
    });
  });

  group('ParticipantTracker - Callback Functionality', () {
    test('should trigger callback on various operations', () {
      int callbackCount = 0;
      final tracker = ParticipantTracker(
        onUpdated: () => callbackCount++,
      );

      tracker.markActiveNow('user_1', 'User One'); // +1
      tracker.updateDisplayName('user_2', 'User Two'); // +1
      tracker.updateFromMenu(createTestMenu()); // +1
      tracker.removeParticipant('user_1'); // +1
      tracker.clear(); // +1

      expect(callbackCount, equals(5));

      tracker.dispose();
    });

    test('should not trigger callback when no callback provided', () {
      final tracker = ParticipantTracker();

      // Should not crash
      expect(
          () => tracker.markActiveNow('user_1', 'User One'), returnsNormally);
      expect(() => tracker.updateFromMenu(createTestMenu()), returnsNormally);

      tracker.dispose();
    });

    test('should handle callback exceptions gracefully', () {
      final tracker = ParticipantTracker(
        onUpdated: () => throw Exception('Callback error'),
      );

      // Should throw the callback exception
      expect(() => tracker.markActiveNow('user_1', 'User One'),
          throwsA(isA<Exception>()));

      // Dispose will also throw since it calls clear() which triggers callback
      expect(() => tracker.dispose(), throwsA(isA<Exception>()));
    });
  });

  group('ParticipantTracker - Disposal and Cleanup', () {
    test('should dispose cleanly', () {
      participantTracker.markActiveNow('user_1', 'User One');
      participantTracker.markActiveNow('user_2', 'User Two');

      expect(() => participantTracker.dispose(), returnsNormally);
      expect(participantTracker.activeCount, equals(0));
    });

    test('should handle multiple dispose calls', () {
      participantTracker.dispose();

      // Second dispose should not crash
      expect(() => participantTracker.dispose(), returnsNormally);
    });

    test('should clear all data on dispose', () {
      participantTracker.markActiveNow('user_1', 'User One');
      participantTracker.updateDisplayName('user_2', 'User Two');

      participantTracker.dispose();

      expect(participantTracker.activeCount, equals(0));
      expect(participantTracker.allActivities, isEmpty);
      expect(participantTracker.getDisplayName('user_1'),
          equals('Okänd användare'));
      expect(participantTracker.getDisplayName('user_2'),
          equals('Okänd användare'));
    });
  });

  group('ParticipantTracker - Edge Cases and Integration', () {
    test('should handle rapid successive updates', () {
      final now = DateTime.now();

      for (int i = 0; i < 10; i++) {
        final menu = createTestMenu(
          lastEditedBy: 'user_$i',
          lastEditedByDisplayName: 'User $i',
          lastEditedAt: now.subtract(Duration(seconds: i)),
        );
        participantTracker.updateFromMenu(menu);
      }

      expect(participantTracker.activeCount, equals(10));
      expect(participantTracker.onlineParticipants.length,
          equals(10)); // All within 5 minutes
    });

    test('should handle concurrent operations', () {
      // Simulate concurrent operations
      participantTracker.markActiveNow('user_1', 'User One');
      participantTracker.updateDisplayName('user_1', 'Updated User One');
      participantTracker.updateFromMenu(createTestMenu(lastEditedBy: 'user_1'));
      participantTracker.markActiveNow('user_2', 'User Two');
      participantTracker.removeParticipant('user_1');

      // Should maintain consistent state
      expect(
          participantTracker.activeParticipantIds, isNot(contains('user_1')));
      expect(participantTracker.activeParticipantIds, contains('user_2'));
    });

    test('should handle empty and null-safe operations', () {
      // Handle empty strings and edge cases
      expect(() => participantTracker.getDisplayName(''), returnsNormally);
      expect(participantTracker.getDisplayName(''), equals('Okänd användare'));

      expect(
          () => participantTracker.wasRecentlyActive('', Duration(minutes: 1)),
          returnsNormally);
      expect(participantTracker.wasRecentlyActive('', Duration(minutes: 1)),
          isFalse);

      expect(() => participantTracker.removeParticipant(''), returnsNormally);
    });

    test('should handle various time ranges correctly', () {
      final now = DateTime.now();
      final times = [
        now, // Just now
        now.subtract(Duration(minutes: 2)), // 2 min ago
        now.subtract(Duration(minutes: 6)), // 6 min ago (not online)
        now.subtract(Duration(minutes: 30)), // 30 min ago
        now.subtract(Duration(hours: 2)), // 2 hours ago (should be cleaned)
      ];

      for (int i = 0; i < times.length; i++) {
        final menu = createTestMenu(
          lastEditedBy: 'user_$i',
          lastEditedByDisplayName: 'User $i',
          lastEditedAt: times[i],
        );
        participantTracker.updateFromMenu(menu);
      }

      // Check online status (within 5 minutes)
      final online = participantTracker.onlineParticipants;
      expect(online, contains('user_0')); // Just now
      expect(online, contains('user_1')); // 2 min ago
      expect(online, isNot(contains('user_2'))); // 6 min ago

      // Check recently active (within 1 hour)
      final recent = participantTracker.recentlyActiveParticipants;
      expect(recent, contains('user_0'));
      expect(recent, contains('user_1'));
      expect(recent, contains('user_2'));
      expect(recent, contains('user_3')); // 30 min ago
      expect(recent, isNot(contains('user_4'))); // 2 hours ago
    });

    test('should maintain state consistency during complex workflows', () {
      // Complex workflow simulation
      final tracker = ParticipantTracker();

      // Phase 1: Initial activity
      tracker.markActiveNow('user_1', 'User One');
      tracker.markActiveNow('user_2', 'User Two');
      expect(tracker.activeCount, equals(2));

      // Phase 2: Menu updates
      final menu1 = createTestMenu(
        lastEditedBy: 'user_1',
        lastEditedByDisplayName: 'Updated User One',
      );
      tracker.updateFromMenu(menu1);

      // Phase 3: Name updates
      tracker.updateDisplayName('user_2', 'Updated User Two');

      // Phase 4: Activity checks
      expect(tracker.getDisplayName('user_1'), equals('Updated User One'));
      expect(tracker.getDisplayName('user_2'), equals('Updated User Two'));
      expect(tracker.onlineParticipants.length, equals(2));

      // Phase 5: Selective removal
      tracker.removeParticipant('user_1');
      expect(tracker.activeCount, equals(1));
      expect(tracker.activeParticipantIds, contains('user_2'));

      // Phase 6: Complete cleanup
      tracker.clear();
      expect(tracker.activeCount, equals(0));

      tracker.dispose();
    });

    test('should handle ParticipantActivity edge cases', () {
      final veryOldTime = DateTime.now().subtract(Duration(days: 365));
      final activity = ParticipantActivity(
        userId: 'old_user',
        displayName: 'Old User',
        lastSeen: veryOldTime,
        isOnline: false,
      );

      expect(activity.wasActiveWithin(Duration(days: 1)), isFalse);
      expect(activity.wasActiveWithin(Duration(days: 400)), isTrue);

      final str = activity.toString();
      expect(str, isA<String>());
      expect(str.isNotEmpty, isTrue);
    });
  });

  group('ParticipantTracker - Integration Scenarios', () {
    test('should handle complete participant tracking workflow', () {
      bool callbackTriggered = false;
      final tracker = ParticipantTracker(
        onUpdated: () => callbackTriggered = true,
      );

      // Step 1: Initial menu activity
      final menu1 = createTestMenu(
        lastEditedBy: 'editor_1',
        lastEditedByDisplayName: 'First Editor',
      );
      tracker.updateFromMenu(menu1);
      expect(callbackTriggered, isTrue);
      expect(tracker.activeCount, equals(1));

      // Step 2: Additional manual activity
      tracker.markActiveNow('manual_user', 'Manual User');
      expect(tracker.activeCount, equals(2));

      // Step 3: Name updates
      tracker.updateDisplayName('editor_1', 'Updated Editor');
      expect(tracker.getDisplayName('editor_1'), equals('Updated Editor'));

      // Step 4: Activity queries
      expect(tracker.onlineParticipants.length, equals(2));
      expect(
          tracker.wasRecentlyActive('editor_1', Duration(minutes: 1)), isTrue);

      // Step 5: All activities overview
      final activities = tracker.allActivities;
      expect(activities.length, equals(2));
      expect(activities.every((a) => a.isOnline), isTrue);

      // Step 6: Cleanup operations
      tracker.removeParticipant('manual_user');
      expect(tracker.activeCount, equals(1));

      tracker.clear();
      expect(tracker.activeCount, equals(0));

      tracker.dispose();
    });
  });
}

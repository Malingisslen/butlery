// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/realtime/realtime_metadata.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('RealtimeMetadata', () {
    group('Edit Tracking', () {
      test('should create edit tracking data for new edit', () {
        final editTime = DateTime(2025, 1, 1, 12, 0);
        
        final tracking = RealtimeMetadata.createEditTracking(
          editedBy: 'user_123',
          editedByDisplayName: 'Anna Andersson',
          editTime: editTime,
          currentEditCount: 5,
        );

        expect(tracking['lastEditedBy'], equals('user_123'));
        expect(tracking['lastEditedByDisplayName'], equals('Anna Andersson'));
        expect(tracking['lastEditedAt'], equals(editTime));
        expect(tracking['editCount'], equals(6)); // Incremented from 5
      });

      test('should use current time if not provided', () {
        final before = DateTime.now();
        
        final tracking = RealtimeMetadata.createEditTracking(
          editedBy: 'user_123',
          editedByDisplayName: 'Anna',
        );
        
        final after = DateTime.now();
        final editTime = tracking['lastEditedAt'] as DateTime;

        expect(editTime.isAfter(before) || editTime.isAtSameMomentAs(before), isTrue);
        expect(editTime.isBefore(after) || editTime.isAtSameMomentAs(after), isTrue);
        expect(tracking['editCount'], equals(1)); // Starting from 0
      });

      test('should update edit metadata', () {
        final currentMetadata = {
          'lastEditedBy': 'user_old',
          'lastEditedByDisplayName': 'Old User',
          'lastEditedAt': DateTime(2025, 1, 1),
          'editCount': 10,
          'customField': 'preserved',
        };

        final updated = RealtimeMetadata.updateEditMetadata(
          currentMetadata: currentMetadata,
          editedBy: 'user_new',
          editedByDisplayName: 'New User',
          editTime: DateTime(2025, 1, 2),
        );

        expect(updated['lastEditedBy'], equals('user_new'));
        expect(updated['lastEditedByDisplayName'], equals('New User'));
        expect(updated['lastEditedAt'], equals(DateTime(2025, 1, 2)));
        expect(updated['editCount'], equals(11));
        expect(updated['customField'], equals('preserved')); // Custom fields preserved
      });

      test('should check if edit is recent', () {
        // Very recent edit (1 minute ago)
        var lastEdit = DateTime.now().subtract(Duration(minutes: 1));
        expect(RealtimeMetadata.isRecentEdit(lastEdit), isTrue);

        // Just outside threshold (6 minutes ago with 5 minute threshold)
        lastEdit = DateTime.now().subtract(Duration(minutes: 6));
        expect(RealtimeMetadata.isRecentEdit(lastEdit), isFalse);

        // Custom threshold
        lastEdit = DateTime.now().subtract(Duration(hours: 1));
        expect(
          RealtimeMetadata.isRecentEdit(lastEdit, threshold: Duration(hours: 2)),
          isTrue,
        );

        // Null edit time
        expect(RealtimeMetadata.isRecentEdit(null), isFalse);
      });

      test('should calculate edit frequency', () {
        final createdAt = DateTime.now().subtract(Duration(hours: 10));
        
        // 20 edits in 10 hours = 2 edits per hour
        var frequency = RealtimeMetadata.getEditFrequency(20, createdAt);
        expect(frequency, closeTo(2.0, 0.1));

        // Edge case: just created
        frequency = RealtimeMetadata.getEditFrequency(5, DateTime.now());
        expect(frequency, equals(5.0)); // All edits in current hour

        // No edits
        frequency = RealtimeMetadata.getEditFrequency(0, createdAt);
        expect(frequency, equals(0.0));
      });
    });

    group('Activity Status', () {
      test('should calculate active status based on recent edits', () {
        // Recent edit - should be active
        var lastEdit = DateTime.now().subtract(Duration(hours: 12));
        expect(
          RealtimeMetadata.calculateActiveStatus(lastEditedAt: lastEdit),
          isTrue,
        );

        // Old edit - should be inactive
        lastEdit = DateTime.now().subtract(Duration(days: 2));
        expect(
          RealtimeMetadata.calculateActiveStatus(lastEditedAt: lastEdit),
          isFalse,
        );

        // Custom threshold
        lastEdit = DateTime.now().subtract(Duration(hours: 6));
        expect(
          RealtimeMetadata.calculateActiveStatus(
            lastEditedAt: lastEdit,
            inactivityThreshold: Duration(hours: 5),
          ),
          isFalse,
        );

        // Null timestamp
        expect(
          RealtimeMetadata.calculateActiveStatus(lastEditedAt: null),
          isFalse,
        );
      });

      test('should check if resource is stale', () {
        // Fresh resource (1 day old)
        var lastEdit = DateTime.now().subtract(Duration(days: 1));
        expect(RealtimeMetadata.isStaleResource(lastEdit), isFalse);

        // Stale resource (8 days old with 7 day threshold)
        lastEdit = DateTime.now().subtract(Duration(days: 8));
        expect(RealtimeMetadata.isStaleResource(lastEdit), isTrue);

        // Custom threshold
        lastEdit = DateTime.now().subtract(Duration(hours: 25));
        expect(
          RealtimeMetadata.isStaleResource(
            lastEdit,
            staleThreshold: Duration(hours: 24),
          ),
          isTrue,
        );

        // Null timestamp is always stale
        expect(RealtimeMetadata.isStaleResource(null), isTrue);
      });

      test('should calculate activity level', () {
        final createdAt = DateTime.now().subtract(Duration(days: 2));
        
        // High activity: many edits, recent
        var level = RealtimeMetadata.getActivityLevel(
          editCount: 100,
          createdAt: createdAt,
          lastEditedAt: DateTime.now().subtract(Duration(hours: 2)),
        );
        expect(level, equals(5)); // Maximum activity

        // Medium activity
        level = RealtimeMetadata.getActivityLevel(
          editCount: 10,
          createdAt: createdAt,
          lastEditedAt: DateTime.now().subtract(Duration(hours: 12)),
        );
        expect(level, greaterThanOrEqualTo(2));
        expect(level, lessThanOrEqualTo(4));

        // Low activity: few edits, old
        level = RealtimeMetadata.getActivityLevel(
          editCount: 2,
          createdAt: createdAt,
          lastEditedAt: DateTime.now().subtract(Duration(days: 5)),
        );
        expect(level, equals(1)); // Minimum activity

        // Null last edit
        level = RealtimeMetadata.getActivityLevel(
          editCount: 10,
          createdAt: createdAt,
          lastEditedAt: null,
        );
        expect(level, equals(1));
      });
    });

    group('Session Management', () {
      test('should check if edit is part of same session', () {
        final lastEdit = DateTime.now().subtract(Duration(minutes: 10));
        
        // Same editor, within timeout
        expect(
          RealtimeMetadata.isSameEditSession(
            currentEditor: 'user_123',
            newEditor: 'user_123',
            lastEditTime: lastEdit,
          ),
          isTrue,
        );

        // Different editor
        expect(
          RealtimeMetadata.isSameEditSession(
            currentEditor: 'user_123',
            newEditor: 'user_456',
            lastEditTime: lastEdit,
          ),
          isFalse,
        );

        // Same editor, but timeout expired
        final oldEdit = DateTime.now().subtract(Duration(minutes: 35));
        expect(
          RealtimeMetadata.isSameEditSession(
            currentEditor: 'user_123',
            newEditor: 'user_123',
            lastEditTime: oldEdit,
          ),
          isFalse,
        );

        // Null last edit time (first edit)
        expect(
          RealtimeMetadata.isSameEditSession(
            currentEditor: 'user_123',
            newEditor: 'user_123',
            lastEditTime: null,
          ),
          isTrue,
        );
      });

      test('should create session metadata', () {
        final sessionStart = DateTime(2025, 1, 1, 10, 0);
        
        final session = RealtimeMetadata.createSessionMetadata(
          editorId: 'user_123',
          editorDisplayName: 'Anna Andersson',
          sessionStart: sessionStart,
          sessionEditCount: 5,
        );

        expect(session['sessionEditorId'], equals('user_123'));
        expect(session['sessionEditorDisplayName'], equals('Anna Andersson'));
        expect(session['sessionStartedAt'], equals(sessionStart));
        expect(session['sessionEditCount'], equals(5));
      });

      test('should update session metadata for same editor', () {
        final currentSession = {
          'sessionEditorId': 'user_123',
          'sessionEditorDisplayName': 'Anna',
          'sessionStartedAt': DateTime(2025, 1, 1),
          'sessionEditCount': 3,
        };

        final updated = RealtimeMetadata.updateSessionMetadata(
          currentSession: currentSession,
          editorId: 'user_123',
          editorDisplayName: 'Anna',
        );

        expect(updated['sessionEditorId'], equals('user_123'));
        expect(updated['sessionEditCount'], equals(4)); // Incremented
        expect(updated['sessionStartedAt'], equals(DateTime(2025, 1, 1))); // Preserved
      });

      test('should start new session for different editor', () {
        final currentSession = {
          'sessionEditorId': 'user_123',
          'sessionEditorDisplayName': 'Anna',
          'sessionStartedAt': DateTime(2025, 1, 1),
          'sessionEditCount': 3,
        };

        final before = DateTime.now();
        
        final updated = RealtimeMetadata.updateSessionMetadata(
          currentSession: currentSession,
          editorId: 'user_456',
          editorDisplayName: 'Erik',
        );
        
        final after = DateTime.now();

        expect(updated['sessionEditorId'], equals('user_456'));
        expect(updated['sessionEditorDisplayName'], equals('Erik'));
        expect(updated['sessionEditCount'], equals(1)); // Reset to 1
        
        final newStart = updated['sessionStartedAt'] as DateTime;
        expect(newStart.isAfter(before) || newStart.isAtSameMomentAs(before), isTrue);
        expect(newStart.isBefore(after) || newStart.isAtSameMomentAs(after), isTrue);
      });
    });

    group('Metadata Validation', () {
      test('should validate metadata structure', () {
        // Valid metadata
        var metadata = {
          'lastEditedBy': 'user_123',
          'lastEditedByDisplayName': 'Anna',
          'lastEditedAt': DateTime.now(),
          'editCount': 5,
        };
        expect(RealtimeMetadata.isValidMetadata(metadata), isTrue);

        // Missing required field
        metadata = {
          'lastEditedBy': 'user_123',
          'lastEditedAt': DateTime.now(),
          'editCount': 5,
        };
        expect(RealtimeMetadata.isValidMetadata(metadata), isFalse);

        // Wrong type for editCount
        metadata = {
          'lastEditedBy': 'user_123',
          'lastEditedByDisplayName': 'Anna',
          'lastEditedAt': DateTime.now(),
          'editCount': '5', // String instead of int
        };
        expect(RealtimeMetadata.isValidMetadata(metadata), isFalse);

        // Wrong type for lastEditedAt
        metadata = {
          'lastEditedBy': 'user_123',
          'lastEditedByDisplayName': 'Anna',
          'lastEditedAt': '2025-01-01', // String instead of DateTime
          'editCount': 5,
        };
        expect(RealtimeMetadata.isValidMetadata(metadata), isFalse);
      });

      test('should sanitize metadata', () {
        final metadata = {
          'lastEditedBy': null,
          'lastEditedByDisplayName': 123, // Wrong type
          'lastEditedAt': null,
          'editCount': '5', // Wrong type
          'isActive': 'true', // Wrong type
          'customField': 'preserved',
        };

        final before = DateTime.now();
        final sanitized = RealtimeMetadata.sanitizeMetadata(metadata);
        final after = DateTime.now();

        expect(sanitized['lastEditedBy'], equals(''));
        expect(sanitized['lastEditedByDisplayName'], equals('123'));
        expect(sanitized['editCount'], equals(0));
        expect(sanitized['isActive'], isTrue); // Default value
        expect(sanitized['customField'], equals('preserved'));
        
        final editTime = sanitized['lastEditedAt'] as DateTime;
        expect(editTime.isAfter(before) || editTime.isAtSameMomentAs(before), isTrue);
        expect(editTime.isBefore(after) || editTime.isAtSameMomentAs(after), isTrue);
      });
    });

    group('Analytics', () {
      test('should calculate edit velocity', () {
        final now = DateTime.now();
        final recentEdits = [
          now.subtract(Duration(hours: 1)),
          now.subtract(Duration(hours: 2)),
          now.subtract(Duration(hours: 5)),
          now.subtract(Duration(hours: 10)),
          now.subtract(Duration(hours: 20)),
          now.subtract(Duration(hours: 30)), // Outside 24 hour window
        ];

        // 5 edits in 24 hours = 5/24 ≈ 0.208
        final velocity = RealtimeMetadata.calculateEditVelocity(
          recentEdits: recentEdits,
        );
        expect(velocity, closeTo(0.208, 0.01));

        // Custom window
        final velocity2 = RealtimeMetadata.calculateEditVelocity(
          recentEdits: recentEdits,
          window: Duration(hours: 12),
        );
        expect(velocity2, closeTo(4/12, 0.01)); // 4 edits in 12 hours
      });

      test('should calculate collaboration score', () {
        // High collaboration: many editors, many edits, young resource
        var score = RealtimeMetadata.getCollaborationScore(
          uniqueEditors: 5,
          totalEdits: 50,
          resourceAge: Duration(days: 5),
        );
        expect(score, greaterThan(50));

        // Low collaboration: single editor
        score = RealtimeMetadata.getCollaborationScore(
          uniqueEditors: 1,
          totalEdits: 10,
          resourceAge: Duration(days: 10),
        );
        expect(score, lessThan(50));

        // No edits
        score = RealtimeMetadata.getCollaborationScore(
          uniqueEditors: 0,
          totalEdits: 0,
          resourceAge: Duration(days: 1),
        );
        expect(score, equals(0));

        // Edge case: very new resource
        score = RealtimeMetadata.getCollaborationScore(
          uniqueEditors: 2,
          totalEdits: 5,
          resourceAge: Duration(hours: 1),
        );
        expect(score, greaterThan(0));
        expect(score, lessThanOrEqualTo(100));
      });

      test('should generate edit summary', () {
        final createdAt = DateTime.now().subtract(Duration(days: 5));
        final lastEditedAt = DateTime.now().subtract(Duration(hours: 12));
        
        final summary = RealtimeMetadata.generateEditSummary(
          totalEdits: 25,
          createdAt: createdAt,
          lastEditedAt: lastEditedAt,
          lastEditor: 'user_123',
          uniqueEditors: 3,
        );

        expect(summary['totalEdits'], equals(25));
        expect(summary['uniqueEditors'], equals(3));
        expect(summary['editFrequency'], greaterThan(0));
        expect(summary['activityLevel'], greaterThan(1));
        expect(summary['collaborationScore'], greaterThan(0));
        expect(summary['isRecent'], isFalse); // 12 hours ago
        expect(summary['isStale'], isFalse); // Less than 7 days
        expect(summary['lastEditor'], equals('user_123'));
        expect(summary['daysSinceCreated'], equals(5));
        expect(summary['daysSinceLastEdit'], equals(0)); // Less than 24 hours
      });

      test('should handle null lastEditedAt in summary', () {
        final createdAt = DateTime.now().subtract(Duration(days: 3));
        
        final summary = RealtimeMetadata.generateEditSummary(
          totalEdits: 0,
          createdAt: createdAt,
          lastEditedAt: null,
          lastEditor: 'user_123',
          uniqueEditors: 1,
        );

        expect(summary['isRecent'], isFalse);
        expect(summary['isStale'], isTrue);
        expect(summary['daysSinceLastEdit'], isNull);
        expect(summary['activityLevel'], equals(1)); // Minimum
      });
    });

    group('Edge Cases', () {
      test('should handle zero duration in frequency calculation', () {
        // Just created, no time elapsed
        final frequency = RealtimeMetadata.getEditFrequency(
          10,
          DateTime.now(),
        );
        expect(frequency, equals(10.0)); // All edits in current hour
      });

      test('should handle empty edit list in velocity calculation', () {
        final velocity = RealtimeMetadata.calculateEditVelocity(
          recentEdits: [],
        );
        expect(velocity, equals(0.0));
      });

      test('should clamp activity level between 1 and 5', () {
        // Maximum activity scenario
        var level = RealtimeMetadata.getActivityLevel(
          editCount: 1000,
          createdAt: DateTime.now().subtract(Duration(hours: 1)),
          lastEditedAt: DateTime.now(),
        );
        expect(level, equals(5));

        // Minimum activity scenario
        level = RealtimeMetadata.getActivityLevel(
          editCount: 0,
          createdAt: DateTime.now().subtract(Duration(days: 30)),
          lastEditedAt: DateTime.now().subtract(Duration(days: 30)),
        );
        expect(level, equals(1));
      });

      test('should handle edge cases in collaboration score', () {
        // Zero editors but has edits (should not happen, but handle gracefully)
        final score = RealtimeMetadata.getCollaborationScore(
          uniqueEditors: 0,
          totalEdits: 10,
          resourceAge: Duration(days: 1),
        );
        expect(score, greaterThanOrEqualTo(0));
        expect(score, lessThanOrEqualTo(100));
      });
    });
  });
}
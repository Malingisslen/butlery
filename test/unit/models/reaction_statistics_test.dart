// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/social/reaction_statistics.dart';
import 'package:butlery/models/social/reaction_type.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('ReactionStatistics', () {
    group('Construction', () {
      test('should create with required parameters', () {
        final lastUpdated = DateTime.now();
        final reactionCounts = {
          ReactionType.like: 10,
          ReactionType.love: 5,
        };

        final stats = ReactionStatistics(
          reactionCounts: reactionCounts,
          userReactionCount: 3,
          lastUpdated: lastUpdated,
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        expect(stats.reactionCounts, equals(reactionCounts));
        expect(stats.userReactionCount, equals(3));
        expect(stats.lastUpdated, equals(lastUpdated));
        expect(stats.contentId, equals('recipe_123'));
        expect(stats.contentType, equals('recipe'));
      });
    });

    group('Factory Methods', () {
      test('should create empty statistics', () {
        final stats = ReactionStatistics.empty(
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        expect(stats.reactionCounts, isEmpty);
        expect(stats.userReactionCount, equals(0));
        expect(stats.contentId, equals('recipe_123'));
        expect(stats.contentType, equals('recipe'));
        expect(stats.totalCount, equals(0));
        expect(stats.hasReactions, isFalse);
      });

      test('should create from counts', () {
        final counts = {
          ReactionType.like: 15,
          ReactionType.delicious: 8,
          ReactionType.creative: 3,
        };

        final stats = ReactionStatistics.fromCounts(
          counts,
          contentId: 'recipe_456',
          contentType: 'recipe',
        );

        expect(stats.reactionCounts, equals(counts));
        expect(stats.contentId, equals('recipe_456'));
        expect(stats.contentType, equals('recipe'));
        expect(stats.totalCount, equals(26));
      });

      test('should create from counts with user reaction count', () {
        final counts = {
          ReactionType.like: 5,
        };

        final stats = ReactionStatistics.fromCounts(
          counts,
          contentId: 'menu_789',
          contentType: 'menu',
          userReactionCount: 3,
        );

        expect(stats.reactionCounts, equals(counts));
        expect(stats.userReactionCount, equals(3));
      });

      test('should create from Firestore data', () {
        final firestoreData = {
          'reactionCounts': {
            'like': 10,
            'love': 5,
            'delicious': 3,
          },
          'userReactionCount': 2,
          'lastUpdated': DateTime(2025, 1, 1).millisecondsSinceEpoch,
          'contentId': 'recipe_123',
          'contentType': 'recipe',
        };

        final stats = ReactionStatistics.fromFirestore(
          'recipe_123',
          'recipe',
          firestoreData,
        );

        expect(stats.getCount(ReactionType.like), equals(10));
        expect(stats.getCount(ReactionType.love), equals(5));
        expect(stats.getCount(ReactionType.delicious), equals(3));
        expect(stats.userReactionCount, equals(2));
        expect(stats.lastUpdated.year, equals(2025));
      });

      test('should handle missing fields in Firestore data', () {
        final firestoreData = <String, dynamic>{};

        final stats = ReactionStatistics.fromFirestore(
          'recipe_123',
          'recipe',
          firestoreData,
        );

        expect(stats.reactionCounts, isEmpty);
        expect(stats.userReactionCount, equals(0));
        expect(stats.contentId, equals('recipe_123'));
      });

      test('should skip invalid reaction types in Firestore data', () {
        final firestoreData = {
          'reactionCounts': {
            'like': 10,
            'invalid_type': 5,
            'love': 3,
          },
          'userReactionCount': 0,
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        };

        final stats = ReactionStatistics.fromFirestore(
          'recipe_123',
          'recipe',
          firestoreData,
        );

        expect(stats.getCount(ReactionType.like), equals(10));
        expect(stats.getCount(ReactionType.love), equals(3));
        expect(stats.totalCount, equals(13)); // Invalid type is excluded
      });

      test('should ignore zero counts in Firestore data', () {
        final firestoreData = {
          'reactionCounts': {
            'like': 10,
            'love': 0,
            'delicious': 5,
          },
        };

        final stats = ReactionStatistics.fromFirestore(
          'recipe_123',
          'recipe',
          firestoreData,
        );

        expect(stats.reactionCounts.containsKey(ReactionType.love), isFalse);
        expect(stats.totalCount, equals(15));
      });
    });

    group('Serialization', () {
      test('should serialize to Firestore format', () {
        final stats = ReactionStatistics(
          reactionCounts: {
            ReactionType.like: 10,
            ReactionType.delicious: 5,
          },
          userReactionCount: 2,
          lastUpdated: DateTime(2025, 1, 1),
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        final firestore = stats.toFirestore();

        expect(firestore['reactionCounts']['like'], equals(10));
        expect(firestore['reactionCounts']['delicious'], equals(5));
        expect(firestore['userReactionCount'], equals(2));
        expect(firestore['lastUpdated'],
            equals(DateTime(2025, 1, 1).millisecondsSinceEpoch));
        expect(firestore['contentId'], equals('recipe_123'));
        expect(firestore['contentType'], equals('recipe'));
      });

      test('should round-trip through Firestore', () {
        final original = ReactionStatistics.fromCounts(
          {
            ReactionType.like: 15,
            ReactionType.love: 8,
            ReactionType.helpful: 3,
          },
          contentId: 'recipe_456',
          contentType: 'recipe',
          userReactionCount: 3,
        );

        final firestore = original.toFirestore();
        final restored = ReactionStatistics.fromFirestore(
          'recipe_456',
          'recipe',
          firestore,
        );

        expect(restored.getCount(ReactionType.like), equals(15));
        expect(restored.getCount(ReactionType.love), equals(8));
        expect(restored.getCount(ReactionType.helpful), equals(3));
        expect(restored.userReactionCount, equals(3));
        expect(restored.contentId, equals('recipe_456'));
      });
    });

    group('Statistical Calculations', () {
      late ReactionStatistics stats;

      setUp(() {
        stats = ReactionStatistics.fromCounts(
          {
            ReactionType.like: 20,
            ReactionType.love: 10,
            ReactionType.delicious: 8,
            ReactionType.creative: 2,
          },
          contentId: 'recipe_123',
          contentType: 'recipe',
        );
      });

      test('should calculate total count', () {
        expect(stats.totalCount, equals(40));
      });

      test('should get count for specific reaction type', () {
        expect(stats.getCount(ReactionType.like), equals(20));
        expect(stats.getCount(ReactionType.love), equals(10));
        expect(
            stats.getCount(ReactionType.helpful), equals(0)); // Not in the map
      });

      test('should identify top reaction', () {
        expect(stats.topReaction, equals(ReactionType.like));

        // Test with different distribution
        final stats2 = ReactionStatistics.fromCounts(
          {
            ReactionType.love: 50,
            ReactionType.like: 10,
          },
          contentId: 'recipe_456',
          contentType: 'recipe',
        );
        expect(stats2.topReaction, equals(ReactionType.love));
      });

      test('should return null for top reaction when empty', () {
        final emptyStats = ReactionStatistics.empty(
          contentId: 'recipe_789',
          contentType: 'recipe',
        );
        expect(emptyStats.topReaction, isNull);
      });

      test('should get top N reactions', () {
        final top3 = stats.getTopReactions(3);

        expect(top3.length, equals(3));
        expect(top3[0].key, equals(ReactionType.like));
        expect(top3[0].value, equals(20));
        expect(top3[1].key, equals(ReactionType.love));
        expect(top3[1].value, equals(10));
        expect(top3[2].key, equals(ReactionType.delicious));
        expect(top3[2].value, equals(8));
      });

      test('should handle requesting more top reactions than available', () {
        final top10 = stats.getTopReactions(10);
        expect(top10.length, equals(4)); // Only 4 reaction types in the map
      });

      test('should calculate reaction percentages', () {
        final percentages = stats.reactionPercentages;

        expect(percentages[ReactionType.like], equals(50.0)); // 20/40
        expect(percentages[ReactionType.love], equals(25.0)); // 10/40
        expect(percentages[ReactionType.delicious], equals(20.0)); // 8/40
        expect(percentages[ReactionType.creative], equals(5.0)); // 2/40
      });

      test('should return empty percentages for no reactions', () {
        final emptyStats = ReactionStatistics.empty(
          contentId: 'recipe_789',
          contentType: 'recipe',
        );
        expect(emptyStats.reactionPercentages, isEmpty);
      });
    });

    group('User Tracking', () {
      test('should track if any user has reacted', () {
        final stats = ReactionStatistics(
          reactionCounts: {ReactionType.like: 5},
          userReactionCount: 3,
          lastUpdated: DateTime.now(),
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        expect(stats.hasAnyUserReacted, isTrue);
      });

      test('should return false when no users have reacted', () {
        final stats = ReactionStatistics(
          reactionCounts: {},
          userReactionCount: 0,
          lastUpdated: DateTime.now(),
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        expect(stats.hasAnyUserReacted, isFalse);
      });
    });

    group('Increment/Decrement Operations', () {
      test('should increment new reaction', () {
        final original = ReactionStatistics.empty(
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        final updated =
            original.incrementReaction(ReactionType.like, isNewUser: true);

        expect(updated.getCount(ReactionType.like), equals(1));
        expect(updated.userReactionCount, equals(1));
        expect(updated.totalCount, equals(1));
      });

      test('should increment existing reaction without new user', () {
        final original = ReactionStatistics.fromCounts(
          {ReactionType.like: 5},
          contentId: 'recipe_123',
          contentType: 'recipe',
          userReactionCount: 2,
        );

        final updated = original.incrementReaction(ReactionType.like);

        expect(updated.getCount(ReactionType.like), equals(6));
        expect(updated.userReactionCount, equals(2)); // Not incremented
        expect(updated.totalCount, equals(6));
      });

      test('should increment existing reaction with new user', () {
        final original = ReactionStatistics.fromCounts(
          {ReactionType.like: 5},
          contentId: 'recipe_123',
          contentType: 'recipe',
          userReactionCount: 2,
        );

        final updated =
            original.incrementReaction(ReactionType.like, isNewUser: true);

        expect(updated.getCount(ReactionType.like), equals(6));
        expect(updated.userReactionCount, equals(3));
        expect(updated.totalCount, equals(6));
      });

      test('should decrement reaction', () {
        final original = ReactionStatistics.fromCounts(
          {
            ReactionType.like: 5,
            ReactionType.love: 3,
          },
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        final updated = original.decrementReaction(ReactionType.like);

        expect(updated.getCount(ReactionType.like), equals(4));
        expect(updated.getCount(ReactionType.love), equals(3));
        expect(updated.totalCount, equals(7));
      });

      test('should decrement user count when was last reaction', () {
        final original = ReactionStatistics.fromCounts(
          {ReactionType.like: 5},
          contentId: 'recipe_123',
          contentType: 'recipe',
          userReactionCount: 3,
        );

        final updated = original.decrementReaction(ReactionType.like,
            wasLastReaction: true);

        expect(updated.getCount(ReactionType.like), equals(4));
        expect(updated.userReactionCount, equals(2));
      });

      test('should remove reaction type when count reaches zero', () {
        final original = ReactionStatistics.fromCounts(
          {
            ReactionType.like: 1,
            ReactionType.love: 3,
          },
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        final updated = original.decrementReaction(ReactionType.like);

        expect(updated.reactionCounts.containsKey(ReactionType.like), isFalse);
        expect(updated.getCount(ReactionType.like), equals(0));
        expect(updated.totalCount, equals(3));
      });

      test('should handle decrementing non-existent reaction', () {
        final original = ReactionStatistics.fromCounts(
          {ReactionType.like: 5},
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        final updated = original.decrementReaction(ReactionType.love);

        expect(updated.getCount(ReactionType.love), equals(0));
        expect(updated.getCount(ReactionType.like), equals(5));
        expect(updated.totalCount, equals(5));
      });
    });

    group('Copy Methods', () {
      test('should copy with new values', () {
        final original = ReactionStatistics.fromCounts(
          {ReactionType.like: 10},
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        final newCounts = {
          ReactionType.love: 5,
          ReactionType.delicious: 3,
        };
        final newTime = DateTime(2025, 2, 1);

        final copied = original.copyWith(
          reactionCounts: newCounts,
          userReactionCount: 5,
          lastUpdated: newTime,
        );

        expect(copied.reactionCounts, equals(newCounts));
        expect(copied.userReactionCount, equals(5));
        expect(copied.lastUpdated, equals(newTime));
        expect(copied.contentId, equals('recipe_123')); // Preserved
      });

      test('should preserve original values when not specified', () {
        final original = ReactionStatistics.fromCounts(
          {ReactionType.like: 10},
          contentId: 'recipe_123',
          contentType: 'recipe',
          userReactionCount: 1,
        );

        final copied = original.copyWith();

        expect(copied.reactionCounts, equals(original.reactionCounts));
        expect(copied.userReactionCount, equals(original.userReactionCount));
        expect(copied.contentId, equals(original.contentId));
        expect(copied.contentType, equals(original.contentType));
      });
    });

    group('Properties', () {
      test('should get active reaction types', () {
        final stats = ReactionStatistics.fromCounts(
          {
            ReactionType.like: 10,
            ReactionType.love: 5,
            ReactionType.creative: 1,
          },
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        final activeTypes = stats.activeReactionTypes;

        expect(activeTypes, contains(ReactionType.like));
        expect(activeTypes, contains(ReactionType.love));
        expect(activeTypes, contains(ReactionType.creative));
        expect(activeTypes.length, equals(3));
      });

      test('should check if has reactions', () {
        final withReactions = ReactionStatistics.fromCounts(
          {ReactionType.like: 1},
          contentId: 'recipe_123',
          contentType: 'recipe',
        );
        expect(withReactions.hasReactions, isTrue);

        final empty = ReactionStatistics.empty(
          contentId: 'recipe_456',
          contentType: 'recipe',
        );
        expect(empty.hasReactions, isFalse);
      });
    });

    group('Equality and HashCode', () {
      test('should be equal when content ID and type match', () {
        final stats1 = ReactionStatistics.fromCounts(
          {ReactionType.like: 10},
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        final stats2 = ReactionStatistics.fromCounts(
          {ReactionType.love: 5},
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        expect(stats1, equals(stats2));
        expect(stats1.hashCode, equals(stats2.hashCode));
      });

      test('should not be equal when content ID differs', () {
        final stats1 = ReactionStatistics.empty(
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        final stats2 = ReactionStatistics.empty(
          contentId: 'recipe_456',
          contentType: 'recipe',
        );

        expect(stats1, isNot(equals(stats2)));
      });

      test('should not be equal when content type differs', () {
        final stats1 = ReactionStatistics.empty(
          contentId: 'content_123',
          contentType: 'recipe',
        );

        final stats2 = ReactionStatistics.empty(
          contentId: 'content_123',
          contentType: 'menu',
        );

        expect(stats1, isNot(equals(stats2)));
      });
    });

    group('Edge Cases', () {
      test('should handle empty statistics', () {
        final stats = ReactionStatistics.empty(
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        expect(stats.totalCount, equals(0));
        expect(stats.topReaction, isNull);
        expect(stats.getTopReactions(5), isEmpty);
        expect(stats.reactionPercentages, isEmpty);
        expect(stats.activeReactionTypes, isEmpty);
        expect(stats.hasReactions, isFalse);
      });

      test('should handle single reaction', () {
        final stats = ReactionStatistics.fromCounts(
          {ReactionType.like: 1},
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        expect(stats.totalCount, equals(1));
        expect(stats.topReaction, equals(ReactionType.like));
        expect(stats.getTopReactions(1).first.key, equals(ReactionType.like));
        expect(stats.reactionPercentages[ReactionType.like], equals(100.0));
      });

      test('should handle tied reactions for top reaction', () {
        final stats = ReactionStatistics.fromCounts(
          {
            ReactionType.like: 10,
            ReactionType.love: 10,
            ReactionType.delicious: 5,
          },
          contentId: 'recipe_123',
          contentType: 'recipe',
        );

        // Should return first encountered max
        expect(stats.topReaction, isIn([ReactionType.like, ReactionType.love]));
        expect(stats.totalCount, equals(25));
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/social/content_reaction.dart';
import 'package:butlery/models/social/reaction_type.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('ContentReaction', () {
    group('Construction', () {
      test('should create with required parameters', () {
        final now = DateTime.now();
        final reaction = ContentReaction(
          id: 'reaction_123',
          contentId: 'recipe_456',
          contentType: 'recipe',
          userId: 'user_789',
          reactionType: ReactionType.delicious,
          createdAt: now,
        );
        
        expect(reaction.id, equals('reaction_123'));
        expect(reaction.contentId, equals('recipe_456'));
        expect(reaction.contentType, equals('recipe'));
        expect(reaction.userId, equals('user_789'));
        expect(reaction.reactionType, equals(ReactionType.delicious));
        expect(reaction.createdAt, equals(now));
        expect(reaction.updatedAt, isNull);
      });
      
      test('should create with all parameters including updatedAt', () {
        final createdTime = DateTime(2024, 1, 15, 10, 30);
        final updatedTime = DateTime(2024, 1, 15, 12, 0);
        
        final reaction = ContentReaction(
          id: 'reaction_123',
          contentId: 'comment_456',
          contentType: 'comment',
          userId: 'user_789',
          reactionType: ReactionType.helpful,
          createdAt: createdTime,
          updatedAt: updatedTime,
        );
        
        expect(reaction.updatedAt, equals(updatedTime));
        expect(reaction.wasUpdated, isTrue);
      });
      
      test('should handle different content types', () {
        final recipeReaction = ContentReaction(
          id: 'r1',
          contentId: 'recipe_1',
          contentType: 'recipe',
          userId: 'user_1',
          reactionType: ReactionType.delicious,
          createdAt: DateTime.now(),
        );
        
        final commentReaction = ContentReaction(
          id: 'r2',
          contentId: 'comment_1',
          contentType: 'comment',
          userId: 'user_1',
          reactionType: ReactionType.helpful,
          createdAt: DateTime.now(),
        );
        
        final menuReaction = ContentReaction(
          id: 'r3',
          contentId: 'menu_1',
          contentType: 'menu',
          userId: 'user_1',
          reactionType: ReactionType.creative,
          createdAt: DateTime.now(),
        );
        
        expect(recipeReaction.contentType, equals('recipe'));
        expect(commentReaction.contentType, equals('comment'));
        expect(menuReaction.contentType, equals('menu'));
      });
      
      test('should handle all reaction types', () {
        final reactions = ReactionType.values.map((type) => ContentReaction(
          id: 'r_${type.key}',
          contentId: 'content_1',
          contentType: 'recipe',
          userId: 'user_1',
          reactionType: type,
          createdAt: DateTime.now(),
        )).toList();
        
        expect(reactions.length, equals(ReactionType.values.length));
        expect(reactions.any((r) => r.reactionType == ReactionType.like), isTrue);
        expect(reactions.any((r) => r.reactionType == ReactionType.love), isTrue);
        expect(reactions.any((r) => r.reactionType == ReactionType.helpful), isTrue);
        expect(reactions.any((r) => r.reactionType == ReactionType.delicious), isTrue);
        expect(reactions.any((r) => r.reactionType == ReactionType.easy), isTrue);
        expect(reactions.any((r) => r.reactionType == ReactionType.creative), isTrue);
      });
    });
    
    group('Factory Methods', () {
      test('should create with auto-generated composite ID', () {
        final reaction = ContentReaction.create(
          contentId: 'recipe_456',
          contentType: 'recipe',
          userId: 'user_789',
          reactionType: ReactionType.delicious,
        );
        
        expect(reaction.id, equals('recipe_recipe_456_user_789'));
        expect(reaction.contentId, equals('recipe_456'));
        expect(reaction.contentType, equals('recipe'));
        expect(reaction.userId, equals('user_789'));
        expect(reaction.reactionType, equals(ReactionType.delicious));
        expect(reaction.createdAt, isNotNull);
        expect(reaction.updatedAt, isNull);
      });
      
      test('should generate unique composite IDs for same user different content', () {
        final reaction1 = ContentReaction.create(
          contentId: 'recipe_1',
          contentType: 'recipe',
          userId: 'user_123',
          reactionType: ReactionType.like,
        );
        
        final reaction2 = ContentReaction.create(
          contentId: 'recipe_2',
          contentType: 'recipe',
          userId: 'user_123',
          reactionType: ReactionType.like,
        );
        
        expect(reaction1.id, equals('recipe_recipe_1_user_123'));
        expect(reaction2.id, equals('recipe_recipe_2_user_123'));
        expect(reaction1.id, isNot(equals(reaction2.id)));
      });
      
      test('should generate same composite ID for same user same content', () {
        final reaction1 = ContentReaction.create(
          contentId: 'recipe_123',
          contentType: 'recipe',
          userId: 'user_456',
          reactionType: ReactionType.like,
        );
        
        final reaction2 = ContentReaction.create(
          contentId: 'recipe_123',
          contentType: 'recipe',
          userId: 'user_456',
          reactionType: ReactionType.love, // Different reaction but same ID
        );
        
        expect(reaction1.id, equals('recipe_recipe_123_user_456'));
        expect(reaction2.id, equals('recipe_recipe_123_user_456'));
        expect(reaction1.id, equals(reaction2.id)); // Same ID ensures one reaction per user per content
      });
      
      test('should create from Firestore data', () {
        final createdDate = DateTime(2024, 1, 15, 10, 30);
        final updatedDate = DateTime(2024, 1, 15, 12, 0);
        
        final data = {
          'contentId': 'recipe_456',
          'contentType': 'recipe',
          'userId': 'user_789',
          'reactionType': 'delicious',
          'createdAt': Timestamp.fromDate(createdDate),
          'updatedAt': Timestamp.fromDate(updatedDate),
        };
        
        final reaction = ContentReaction.fromFirestore('reaction_123', data);
        
        expect(reaction.id, equals('reaction_123'));
        expect(reaction.contentId, equals('recipe_456'));
        expect(reaction.contentType, equals('recipe'));
        expect(reaction.userId, equals('user_789'));
        expect(reaction.reactionType, equals(ReactionType.delicious));
        expect(reaction.createdAt, equals(createdDate));
        expect(reaction.updatedAt, equals(updatedDate));
      });
      
      test('should handle missing Firestore fields with defaults', () {
        final data = <String, dynamic>{}; // Empty data
        
        final reaction = ContentReaction.fromFirestore('reaction_123', data);
        
        expect(reaction.id, equals('reaction_123'));
        expect(reaction.contentId, isEmpty);
        expect(reaction.contentType, isEmpty);
        expect(reaction.userId, isEmpty);
        expect(reaction.reactionType, equals(ReactionType.like)); // Default
        expect(reaction.createdAt, isNotNull);
        expect(reaction.updatedAt, isNull);
      });
    });
    
    group('JSON Serialization', () {
      test('should serialize to JSON', () {
        final createdTime = DateTime(2024, 1, 15, 10, 30);
        final updatedTime = DateTime(2024, 1, 15, 12, 0);
        
        final reaction = ContentReaction(
          id: 'reaction_123',
          contentId: 'recipe_456',
          contentType: 'recipe',
          userId: 'user_789',
          reactionType: ReactionType.delicious,
          createdAt: createdTime,
          updatedAt: updatedTime,
        );
        
        final json = reaction.toJson();
        
        expect(json['id'], equals('reaction_123'));
        expect(json['contentId'], equals('recipe_456'));
        expect(json['contentType'], equals('recipe'));
        expect(json['userId'], equals('user_789'));
        expect(json['reactionType'], equals('delicious'));
        expect(json['createdAt'], equals(createdTime.toIso8601String()));
        expect(json['updatedAt'], equals(updatedTime.toIso8601String()));
      });
      
      test('should deserialize from JSON', () {
        final json = {
          'id': 'reaction_123',
          'contentId': 'recipe_456',
          'contentType': 'recipe',
          'userId': 'user_789',
          'reactionType': 'delicious',
          'createdAt': '2024-01-15T10:30:00.000',
          'updatedAt': '2024-01-15T12:00:00.000',
        };
        
        final reaction = ContentReaction.fromJson(json);
        
        expect(reaction.id, equals('reaction_123'));
        expect(reaction.contentId, equals('recipe_456'));
        expect(reaction.contentType, equals('recipe'));
        expect(reaction.userId, equals('user_789'));
        expect(reaction.reactionType, equals(ReactionType.delicious));
        expect(reaction.createdAt, equals(DateTime(2024, 1, 15, 10, 30)));
        expect(reaction.updatedAt, equals(DateTime(2024, 1, 15, 12, 0)));
      });
      
      test('should round-trip JSON serialization', () {
        final original = ContentReaction.create(
          contentId: 'recipe_456',
          contentType: 'recipe',
          userId: 'user_789',
          reactionType: ReactionType.creative,
        );
        
        final json = original.toJson();
        final deserialized = ContentReaction.fromJson(json);
        
        expect(deserialized.id, equals(original.id));
        expect(deserialized.contentId, equals(original.contentId));
        expect(deserialized.contentType, equals(original.contentType));
        expect(deserialized.userId, equals(original.userId));
        expect(deserialized.reactionType, equals(original.reactionType));
      });
      
      test('should handle null updatedAt in JSON', () {
        final json = {
          'id': 'reaction_123',
          'contentId': 'recipe_456',
          'contentType': 'recipe',
          'userId': 'user_789',
          'reactionType': 'like',
          'createdAt': '2024-01-15T10:30:00.000',
          'updatedAt': null,
        };
        
        final reaction = ContentReaction.fromJson(json);
        
        expect(reaction.updatedAt, isNull);
        expect(reaction.wasUpdated, isFalse);
      });
    });
    
    group('Firestore Serialization', () {
      test('should serialize to Firestore format', () {
        final createdTime = DateTime(2024, 1, 15, 10, 30);
        final reaction = ContentReaction(
          id: 'reaction_123',
          contentId: 'recipe_456',
          contentType: 'recipe',
          userId: 'user_789',
          reactionType: ReactionType.delicious,
          createdAt: createdTime,
        );
        
        final firestore = reaction.toFirestore();
        
        expect(firestore['contentId'], equals('recipe_456'));
        expect(firestore['contentType'], equals('recipe'));
        expect(firestore['userId'], equals('user_789'));
        expect(firestore['reactionType'], equals('delicious'));
        expect(firestore['createdAt'], isNotNull);
        expect(firestore.containsKey('id'), isFalse); // ID is document ID
        expect(firestore.containsKey('updatedAt'), isFalse); // Not set
      });
      
      test('should include updatedAt when present', () {
        final reaction = ContentReaction(
          id: 'reaction_123',
          contentId: 'recipe_456',
          contentType: 'recipe',
          userId: 'user_789',
          reactionType: ReactionType.delicious,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final firestore = reaction.toFirestore();
        
        expect(firestore.containsKey('updatedAt'), isTrue);
        expect(firestore['updatedAt'], isNotNull);
      });
    });
    
    group('copyWith Operations', () {
      late ContentReaction original;
      
      setUp(() {
        original = ContentReaction.create(
          contentId: 'recipe_456',
          contentType: 'recipe',
          userId: 'user_789',
          reactionType: ReactionType.like,
        );
      });
      
      test('should update reaction type', () {
        final updated = original.copyWith(
          reactionType: ReactionType.delicious,
          updatedAt: DateTime.now(),
        );
        
        expect(updated.reactionType, equals(ReactionType.delicious));
        expect(updated.updatedAt, isNotNull);
        expect(updated.id, equals(original.id));
        expect(updated.contentId, equals(original.contentId));
      });
      
      test('should update timestamps', () {
        final newUpdatedAt = DateTime.now();
        final updated = original.copyWith(
          updatedAt: newUpdatedAt,
        );
        
        expect(updated.updatedAt, equals(newUpdatedAt));
        expect(updated.wasUpdated, isTrue);
      });
      
      test('should preserve immutability', () {
        final updated = original.copyWith(
          reactionType: ReactionType.love,
        );
        
        expect(original.reactionType, equals(ReactionType.like));
        expect(updated.reactionType, equals(ReactionType.love));
        expect(original.id, equals(updated.id));
      });
    });
    
    group('Display Properties', () {
      late ContentReaction reaction;
      
      setUp(() {
        reaction = ContentReaction.create(
          contentId: 'recipe_456',
          contentType: 'recipe',
          userId: 'user_789',
          reactionType: ReactionType.delicious,
        );
      });
      
      test('should get display text with emoji', () {
        expect(reaction.displayText, equals('😋 Läcker'));
        
        final loveReaction = reaction.copyWith(reactionType: ReactionType.love);
        expect(loveReaction.displayText, equals('😍 Älska'));
        
        final helpfulReaction = reaction.copyWith(reactionType: ReactionType.helpful);
        expect(helpfulReaction.displayText, equals('👍 Hjälpsam'));
      });
      
      test('should track if reaction was updated', () {
        expect(reaction.wasUpdated, isFalse);
        
        final updated = reaction.copyWith(
          reactionType: ReactionType.creative,
          updatedAt: DateTime.now(),
        );
        
        expect(updated.wasUpdated, isTrue);
      });
      
      test('should calculate age of reaction', () {
        final oldReaction = ContentReaction(
          id: 'reaction_123',
          contentId: 'recipe_456',
          contentType: 'recipe',
          userId: 'user_789',
          reactionType: ReactionType.like,
          createdAt: DateTime.now().subtract(Duration(hours: 5)),
        );
        
        expect(oldReaction.age.inHours, greaterThanOrEqualTo(4));
        expect(oldReaction.age.inHours, lessThanOrEqualTo(6));
      });
    });
    
    group('Equality and Hashing', () {
      test('should be equal when IDs match', () {
        final reaction1 = ContentReaction(
          id: 'reaction_123',
          contentId: 'recipe_456',
          contentType: 'recipe',
          userId: 'user_789',
          reactionType: ReactionType.like,
          createdAt: DateTime.now(),
        );
        
        final reaction2 = ContentReaction(
          id: 'reaction_123',
          contentId: 'different_recipe',
          contentType: 'comment',
          userId: 'different_user',
          reactionType: ReactionType.creative,
          createdAt: DateTime.now(),
        );
        
        expect(reaction1, equals(reaction2));
        expect(reaction1.hashCode, equals(reaction2.hashCode));
      });
      
      test('should not be equal when IDs differ', () {
        final reaction1 = ContentReaction.create(
          contentId: 'recipe_456',
          contentType: 'recipe',
          userId: 'user_789',
          reactionType: ReactionType.like,
        );
        
        final reaction2 = ContentReaction.create(
          contentId: 'recipe_456',
          contentType: 'recipe',
          userId: 'user_999', // Different user = different composite ID
          reactionType: ReactionType.like,
        );
        
        expect(reaction1, isNot(equals(reaction2)));
      });
      
      test('should be equal to itself', () {
        final reaction = ContentReaction.create(
          contentId: 'recipe_456',
          contentType: 'recipe',
          userId: 'user_789',
          reactionType: ReactionType.delicious,
        );
        
        expect(reaction, equals(reaction));
      });
    });
    
    group('toString', () {
      test('should provide meaningful string representation', () {
        final reaction = ContentReaction(
          id: 'reaction_123',
          contentId: 'recipe_456',
          contentType: 'recipe',
          userId: 'user_789',
          reactionType: ReactionType.delicious,
          createdAt: DateTime.now(),
        );
        
        final str = reaction.toString();
        
        expect(str, contains('reaction_123'));
        expect(str, contains('recipe_456'));
        expect(str, contains('recipe'));
        expect(str, contains('user_789'));
        expect(str, contains('delicious'));
      });
    });
    
    group('Edge Cases', () {
      test('should handle empty content type and ID', () {
        final reaction = ContentReaction(
          id: 'reaction_123',
          contentId: '',
          contentType: '',
          userId: 'user_789',
          reactionType: ReactionType.like,
          createdAt: DateTime.now(),
        );
        
        expect(reaction.contentId, isEmpty);
        expect(reaction.contentType, isEmpty);
      });
      
      test('should handle all Swedish reaction names', () {
        final reactions = [
          ReactionType.like,     // Gilla
          ReactionType.love,     // Älska
          ReactionType.helpful,  // Hjälpsam
          ReactionType.delicious, // Läcker
          ReactionType.easy,     // Enkel
          ReactionType.creative, // Kreativ
        ];
        
        for (final type in reactions) {
          final reaction = ContentReaction.create(
            contentId: 'content_1',
            contentType: 'recipe',
            userId: 'user_1',
            reactionType: type,
          );
          
          expect(reaction.displayText, contains(type.displayName));
          expect(reaction.displayText, contains(type.emoji));
        }
      });
      
      test('should handle rapid reaction changes', () {
        var reaction = ContentReaction.create(
          contentId: 'recipe_456',
          contentType: 'recipe',
          userId: 'user_789',
          reactionType: ReactionType.like,
        );
        
        // Simulate rapid reaction changes
        final types = [
          ReactionType.love,
          ReactionType.delicious,
          ReactionType.creative,
          ReactionType.helpful,
          ReactionType.easy,
          ReactionType.like,
        ];
        
        for (final type in types) {
          reaction = reaction.copyWith(
            reactionType: type,
            updatedAt: DateTime.now(),
          );
          expect(reaction.reactionType, equals(type));
        }
        
        expect(reaction.wasUpdated, isTrue);
      });
      
      test('should maintain composite ID consistency', () {
        // Same user can only have one reaction per content
        final reaction1 = ContentReaction.create(
          contentId: 'recipe_123',
          contentType: 'recipe',
          userId: 'user_456',
          reactionType: ReactionType.like,
        );
        
        // User changes reaction type - same ID should be generated
        final reaction2 = ContentReaction.create(
          contentId: 'recipe_123',
          contentType: 'recipe',
          userId: 'user_456',
          reactionType: ReactionType.delicious,
        );
        
        expect(reaction1.id, equals(reaction2.id));
        expect(reaction1.id, equals('recipe_recipe_123_user_456'));
      });
      
      test('should handle very old reactions', () {
        final veryOld = ContentReaction(
          id: 'reaction_123',
          contentId: 'recipe_456',
          contentType: 'recipe',
          userId: 'user_789',
          reactionType: ReactionType.like,
          createdAt: DateTime.now().subtract(Duration(days: 365)),
        );
        
        expect(veryOld.age.inDays, greaterThanOrEqualTo(364));
        expect(veryOld.age.inDays, lessThanOrEqualTo(366));
      });
      
      test('should handle unknown reaction type key', () {
        final data = {
          'contentId': 'recipe_456',
          'contentType': 'recipe',
          'userId': 'user_789',
          'reactionType': 'unknown_reaction', // Invalid key
          'createdAt': Timestamp.fromDate(DateTime.now()),
        };
        
        final reaction = ContentReaction.fromFirestore('reaction_123', data);
        
        expect(reaction.reactionType, equals(ReactionType.like)); // Falls back to like
      });
    });
  });
}
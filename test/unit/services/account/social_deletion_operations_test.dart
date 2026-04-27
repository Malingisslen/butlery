import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/services/account/account_deletion/social_deletion_operations.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

class _MockMessagingRepository extends Mock implements MessagingRepository {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late _MockMessagingRepository mockMessagingRepo;
  late SocialDeletionOperations operations;

  const testUserId = 'deleted-user';
  const otherUserId = 'other-user';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockMessagingRepo = _MockMessagingRepository();
    when(() => mockMessagingRepo.deleteAllMessagesForUser(any()))
        .thenAnswer((_) async => 0);
    operations = SocialDeletionOperations(
      fakeFirestore,
      messagingRepository: mockMessagingRepo,
    );
  });

  group('removeFriendConnections', () {
    test(
        'should delete friends, friendCategories, friend requests and group invitations for user',
        () async {
      // Arrange - seed friends subcollection
      await fakeFirestore
          .collection(FirestoreCollections.users)
          .doc(testUserId)
          .collection(FirestoreCollections.userFriends)
          .doc('friend1')
          .set({'friendId': otherUserId});

      await fakeFirestore
          .collection(FirestoreCollections.users)
          .doc(testUserId)
          .collection(FirestoreCollections.userFriendCategories)
          .doc('cat1')
          .set({'name': 'Close friends'});

      // Seed social requests (friend requests + group invitations)
      await fakeFirestore
          .collection(FirestoreCollections.socialRequests)
          .doc('req-outgoing')
          .set({
        'type': 'friend',
        'fromUserId': testUserId,
        'toUserId': otherUserId
      });
      await fakeFirestore
          .collection(FirestoreCollections.socialRequests)
          .doc('req-incoming')
          .set({
        'type': 'friend',
        'fromUserId': otherUserId,
        'toUserId': testUserId
      });
      await fakeFirestore
          .collection(FirestoreCollections.socialRequests)
          .doc('inv-outgoing')
          .set({
        'type': 'groupInvitation',
        'fromUserId': testUserId,
        'toUserId': otherUserId
      });
      await fakeFirestore
          .collection(FirestoreCollections.socialRequests)
          .doc('inv-incoming')
          .set({
        'type': 'groupInvitation',
        'fromUserId': otherUserId,
        'toUserId': testUserId
      });

      // Act
      final result = await operations.removeFriendConnections(testUserId);

      // Assert
      expect(result, true);

      final friends = await fakeFirestore
          .collection(FirestoreCollections.users)
          .doc(testUserId)
          .collection(FirestoreCollections.userFriends)
          .get();
      expect(friends.docs, isEmpty);

      final categories = await fakeFirestore
          .collection(FirestoreCollections.users)
          .doc(testUserId)
          .collection(FirestoreCollections.userFriendCategories)
          .get();
      expect(categories.docs, isEmpty);

      final socialRequests = await fakeFirestore
          .collection(FirestoreCollections.socialRequests)
          .get();
      expect(socialRequests.docs, isEmpty);
    });

    test('should return true when no friend data exists', () async {
      final result = await operations.removeFriendConnections(testUserId);
      expect(result, true);
    });
  });

  group('removeFromSharedContent', () {
    test(
        'should delete membership docs from members subcollection via collectionGroup',
        () async {
      // Arrange
      await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('recipe1')
          .collection(FirestoreCollections.members)
          .doc('member1')
          .set({'userId': testUserId, 'role': 'viewer'});

      // Keep another user's membership intact
      await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('recipe1')
          .collection(FirestoreCollections.members)
          .doc('member2')
          .set({'userId': otherUserId, 'role': 'editor'});

      // Act
      final result = await operations.removeFromSharedContent(testUserId);

      // Assert
      expect(result, true);

      final remainingMembers = await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('recipe1')
          .collection(FirestoreCollections.members)
          .get();
      expect(remainingMembers.docs.length, 1);
      expect(remainingMembers.docs.first.data()['userId'], otherUserId);
    });

    test(
        'should delete views, engagements, and dismissals subcollection docs for user',
        () async {
      // Arrange
      await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('recipe1')
          .collection('views')
          .doc('view1')
          .set({'userId': testUserId, 'timestamp': Timestamp.now()});

      await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('recipe1')
          .collection('engagements')
          .doc('eng1')
          .set({'userId': testUserId});

      await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('recipe1')
          .collection('dismissals')
          .doc('dis1')
          .set({'userId': testUserId});

      // Act
      final result = await operations.removeFromSharedContent(testUserId);

      // Assert
      expect(result, true);

      final views = await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('recipe1')
          .collection('views')
          .get();
      expect(views.docs, isEmpty);

      final engagements = await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('recipe1')
          .collection('engagements')
          .get();
      expect(engagements.docs, isEmpty);

      final dismissals = await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('recipe1')
          .collection('dismissals')
          .get();
      expect(dismissals.docs, isEmpty);
    });

    test(
        'should remove user from legacy sharedWith array without affecting other users',
        () async {
      // Arrange
      await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('recipe2')
          .set({
        'sharedWith': [testUserId, otherUserId],
        'ownerId': 'someone-else',
        'title': 'Shared recipe',
      });

      // Act
      final result = await operations.removeFromSharedContent(testUserId);

      // Assert
      expect(result, true);

      final doc = await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('recipe2')
          .get();
      expect(doc.exists, true);
      final sharedWith = List<String>.from(doc.data()!['sharedWith']);
      expect(sharedWith, contains(otherUserId));
      expect(sharedWith, isNot(contains(testUserId)));
    });

    test('should delete owned shared recipes', () async {
      // Arrange
      await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('recipe3')
          .set({'ownerId': testUserId, 'title': 'My shared recipe'});

      // Keep other user's recipe
      await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('recipe4')
          .set({'ownerId': otherUserId, 'title': 'Other recipe'});

      // Act
      final result = await operations.removeFromSharedContent(testUserId);

      // Assert
      expect(result, true);

      final owned = await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('recipe3')
          .get();
      expect(owned.exists, false);

      final otherRecipe = await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('recipe4')
          .get();
      expect(otherRecipe.exists, true);
    });
  });

  group('deleteCommentsAndRatings', () {
    test(
        'should anonymize recipe comments and delete ratings/menu data with correct field names',
        () async {
      // Arrange — use actual field names from each collection
      await fakeFirestore
          .collection(FirestoreCollections.recipeComments)
          .doc('rc1')
          .set({
        'authorId': testUserId,
        'authorDisplayName': 'Test User',
        'authorAvatarUrl': 'https://example.com/avatar.jpg',
        'text': 'Great recipe!',
        'isDeleted': false,
      });
      await fakeFirestore
          .collection(FirestoreCollections.recipeRatings)
          .doc('rr1')
          .set({'userId': testUserId, 'rating': 5});
      await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('menu1')
          .collection(FirestoreCollections.comments)
          .doc('mc1')
          .set({'commentedBy': testUserId, 'text': 'Nice menu'});
      await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('menu1')
          .collection(FirestoreCollections.ratings)
          .doc('mr1')
          .set({'ratedBy': testUserId, 'rating': 4});

      // Seed other user's data that should remain
      await fakeFirestore
          .collection(FirestoreCollections.recipeComments)
          .doc('rc2')
          .set({'authorId': otherUserId, 'text': 'Also great!'});

      // Act
      final result = await operations.deleteCommentsAndRatings(testUserId);

      // Assert
      expect(result, true);

      // Recipe comments should be anonymized, NOT deleted
      final anonymized = await fakeFirestore
          .collection(FirestoreCollections.recipeComments)
          .doc('rc1')
          .get();
      expect(anonymized.exists, true);
      expect(anonymized.data()!['authorId'], 'deleted');
      expect(anonymized.data()!['authorDisplayName'], 'Borttagen användare');
      expect(anonymized.data()!['authorAvatarUrl'], isNull);
      expect(anonymized.data()!['isDeleted'], true);
      expect(anonymized.data()!['text'], '[Kommentar borttagen]');

      // Recipe ratings should be hard-deleted
      final ratings = await fakeFirestore
          .collection(FirestoreCollections.recipeRatings)
          .where('userId', isEqualTo: testUserId)
          .get();
      expect(ratings.docs, isEmpty);

      // Menu comments should be hard-deleted (subcollection under shared menus)
      final menuComments = await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('menu1')
          .collection(FirestoreCollections.comments)
          .where('commentedBy', isEqualTo: testUserId)
          .get();
      expect(menuComments.docs, isEmpty);

      // Menu ratings should be hard-deleted (subcollection under shared menus)
      final menuRatings = await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('menu1')
          .collection(FirestoreCollections.ratings)
          .where('ratedBy', isEqualTo: testUserId)
          .get();
      expect(menuRatings.docs, isEmpty);

      // Other user's comment should remain untouched
      final otherComment = await fakeFirestore
          .collection(FirestoreCollections.recipeComments)
          .doc('rc2')
          .get();
      expect(otherComment.exists, true);
      expect(otherComment.data()!['authorId'], otherUserId);
    });

    test('should return true when no comments or ratings exist', () async {
      final result = await operations.deleteCommentsAndRatings(testUserId);
      expect(result, true);
    });
  });

  group('deleteUserReports', () {
    test('should delete all reports submitted by user', () async {
      // Arrange
      await fakeFirestore
          .collection('reports')
          .doc('report1')
          .set({'reporterId': testUserId, 'reason': 'spam'});
      await fakeFirestore
          .collection('reports')
          .doc('report2')
          .set({'reporterId': testUserId, 'reason': 'abuse'});

      // Other user's report should remain
      await fakeFirestore
          .collection('reports')
          .doc('report3')
          .set({'reporterId': otherUserId, 'reason': 'other'});

      // Act
      final result = await operations.deleteUserReports(testUserId);

      // Assert
      expect(result, true);

      final userReports = await fakeFirestore
          .collection('reports')
          .where('reporterId', isEqualTo: testUserId)
          .get();
      expect(userReports.docs, isEmpty);

      final otherReport =
          await fakeFirestore.collection('reports').doc('report3').get();
      expect(otherReport.exists, true);
    });
  });

  group('edge cases', () {
    test('should return true for all methods when no data exists', () async {
      // All methods should handle empty state gracefully
      expect(await operations.removeFriendConnections(testUserId), true);
      expect(await operations.removeFromSharedContent(testUserId), true);
      expect(await operations.deleteCommentsAndRatings(testUserId), true);
      expect(await operations.deleteUserReports(testUserId), true);
    });

    test('should handle batch commit threshold with many documents', () async {
      // Seed more than _batchLimit (450) docs to verify _commitIfNeeded works
      // Using 460 friend request docs to cross the threshold
      for (var i = 0; i < 460; i++) {
        await fakeFirestore
            .collection(FirestoreCollections.socialRequests)
            .doc('req-$i')
            .set({'fromUserId': testUserId, 'toUserId': 'user-$i'});
      }

      // Act - should not throw despite exceeding single batch limit
      final result = await operations.removeFriendConnections(testUserId);

      // Assert
      expect(result, true);

      final remaining = await fakeFirestore
          .collection(FirestoreCollections.socialRequests)
          .where('fromUserId', isEqualTo: testUserId)
          .get();
      expect(remaining.docs, isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/account/account_deletion/social_deletion_operations.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late SocialDeletionOperations operations;

  const testUserId = 'deleted-user';
  const otherUserId = 'other-user';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    operations = SocialDeletionOperations(fakeFirestore);
  });

  group('removeFriendConnections', () {
    test('should delete friends, friendCategories, friend requests and group invitations for user', () async {
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

      // Seed friend requests in both directions
      await fakeFirestore
          .collection(FirestoreCollections.friendRequests)
          .doc('req-outgoing')
          .set({'fromUserId': testUserId, 'toUserId': otherUserId});
      await fakeFirestore
          .collection(FirestoreCollections.friendRequests)
          .doc('req-incoming')
          .set({'fromUserId': otherUserId, 'toUserId': testUserId});

      // Seed group invitations in both directions
      await fakeFirestore
          .collection(FirestoreCollections.groupInvitations)
          .doc('inv-outgoing')
          .set({'fromUserId': testUserId, 'toUserId': otherUserId});
      await fakeFirestore
          .collection(FirestoreCollections.groupInvitations)
          .doc('inv-incoming')
          .set({'fromUserId': otherUserId, 'toUserId': testUserId});

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

      final friendRequests = await fakeFirestore
          .collection(FirestoreCollections.friendRequests)
          .get();
      expect(friendRequests.docs, isEmpty);

      final groupInvitations = await fakeFirestore
          .collection(FirestoreCollections.groupInvitations)
          .get();
      expect(groupInvitations.docs, isEmpty);
    });

    test('should return true when no friend data exists', () async {
      final result = await operations.removeFriendConnections(testUserId);
      expect(result, true);
    });
  });

  group('removeFromSharedContent', () {
    test('should delete membership docs from members subcollection via collectionGroup', () async {
      // Arrange
      await fakeFirestore
          .collection(FirestoreCollections.sharedRecipes)
          .doc('recipe1')
          .collection(FirestoreCollections.members)
          .doc('member1')
          .set({'userId': testUserId, 'role': 'viewer'});

      // Keep another user's membership intact
      await fakeFirestore
          .collection(FirestoreCollections.sharedRecipes)
          .doc('recipe1')
          .collection(FirestoreCollections.members)
          .doc('member2')
          .set({'userId': otherUserId, 'role': 'editor'});

      // Act
      final result = await operations.removeFromSharedContent(testUserId);

      // Assert
      expect(result, true);

      final remainingMembers = await fakeFirestore
          .collection(FirestoreCollections.sharedRecipes)
          .doc('recipe1')
          .collection(FirestoreCollections.members)
          .get();
      expect(remainingMembers.docs.length, 1);
      expect(remainingMembers.docs.first.data()['userId'], otherUserId);
    });

    test('should delete views, engagements, and dismissals subcollection docs for user', () async {
      // Arrange
      await fakeFirestore
          .collection(FirestoreCollections.sharedRecipes)
          .doc('recipe1')
          .collection('views')
          .doc('view1')
          .set({'userId': testUserId, 'timestamp': Timestamp.now()});

      await fakeFirestore
          .collection(FirestoreCollections.sharedRecipes)
          .doc('recipe1')
          .collection('engagements')
          .doc('eng1')
          .set({'userId': testUserId});

      await fakeFirestore
          .collection(FirestoreCollections.sharedRecipes)
          .doc('recipe1')
          .collection('dismissals')
          .doc('dis1')
          .set({'userId': testUserId});

      // Act
      final result = await operations.removeFromSharedContent(testUserId);

      // Assert
      expect(result, true);

      final views = await fakeFirestore
          .collection(FirestoreCollections.sharedRecipes)
          .doc('recipe1')
          .collection('views')
          .get();
      expect(views.docs, isEmpty);

      final engagements = await fakeFirestore
          .collection(FirestoreCollections.sharedRecipes)
          .doc('recipe1')
          .collection('engagements')
          .get();
      expect(engagements.docs, isEmpty);

      final dismissals = await fakeFirestore
          .collection(FirestoreCollections.sharedRecipes)
          .doc('recipe1')
          .collection('dismissals')
          .get();
      expect(dismissals.docs, isEmpty);
    });

    test('should remove user from legacy sharedWith array without affecting other users', () async {
      // Arrange
      await fakeFirestore
          .collection(FirestoreCollections.sharedRecipes)
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
          .collection(FirestoreCollections.sharedRecipes)
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
          .collection(FirestoreCollections.sharedRecipes)
          .doc('recipe3')
          .set({'ownerId': testUserId, 'title': 'My shared recipe'});

      // Keep other user's recipe
      await fakeFirestore
          .collection(FirestoreCollections.sharedRecipes)
          .doc('recipe4')
          .set({'ownerId': otherUserId, 'title': 'Other recipe'});

      // Act
      final result = await operations.removeFromSharedContent(testUserId);

      // Assert
      expect(result, true);

      final owned = await fakeFirestore
          .collection(FirestoreCollections.sharedRecipes)
          .doc('recipe3')
          .get();
      expect(owned.exists, false);

      final otherRecipe = await fakeFirestore
          .collection(FirestoreCollections.sharedRecipes)
          .doc('recipe4')
          .get();
      expect(otherRecipe.exists, true);
    });
  });

  group('deleteCommentsAndRatings', () {
    test('should anonymize recipe comments and delete ratings/menu data with correct field names', () async {
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
          .collection(FirestoreCollections.menuComments)
          .doc('mc1')
          .set({'commentedBy': testUserId, 'text': 'Nice menu'});
      await fakeFirestore
          .collection(FirestoreCollections.menuRatings)
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
      expect(anonymized.data()!['text'], '[Borttaget]');

      // Recipe ratings should be hard-deleted
      final ratings = await fakeFirestore
          .collection(FirestoreCollections.recipeRatings)
          .where('userId', isEqualTo: testUserId)
          .get();
      expect(ratings.docs, isEmpty);

      // Menu comments should be hard-deleted
      final menuComments = await fakeFirestore
          .collection(FirestoreCollections.menuComments)
          .where('commentedBy', isEqualTo: testUserId)
          .get();
      expect(menuComments.docs, isEmpty);

      // Menu ratings should be hard-deleted
      final menuRatings = await fakeFirestore
          .collection(FirestoreCollections.menuRatings)
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

  group('deleteSharedMenus', () {
    test('should remove user from sharedWith and delete owned menus', () async {
      // Arrange - menu shared with user
      await fakeFirestore
          .collection(FirestoreCollections.sharedMenus)
          .doc('menu1')
          .set({
        'sharedWith': [testUserId, otherUserId],
        'ownerId': 'someone-else',
      });

      // Menu owned by user
      await fakeFirestore
          .collection(FirestoreCollections.sharedMenus)
          .doc('menu2')
          .set({'ownerId': testUserId, 'sharedWith': []});

      // Act
      final result = await operations.deleteSharedMenus(testUserId);

      // Assert
      expect(result, true);

      final menu1 = await fakeFirestore
          .collection(FirestoreCollections.sharedMenus)
          .doc('menu1')
          .get();
      expect(menu1.exists, true);
      final sharedWith = List<String>.from(menu1.data()!['sharedWith']);
      expect(sharedWith, isNot(contains(testUserId)));
      expect(sharedWith, contains(otherUserId));

      final menu2 = await fakeFirestore
          .collection(FirestoreCollections.sharedMenus)
          .doc('menu2')
          .get();
      expect(menu2.exists, false);
    });
  });

  group('deleteSharedShoppingLists', () {
    test('should remove user from sharedWith and delete owned lists', () async {
      // Arrange
      await fakeFirestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc('list1')
          .set({
        'sharedWith': [testUserId, otherUserId],
        'ownerId': 'someone-else',
      });

      await fakeFirestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc('list2')
          .set({'ownerId': testUserId, 'sharedWith': []});

      // Act
      final result = await operations.deleteSharedShoppingLists(testUserId);

      // Assert
      expect(result, true);

      final list1 = await fakeFirestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc('list1')
          .get();
      expect(list1.exists, true);
      final sharedWith = List<String>.from(list1.data()!['sharedWith']);
      expect(sharedWith, isNot(contains(testUserId)));
      expect(sharedWith, contains(otherUserId));

      final list2 = await fakeFirestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc('list2')
          .get();
      expect(list2.exists, false);
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

      final otherReport = await fakeFirestore
          .collection('reports')
          .doc('report3')
          .get();
      expect(otherReport.exists, true);
    });
  });

  group('edge cases', () {
    test('should return true for all methods when no data exists', () async {
      // All methods should handle empty state gracefully
      expect(await operations.removeFriendConnections(testUserId), true);
      expect(await operations.removeFromSharedContent(testUserId), true);
      expect(await operations.deleteCommentsAndRatings(testUserId), true);
      expect(await operations.deleteSharedMenus(testUserId), true);
      expect(await operations.deleteSharedShoppingLists(testUserId), true);
      expect(await operations.deleteUserReports(testUserId), true);
    });

    test('should handle batch commit threshold with many documents', () async {
      // Seed more than _batchLimit (450) docs to verify _commitIfNeeded works
      // Using 460 friend request docs to cross the threshold
      for (var i = 0; i < 460; i++) {
        await fakeFirestore
            .collection(FirestoreCollections.friendRequests)
            .doc('req-$i')
            .set({'fromUserId': testUserId, 'toUserId': 'user-$i'});
      }

      // Act - should not throw despite exceeding single batch limit
      final result = await operations.removeFriendConnections(testUserId);

      // Assert
      expect(result, true);

      final remaining = await fakeFirestore
          .collection(FirestoreCollections.friendRequests)
          .where('fromUserId', isEqualTo: testUserId)
          .get();
      expect(remaining.docs, isEmpty);
    });
  });
}

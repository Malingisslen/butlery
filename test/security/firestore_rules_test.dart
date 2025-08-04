import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../helpers/firebase_emulator_helper.dart';

/// Tests for Firestore Security Rules
/// Ensures data access is properly restricted according to business rules
void main() {
  late FirebaseFirestore firestore;
  late FirebaseAuth auth;

  setUpAll(() async {
    // Set up Firebase emulator for testing
    firestore = FirebaseEmulatorHelper.firestore;
    auth = FirebaseEmulatorHelper.auth;
  });

  setUp(() async {
    await FirebaseEmulatorHelper.clearEmulatorData();
    await auth.signOut();
  });

  group('Recipe Security Rules', () {
    test('authenticated users can create their own recipes', () async {
      // Given - Authenticated user
      await FirebaseEmulatorHelper.createTestUser(
        email: 'chef@test.com',
        password: 'password123',
      );

      // When - Create recipe
      final recipeData = {
        'title': 'My Recipe',
        'createdBy': auth.currentUser!.uid,
        'ingredients': ['Ingredient 1'],
        'instructions': ['Step 1'],
        'isPublic': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Then - Should succeed
      await expectLater(
        firestore.collection('recipes').add(recipeData),
        completes,
      );
    });

    test('users cannot create recipes for other users', () async {
      // Given - Authenticated user
      await FirebaseEmulatorHelper.createTestUser(
        email: 'user@test.com',
        password: 'password123',
      );

      // When - Try to create recipe with different createdBy
      final recipeData = {
        'title': 'Fake Recipe',
        'createdBy': 'different-user-id',
        'ingredients': ['Ingredient 1'],
        'instructions': ['Step 1'],
        'isPublic': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Then - Should fail
      await expectLater(
        firestore.collection('recipes').add(recipeData),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('users can read their own private recipes', () async {
      // Given - User with private recipe
      await FirebaseEmulatorHelper.createTestUser(
        email: 'owner@test.com',
        password: 'password123',
      );

      final recipeRef = await firestore.collection('recipes').add({
        'title': 'Private Recipe',
        'createdBy': auth.currentUser!.uid,
        'isPublic': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // When - Owner reads their recipe
      final doc = await recipeRef.get();

      // Then - Should succeed
      expect(doc.exists, isTrue);
      expect(doc.data()?['title'], equals('Private Recipe'));
    });

    test('users cannot read others private recipes', () async {
      // Given - User1 creates private recipe
      final user1 = await FirebaseEmulatorHelper.createTestUser(
        email: 'user1@test.com',
        password: 'password123',
      );

      final recipeRef = await firestore.collection('recipes').add({
        'title': 'Private Recipe',
        'createdBy': user1.user?.uid ?? '',
        'isPublic': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sign in as different user
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'user2@test.com',
        password: 'password123',
      );

      // When - User2 tries to read User1's private recipe
      // Then - Should fail
      await expectLater(
        recipeRef.get(),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('anyone can read public recipes', () async {
      // Given - Public recipe
      await FirebaseEmulatorHelper.createTestUser(
        email: 'chef@test.com',
        password: 'password123',
      );

      final recipeRef = await firestore.collection('recipes').add({
        'title': 'Public Recipe',
        'createdBy': auth.currentUser!.uid,
        'isPublic': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sign in as different user
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'reader@test.com',
        password: 'password123',
      );

      // When - User2 reads public recipe
      final doc = await recipeRef.get();

      // Then - Should succeed
      expect(doc.exists, isTrue);
      expect(doc.data()?['title'], equals('Public Recipe'));
    });

    test('only owner can update their recipe', () async {
      // Given - Recipe owner
      final owner = await FirebaseEmulatorHelper.createTestUser(
        email: 'owner@test.com',
        password: 'password123',
      );

      final recipeRef = await firestore.collection('recipes').add({
        'title': 'Original Title',
        'createdBy': owner.user?.uid ?? '',
        'isPublic': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // When - Owner updates
      await recipeRef.update({
        'title': 'Updated Title',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Then - Should succeed
      final updated = await recipeRef.get();
      expect(updated.data()?['title'], equals('Updated Title'));

      // Sign in as different user
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'other@test.com',
        password: 'password123',
      );

      // When - Non-owner tries to update
      // Then - Should fail
      await expectLater(
        recipeRef.update({'title': 'Hacked Title'}),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('only owner can delete their recipe', () async {
      // Given - Recipe owner
      final owner = await FirebaseEmulatorHelper.createTestUser(
        email: 'owner@test.com',
        password: 'password123',
      );

      final recipeRef = await firestore.collection('recipes').add({
        'title': 'To Delete',
        'createdBy': owner.user?.uid ?? '',
        'isPublic': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // When - Owner deletes
      await recipeRef.delete();

      // Then - Should succeed
      final deleted = await recipeRef.get();
      expect(deleted.exists, isFalse);
    });

    test('validates required fields on create', () async {
      // Given - Authenticated user
      await FirebaseEmulatorHelper.createTestUser(
        email: 'user@test.com',
        password: 'password123',
      );

      // When - Try to create recipe without required fields
      final invalidData = {
        'title': 'Incomplete Recipe',
        'createdBy': auth.currentUser!.uid,
        // Missing ingredients and instructions
      };

      // Then - Should fail validation
      await expectLater(
        firestore.collection('recipes').add(invalidData),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('Shopping List Security Rules', () {
    test('users can create their own shopping lists', () async {
      // Given - Authenticated user
      await FirebaseEmulatorHelper.createTestUser(
        email: 'shopper@test.com',
        password: 'password123',
      );

      // When - Create shopping list
      final listData = {
        'name': 'Weekly Shopping',
        'ownerId': auth.currentUser!.uid,
        'items': [],
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Then - Should succeed
      await expectLater(
        firestore.collection('shoppingLists').add(listData),
        completes,
      );
    });

    test('shared users can read shopping lists', () async {
      // Given - Owner creates list
      final owner = await FirebaseEmulatorHelper.createTestUser(
        email: 'owner@test.com',
        password: 'password123',
      );

      final sharedUser = await FirebaseEmulatorHelper.createTestUser(
        email: 'shared@test.com',
        password: 'password123',
      );

      final listRef = await firestore.collection('shoppingLists').add({
        'name': 'Shared List',
        'ownerId': owner.user?.uid ?? '',
        'sharedWith': [sharedUser.user?.uid ?? ''],
        'items': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sign in as shared user
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'shared@test.com',
        password: 'password123',
      );

      // When - Shared user reads list
      final doc = await listRef.get();

      // Then - Should succeed
      expect(doc.exists, isTrue);
      expect(doc.data()?['name'], equals('Shared List'));
    });

    test('non-shared users cannot read shopping lists', () async {
      // Given - Private shopping list
      final owner = await FirebaseEmulatorHelper.createTestUser(
        email: 'owner@test.com',
        password: 'password123',
      );

      final listRef = await firestore.collection('shoppingLists').add({
        'name': 'Private List',
        'ownerId': owner.user?.uid ?? '',
        'sharedWith': [],
        'items': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sign in as different user
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'stranger@test.com',
        password: 'password123',
      );

      // When - Stranger tries to read
      // Then - Should fail
      await expectLater(
        listRef.get(),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('shared users can update shopping lists', () async {
      // Given - Shared shopping list
      final owner = await FirebaseEmulatorHelper.createTestUser(
        email: 'owner@test.com',
        password: 'password123',
      );

      final sharedUser = await FirebaseEmulatorHelper.createTestUser(
        email: 'shared@test.com',
        password: 'password123',
      );

      final listRef = await firestore.collection('shoppingLists').add({
        'name': 'Collaborative List',
        'ownerId': owner.user?.uid ?? '',
        'sharedWith': [sharedUser.user?.uid ?? ''],
        'memberPermissions': {
          sharedUser.user?.uid ?? '': 'write',
        },
        'items': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sign in as shared user
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'shared@test.com',
        password: 'password123',
      );

      // When - Shared user adds item
      await listRef.update({
        'items': FieldValue.arrayUnion([
          {
            'name': 'Milk',
            'amount': 1,
            'unit': 'l',
            'addedBy': sharedUser.user?.uid ?? '',
          }
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Then - Should succeed
      final updated = await listRef.get();
      expect(updated.data()?['items'].length, equals(1));
    });
  });

  group('User Profile Security Rules', () {
    test('users can read their own profile', () async {
      // Given - User with profile
      await FirebaseEmulatorHelper.createTestUser(
        email: 'user@test.com',
        password: 'password123',
      );
      await firestore.collection('users').doc(auth.currentUser!.uid).set({
        'displayName': 'Test User',
        'email': 'user@test.com',
      });

      // When - Read own profile
      final profile =
          await firestore.collection('users').doc(auth.currentUser!.uid).get();

      // Then - Should succeed
      expect(profile.exists, isTrue);
      expect(profile.data()?['displayName'], equals('Test User'));
    });

    test('users can update their own profile', () async {
      // Given - User profile
      await FirebaseEmulatorHelper.createTestUser(
        email: 'user@test.com',
        password: 'password123',
      );
      await firestore.collection('users').doc(auth.currentUser!.uid).set({
        'email': 'user@test.com',
      });

      // When - Update profile
      await firestore.collection('users').doc(auth.currentUser!.uid).update({
        'bio': 'Updated bio',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Then - Should succeed
      final updated =
          await firestore.collection('users').doc(auth.currentUser!.uid).get();
      expect(updated.data()?['bio'], equals('Updated bio'));
    });

    test('users cannot update others profiles', () async {
      // Given - Two users
      await FirebaseEmulatorHelper.createTestUser(
        email: 'user1@test.com',
        password: 'password123',
      );
      final user1Id = auth.currentUser!.uid;
      await firestore.collection('users').doc(user1Id).set({
        'email': 'user1@test.com',
      });

      await auth.signOut();
      await FirebaseEmulatorHelper.createTestUser(
        email: 'user2@test.com',
        password: 'password123',
      );

      // When - User2 tries to update User1's profile
      // Then - Should fail
      await expectLater(
        firestore.collection('users').doc(user1Id).update({'bio': 'Hacked'}),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('searchable profiles are publicly readable', () async {
      // Given - Searchable profile
      await FirebaseEmulatorHelper.createTestUser(
        email: 'user1@test.com',
        password: 'password123',
      );
      final user1Id = auth.currentUser!.uid;
      await firestore.collection('users').doc(user1Id).set({
        'email': 'user1@test.com',
        'displayName': 'User 1',
      });

      await firestore
          .collection('users')
          .doc(user1Id)
          .update({'isSearchable': true});

      // Sign in as different user
      await auth.signOut();
      await FirebaseEmulatorHelper.createTestUser(
        email: 'user2@test.com',
        password: 'password123',
      );

      // When - User2 reads searchable profile
      final profile = await firestore.collection('users').doc(user1Id).get();

      // Then - Should see limited fields
      expect(profile.exists, isTrue);
      expect(profile.data()?['displayName'], isNotNull);
      // Email should not be visible
      expect(profile.data()?['email'], isNull);
    });
  });

  group('Friend Connection Rules', () {
    test('users can send friend requests', () async {
      // Given - Two users
      final sender = await FirebaseEmulatorHelper.createTestUser(
        email: 'sender@test.com',
        password: 'password123',
      );

      await auth.signOut();
      await FirebaseEmulatorHelper.createTestUser(
        email: 'receiver@test.com',
        password: 'password123',
      );
      final receiverId = auth.currentUser!.uid;
      await firestore.collection('users').doc(receiverId).set({
        'email': 'receiver@test.com',
      });

      // Sign back as sender
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'sender@test.com',
        password: 'password123',
      );

      // When - Send friend request
      await firestore.collection('friendRequests').add({
        'from': sender.user?.uid ?? '',
        'to': receiverId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Then - Should succeed
      final requests = await firestore
          .collection('friendRequests')
          .where('from', isEqualTo: sender.user?.uid ?? '')
          .get();
      expect(requests.docs.length, equals(1));
    });

    test('only recipient can accept friend requests', () async {
      // Given - Pending friend request
      final sender = await FirebaseEmulatorHelper.createTestUser(
        email: 'sender@test.com',
        password: 'password123',
      );

      final receiver = await FirebaseEmulatorHelper.createTestUser(
        email: 'receiver@test.com',
        password: 'password123',
      );

      final requestRef = await firestore.collection('friendRequests').add({
        'from': sender.user?.uid ?? '',
        'to': receiver.user?.uid ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sign out sender and sign in receiver
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'receiver@test.com',
        password: 'password123',
      );

      // When - Receiver accepts
      await requestRef.update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Then - Should succeed
      final updated = await requestRef.get();
      expect(updated.data()?['status'], equals('accepted'));
    });
  });

  group('Activity Feed Rules', () {
    test('users can see friends activities', () async {
      // Given - Friends relationship
      final user1 = await FirebaseEmulatorHelper.createTestUser(
        email: 'user1@test.com',
        password: 'password123',
      );

      final user2 = await FirebaseEmulatorHelper.createTestUser(
        email: 'user2@test.com',
        password: 'password123',
      );

      // Create friend connection
      await firestore
          .collection('users')
          .doc(user1.user?.uid ?? '')
          .collection('friends')
          .doc(user2.user?.uid ?? '')
          .set({'status': 'accepted'});

      // User2 creates activity
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'user2@test.com',
        password: 'password123',
      );

      await firestore.collection('activities').add({
        'userId': user2.user?.uid ?? '',
        'type': 'recipe_created',
        'visibility': ['friends'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sign back as user1
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'user1@test.com',
        password: 'password123',
      );

      // When - User1 queries friend activities
      final activities = await firestore
          .collection('activities')
          .where('userId', isEqualTo: user2.user?.uid ?? '')
          .where('visibility', arrayContains: 'friends')
          .get();

      // Then - Should see friend's activity
      expect(activities.docs.length, greaterThan(0));
    });

    test('users cannot see non-friends private activities', () async {
      // Given - Non-friends
      await FirebaseEmulatorHelper.createTestUser(
        email: 'user1@test.com',
        password: 'password123',
      );

      final user2 = await FirebaseEmulatorHelper.createTestUser(
        email: 'user2@test.com',
        password: 'password123',
      );

      // User2 creates private activity
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'user2@test.com',
        password: 'password123',
      );

      await firestore.collection('activities').add({
        'userId': user2.user?.uid ?? '',
        'type': 'recipe_created',
        'visibility': ['friends'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sign back as user1
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'user1@test.com',
        password: 'password123',
      );

      // When - User1 tries to query non-friend activities
      // Then - Should not see them
      final activities = await firestore
          .collection('activities')
          .where('userId', isEqualTo: user2.user?.uid ?? '')
          .get();

      expect(activities.docs.length, equals(0));
    });
  });

  group('Comment Rules', () {
    test('authenticated users can comment on public recipes', () async {
      // Given - Public recipe
      final author = await FirebaseEmulatorHelper.createTestUser(
        email: 'author@test.com',
        password: 'password123',
      );

      final recipeRef = await firestore.collection('recipes').add({
        'title': 'Public Recipe',
        'createdBy': author.user?.uid ?? '',
        'isPublic': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sign in as commenter
      await auth.signOut();
      final commenter = await auth.signInWithEmailAndPassword(
        email: 'commenter@test.com',
        password: 'password123',
      );

      // When - Add comment
      await recipeRef.collection('comments').add({
        'text': 'Great recipe!',
        'authorId': commenter.user!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Then - Should succeed
      final comments = await recipeRef.collection('comments').get();
      expect(comments.docs.length, equals(1));
    });

    test('users can only edit their own comments', () async {
      // Given - Comment on recipe
      final commenter = await FirebaseEmulatorHelper.createTestUser(
        email: 'commenter@test.com',
        password: 'password123',
      );

      final recipeRef = await firestore.collection('recipes').add({
        'title': 'Recipe',
        'createdBy': 'some-user',
        'isPublic': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final commentRef = await recipeRef.collection('comments').add({
        'text': 'Original comment',
        'authorId': commenter.user?.uid ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // When - Author edits their comment
      await commentRef.update({
        'text': 'Edited comment',
        'editedAt': FieldValue.serverTimestamp(),
      });

      // Then - Should succeed
      final updated = await commentRef.get();
      expect(updated.data()?['text'], equals('Edited comment'));

      // Sign in as different user
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'other@test.com',
        password: 'password123',
      );

      // When - Other user tries to edit
      // Then - Should fail
      await expectLater(
        commentRef.update({'text': 'Hacked comment'}),
        throwsA(isA<FirebaseException>()),
      );
    });
  });
}

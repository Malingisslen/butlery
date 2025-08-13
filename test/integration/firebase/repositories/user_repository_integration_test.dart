/// Integration tests for Firebase User Repository
/// 
/// Tests actual Firebase operations with emulator including FieldValue operations,
/// server timestamps, batch operations, and complex queries.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/firebase/firebase_user_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import '../setup/firebase_test_setup.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/user_profile_factory.dart';

void main() {
  group('Firebase User Repository Integration', () {
    late FirebaseFirestore firestore;
    late FirebaseUserRepository repository;
    late AuthRepository mockAuthRepository;
    late User testUser;
    
    setUpAll(() async {
      await FirebaseTestSetup.initialize();
      firestore = FirebaseFirestore.instance;
    });
    
    setUp(() async {
      await FirebaseTestSetup.clearEmulatorData();
      
      // Create test user
      testUser = await FirebaseTestSetup.createTestUser(
        email: 'test@example.com',
        password: 'test123',
      );
      
      // Setup mock auth repository
      mockAuthRepository = MockFactory.createAuthRepository(
        isAuthenticated: true,
        userId: testUser.uid,
        user: testUser,
      );
      
      // Create repository with Firebase emulator
      repository = FirebaseUserRepository(
        firestore: firestore,
        authRepository: mockAuthRepository,
      );
    });
    
    tearDown(() async {
      await FirebaseAuth.instance.signOut();
    });
    
    group('Profile with FieldValue.serverTimestamp', () {
      test('should save profile with server timestamps', () async {
        // Arrange
        final profile = UserProfileFactory.build(
          uid: testUser.uid,
          displayName: 'Test User',
          email: 'test@example.com',
        );
        
        // Act
        await repository.saveProfile(profile);
        
        // Assert
        final doc = await firestore
            .collection('public_profiles')
            .doc(testUser.uid)
            .get();
        
        expect(doc.exists, isTrue);
        expect(doc.data()?['displayName'], equals('Test User'));
        expect(doc.data()?['updatedAt'], isA<Timestamp>());
        
        // Verify timestamp is close to current time
        final timestamp = doc.data()?['updatedAt'] as Timestamp;
        expect(
          timestamp.toDate().difference(DateTime.now()).inMinutes.abs(),
          lessThan(1),
        );
      });
      
      test('should update online status with lastActiveAt timestamp', () async {
        // Arrange - Create profile first
        final profile = UserProfileFactory.build(
          uid: testUser.uid,
          displayName: 'Test User',
        );
        await repository.saveProfile(profile);
        
        // Act
        await repository.updateOnlineStatus(testUser.uid, true);
        
        // Assert
        final doc = await firestore
            .collection('public_profiles')
            .doc(testUser.uid)
            .get();
        
        expect(doc.data()?['isOnline'], isTrue);
        expect(doc.data()?['lastActiveAt'], isA<Timestamp>());
        
        // Verify lastActiveAt is recent
        final lastActive = (doc.data()?['lastActiveAt'] as Timestamp).toDate();
        expect(
          lastActive.difference(DateTime.now()).inMinutes.abs(),
          lessThan(1),
        );
      });
      
      test('should update FCM token with timestamp', () async {
        // Arrange - Create profile first
        final profile = UserProfileFactory.build(uid: testUser.uid);
        await repository.saveProfile(profile);
        
        // Act
        await repository.updateFCMToken(testUser.uid, 'fcm-token-123');
        
        // Assert
        final doc = await firestore
            .collection('public_profiles')
            .doc(testUser.uid)
            .get();
        
        expect(doc.data()?['fcmToken'], equals('fcm-token-123'));
        expect(doc.data()?['fcmTokenUpdatedAt'], isA<Timestamp>());
      });
    });
    
    group('Batch Operations', () {
      test('should fetch multiple profiles in batches', () async {
        // Arrange - Create 25 profiles (more than typical batch size)
        final userIds = <String>[];
        for (int i = 0; i < 25; i++) {
          final uid = 'user-$i';
          userIds.add(uid);
          
          await firestore.collection('public_profiles').doc(uid).set({
            'uid': uid,
            'displayName': 'User $i',
            'email': 'user$i@example.com',
            'displayNameLower': 'user $i',
            'isSearchable': true,
            'joinedAt': FieldValue.serverTimestamp(),
            'lastActiveAt': FieldValue.serverTimestamp(),
          });
        }
        
        // Act
        final profiles = await repository.fetchProfiles(userIds);
        
        // Assert
        expect(profiles, hasLength(25));
        for (int i = 0; i < 25; i++) {
          expect(profiles.any((p) => p.uid == 'user-$i'), isTrue);
        }
      });
      
      test('should handle empty list in fetchProfiles', () async {
        // Act
        final profiles = await repository.fetchProfiles([]);
        
        // Assert
        expect(profiles, isEmpty);
      });
    });
    
    group('Search with Complex Queries', () {
      test('should search profiles with case-insensitive matching', () async {
        // Arrange - Create searchable profiles
        final profiles = [
          {'uid': 'user-1', 'displayName': 'John Doe', 'displayNameLower': 'john doe'},
          {'uid': 'user-2', 'displayName': 'Jane Smith', 'displayNameLower': 'jane smith'},
          {'uid': 'user-3', 'displayName': 'Johnny Walker', 'displayNameLower': 'johnny walker'},
          {'uid': testUser.uid, 'displayName': 'John Test', 'displayNameLower': 'john test'}, // Current user
        ];
        
        for (final profile in profiles) {
          await firestore.collection('public_profiles').doc(profile['uid'] as String).set({
            ...profile,
            'isSearchable': true,
            'email': '${profile['uid']}@example.com',
            'joinedAt': FieldValue.serverTimestamp(),
            'lastActiveAt': FieldValue.serverTimestamp(),
          });
        }
        
        // Act - Search for "john"
        final results = await repository.searchProfiles('john');
        
        // Assert - Should find John Doe and Johnny Walker, but not current user
        expect(results.length, greaterThanOrEqualTo(2));
        expect(results.any((p) => p.displayName == 'John Doe'), isTrue);
        expect(results.any((p) => p.displayName == 'Johnny Walker'), isTrue);
        expect(results.any((p) => p.uid == testUser.uid), isFalse); // Excludes current user
      });
      
      test('should search by email when allowed', () async {
        // Arrange
        await firestore.collection('public_profiles').doc('email-user').set({
          'uid': 'email-user',
          'displayName': 'Email User',
          'displayNameLower': 'email user',
          'email': 'unique@example.com',
          'allowEmailSearch': true,
          'isSearchable': true,
          'joinedAt': FieldValue.serverTimestamp(),
        });
        
        // Act
        final results = await repository.searchProfiles('unique@example.com');
        
        // Assert
        expect(results, hasLength(1));
        expect(results.first.email, equals('unique@example.com'));
      });
      
      test('should respect isSearchable flag', () async {
        // Arrange
        await firestore.collection('public_profiles').doc('hidden-user').set({
          'uid': 'hidden-user',
          'displayName': 'Hidden User',
          'displayNameLower': 'hidden user',
          'isSearchable': false, // Not searchable
          'joinedAt': FieldValue.serverTimestamp(),
        });
        
        await firestore.collection('public_profiles').doc('visible-user').set({
          'uid': 'visible-user',
          'displayName': 'Hidden Visible', // Contains "hidden"
          'displayNameLower': 'hidden visible',
          'isSearchable': true,
          'joinedAt': FieldValue.serverTimestamp(),
        });
        
        // Act
        final results = await repository.searchProfiles('hidden');
        
        // Assert - Should only find the searchable one
        expect(results, hasLength(1));
        expect(results.first.uid, equals('visible-user'));
      });
    });
    
    group('Display Name Availability', () {
      test('should check display name availability with case insensitivity', () async {
        // Arrange
        await firestore.collection('public_profiles').doc('existing-user').set({
          'uid': 'existing-user',
          'displayName': 'John Doe',
          'displayNameLower': 'john doe',
          'joinedAt': FieldValue.serverTimestamp(),
        });
        
        // Act
        final taken1 = await repository.isDisplayNameAvailable('John Doe');
        final taken2 = await repository.isDisplayNameAvailable('john doe');
        final taken3 = await repository.isDisplayNameAvailable('JOHN DOE');
        final available = await repository.isDisplayNameAvailable('Jane Smith');
        
        // Assert
        expect(taken1, isFalse);
        expect(taken2, isFalse);
        expect(taken3, isFalse);
        expect(available, isTrue);
      });
      
      test('should allow current user to keep their display name', () async {
        // Arrange
        await firestore.collection('public_profiles').doc(testUser.uid).set({
          'uid': testUser.uid,
          'displayName': 'Test User',
          'displayNameLower': 'test user',
          'joinedAt': FieldValue.serverTimestamp(),
        });
        
        // Act
        final available = await repository.isDisplayNameAvailable('Test User');
        
        // Assert
        expect(available, isTrue); // True because it's their own name
      });
    });
    
    group('Base User Document', () {
      test('should ensure base user document with merge', () async {
        // Arrange - Create partial document
        await firestore.collection('users').doc(testUser.uid).set({
          'someExistingField': 'value',
        });
        
        // Act
        await repository.ensureBaseUserDocument(testUser.uid);
        
        // Assert
        final doc = await firestore
            .collection('users')
            .doc(testUser.uid)
            .get();
        
        expect(doc.exists, isTrue);
        expect(doc.data()?['uid'], equals(testUser.uid));
        expect(doc.data()?['initialized'], isTrue);
        expect(doc.data()?['createdAt'], isA<Timestamp>());
        expect(doc.data()?['someExistingField'], equals('value')); // Preserved
      });
    });
    
    group('Profile Statistics Updates', () {
      test('should increment statistics atomically', () async {
        // Arrange
        await firestore.collection('public_profiles').doc(testUser.uid).set({
          'uid': testUser.uid,
          'displayName': 'Test User',
          'friendsCount': 5,
          'publicRecipeCount': 10,
          'joinedAt': FieldValue.serverTimestamp(),
        });
        
        // Act
        await repository.updateProfileStats(
          testUser.uid,
          friendsCount: 8,
          publicRecipeCount: 15,
        );
        
        // Assert
        final doc = await firestore
            .collection('public_profiles')
            .doc(testUser.uid)
            .get();
        
        expect(doc.data()?['friendsCount'], equals(8));
        expect(doc.data()?['publicRecipeCount'], equals(15));
        expect(doc.data()?['updatedAt'], isA<Timestamp>());
      });
    });
    
    group('Real-time Updates', () {
      test('should receive real-time profile updates', () async {
        // Arrange
        final profileRef = firestore
            .collection('public_profiles')
            .doc(testUser.uid);
        
        // Create initial profile
        await profileRef.set({
          'uid': testUser.uid,
          'displayName': 'Initial Name',
          'isOnline': false,
          'joinedAt': FieldValue.serverTimestamp(),
        });
        
        // Setup listener
        final updates = <Map<String, dynamic>?>[];
        final subscription = profileRef.snapshots().listen((snapshot) {
          updates.add(snapshot.data());
        });
        
        // Wait for initial state
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Act - Update profile
        await repository.updateOnlineStatus(testUser.uid, true);
        await Future.delayed(const Duration(milliseconds: 100));
        
        await profileRef.update({'displayName': 'Updated Name'});
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Assert
        expect(updates.length, greaterThanOrEqualTo(3));
        expect(updates.last?['displayName'], equals('Updated Name'));
        expect(updates.last?['isOnline'], isTrue);
        
        // Cleanup
        await subscription.cancel();
      });
    });
    
    group('Complex Profile Operations', () {
      test('should handle concurrent profile updates', () async {
        // Arrange
        await firestore.collection('public_profiles').doc(testUser.uid).set({
          'uid': testUser.uid,
          'displayName': 'Test User',
          'friendsCount': 0,
          'joinedAt': FieldValue.serverTimestamp(),
        });
        
        // Act - Multiple concurrent updates
        final futures = <Future>[];
        for (int i = 0; i < 5; i++) {
          futures.add(
            firestore.collection('public_profiles').doc(testUser.uid).update({
              'friendsCount': FieldValue.increment(1),
            }),
          );
        }
        await Future.wait(futures);
        
        // Assert
        final doc = await firestore
            .collection('public_profiles')
            .doc(testUser.uid)
            .get();
        
        expect(doc.data()?['friendsCount'], equals(5));
      });
      
      test('should clear FCM token with FieldValue.delete', () async {
        // Arrange
        await firestore.collection('public_profiles').doc(testUser.uid).set({
          'uid': testUser.uid,
          'displayName': 'Test User',
          'fcmToken': 'old-token',
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'joinedAt': FieldValue.serverTimestamp(),
        });
        
        // Act
        await repository.clearFCMToken(testUser.uid);
        
        // Assert
        final doc = await firestore
            .collection('public_profiles')
            .doc(testUser.uid)
            .get();
        
        expect(doc.data()?['fcmToken'], isNull);
        expect(doc.data()?['fcmTokenUpdatedAt'], isNull);
      });
    });
  });
}
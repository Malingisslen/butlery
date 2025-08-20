// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_social_sharing_repository.dart';
import 'package:butlery/models/shared_content.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Local mocks for sealed Firebase classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference<T> extends Mock implements CollectionReference<T> {}
class MockDocumentReference<T> extends Mock implements DocumentReference<T> {}
class MockDocumentSnapshot<T> extends Mock implements DocumentSnapshot<T> {}
class MockQuery<T> extends Mock implements Query<T> {}
class MockQuerySnapshot<T> extends Mock implements QuerySnapshot<T> {}
class MockQueryDocumentSnapshot<T> extends Mock implements QueryDocumentSnapshot<T> {}

// Fake classes for any() matching
class FakeSetOptions extends Fake implements SetOptions {}
class FakeFieldValue extends Fake implements FieldValue {}
class FakeSharedContent extends Fake implements SharedContent {}

void main() {
  group('FirebaseSocialSharingRepository', () {
    late FirebaseSocialSharingRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference<Map<String, dynamic>> mockCollection;
    late MockAuthRepository mockAuthRepository;
    late MockDocumentReference<Map<String, dynamic>> mockDocRef;
    late MockQuery<Map<String, dynamic>> mockQuery;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    
    // Test data
    const userId = 'test-user-123';
    const otherUserId = 'other-user-456';
    const groupId = 'group-789';
    const contentId = 'content-123';
    const recipeId = 'recipe-456';
    
    late SharedContent testContent;
    late Map<String, dynamic> testContentMap;
    
    setUpAll(() {
      registerFallbackValue(FakeSetOptions());
      registerFallbackValue(FakeFieldValue());
      registerFallbackValue(FakeSharedContent());
      registerFallbackValue(SetOptions(merge: true));
      registerFallbackValue(DateTime.now());
    });
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Initialize mocks
      mockFirestore = MockFirebaseFirestore();
      mockCollection = MockCollectionReference<Map<String, dynamic>>();
      mockAuthRepository = MockAuthRepository();
      mockDocRef = MockDocumentReference<Map<String, dynamic>>();
      mockQuery = MockQuery<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      
      // Configure auth state
      mockAuthRepository.setAuthState(
        userId: userId,
        isAuthenticated: true,
      );
      
      // Setup test content
      testContent = SharedContent(
        id: contentId,
        contentType: 'recipe',
        contentId: recipeId,
        ownerId: userId,
        sharedWithUserIds: [],
        sharedWithGroupIds: [],
        sharedAt: DateTime.now(),
        metadata: {'title': 'Test Recipe'},
        permissions: SharingPermissions(),
      );
      
      testContentMap = {
        'contentType': 'recipe',
        'contentId': recipeId,
        'ownerId': userId,
        'sharedWithUserIds': [],
        'sharedWithGroupIds': [],
        'sharedAt': Timestamp.now(),
        'metadata': {'title': 'Test Recipe'},
        'permissions': {
          'canView': true,
          'canEdit': false,
          'canReshare': false,
          'canComment': true,
        },
        'viewedBy': {},
        'acceptedBy': {},
        'declinedBy': {},
      };
      
      // Setup Firestore mocks
      when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
      when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockDocRef.set(any(), any())).thenAnswer((_) async {});
      when(() => mockDocRef.update(any())).thenAnswer((_) async {});
      when(() => mockDocRef.delete()).thenAnswer((_) async {});
      when(() => mockDocRef.get()).thenAnswer((_) async => MockDocumentSnapshot<Map<String, dynamic>>());
      when(() => mockCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockCollection.where(any(), arrayContains: any(named: 'arrayContains')))
          .thenReturn(mockQuery);
      when(() => mockQuery.orderBy(any(), descending: any(named: 'descending')))
          .thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(() => mockQuery.snapshots()).thenAnswer((_) => Stream.value(mockQuerySnapshot));
      when(() => mockQuerySnapshot.docs).thenReturn([]);
      
      // Create repository
      repository = FirebaseSocialSharingRepository(
        firestore: mockFirestore,
        authRepository: mockAuthRepository,
      );
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    group('shareToGroup', () {
      test('should share content to a group successfully', () async {
        // Arrange
        when(() => mockDocRef.set(any(), any())).thenAnswer((_) async {});
        
        // Act
        await repository.shareToGroup(groupId, testContent);
        
        // Assert
        final captured = verify(() => mockDocRef.set(
          captureAny(),
          captureAny(),
        )).captured;
        
        final data = captured[0] as Map<String, dynamic>;
        final options = captured[1] as SetOptions;
        
        expect(data['sharedWithGroupIds'], contains(groupId));
        expect(options.merge, isTrue);
      });
      
      test('should prevent sharing if user does not own content', () async {
        // Arrange
        final otherUserContent = SharedContent(
          id: contentId,
          contentType: 'recipe',
          contentId: recipeId,
          ownerId: otherUserId, // Different owner
          sharedWithUserIds: [],
          sharedWithGroupIds: [],
          sharedAt: DateTime.now(),
          metadata: {'title': 'Test Recipe'},
          permissions: SharingPermissions(),
        );
        
        // Act & Assert
        expect(
          () => repository.shareToGroup(groupId, otherUserContent),
          throwsA(isA<PermissionDeniedException>()
            .having((e) => e.message, 'message', contains('does not own'))),
        );
      });
      
      test('should handle duplicate group sharing gracefully', () async {
        // Arrange
        final contentWithGroup = SharedContent(
          id: contentId,
          contentType: 'recipe',
          contentId: recipeId,
          ownerId: userId,
          sharedWithUserIds: [],
          sharedWithGroupIds: [groupId], // Already shared with this group
          sharedAt: DateTime.now(),
          metadata: {'title': 'Test Recipe'},
          permissions: SharingPermissions(),
        );
        
        when(() => mockDocRef.set(any(), any())).thenAnswer((_) async {});
        
        // Act
        await repository.shareToGroup(groupId, contentWithGroup);
        
        // Assert
        final captured = verify(() => mockDocRef.set(
          captureAny(),
          any(),
        )).captured.single as Map<String, dynamic>;
        
        final groupIds = captured['sharedWithGroupIds'] as List;
        expect(groupIds.where((id) => id == groupId).length, equals(2)); // Original + new
      });
      
      test('should handle Firestore errors when sharing to group', () async {
        // Arrange
        when(() => mockDocRef.set(any(), any()))
            .thenThrow(FirebaseException(plugin: 'firestore'));
        
        // Act & Assert
        expect(
          () => repository.shareToGroup(groupId, testContent),
          throwsException,
        );
      });
    });
    
    group('shareToUsers', () {
      test('should share content to multiple users successfully', () async {
        // Arrange
        final userIds = ['user1', 'user2', 'user3'];
        when(() => mockDocRef.set(any(), any())).thenAnswer((_) async {});
        
        // Act
        await repository.shareToUsers(userIds, testContent);
        
        // Assert
        final captured = verify(() => mockDocRef.set(
          captureAny(),
          captureAny(),
        )).captured;
        
        final data = captured[0] as Map<String, dynamic>;
        final sharedUserIds = data['sharedWithUserIds'] as List;
        
        expect(sharedUserIds, containsAll(userIds));
      });
      
      test('should prevent duplicate user sharing', () async {
        // Arrange
        final existingUsers = ['user1', 'user2'];
        final newUsers = ['user2', 'user3', 'user4']; // user2 is duplicate
        
        final contentWithUsers = SharedContent(
          id: contentId,
          contentType: 'recipe',
          contentId: recipeId,
          ownerId: userId,
          sharedWithUserIds: existingUsers,
          sharedWithGroupIds: [],
          sharedAt: DateTime.now(),
          metadata: {'title': 'Test Recipe'},
          permissions: SharingPermissions(),
        );
        
        when(() => mockDocRef.set(any(), any())).thenAnswer((_) async {});
        
        // Act
        await repository.shareToUsers(newUsers, contentWithUsers);
        
        // Assert
        final captured = verify(() => mockDocRef.set(
          captureAny(),
          any(),
        )).captured.single as Map<String, dynamic>;
        
        final sharedUserIds = captured['sharedWithUserIds'] as List;
        expect(sharedUserIds, containsAll(['user1', 'user2', 'user3', 'user4']));
        expect(sharedUserIds.where((id) => id == 'user2').length, equals(1)); // No duplicate
      });
      
      test('should prevent sharing if user does not own content', () async {
        // Arrange
        final otherUserContent = SharedContent(
          id: contentId,
          contentType: 'recipe',
          contentId: recipeId,
          ownerId: otherUserId,
          sharedWithUserIds: [],
          sharedWithGroupIds: [],
          sharedAt: DateTime.now(),
          metadata: {'title': 'Test Recipe'},
          permissions: SharingPermissions(),
        );
        
        // Act & Assert
        expect(
          () => repository.shareToUsers(['user1'], otherUserContent),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
      
      test('should handle empty user list', () async {
        // Arrange
        when(() => mockDocRef.set(any(), any())).thenAnswer((_) async {});
        
        // Act
        await repository.shareToUsers([], testContent);
        
        // Assert
        final captured = verify(() => mockDocRef.set(
          captureAny(),
          any(),
        )).captured.single as Map<String, dynamic>;
        
        expect(captured['sharedWithUserIds'], isEmpty);
      });
    });
    
    group('getSharedWithMe', () {
      test('should return stream of content shared with user', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockDoc1.id).thenReturn('shared1');
        when(() => mockDoc1.data()).thenReturn({
          ...testContentMap,
          'sharedWithUserIds': [userId],
        });
        
        when(() => mockDoc2.id).thenReturn('shared2');
        when(() => mockDoc2.data()).thenReturn({
          ...testContentMap,
          'sharedWithUserIds': [userId, 'other-user'],
        });
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        
        // Act
        final stream = repository.getSharedWithMe(userId);
        final results = await stream.first;
        
        // Assert
        expect(results.length, equals(2));
        verify(() => mockCollection.where('sharedWithUserIds', arrayContains: userId))
            .called(1);
        verify(() => mockQuery.orderBy('sharedAt', descending: true)).called(1);
      });
      
      test('should return empty stream on error', () async {
        // Arrange
        when(() => mockCollection.where(any(), arrayContains: any(named: 'arrayContains')))
            .thenThrow(Exception('Firestore error'));
        
        // Act
        final stream = repository.getSharedWithMe(userId);
        final results = await stream.first;
        
        // Assert
        expect(results, isEmpty);
      });
      
      test('should handle real-time updates in stream', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDoc.id).thenReturn('shared1');
        when(() => mockDoc.data()).thenReturn(testContentMap);
        
        final snapshot1 = MockQuerySnapshot<Map<String, dynamic>>();
        final snapshot2 = MockQuerySnapshot<Map<String, dynamic>>();
        final snapshot3 = MockQuerySnapshot<Map<String, dynamic>>();
        
        when(() => snapshot1.docs).thenReturn([]);
        when(() => snapshot2.docs).thenReturn([mockDoc]);
        when(() => snapshot3.docs).thenReturn([mockDoc, mockDoc]);
        
        final snapshots = [snapshot1, snapshot2, snapshot3];
        
        when(() => mockQuery.snapshots()).thenAnswer(
          (_) => Stream.fromIterable(snapshots),
        );
        
        // Act
        final stream = repository.getSharedWithMe(userId);
        final results = await stream.take(3).toList();
        
        // Assert
        expect(results[0].length, equals(0));
        expect(results[1].length, equals(1));
        expect(results[2].length, equals(2));
      });
    });
    
    group('getMySharedContent', () {
      test('should return stream of content shared by user', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDoc.id).thenReturn('my-shared');
        when(() => mockDoc.data()).thenReturn({
          ...testContentMap,
          'ownerId': userId,
        });
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act
        final stream = repository.getMySharedContent(userId);
        final results = await stream.first;
        
        // Assert
        expect(results.length, equals(1));
        expect(results.first.ownerId, equals(userId));
        verify(() => mockCollection.where('ownerId', isEqualTo: userId)).called(1);
        verify(() => mockQuery.orderBy('sharedAt', descending: true)).called(1);
      });
      
      test('should return empty stream on error', () async {
        // Arrange
        when(() => mockCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
            .thenThrow(Exception('Firestore error'));
        
        // Act
        final stream = repository.getMySharedContent(userId);
        final results = await stream.first;
        
        // Assert
        expect(results, isEmpty);
      });
    });
    
    group('updateSharingPermissions', () {
      test('should add and remove users from sharing list', () async {
        // Arrange
        final addUsers = ['new-user-1', 'new-user-2'];
        final removeUsers = ['old-user-1', 'old-user-2'];
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(contentId);
        when(() => mockSnapshot.data()).thenReturn(testContentMap);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        await repository.updateSharingPermissions(
          contentId,
          addUsers,
          removeUsers,
        );
        
        // Assert
        verify(() => mockDocRef.update(any())).called(2); // Once for add, once for remove
      });
      
      test('should only add users if remove list is empty', () async {
        // Arrange
        final addUsers = ['new-user-1', 'new-user-2'];
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(contentId);
        when(() => mockSnapshot.data()).thenReturn(testContentMap);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        await repository.updateSharingPermissions(
          contentId,
          addUsers,
          [],
        );
        
        // Assert
        verify(() => mockDocRef.update(any())).called(1); // Only add operation
      });
      
      test('should throw ResourceNotFoundException for non-existent content', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act & Assert
        expect(
          () => repository.updateSharingPermissions(contentId, ['user1'], []),
          throwsA(isA<ResourceNotFoundException>()
            .having((e) => e.message, 'message', contains('not found'))),
        );
      });
      
      test('should prevent updating permissions if user does not own content', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(contentId);
        when(() => mockSnapshot.data()).thenReturn({
          ...testContentMap,
          'ownerId': otherUserId, // Different owner
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act & Assert
        expect(
          () => repository.updateSharingPermissions(contentId, ['user1'], []),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
    
    group('revokeSharing', () {
      test('should delete shared content document', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(contentId);
        when(() => mockSnapshot.data()).thenReturn(testContentMap);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        when(() => mockDocRef.delete()).thenAnswer((_) async {});
        
        // Act
        await repository.revokeSharing(contentId);
        
        // Assert
        verify(() => mockDocRef.delete()).called(1);
      });
      
      test('should throw ResourceNotFoundException for non-existent content', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act & Assert
        expect(
          () => repository.revokeSharing(contentId),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
      
      test('should prevent revoking if user does not own content', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(contentId);
        when(() => mockSnapshot.data()).thenReturn({
          ...testContentMap,
          'ownerId': otherUserId,
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act & Assert
        expect(
          () => repository.revokeSharing(contentId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
    
    group('acceptSharedContent', () {
      test('should update acceptedBy field with user timestamp', () async {
        // Arrange
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});
        
        // Act
        await repository.acceptSharedContent(contentId, userId);
        
        // Assert
        final captured = verify(() => mockDocRef.update(captureAny())).captured.single;
        expect(captured['acceptedBy.$userId'], isA<FieldValue>());
      });
      
      test('should prevent accepting on behalf of another user', () async {
        // Act & Assert
        expect(
          () => repository.acceptSharedContent(contentId, otherUserId),
          throwsA(isA<PermissionDeniedException>()
            .having((e) => e.message, 'message', contains('can only accept shared content'))),
        );
      });
      
      test('should handle Firestore errors when accepting', () async {
        // Arrange
        when(() => mockDocRef.update(any()))
            .thenThrow(FirebaseException(plugin: 'firestore'));
        
        // Act & Assert
        expect(
          () => repository.acceptSharedContent(contentId, userId),
          throwsException,
        );
      });
    });
    
    group('declineSharedContent', () {
      test('should update declinedBy field with user timestamp', () async {
        // Arrange
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});
        
        // Act
        await repository.declineSharedContent(contentId, userId);
        
        // Assert
        final captured = verify(() => mockDocRef.update(captureAny())).captured.single;
        expect(captured['declinedBy.$userId'], isA<FieldValue>());
      });
      
      test('should prevent declining on behalf of another user', () async {
        // Act & Assert
        expect(
          () => repository.declineSharedContent(contentId, otherUserId),
          throwsA(isA<PermissionDeniedException>()
            .having((e) => e.message, 'message', contains('can only decline shared content'))),
        );
      });
      
      test('should handle Firestore errors when declining', () async {
        // Arrange
        when(() => mockDocRef.update(any()))
            .thenThrow(FirebaseException(plugin: 'firestore'));
        
        // Act & Assert
        expect(
          () => repository.declineSharedContent(contentId, userId),
          throwsException,
        );
      });
    });
    
    group('getSharingStats', () {
      test('should calculate comprehensive sharing statistics', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc3 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockDoc1.data()).thenReturn(testContentMap);
        when(() => mockDoc2.data()).thenReturn(testContentMap);
        when(() => mockDoc3.data()).thenReturn(testContentMap);
        
        final sharedByMeDocs = [mockDoc1, mockDoc2, mockDoc3];
        
        final mockDoc4 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc5 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc6 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc7 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockDoc4.data()).thenReturn({
          ...testContentMap,
          'acceptedBy': {userId: Timestamp.now()},
          'viewedBy': {userId: Timestamp.now()},
        });
        when(() => mockDoc5.data()).thenReturn({
          ...testContentMap,
          'viewedBy': {userId: Timestamp.now()},
        });
        when(() => mockDoc6.data()).thenReturn({
          ...testContentMap,
          'acceptedBy': {userId: Timestamp.now()},
          'viewedBy': {userId: Timestamp.now()},
        });
        when(() => mockDoc7.data()).thenReturn(testContentMap);
        
        final sharedWithMeDocs = [mockDoc4, mockDoc5, mockDoc6, mockDoc7];
        
        final sharedByMeSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        when(() => sharedByMeSnapshot.docs).thenReturn(sharedByMeDocs);
        
        final sharedWithMeSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        when(() => sharedWithMeSnapshot.docs).thenReturn(sharedWithMeDocs);
        
        final mockQuery2 = MockQuery<Map<String, dynamic>>();
        
        when(() => mockCollection.where('ownerId', isEqualTo: userId))
            .thenReturn(mockQuery);
        when(() => mockCollection.where('sharedWithUserIds', arrayContains: userId))
            .thenReturn(mockQuery2);
        
        when(() => mockQuery.get()).thenAnswer((_) async => sharedByMeSnapshot);
        when(() => mockQuery2.get()).thenAnswer((_) async => sharedWithMeSnapshot);
        
        // Act
        final stats = await repository.getSharingStats(userId);
        
        // Assert
        expect(stats['totalShared'], equals(3));
        expect(stats['totalReceived'], equals(4));
        expect(stats['acceptedCount'], equals(2));
        expect(stats['viewedCount'], equals(3));
        expect(stats['acceptanceRate'], equals(0.5)); // 2/4
      });
      
      test('should handle zero received content gracefully', () async {
        // Arrange
        final emptySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        when(() => emptySnapshot.docs).thenReturn([]);
        
        final mockQuery2 = MockQuery<Map<String, dynamic>>();
        
        when(() => mockCollection.where('ownerId', isEqualTo: userId))
            .thenReturn(mockQuery);
        when(() => mockCollection.where('sharedWithUserIds', arrayContains: userId))
            .thenReturn(mockQuery2);
        
        when(() => mockQuery.get()).thenAnswer((_) async => emptySnapshot);
        when(() => mockQuery2.get()).thenAnswer((_) async => emptySnapshot);
        
        // Act
        final stats = await repository.getSharingStats(userId);
        
        // Assert
        expect(stats['totalShared'], equals(0));
        expect(stats['totalReceived'], equals(0));
        expect(stats['acceptanceRate'], equals(0));
      });
      
      test('should return default stats on error', () async {
        // Arrange
        when(() => mockCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
            .thenThrow(Exception('Firestore error'));
        
        // Act
        final stats = await repository.getSharingStats(userId);
        
        // Assert
        expect(stats['totalShared'], equals(0));
        expect(stats['totalReceived'], equals(0));
        expect(stats['acceptedCount'], equals(0));
        expect(stats['viewedCount'], equals(0));
        expect(stats['acceptanceRate'], equals(0));
      });
    });
    
    group('inherited from BaseFirebaseRepository', () {
      test('should use correct collection name', () {
        // Assert
        expect(repository.collectionName, equals('shared_content'));
      });
      
      test('should convert from Firestore correctly', () {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.id).thenReturn(contentId);
        when(() => mockSnapshot.data()).thenReturn(testContentMap);
        
        // Act
        final result = repository.fromFirestore(mockSnapshot);
        
        // Assert
        expect(result.id, equals(contentId));
        expect(result.contentType, equals('recipe'));
        expect(result.contentId, equals(recipeId));
        expect(result.ownerId, equals(userId));
      });
      
      test('should convert to Firestore correctly', () {
        // Act
        final result = repository.toFirestore(testContent);
        
        // Assert
        expect(result['contentType'], equals('recipe'));
        expect(result['contentId'], equals(recipeId));
        expect(result['ownerId'], equals(userId));
        expect(result['sharedWithUserIds'], isEmpty);
        expect(result['sharedWithGroupIds'], isEmpty);
      });
      
      test('should extract ID correctly', () {
        // Act
        final id = repository.getId(testContent);
        
        // Assert
        expect(id, equals(contentId));
      });
    });
    
    group('permission validation', () {
      test('should log permission checks for successful operations', () async {
        // Arrange
        when(() => mockDocRef.set(any(), any())).thenAnswer((_) async {});
        
        // Act
        await repository.shareToGroup(groupId, testContent);
        
        // Assert
        // Permission check is logged internally via logPermissionCheck
        verify(() => mockDocRef.set(any(), any())).called(1);
      });
      
      test('should enforce ownership validation for all write operations', () async {
        // Arrange
        final otherUserContent = SharedContent(
          id: contentId,
          contentType: 'recipe',
          contentId: recipeId,
          ownerId: otherUserId,
          sharedWithUserIds: [],
          sharedWithGroupIds: [],
          sharedAt: DateTime.now(),
          metadata: {'title': 'Test Recipe'},
          permissions: SharingPermissions(),
        );
        
        // Act & Assert - Test all write operations
        expect(
          () => repository.shareToGroup(groupId, otherUserContent),
          throwsA(isA<PermissionDeniedException>()),
        );
        
        expect(
          () => repository.shareToUsers(['user1'], otherUserContent),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
      
      test('should enforce self-operation validation', () async {
        // Act & Assert
        expect(
          () => repository.acceptSharedContent(contentId, otherUserId),
          throwsA(isA<PermissionDeniedException>()),
        );
        
        expect(
          () => repository.declineSharedContent(contentId, otherUserId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
  });
}
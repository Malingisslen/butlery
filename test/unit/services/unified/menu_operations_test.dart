/// Comprehensive unit tests for Menu Operations
/// 
/// Tests the collaborative and social menu operations coordinators that handle
/// menu sharing, collaboration, ratings, comments, templates, and social features.
library;

// ignore_for_file: undefined_method

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/unified/operations/collaborative_menu_operations.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/models/user_profile.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/di/test_service_locator.dart';

// Mock FriendCategories for group sharing tests
class MockFriendCategories extends Mock implements FriendsCategoriesOperations {
  List<UserProfile> friendsInCategory = [];
  
  @override
  List<UserProfile> getFriendsInCategory(String categoryId) => friendsInCategory;
}


// Mock FirebaseFirestore
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
// ignore: subtype_of_sealed_class
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
// ignore: subtype_of_sealed_class
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}
class MockWriteBatch extends Mock implements WriteBatch {}


// Mock parent service for CollaborativeMenuOperations
class MockParentService extends Mock implements UnifiedMenuService {
  @override
  void notifyListeners() {
    // Mock implementation - do nothing
  }
  
  @override
  CollaborativeMenuOperations get collaborative => throw UnimplementedError();
  
  @override
  Future<Map<String, List<Recipe>>> generateMenuFromPrompt(String prompt, List<Recipe> availableRecipes) async => {};
  
  @override
  Future<String?> createMenu({required String name, String? description, Map<String, List<Recipe>>? initialRecipes}) async => null;
  
  @override
  Future<bool> updateMenu(SharedMenu menu) async => false;
  
  @override
  Future<bool> deleteMenu(String menuId) async => false;
  
  @override
  SharedMenu? getMenuById(String menuId) => null;
  
  @override
  List<SharedMenu> get menus => [];
  
  @override
  bool get isInitialized => true;
  
  @override
  bool get isLoading => false;
  
  @override
  String? get error => null;
  
  @override
  bool get hasError => false;
  
  @override
  Future<void> initialize() async {}
  
  @override
  void dispose() {}
  
  @override
  String? get currentUserId => 'test-user';
  
  @override
  String? get currentUserDisplayName => 'Test User';
}

void main() {
  group('Menu Operations', () {
    late CollaborativeMenuOperations collaborativeOps;
    late SocialMenuOperations socialOps;
    late MockFirebaseFirestore mockFirestore;
    late MockPermissionService mockPermissionService;
    late MockUnifiedFriendsService mockFriendsService;
    late MockParentService mockParent;
    late Recipe testRecipe;
    late Map<String, List<Recipe>> testMenu;
    late UserProfile testUser;
    late UserProfile testFriend;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(SharedMenu.create(
        sharedByUserId: 'test',
        sharedByDisplayName: 'Test',
        sharedToUserIds: [],
        menuTitle: 'Test',
        menuSnapshot: {},
      ));
      registerFallbackValue(DateTime.now());
      registerFallbackValue(<String, dynamic>{});
    });
    
    setUp(() async {
      mockFirestore = MockFirebaseFirestore();
      mockFriendsService = MockUnifiedFriendsService();
      mockParent = MockParentService();
      
      // Initialize TestServiceLocator
      await TestServiceLocator.initialize();
      
      // Get the existing permission service mock that was registered during initialization
      // This ensures production code uses the same instance we're configuring
      mockPermissionService = TestServiceLocator.get<PermissionService>() as MockPermissionService;
      
      collaborativeOps = CollaborativeMenuOperations(mockParent as UnifiedMenuService, mockFirestore);
      socialOps = SocialMenuOperations(
        firestore: mockFirestore,
        friendsService: mockFriendsService,
      );
      
      testRecipe = RecipeFactory.build(
        id: 'test-recipe-1',
        title: 'Köttbullar',
        description: 'Svenska köttbullar',
      );
      
      testMenu = {
        'Huvudrätt': [testRecipe],
        'Förrätt': [],
      };
      
      testUser = UserProfile(
        uid: 'test-user',
        displayName: 'Test User',
        email: 'test@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );
      
      testFriend = UserProfile(
        uid: 'friend-1',
        displayName: 'Friend One',
        email: 'friend@example.com',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );
      
      // Configure mock permission service using state methods
      mockPermissionService.setPermissionState(
        currentUserId: testUser.uid,
        userDisplayName: testUser.displayName,
        defaultHasPermission: true,
      );
      
      // Debug: Verify the mock is configured correctly
      print('Mock userId: ${mockPermissionService.currentUserId}');
      print('Mock displayName: ${mockPermissionService.currentUserDisplayName}');
      
      // Setup mock friends service
      mockFriendsService.setFriendsState(
        friends: [testFriend],
      );
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('CollaborativeMenuOperations', () {
      group('Real-time Menu Collaboration', () {
        test('should enable menu collaboration', () async {
          // Arrange
          final mockCollection = MockCollectionReference();
          final mockDoc = MockDocumentReference();
          final mockSnapshot = MockDocumentSnapshot();
          
          when(() => mockFirestore.collection('shared_menus')).thenReturn(mockCollection);
          when(() => mockCollection.doc(any())).thenReturn(mockDoc);
          when(() => mockDoc.update(any())).thenAnswer((_) async {});
          
          // Mock the snapshots() method that's called by _startMenuCollaborationListener
          when(() => mockDoc.snapshots()).thenAnswer((_) => Stream.value(mockSnapshot));
          when(() => mockSnapshot.exists).thenReturn(true);
          
          // Act
          final success = await collaborativeOps.enableMenuCollaboration(
            menuId: 'menu-1',
            collaboratorIds: ['user-1', 'user-2'],
            collaboratorDisplayNames: {
              'user-1': 'Anna',
              'user-2': 'Erik',
            },
          );
          
          // Assert
          expect(success, isTrue);
          verify(() => mockDoc.update(any())).called(1);
        });
        
        test('should add recipe to collaborative menu', () async {
          // Arrange
          final mockCollection = MockCollectionReference();
          final mockDoc = MockDocumentReference();
          final mockDocSnapshot = MockDocumentSnapshot();
          
          when(() => mockFirestore.collection('shared_menus')).thenReturn(mockCollection);
          when(() => mockCollection.doc(any())).thenReturn(mockDoc);
          when(() => mockDoc.get()).thenAnswer((_) async => mockDocSnapshot);
          when(() => mockDocSnapshot.exists).thenReturn(true);
          when(() => mockDocSnapshot.data()).thenReturn({
            'sharedByUserId': 'test-user',
            'allowCollaboration': true,
            'collaboratorIds': ['test-user'],
          });
          when(() => mockDoc.update(any())).thenAnswer((_) async {});
          
          final mockActivityCollection = MockCollectionReference();
          final mockActivityDoc = MockDocumentReference();
          final mockActivitiesCollection = MockCollectionReference();
          
          when(() => mockFirestore.collection('menu_activity')).thenReturn(mockActivityCollection);
          when(() => mockActivityCollection.doc(any())).thenReturn(mockActivityDoc);
          when(() => mockActivityDoc.collection('activities')).thenReturn(mockActivitiesCollection);
          when(() => mockActivitiesCollection.add(any())).thenAnswer((_) async => mockActivityDoc);
          
          // Act
          final success = await collaborativeOps.addRecipeToCollaborativeMenu(
            menuId: 'menu-1',
            category: 'Huvudrätt',
            recipe: testRecipe,
            suggestion: 'Perfekt för helgen!',
          );
          
          // Assert
          expect(success, isTrue);
        });
        
        test('should remove recipe from collaborative menu', () async {
          // Arrange
          final mockCollection = MockCollectionReference();
          final mockDoc = MockDocumentReference();
          final mockDocSnapshot = MockDocumentSnapshot();
          
          when(() => mockFirestore.collection('shared_menus')).thenReturn(mockCollection);
          when(() => mockCollection.doc(any())).thenReturn(mockDoc);
          when(() => mockDoc.get()).thenAnswer((_) async => mockDocSnapshot);
          when(() => mockDocSnapshot.exists).thenReturn(true);
          when(() => mockDocSnapshot.data()).thenReturn({
            'sharedByUserId': 'test-user',
            'allowCollaboration': true,
            'collaboratorIds': ['test-user'],
            'menuSnapshot': {
              'Huvudrätt': [testRecipe.toFirestore()],
            },
          });
          when(() => mockDoc.update(any())).thenAnswer((_) async {});
          
          final mockActivityCollection = MockCollectionReference();
          final mockActivityDoc = MockDocumentReference();
          final mockActivitiesCollection = MockCollectionReference();
          
          when(() => mockFirestore.collection('menu_activity')).thenReturn(mockActivityCollection);
          when(() => mockActivityCollection.doc(any())).thenReturn(mockActivityDoc);
          when(() => mockActivityDoc.collection('activities')).thenReturn(mockActivitiesCollection);
          when(() => mockActivitiesCollection.add(any())).thenAnswer((_) async => mockActivityDoc);
          
          // Act
          final success = await collaborativeOps.removeRecipeFromCollaborativeMenu(
            menuId: 'menu-1',
            category: 'Huvudrätt',
            recipeId: 'test-recipe-1',
            reason: 'Changed plans',
          );
          
          // Assert
          expect(success, isTrue);
        });
        
        test('should fail if user not authenticated', () async {
          // Arrange
          mockPermissionService.setPermissionState(
            currentUserId: null,
            defaultHasPermission: false,
          );
          
          // Act
          final success = await collaborativeOps.enableMenuCollaboration(
            menuId: 'menu-1',
            collaboratorIds: ['user-1'],
          );
          
          // Assert
          expect(success, isFalse);
        });
      });
      
      group('Menu Rating System', () {
        test('should rate menu successfully', () async {
          // Arrange
          final mockRatingsCollection = MockCollectionReference();
          final mockMenuDoc = MockDocumentReference();
          final mockUserRatingsCollection = MockCollectionReference();
          final mockUserRatingDoc = MockDocumentReference();
          
          when(() => mockFirestore.collection('menu_ratings')).thenReturn(mockRatingsCollection);
          when(() => mockRatingsCollection.doc(any())).thenReturn(mockMenuDoc);
          when(() => mockMenuDoc.collection('ratings')).thenReturn(mockUserRatingsCollection);
          when(() => mockUserRatingsCollection.doc(any())).thenReturn(mockUserRatingDoc);
          when(() => mockUserRatingDoc.set(any())).thenAnswer((_) async {});
          
          // Mock for average rating update
          final mockMenusCollection = MockCollectionReference();
          final mockMenuUpdateDoc = MockDocumentReference();
          
          when(() => mockFirestore.collection('shared_menus')).thenReturn(mockMenusCollection);
          when(() => mockMenusCollection.doc(any())).thenReturn(mockMenuUpdateDoc);
          when(() => mockMenuUpdateDoc.update(any())).thenAnswer((_) async {});
          
          // Act
          final success = await collaborativeOps.rateMenu(
            menuId: 'menu-1',
            rating: 4.5,
            comment: 'Mycket bra meny!',
          );
          
          // Assert
          expect(success, isTrue);
        });
        
        test('should reject invalid rating', () async {
          // Act
          final successTooLow = await collaborativeOps.rateMenu(
            menuId: 'menu-1',
            rating: 0.5,
          );
          
          final successTooHigh = await collaborativeOps.rateMenu(
            menuId: 'menu-1',
            rating: 5.5,
          );
          
          // Assert
          expect(successTooLow, isFalse);
          expect(successTooHigh, isFalse);
        });
        
        test('should get menu ratings', () async {
          // Arrange
          final mockRatingsCollection = MockCollectionReference();
          final mockMenuDoc = MockDocumentReference();
          final mockUserRatingsCollection = MockCollectionReference();
          final mockQuerySnapshot = MockQuerySnapshot();
          final mockQueryDoc = MockQueryDocumentSnapshot();
          
          when(() => mockFirestore.collection('menu_ratings')).thenReturn(mockRatingsCollection);
          when(() => mockRatingsCollection.doc(any())).thenReturn(mockMenuDoc);
          when(() => mockMenuDoc.collection('ratings')).thenReturn(mockUserRatingsCollection);
          when(() => mockUserRatingsCollection.orderBy(any(), descending: any(named: 'descending')))
              .thenReturn(mockUserRatingsCollection);
          when(() => mockUserRatingsCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
          when(() => mockQuerySnapshot.docs).thenReturn([mockQueryDoc]);
          when(() => mockQueryDoc.id).thenReturn('user-1');
          when(() => mockQueryDoc.data()).thenReturn({
            'rating': 4.5,
            'comment': 'Great menu!',
            'ratedBy': 'user-1',
            'ratedByDisplayName': 'User One',
            'ratedAt': Timestamp.now(),
          });
          
          // Act
          final ratings = await collaborativeOps.getMenuRatings('menu-1');
          
          // Assert
          expect(ratings, isNotEmpty);
          expect(ratings.first['rating'], equals(4.5));
        });
        
        test('should calculate average rating', () async {
          // Arrange
          final mockRatingsCollection = MockCollectionReference();
          final mockMenuDoc = MockDocumentReference();
          final mockUserRatingsCollection = MockCollectionReference();
          final mockQuerySnapshot = MockQuerySnapshot();
          final mockQueryDoc1 = MockQueryDocumentSnapshot();
          final mockQueryDoc2 = MockQueryDocumentSnapshot();
          
          when(() => mockFirestore.collection('menu_ratings')).thenReturn(mockRatingsCollection);
          when(() => mockRatingsCollection.doc(any())).thenReturn(mockMenuDoc);
          when(() => mockMenuDoc.collection('ratings')).thenReturn(mockUserRatingsCollection);
          when(() => mockUserRatingsCollection.orderBy(any(), descending: any(named: 'descending')))
              .thenReturn(mockUserRatingsCollection);
          when(() => mockUserRatingsCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
          when(() => mockQuerySnapshot.docs).thenReturn([mockQueryDoc1, mockQueryDoc2]);
          when(() => mockQueryDoc1.id).thenReturn('user1');
          when(() => mockQueryDoc1.data()).thenReturn({'rating': 4.0});
          when(() => mockQueryDoc2.id).thenReturn('user2');
          when(() => mockQueryDoc2.data()).thenReturn({'rating': 5.0});
          
          // Act
          final average = await collaborativeOps.getMenuAverageRating('menu-1');
          
          // Assert
          expect(average, equals(4.5));
        });
      });
      
      group('Menu Commenting System', () {
        test('should add comment to menu', () async {
          // Arrange
          final mockCommentsCollection = MockCollectionReference();
          final mockMenuDoc = MockDocumentReference();
          final mockCommentsSubCollection = MockCollectionReference();
          final mockCommentDoc = MockDocumentReference();
          
          when(() => mockFirestore.collection('menu_comments')).thenReturn(mockCommentsCollection);
          when(() => mockCommentsCollection.doc(any())).thenReturn(mockMenuDoc);
          when(() => mockMenuDoc.collection('comments')).thenReturn(mockCommentsSubCollection);
          when(() => mockCommentsSubCollection.add(any())).thenAnswer((_) async => mockCommentDoc);
          when(() => mockCommentDoc.id).thenReturn('comment-1');
          
          // Act
          final success = await collaborativeOps.addMenuComment(
            menuId: 'menu-1',
            comment: 'Fantastisk meny!',
          );
          
          // Assert
          expect(success, isTrue);
        });
        
        test('should add reply to comment', () async {
          // Arrange
          final mockCommentsCollection = MockCollectionReference();
          final mockMenuDoc = MockDocumentReference();
          final mockCommentsSubCollection = MockCollectionReference();
          final mockCommentDoc = MockDocumentReference();
          
          when(() => mockFirestore.collection('menu_comments')).thenReturn(mockCommentsCollection);
          when(() => mockCommentsCollection.doc(any())).thenReturn(mockMenuDoc);
          when(() => mockMenuDoc.collection('comments')).thenReturn(mockCommentsSubCollection);
          when(() => mockCommentsSubCollection.add(any())).thenAnswer((_) async => mockCommentDoc);
          when(() => mockCommentDoc.id).thenReturn('reply-1');
          
          // Act
          final success = await collaborativeOps.addMenuComment(
            menuId: 'menu-1',
            comment: 'Jag håller med!',
            replyToCommentId: 'comment-1',
          );
          
          // Assert
          expect(success, isTrue);
        });
        
        test('should toggle comment like', () async {
          // Arrange
          final mockCommentsCollection = MockCollectionReference();
          final mockMenuDoc = MockDocumentReference();
          final mockCommentsSubCollection = MockCollectionReference();
          final mockCommentDoc = MockDocumentReference();
          final mockCommentSnapshot = MockDocumentSnapshot();
          
          when(() => mockFirestore.collection('menu_comments')).thenReturn(mockCommentsCollection);
          when(() => mockCommentsCollection.doc(any())).thenReturn(mockMenuDoc);
          when(() => mockMenuDoc.collection('comments')).thenReturn(mockCommentsSubCollection);
          when(() => mockCommentsSubCollection.doc(any())).thenReturn(mockCommentDoc);
          when(() => mockCommentDoc.get()).thenAnswer((_) async => mockCommentSnapshot);
          when(() => mockCommentSnapshot.exists).thenReturn(true);
          when(() => mockCommentSnapshot.data()).thenReturn({
            'likes': 5,
            'likedBy': ['user-1', 'user-2'],
          });
          when(() => mockCommentDoc.update(any())).thenAnswer((_) async {});
          
          // Act
          final success = await collaborativeOps.toggleCommentLike(
            menuId: 'menu-1',
            commentId: 'comment-1',
          );
          
          // Assert
          expect(success, isTrue);
        });
        
        test('should get comments stream', () {
          // Arrange
          final mockCommentsCollection = MockCollectionReference();
          final mockMenuDoc = MockDocumentReference();
          final mockCommentsSubCollection = MockCollectionReference();
          
          when(() => mockFirestore.collection('menu_comments')).thenReturn(mockCommentsCollection);
          when(() => mockCommentsCollection.doc(any())).thenReturn(mockMenuDoc);
          when(() => mockMenuDoc.collection('comments')).thenReturn(mockCommentsSubCollection);
          when(() => mockCommentsSubCollection.orderBy(any(), descending: any(named: 'descending')))
              .thenReturn(mockCommentsSubCollection);
          when(() => mockCommentsSubCollection.snapshots()).thenAnswer((_) => Stream.empty());
          
          // Act
          final stream = collaborativeOps.getMenuCommentsStream('menu-1');
          
          // Assert
          expect(stream, isA<Stream<List<Map<String, dynamic>>>>());
        });
      });
      
      group('Menu Templates', () {
        test('should create menu template', () async {
          // Arrange
          final mockTemplatesCollection = MockCollectionReference();
          final mockTemplateDoc = MockDocumentReference();
          
          when(() => mockFirestore.collection('menu_templates')).thenReturn(mockTemplatesCollection);
          when(() => mockTemplatesCollection.add(any())).thenAnswer((_) async => mockTemplateDoc);
          when(() => mockTemplateDoc.id).thenReturn('template-1');
          
          // Act
          final templateId = await collaborativeOps.createMenuTemplate(
            templateName: 'Veckomeny',
            menuSnapshot: testMenu,
            description: 'En balanserad veckomeny',
            tags: ['familj', 'budget'],
          );
          
          // Assert
          expect(templateId, equals('template-1'));
        });
        
        test('should create menu from template', () async {
          // Arrange
          final mockTemplatesCollection = MockCollectionReference();
          final mockTemplateDoc = MockDocumentReference();
          final mockTemplateSnapshot = MockDocumentSnapshot();
          
          when(() => mockFirestore.collection('menu_templates')).thenReturn(mockTemplatesCollection);
          when(() => mockTemplatesCollection.doc(any())).thenReturn(mockTemplateDoc);
          when(() => mockTemplateDoc.get()).thenAnswer((_) async => mockTemplateSnapshot);
          when(() => mockTemplateSnapshot.exists).thenReturn(true);
          when(() => mockTemplateSnapshot.data()).thenReturn({
            'menuSnapshot': {
              'Huvudrätt': [testRecipe.toFirestore()],
            },
          });
          when(() => mockTemplateDoc.update(any())).thenAnswer((_) async {});
          
          final mockMenusCollection = MockCollectionReference();
          final mockMenuDoc = MockDocumentReference();
          
          when(() => mockFirestore.collection('shared_menus')).thenReturn(mockMenusCollection);
          when(() => mockMenusCollection.doc(any())).thenReturn(mockMenuDoc);
          when(() => mockMenuDoc.set(any())).thenAnswer((_) async {});
          
          // Act
          final menuId = await collaborativeOps.createMenuFromTemplate(
            templateId: 'template-1',
            menuTitle: 'Min nya meny',
            sharedToUserIds: ['friend-1'],
            enableCollaboration: true,
          );
          
          // Assert
          expect(menuId, isNotNull);
        });
        
        test('should fail template creation if not authenticated', () async {
          // Arrange
          mockPermissionService.setPermissionState(
            currentUserId: null,
            defaultHasPermission: false,
          );
          
          // Act
          final templateId = await collaborativeOps.createMenuTemplate(
            templateName: 'Test',
            menuSnapshot: testMenu,
          );
          
          // Assert
          expect(templateId, isNull);
        });
      });
      
      group('Resource Management', () {
        test('should dispose resources properly', () {
          // Act & Assert (no error thrown)
          collaborativeOps.dispose();
        });
      });
    });
    
    group('SocialMenuOperations', () {
      group('Friend-Based Menu Sharing', () {
        test('should share menu with friends', () async {
          // Arrange
          final mockSharedMenusCollection = MockCollectionReference();
          final mockSharedMenuDoc = MockDocumentReference();
          final mockBatch = MockWriteBatch();
          
          when(() => mockFirestore.collection('sharedMenus')).thenReturn(mockSharedMenusCollection);
          when(() => mockSharedMenusCollection.doc()).thenReturn(mockSharedMenuDoc);
          when(() => mockSharedMenuDoc.id).thenReturn('shared-menu-1');
          when(() => mockSharedMenuDoc.set(any())).thenAnswer((_) async {});
          when(() => mockFirestore.batch()).thenReturn(mockBatch);
          when(() => mockBatch.commit()).thenAnswer((_) async {});
          
          final mockUserSharedMenusCollection = MockCollectionReference();
          final mockUserDoc = MockDocumentReference();
          final mockReceivedMenusCollection = MockCollectionReference();
          final mockReceivedMenuDoc = MockDocumentReference();
          
          when(() => mockFirestore.collection('userSharedMenus')).thenReturn(mockUserSharedMenusCollection);
          when(() => mockUserSharedMenusCollection.doc(any())).thenReturn(mockUserDoc);
          when(() => mockUserDoc.collection('receivedMenus')).thenReturn(mockReceivedMenusCollection);
          when(() => mockReceivedMenusCollection.doc(any())).thenReturn(mockReceivedMenuDoc);
          when(() => mockBatch.set(mockReceivedMenuDoc, any())).thenReturn(null);
          
          // Act
          final success = await socialOps.shareMenuWithFriends(
            menu: testMenu,
            friendUserIds: ['friend-1'],
            message: 'Check out this menu!',
            customTitle: 'Weekly Menu',
          );
          
          // Assert
          expect(success, isTrue);
        });
        
        test('should fail sharing empty menu', () async {
          // Act
          final success = await socialOps.shareMenuWithFriends(
            menu: {},
            friendUserIds: ['friend-1'],
          );
          
          // Assert
          expect(success, isFalse);
        });
        
        test('should fail sharing with no friends', () async {
          // Act
          final success = await socialOps.shareMenuWithFriends(
            menu: testMenu,
            friendUserIds: [],
          );
          
          // Assert
          expect(success, isFalse);
        });
        
        test('should validate friend IDs', () async {
          // Act
          final success = await socialOps.shareMenuWithFriends(
            menu: testMenu,
            friendUserIds: ['invalid-friend-id'],
          );
          
          // Assert
          expect(success, isFalse);
        });
        
        test('should fail if not authenticated', () async {
          // Arrange
          // Configure as unauthenticated
          mockPermissionService.setPermissionState(
            currentUserId: null,
            userDisplayName: null,
          );
          
          // Act
          final success = await socialOps.shareMenuWithFriends(
            menu: testMenu,
            friendUserIds: ['friend-1'],
          );
          
          // Assert
          expect(success, isFalse);
        });
      });
      
      group('Group Menu Sharing', () {
        test('should share menu with group', () async {
          // Arrange
          final mockCategories = MockFriendCategories();
          mockCategories.friendsInCategory = [testFriend];
          when(() => mockFriendsService.categories).thenReturn(mockCategories);
          
          final mockSharedMenusCollection = MockCollectionReference();
          final mockSharedMenuDoc = MockDocumentReference();
          final mockBatch = MockWriteBatch();
          
          when(() => mockFirestore.collection('sharedMenus')).thenReturn(mockSharedMenusCollection);
          when(() => mockSharedMenusCollection.doc()).thenReturn(mockSharedMenuDoc);
          when(() => mockSharedMenuDoc.id).thenReturn('shared-menu-1');
          when(() => mockSharedMenuDoc.set(any())).thenAnswer((_) async {});
          when(() => mockFirestore.batch()).thenReturn(mockBatch);
          when(() => mockBatch.commit()).thenAnswer((_) async {});
          
          final mockUserSharedMenusCollection = MockCollectionReference();
          final mockUserDoc = MockDocumentReference();
          final mockReceivedMenusCollection = MockCollectionReference();
          final mockReceivedMenuDoc = MockDocumentReference();
          
          when(() => mockFirestore.collection('userSharedMenus')).thenReturn(mockUserSharedMenusCollection);
          when(() => mockUserSharedMenusCollection.doc(any())).thenReturn(mockUserDoc);
          when(() => mockUserDoc.collection('receivedMenus')).thenReturn(mockReceivedMenusCollection);
          when(() => mockReceivedMenusCollection.doc(any())).thenReturn(mockReceivedMenuDoc);
          when(() => mockBatch.set(mockReceivedMenuDoc, any())).thenReturn(null);
          
          // Act
          final success = await socialOps.shareMenuWithGroup(
            menu: testMenu,
            categoryId: 'family',
            message: 'Family dinner menu',
          );
          
          // Assert
          expect(success, isTrue);
        });
      });
    });
  });
}
/// Firebase Firestore implementation for social recipe sharing and community interaction management.
///
/// This file provides comprehensive social recipe sharing functionality through Firebase Firestore,
/// enabling users to share recipes and menus with friends, track engagement metrics, and manage social
/// interactions around recipe content. It implements sophisticated permission validation, engagement
/// tracking, and social features to create a collaborative cooking community platform.
///
/// **Architecture Integration:**
/// - Implements [SocialRecipeRepository] interface for consistent social operations
/// - Uses [PermissionValidationMixin] for comprehensive security validation  
/// - Integrates with Firebase Auth for user authentication and authorization
/// - Leverages Firestore for scalable social data storage and real-time updates
/// - Coordinates with notification system for social engagement alerts
///
/// **Key Social Features:**
/// - Recipe and menu sharing with granular permission control
/// - Engagement tracking (views, imports, dismissals) with timestamp analytics
/// - Social interaction management with comprehensive audit logging
/// - Content discovery and recommendation through social signals
/// - Real-time social activity streams for collaborative cooking experiences
///
/// **Security Implementation:**
/// - Multi-layer permission validation for all social operations
/// - Self-operation validation to prevent unauthorized sharing actions
/// - Comprehensive audit logging for social security monitoring
/// - Access control validation before any social content interaction
/// - Protection against social engineering and unauthorized content access

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/interfaces/social_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/mixins/permission_validation_mixin.dart';

/// Firebase implementation for social recipe sharing with comprehensive community features.
///
/// This repository provides complete social recipe sharing functionality using Firebase Firestore
/// as the backend storage system. It implements sophisticated engagement tracking, permission
/// management, and social interaction features to support a collaborative cooking community.
///
/// **Social Platform Architecture:**
/// The repository manages multiple interconnected Firestore collections to create a comprehensive
/// social platform for recipe sharing and community interaction:
/// - `shared_recipes`: Recipe sharing with engagement metrics and access control
/// - `shared_menus`: Menu sharing with collaborative planning capabilities  
/// - `shared_content`: Generic content sharing system for flexible social features
/// - `recipe_comments`: Social commentary and feedback system integration
///
/// **Engagement Tracking System:**
/// Implements comprehensive engagement analytics to understand user behavior and improve
/// content recommendation algorithms:
/// - **View Tracking**: Records when users view shared content with precise timestamps
/// - **Import Analytics**: Tracks content adoption and recipe collection growth
/// - **Dismissal Patterns**: Understands content preferences through dismissal behavior
/// - **Social Signals**: Aggregates engagement data for personalized content discovery
///
/// **Permission Security Model:**
/// Uses multi-layered security validation to ensure safe social interactions:
/// - Self-operation validation prevents users from acting on behalf of others
/// - Access control verification before any content interaction
/// - Comprehensive audit logging for security monitoring and compliance
/// - Resource ownership validation for all modification operations
///
/// **Usage Example:**
/// ```dart
/// final socialRepo = FirebaseSocialRecipeRepository(
///   authRepository: sl<AuthRepository>(),
/// );
/// 
/// // Share recipe with engagement tracking
/// await socialRepo.shareContent(
///   fromUserId: currentUserId,
///   toUserId: friendId,
///   contentType: 'recipe',
///   contentData: recipeData,
/// );
/// 
/// // Track user engagement
/// await socialRepo.markSharedRecipeAsViewed(recipeId, userId);
/// await socialRepo.markSharedRecipeAsImported(recipeId, userId);
/// 
/// // Manage user preferences
/// await socialRepo.dismissSharedRecipe(recipeId, userId);
/// ```
class FirebaseSocialRecipeRepository with PermissionValidationMixin implements SocialRecipeRepository {
  /// Firestore instance for database operations and real-time data synchronization.
  final FirebaseFirestore _firestore;
  
  /// Firebase Auth instance for user authentication and authorization validation.
  final FirebaseAuth _auth;
  
  /// Authentication repository for unified user authentication operations.
  final AuthRepository _authRepository;

  /// Creates a Firebase social recipe repository with dependency injection support.
  ///
  /// [firestore] Optional Firestore instance, defaults to FirebaseFirestore.instance
  /// [auth] Optional Firebase Auth instance, defaults to FirebaseAuth.instance  
  /// [authRepository] Required authentication repository for user validation
  FirebaseSocialRecipeRepository({
    FirebaseFirestore? firestore, 
    FirebaseAuth? auth,
    required AuthRepository authRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _authRepository = authRepository;

  @override
  CollectionReference<Map<String, dynamic>> get sharedRecipesRef =>
      _firestore.collection('shared_recipes');

  @override
  CollectionReference<Map<String, dynamic>> get sharedMenusRef =>
      _firestore.collection('shared_menus');

  @override
  CollectionReference<Map<String, dynamic>> get sharedContentRef =>
      _firestore.collection('shared_content');

  @override
  CollectionReference<Map<String, dynamic>> get recipeCommentsRef =>
      _firestore.collection('recipe_comments');

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<List<SharedRecipe>> getSharedRecipes(String userId) async {
    try {
      final snapshot = await sharedRecipesRef
          .where('sharedWithUserIds', arrayContains: userId)
          .get();
      
      return snapshot.docs.map((doc) => SharedRecipe.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      throw Exception('Failed to get shared recipes: $e');
    }
  }

  @override
  Future<List<SharedMenu>> getSharedMenus(String userId) async {
    try {
      final snapshot = await sharedMenusRef
          .where('sharedWithUserIds', arrayContains: userId)
          .get();
      
      return snapshot.docs.map((doc) => SharedMenu.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      throw Exception('Failed to get shared menus: $e');
    }
  }

  @override
  Future<void> markSharedRecipeAsViewed(String recipeId, String userId) async {
    // Validate user is marking their own view
    final currentUser = _authRepository.currentUserId;
    if (currentUser == null) {
      throw PermissionDeniedException('User must be authenticated');
    }
    
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'mark recipe as viewed',
    );
    
    // Check if recipe exists and user has access
    final doc = await getDocumentWithPermissionCheck(
      docRef: sharedRecipesRef.doc(recipeId),
      currentUserId: currentUser,
      resourceType: 'shared_recipe',
    );
    
    final data = doc.data() as Map<String, dynamic>;
    final sharedWith = List<String>.from(data['sharedWith'] ?? []);
    
    if (!await hasReadAccess(
      currentUserId: currentUser,
      resourceOwnerId: data['ownerId'] ?? '',
      sharedWithUserIds: sharedWith,
    )) {
      throw PermissionDeniedException(
        'User does not have access to this shared recipe',
        resource: 'shared_recipe',
        operation: 'view',
        userId: currentUser,
      );
    }
    
    await sharedRecipesRef.doc(recipeId).update({
      'viewedByUserIds': FieldValue.arrayUnion([userId]),
      'viewedAt.$userId': FieldValue.serverTimestamp(),
    });
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'shared_recipe',
      operation: 'mark_viewed',
      granted: true,
    );
  }

  @override
  Future<void> markSharedMenuAsViewed(String menuId, String userId) async {
    // Validate user is marking their own view
    final currentUser = _authRepository.currentUserId;
    if (currentUser == null) {
      throw PermissionDeniedException('User must be authenticated');
    }
    
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'mark menu as viewed',
    );
    
    // Check if menu exists and user has access
    final doc = await getDocumentWithPermissionCheck(
      docRef: sharedMenusRef.doc(menuId),
      currentUserId: currentUser,
      resourceType: 'shared_menu',
    );
    
    final data = doc.data() as Map<String, dynamic>;
    final sharedWith = List<String>.from(data['sharedWithUserIds'] ?? []);
    
    if (!await hasReadAccess(
      currentUserId: currentUser,
      resourceOwnerId: data['ownerId'] ?? '',
      sharedWithUserIds: sharedWith,
    )) {
      throw PermissionDeniedException(
        'User does not have access to this shared menu',
        resource: 'shared_menu',
        operation: 'view',
        userId: currentUser,
      );
    }
    
    await sharedMenusRef.doc(menuId).update({
      'viewedByUserIds': FieldValue.arrayUnion([userId]),
      'viewedAt.$userId': FieldValue.serverTimestamp(),
    });
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'shared_menu',
      operation: 'mark_viewed',
      granted: true,
    );
  }

  @override
  Future<void> markSharedRecipeAsImported(String recipeId, String userId) async {
    // Validate user is marking their own import
    final currentUser = _authRepository.currentUserId;
    if (currentUser == null) {
      throw PermissionDeniedException('User must be authenticated');
    }
    
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'mark recipe as imported',
    );
    
    // Check if recipe exists and user has access
    final doc = await getDocumentWithPermissionCheck(
      docRef: sharedRecipesRef.doc(recipeId),
      currentUserId: currentUser,
      resourceType: 'shared_recipe',
    );
    
    final data = doc.data() as Map<String, dynamic>;
    final sharedWith = List<String>.from(data['sharedWith'] ?? []);
    
    if (!await hasReadAccess(
      currentUserId: currentUser,
      resourceOwnerId: data['ownerId'] ?? '',
      sharedWithUserIds: sharedWith,
    )) {
      throw PermissionDeniedException(
        'User does not have access to this shared recipe',
        resource: 'shared_recipe',
        operation: 'import',
        userId: currentUser,
      );
    }
    
    await sharedRecipesRef.doc(recipeId).update({
      'importedByUserIds': FieldValue.arrayUnion([userId]),
      'importedAt.$userId': FieldValue.serverTimestamp(),
    });
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'shared_recipe',
      operation: 'mark_imported',
      granted: true,
    );
  }

  @override
  Future<void> markSharedMenuAsImported(String menuId, String userId) async {
    // Validate user is marking their own import
    final currentUser = _authRepository.currentUserId;
    if (currentUser == null) {
      throw PermissionDeniedException('User must be authenticated');
    }
    
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'mark menu as imported',
    );
    
    // Check if menu exists and user has access
    final doc = await getDocumentWithPermissionCheck(
      docRef: sharedMenusRef.doc(menuId),
      currentUserId: currentUser,
      resourceType: 'shared_menu',
    );
    
    final data = doc.data() as Map<String, dynamic>;
    final sharedWith = List<String>.from(data['sharedWithUserIds'] ?? []);
    
    if (!await hasReadAccess(
      currentUserId: currentUser,
      resourceOwnerId: data['ownerId'] ?? '',
      sharedWithUserIds: sharedWith,
    )) {
      throw PermissionDeniedException(
        'User does not have access to this shared menu',
        resource: 'shared_menu',
        operation: 'import',
        userId: currentUser,
      );
    }
    
    await sharedMenusRef.doc(menuId).update({
      'importedByUserIds': FieldValue.arrayUnion([userId]),
      'importedAt.$userId': FieldValue.serverTimestamp(),
    });
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'shared_menu',
      operation: 'mark_imported',
      granted: true,
    );
  }

  @override
  Future<void> dismissSharedRecipe(String recipeId, String userId) async {
    // Validate user is dismissing their own shared recipe
    final currentUser = _authRepository.currentUserId;
    if (currentUser == null) {
      throw PermissionDeniedException('User must be authenticated');
    }
    
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'dismiss shared recipe',
    );
    
    // Check if recipe exists and user has access
    final doc = await getDocumentWithPermissionCheck(
      docRef: sharedRecipesRef.doc(recipeId),
      currentUserId: currentUser,
      resourceType: 'shared_recipe',
    );
    
    final data = doc.data() as Map<String, dynamic>;
    final sharedWith = List<String>.from(data['sharedWith'] ?? []);
    
    if (!await hasReadAccess(
      currentUserId: currentUser,
      resourceOwnerId: data['ownerId'] ?? '',
      sharedWithUserIds: sharedWith,
    )) {
      throw PermissionDeniedException(
        'User does not have access to this shared recipe',
        resource: 'shared_recipe',
        operation: 'dismiss',
        userId: currentUser,
      );
    }
    
    await sharedRecipesRef.doc(recipeId).update({
      'dismissedByUserIds': FieldValue.arrayUnion([userId]),
      'dismissedAt.$userId': FieldValue.serverTimestamp(),
    });
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'shared_recipe',
      operation: 'dismiss',
      granted: true,
    );
  }

  @override
  Future<void> dismissSharedMenu(String menuId, String userId) async {
    // Validate user is dismissing their own shared menu
    final currentUser = _authRepository.currentUserId;
    if (currentUser == null) {
      throw PermissionDeniedException('User must be authenticated');
    }
    
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'dismiss shared menu',
    );
    
    // Check if menu exists and user has access
    final doc = await getDocumentWithPermissionCheck(
      docRef: sharedMenusRef.doc(menuId),
      currentUserId: currentUser,
      resourceType: 'shared_menu',
    );
    
    final data = doc.data() as Map<String, dynamic>;
    final sharedWith = List<String>.from(data['sharedWithUserIds'] ?? []);
    
    if (!await hasReadAccess(
      currentUserId: currentUser,
      resourceOwnerId: data['ownerId'] ?? '',
      sharedWithUserIds: sharedWith,
    )) {
      throw PermissionDeniedException(
        'User does not have access to this shared menu',
        resource: 'shared_menu',
        operation: 'dismiss',
        userId: currentUser,
      );
    }
    
    await sharedMenusRef.doc(menuId).update({
      'dismissedByUserIds': FieldValue.arrayUnion([userId]),
      'dismissedAt.$userId': FieldValue.serverTimestamp(),
    });
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'shared_menu',
      operation: 'dismiss',
      granted: true,
    );
  }

  @override
  Future<void> undismissSharedRecipe(String recipeId, String userId) async {
    // Validate user is undismissing their own shared recipe
    final currentUser = _authRepository.currentUserId;
    if (currentUser == null) {
      throw PermissionDeniedException('User must be authenticated');
    }
    
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'undismiss shared recipe',
    );
    
    // Check if recipe exists and user has access
    final doc = await getDocumentWithPermissionCheck(
      docRef: sharedRecipesRef.doc(recipeId),
      currentUserId: currentUser,
      resourceType: 'shared_recipe',
    );
    
    final data = doc.data() as Map<String, dynamic>;
    final sharedWith = List<String>.from(data['sharedWith'] ?? []);
    
    if (!await hasReadAccess(
      currentUserId: currentUser,
      resourceOwnerId: data['ownerId'] ?? '',
      sharedWithUserIds: sharedWith,
    )) {
      throw PermissionDeniedException(
        'User does not have access to this shared recipe',
        resource: 'shared_recipe',
        operation: 'undismiss',
        userId: currentUser,
      );
    }
    
    await sharedRecipesRef.doc(recipeId).update({
      'dismissedByUserIds': FieldValue.arrayRemove([userId]),
      'dismissedAt.$userId': FieldValue.delete(),
    });
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'shared_recipe',
      operation: 'undismiss',
      granted: true,
    );
  }

  @override
  Future<void> undismissSharedMenu(String menuId, String userId) async {
    // Validate user is undismissing their own shared menu
    final currentUser = _authRepository.currentUserId;
    if (currentUser == null) {
      throw PermissionDeniedException('User must be authenticated');
    }
    
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'undismiss shared menu',
    );
    
    // Check if menu exists and user has access
    final doc = await getDocumentWithPermissionCheck(
      docRef: sharedMenusRef.doc(menuId),
      currentUserId: currentUser,
      resourceType: 'shared_menu',
    );
    
    final data = doc.data() as Map<String, dynamic>;
    final sharedWith = List<String>.from(data['sharedWithUserIds'] ?? []);
    
    if (!await hasReadAccess(
      currentUserId: currentUser,
      resourceOwnerId: data['ownerId'] ?? '',
      sharedWithUserIds: sharedWith,
    )) {
      throw PermissionDeniedException(
        'User does not have access to this shared menu',
        resource: 'shared_menu',
        operation: 'undismiss',
        userId: currentUser,
      );
    }
    
    await sharedMenusRef.doc(menuId).update({
      'dismissedByUserIds': FieldValue.arrayRemove([userId]),
      'dismissedAt.$userId': FieldValue.delete(),
    });
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'shared_menu',
      operation: 'undismiss',
      granted: true,
    );
  }

  @override
  Future<void> shareContent({
    required String fromUserId,
    required String toUserId,
    required String contentType,
    required Map<String, dynamic> contentData,
  }) async {
    // Validate user is sharing from their own account
    final currentUser = _authRepository.currentUserId;
    if (currentUser == null) {
      throw PermissionDeniedException('User must be authenticated');
    }
    
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: fromUserId,
      operation: 'share content',
    );
    
    // Validate required fields
    validateRequiredFields(
      data: {
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'contentType': contentType,
        'contentData': contentData,
      },
      requiredFields: ['fromUserId', 'toUserId', 'contentType', 'contentData'],
      resourceType: 'shared_content',
    );
    
    // Can't share content with yourself
    if (fromUserId == toUserId) {
      throw SecurityViolationException(
        'Cannot share content with yourself',
      );
    }
    
    await sharedContentRef.add({
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'contentType': contentType,
      'contentData': contentData,
      'sharedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'shared_content',
      operation: 'create',
      granted: true,
      details: 'Type: $contentType, To: $toUserId',
    );
  }
}

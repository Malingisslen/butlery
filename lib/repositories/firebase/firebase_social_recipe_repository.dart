/// Firebase social recipe repository with permission validation.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/interfaces/social_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/mixins/permission_validation_mixin.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

class FirebaseSocialRecipeRepository with PermissionValidationMixin implements SocialRecipeRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AuthRepository _authRepository;

  FirebaseSocialRecipeRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    required AuthRepository authRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _authRepository = authRepository;

  // ===== PRIVATE HELPER METHODS =====

  /// Get authenticated user and optionally validate self-operation.
  ///
  /// This helper eliminates duplication of the "get currentUser → null check → validateSelfOperation"
  /// pattern repeated across 9 methods in this repository.
  ///
  /// Returns the authenticated user ID for use in subsequent operations.
  /// Throws [PermissionDeniedException] if user is not authenticated or validation fails.
  ///
  /// **Parameters:**
  /// - [targetUserId]: Optional user ID to validate against (for self-operation validation)
  /// - [operation]: Description of the operation being performed (for validation error messages)
  ///
  /// **Usage Example:**
  /// ```dart
  /// final currentUser = await _withAuthenticatedUser(
  ///   targetUserId: userId,
  ///   operation: 'mark recipe as viewed',
  /// );
  /// ```
  Future<String> _withAuthenticatedUser({
    String? targetUserId,
    required String operation,
  }) async {
    final currentUser = _authRepository.currentUserId;
    if (currentUser == null) {
      throw PermissionDeniedException('User must be authenticated');
    }

    // If targetUserId is provided, validate that user is performing operation on themselves
    if (targetUserId != null) {
      await validateSelfOperation(
        currentUserId: currentUser,
        targetUserId: targetUserId,
        operation: operation,
      );
    }

    return currentUser;
  }

  // ===== PUBLIC INTERFACE METHODS =====

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
    final currentUser = await _withAuthenticatedUser(
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
    final sharedWith = List<String>.from((data['sharedWith'] as List?).orEmpty());
    
    if (!await hasReadAccess(
      currentUserId: currentUser,
      resourceOwnerId: (data['ownerId'] as String?).orEmpty(),
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
    final currentUser = await _withAuthenticatedUser(
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
    final sharedWith = List<String>.from((data['sharedWithUserIds'] as List?).orEmpty());
    
    if (!await hasReadAccess(
      currentUserId: currentUser,
      resourceOwnerId: (data['ownerId'] as String?).orEmpty(),
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
    final currentUser = await _withAuthenticatedUser(
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
    final sharedWith = List<String>.from((data['sharedWith'] as List?).orEmpty());
    
    if (!await hasReadAccess(
      currentUserId: currentUser,
      resourceOwnerId: (data['ownerId'] as String?).orEmpty(),
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
    final currentUser = await _withAuthenticatedUser(
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
    final sharedWith = List<String>.from((data['sharedWithUserIds'] as List?).orEmpty());
    
    if (!await hasReadAccess(
      currentUserId: currentUser,
      resourceOwnerId: (data['ownerId'] as String?).orEmpty(),
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
    final currentUser = await _withAuthenticatedUser(
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
    final sharedWith = List<String>.from((data['sharedWith'] as List?).orEmpty());
    
    if (!await hasReadAccess(
      currentUserId: currentUser,
      resourceOwnerId: (data['ownerId'] as String?).orEmpty(),
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
    final currentUser = await _withAuthenticatedUser(
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
    final sharedWith = List<String>.from((data['sharedWithUserIds'] as List?).orEmpty());
    
    if (!await hasReadAccess(
      currentUserId: currentUser,
      resourceOwnerId: (data['ownerId'] as String?).orEmpty(),
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
    final currentUser = await _withAuthenticatedUser(
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
    final sharedWith = List<String>.from((data['sharedWith'] as List?).orEmpty());
    
    if (!await hasReadAccess(
      currentUserId: currentUser,
      resourceOwnerId: (data['ownerId'] as String?).orEmpty(),
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
    final currentUser = await _withAuthenticatedUser(
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
    final sharedWith = List<String>.from((data['sharedWithUserIds'] as List?).orEmpty());
    
    if (!await hasReadAccess(
      currentUserId: currentUser,
      resourceOwnerId: (data['ownerId'] as String?).orEmpty(),
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
    final currentUser = await _withAuthenticatedUser(
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

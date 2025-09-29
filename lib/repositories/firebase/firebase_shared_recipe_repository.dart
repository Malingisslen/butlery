/// Firebase repository for shared recipe management with consistent invitation patterns.
///
/// This repository implements unified recipe sharing functionality following Single Responsibility Principle,
/// matching the patterns established by SharedShoppingList repository for consistent API design.
/// It provides complete shared recipe operations while maintaining clean separation from
/// business logic and ensuring consistent behavior across all shared content types.
///
/// **Single Responsibility Focus:**
/// This repository exclusively handles shared recipe data operations:
/// - **Shared Recipe Storage**: Complete CRUD operations for shared recipes in Firestore
/// - **Status Management**: Read/unread, imported/dismissed status tracking with atomic updates
/// - **Permission Validation**: Comprehensive access control for shared recipe operations
/// - **Query Operations**: Efficient retrieval of shared recipes with user-specific filtering
///
/// **What This Repository Does NOT Handle:**
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Business logic and validation (handled by services and business layer)
/// - Recipe creation and editing (handled by recipe services)
/// - User authentication (handled by auth services)
///
/// **Shared Recipe Repository Features:**
/// - **Consistent API**: Unified operations matching SharedShoppingList patterns
/// - **Status Tracking**: Read/unread, imported/dismissed status with efficient batch updates
/// - **Permission Security**: Comprehensive access validation with audit logging
/// - **Query Optimization**: Efficient Firestore queries with user-specific filtering
/// - **Error Handling**: Robust exception handling with meaningful error messages
///
/// **Usage Examples:**
/// ```dart
/// // Initialize repository
/// final sharedRecipeRepo = FirebaseSharedRecipeRepository();
///
/// // Create shared recipe
/// final sharedRecipe = SharedRecipe.create(
///   originalRecipeId: recipeId,
///   sharedByUserId: currentUserId,
///   sharedByDisplayName: 'Anna Andersson',
///   sharedToUserIds: [friend1Id, friend2Id],
///   shareMessage: 'Hoppas ni gillar detta familjerecept!',
///   recipeSnapshot: originalRecipe,
/// );
/// await sharedRecipeRepo.createSharedRecipe(sharedRecipe);
///
/// // Get shared recipes for user
/// final sharedRecipes = await sharedRecipeRepo.getSharedRecipesForUser(userId);
///
/// // Update status
/// await sharedRecipeRepo.markAsViewed(recipeId, userId);
/// await sharedRecipeRepo.markAsImported(recipeId, userId);
/// await sharedRecipeRepo.markAsDismissed(recipeId, userId);
/// ```

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/repositories/firebase/base_shared_content_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/core/utils/logger.dart';

/// Firebase repository for shared recipe operations with consistent API patterns
class FirebaseSharedRecipeRepository
    extends BaseSharedContentRepository<SharedRecipe> {
  FirebaseSharedRecipeRepository({
    super.firestore,
    AuthRepository? authRepository,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  @override
  String get collectionName => 'shared_recipes';

  // ===== BASE SHARED CONTENT REPOSITORY IMPLEMENTATIONS =====

  @override
  String get contentTypeName => 'recipe';

  @override
  String get resourceType => 'shared_recipe';

  @override
  List<String> get createRequiredFields => ['recipeSnapshot'];

  @override
  String getContentTitle(SharedRecipe entity) => entity.recipeSnapshot.title;

  @override
  String get importAction => 'imported';

  @override
  String get importField => 'importedByUserIds';

  @override
  bool get supportsCollaboration => true;

  @override
  bool get tracksCounts => true;

  // ===== COLLECTION REFERENCE =====

  @override
  CollectionReference<Map<String, dynamic>> getCollectionRef() {
    return firestore.collection('shared_recipes');
  }

  // ===== SERIALIZATION METHODS =====

  @override
  SharedRecipe fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return SharedRecipe.fromMap(doc.id, doc.data()!);
  }

  @override
  Map<String, dynamic> toFirestore(SharedRecipe entity) {
    return entity.toFirestore();
  }

  @override
  String getId(SharedRecipe entity) => entity.id;

  // ===== FILTERING METHOD IMPLEMENTATIONS =====

  @override
  bool shouldShowToUser(SharedRecipe content, String userId) {
    return content.canBeViewedBy(userId) && !content.isDismissedBy(userId);
  }

  @override
  bool isViewedByUser(SharedRecipe content, String userId) {
    return content.isViewedBy(userId);
  }

  @override
  bool isCreatedBy(SharedRecipe content, String userId) {
    return content.sharedByUserId == userId;
  }

  // ===== SHARED RECIPE OPERATIONS =====

  /// Create new shared recipe with comprehensive validation
  Future<String> createSharedRecipe(SharedRecipe sharedRecipe) async {
    final uid = requireCurrentUserId();

    // Recipe-specific validations
    if (sharedRecipe.sharedByUserId != uid) {
      throw PermissionDeniedException(
          'Cannot create shared recipe for another user');
    }

    if (sharedRecipe.sharedToUserIds.isEmpty) {
      throw ArgumentError('Must specify at least one recipient');
    }

    // Delegate to base class method with all validation and creation logic
    return await createSharedContent(sharedRecipe);
  }

  /// Get all shared recipes for a specific user
  Future<List<SharedRecipe>> getSharedRecipesForUser(String userId) async {
    // Delegate to base class method with all validation and query logic
    return await getSharedContentForUser(userId);
  }

  /// Get specific shared recipe by ID
  Future<SharedRecipe?> getSharedRecipe(String recipeId) async {
    final uid = requireCurrentUserId();

    // Use base class method for retrieval
    final sharedRecipe = await read(recipeId);
    
    if (sharedRecipe == null) {
      return null;
    }

    // Recipe-specific permission validation
    if (!sharedRecipe.canBeViewedBy(uid)) {
      throw PermissionDeniedException('Cannot access this shared recipe');
    }

    // Recipe-specific logging
    logPermissionCheck(
      userId: uid,
      resource: 'shared_recipe',
      operation: 'read',
      granted: true,
      details: 'Recipe: "${sharedRecipe.recipeSnapshot.title}" ($recipeId)',
    );

    return sharedRecipe;
  }

  // ===== STATUS MANAGEMENT (DELEGATED TO BASE CLASS) =====

  /// Mark shared recipe as viewed by user
  @override
  Future<void> markAsViewed(String recipeId, String userId) async {
    // Delegate to base class method
    return await super.markAsViewed(recipeId, userId);
  }

  /// Mark shared recipe as imported by user (copy-on-write)
  Future<void> markAsImported(String recipeId, String userId) async {
    // Delegate to base class method with unified import/join handling
    return await markAsImportedOrJoined(recipeId, userId);
  }

  /// Mark shared recipe as dismissed by user
  @override
  Future<void> markAsDismissed(String recipeId, String userId) async {
    // Delegate to base class method
    return await super.markAsDismissed(recipeId, userId);
  }

  /// Remove dismissal status for user (restore visibility)
  @override
  Future<void> undismiss(String recipeId, String userId) async {
    // Delegate to base class method
    return await super.undismiss(recipeId, userId);
  }

  /// Delete shared recipe (only by creator)
  Future<void> deleteSharedRecipe(String recipeId) async {
    // Delegate to base class method
    return await deleteSharedContent(recipeId);
  }

  // ===== QUERY METHODS (DELEGATED TO BASE CLASS) =====

  /// Get unread shared recipes count for user
  @override
  Future<int> getUnreadCountForUser(String userId) async {
    // Delegate to base class method
    return await super.getUnreadCountForUser(userId);
  }

  /// Get imported shared recipes for user
  Future<List<SharedRecipe>> getImportedRecipesForUser(String userId) async {
    final uid = requireCurrentUserId();

    if (userId != uid) {
      throw PermissionDeniedException(
          'Cannot get imported recipes for another user');
    }

    try {
      final allSharedRecipes = await getSharedRecipesForUser(userId);

      final importedRecipes =
          allSharedRecipes.where((recipe) => recipe.isImportedBy(userId)).toList();

      AppLogger.info(
          '📋 User $userId has imported ${importedRecipes.length} shared recipes');
      return importedRecipes;
    } catch (e) {
      AppLogger.error('Failed to get imported recipes for user $userId: $e');
      throw RepositoryException('Failed to get imported recipes: $e');
    }
  }
}
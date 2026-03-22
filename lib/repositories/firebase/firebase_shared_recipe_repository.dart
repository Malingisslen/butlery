/// Firebase repository for shared recipe management with consistent invitation patterns.
/// This repository implements unified recipe sharing functionality following Single Responsibility Principle,
/// matching the patterns established by SharedShoppingList repository for consistent API design.
/// It provides complete shared recipe operations while maintaining clean separation from
/// business logic and ensuring consistent behavior across all shared content types.
/// **Single Responsibility Focus:**
/// This repository exclusively handles shared recipe data operations:
/// - **Shared Recipe Storage**: Complete CRUD operations for shared recipes in Firestore
/// - **Status Management**: Read/unread, imported/dismissed status tracking with atomic updates
/// - **Permission Validation**: Comprehensive access control for shared recipe operations
/// - **Query Operations**: Efficient retrieval of shared recipes with user-specific filtering
/// **What This Repository Does NOT Handle:**
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Business logic and validation (handled by services and business layer)
/// - Recipe creation and editing (handled by recipe services)
/// - User authentication (handled by auth services)
/// **Shared Recipe Repository Features:**
/// - **Consistent API**: Unified operations matching SharedShoppingList patterns
/// - **Status Tracking**: Read/unread, imported/dismissed status with efficient batch updates
/// - **Permission Security**: Comprehensive access validation with audit logging
/// - **Query Optimization**: Efficient Firestore queries with user-specific filtering
/// - **Error Handling**: Robust exception handling with meaningful error messages
/// **Usage Examples:**
/// ```dart
/// // Initialize repository
/// final sharedRecipeRepo = FirebaseSharedRecipeRepository();
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
/// // Get shared recipes for user
/// final sharedRecipes = await sharedRecipeRepo.getSharedRecipesForUser(userId);
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
import 'package:butlery/repositories/firebase/base_view_repository.dart';
import 'package:butlery/repositories/firebase/base_engagement_repository.dart';
import 'package:butlery/repositories/firebase/base_dismissal_repository.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_recipe_view_repository.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_recipe_engagement_repository.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_recipe_dismissal_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase repository for shared recipe operations with consistent API patterns
class FirebaseSharedRecipeRepository
    extends BaseSharedContentRepository<SharedRecipe> {
  final SharedRecipeViewRepository _viewRepository;
  final SharedRecipeEngagementRepository _engagementRepository;
  final SharedRecipeDismissalRepository _dismissalRepository;

  FirebaseSharedRecipeRepository({
    super.firestore,
    AuthRepository? authRepository,
    SharedRecipeViewRepository? viewRepository,
    SharedRecipeEngagementRepository? engagementRepository,
    SharedRecipeDismissalRepository? dismissalRepository,
  })  : _viewRepository = viewRepository ??
            SharedRecipeViewRepository(
              authRepository: authRepository ?? FirebaseAuthRepository(),
            ),
        _engagementRepository = engagementRepository ??
            SharedRecipeEngagementRepository(
              authRepository: authRepository ?? FirebaseAuthRepository(),
            ),
        _dismissalRepository = dismissalRepository ??
            SharedRecipeDismissalRepository(
              authRepository: authRepository ?? FirebaseAuthRepository(),
            ),
        super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  @override
  String get collectionName => FirestoreCollections.sharedRecipes;
  @override
  BaseViewRepository get viewRepository => _viewRepository;

  @override
  BaseEngagementRepository get engagementRepository => _engagementRepository;

  @override
  BaseDismissalRepository get dismissalRepository => _dismissalRepository;
  @override
  String get contentTypeName => 'recipe';

  @override
  String get counterTypeKey => 'shared_recipes';

  @override
  String get resourceType => 'shared_recipe';

  @override
  List<String> get createRequiredFields => ['recipeTitle'];

  @override
  String getContentTitle(SharedRecipe entity) => entity.recipeTitle;

  @override
  String get importAction => 'imported';

  @override
  String get importField => 'importedByUserIds';

  @override
  bool get supportsCollaboration => true;

  @override
  bool get tracksCounts => true;
  @override
  CollectionReference<Map<String, dynamic>> getCollectionRef() {
    return firestore.collection(FirestoreCollections.sharedRecipes);
  }

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

  @override
  bool shouldShowToUser(SharedRecipe content, String userId) {
    // Issue #014 Migration: If content was found via subcollection query,
    // the user is already verified as a member. Always show.
    // The query itself (members subcollection) handles access control.
    return true;
  }

  @override
  bool isViewedByUser(SharedRecipe content, String userId) {
    // Note (Issue #014): Array-based status removed.
    // Use hasViewed() repository method for actual viewed status.
    // This sync method defaults to false; call hasViewed() for accurate status.
    return false;
  }

  @override
  bool isCreatedBy(SharedRecipe content, String userId) {
    return content.sharedByUserId == userId;
  }

  @override
  DateTime getContentDate(SharedRecipe entity) => entity.sharedAt;

  /// Create new shared recipe with comprehensive validation
  /// Note (Issue #014): recipientIds must be passed separately as sharedToUserIds
  /// is no longer stored in the model (tracked in Firestore subcollections instead).
  Future<String> createSharedRecipe(
    SharedRecipe sharedRecipe, {
    required List<String> recipientIds,
  }) async {
    final uid = requireCurrentUserId();

    // Recipe-specific validations
    if (sharedRecipe.sharedByUserId != uid) {
      throw PermissionDeniedException(
          'Cannot create shared recipe for another user');
    }

    if (recipientIds.isEmpty) {
      throw ArgumentError('Must specify at least one recipient');
    }

    // Create the shared recipe document (seed creator in sharedToUserIds to avoid extra write)
    final recipeId = await createSharedContent(sharedRecipe,
        initialSharedToUserIds: [sharedRecipe.sharedByUserId]);

    // Add all recipients concurrently — each addMember also appends to sharedToUserIds
    await Future.wait(
      recipientIds.map((id) => addMember(recipeId, id, addedBy: uid)),
    );

    AppLogger.success(
        '✅ Created shared recipe with ${recipientIds.length} members in subcollection');

    return recipeId;
  }

  /// Get all shared recipes for a specific user
  Future<List<SharedRecipe>> getSharedRecipesForUser(String userId) async {
    // Use subcollection-based query (Issue #014: Unlimited sharing support)
    return await getSharedContentForUserViaSubcollection(userId);
  }

  /// Get specific shared recipe by ID
  Future<SharedRecipe?> getSharedRecipe(String recipeId) async {
    final uid = requireCurrentUserId();

    // Fetch document directly without base class permission check (Issue #014)
    // We need to check members subcollection, which requires async call
    final doc = await getCollectionRef().doc(recipeId).get();

    if (!doc.exists) {
      return null;
    }

    final sharedRecipe = fromFirestore(doc);

    // Recipe-specific permission validation (Issue #014)
    // Check if user is owner or member via subcollection
    final isOwner = sharedRecipe.sharedByUserId == uid;
    final isMember = await this.isMember(recipeId, uid);
    final canAccess = isOwner || isMember;

    if (!canAccess) {
      throw PermissionDeniedException('Cannot access this shared recipe');
    }

    // Recipe-specific logging
    logPermissionCheck(
      userId: uid,
      resource: 'shared_recipe',
      operation: 'read',
      granted: true,
      details: 'Recipe: "${sharedRecipe.recipeTitle}" ($recipeId)',
    );

    return sharedRecipe;
  }

  /// Mark shared recipe as viewed by user
  @override
  Future<void> markAsViewed(String recipeId, String userId) async {
    await addView(recipeId, userId);
    await decrementUnreadCounter(userId);
  }

  /// Mark shared recipe as imported by user (copy-on-write)
  Future<void> markAsImported(String recipeId, String userId) async {
    // Use subcollection method (Issue #014: Unlimited imports support)
    return await addEngagement(recipeId, userId, action: 'import');
  }

  /// Mark shared recipe as dismissed by user
  @override
  Future<void> markAsDismissed(String recipeId, String userId) async {
    // Use subcollection method (Issue #014: Unlimited dismissals support)
    return await addDismissal(recipeId, userId);
  }

  /// Remove dismissal status for user (restore visibility)
  @override
  Future<void> undismiss(String recipeId, String userId) async {
    // Use subcollection method (Issue #014)
    return await removeDismissal(recipeId, userId);
  }

  /// Delete shared recipe (only by creator)
  Future<void> deleteSharedRecipe(String recipeId) async {
    // Delegate to base class method
    return await deleteSharedContent(recipeId);
  }

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
      // Query engagements subcollection (Issue #014: Unlimited imports support)
      final engagementsSnapshot = await firestore
          .collectionGroup('engagements')
          .where('userId', isEqualTo: userId)
          .where('action', isEqualTo: 'import')
          .limit(200)
          .get();

      if (engagementsSnapshot.docs.isEmpty) {
        AppLogger.info(
            '📋 User ${userId.maskedUserId} has no imported recipes');
        return [];
      }

      // Extract recipe IDs from engagement documents
      final recipeIds = <String>{};
      for (final engagementDoc in engagementsSnapshot.docs) {
        final recipeId = engagementDoc.reference.parent.parent?.id;
        if (recipeId != null) {
          recipeIds.add(recipeId);
        }
      }

      // Batch fetch recipe documents (max 10 per query)
      final importedRecipes = <SharedRecipe>[];
      final recipeIdList = recipeIds.toList();
      for (var i = 0; i < recipeIdList.length; i += 10) {
        final end =
            (i + 10 < recipeIdList.length) ? i + 10 : recipeIdList.length;
        final batch = recipeIdList.sublist(i, end);

        final batchSnapshot = await getCollectionRef()
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        importedRecipes.addAll(
          batchSnapshot.docs.map((doc) => fromFirestore(doc)),
        );
      }

      AppLogger.info(
          '📋 User ${userId.maskedUserId} has imported ${importedRecipes.length} shared recipes');
      return importedRecipes;
    } catch (e) {
      AppLogger.error(
          'Failed to get imported recipes for user ${userId.maskedUserId}: $e');
      throw RepositoryException('Failed to get imported recipes: $e');
    }
  }
}

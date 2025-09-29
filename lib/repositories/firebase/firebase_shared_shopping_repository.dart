/// Firebase repository for shared shopping list management with consistent sharing patterns.
///
/// This repository implements unified sharing functionality following Single Responsibility Principle,
/// matching the patterns established by other shared content repositories for consistent API design.
/// It provides complete shared shopping list operations while maintaining clean separation from
/// business logic and ensuring consistent behavior across all shared content types.
///
/// **Single Responsibility Focus:**
/// This repository exclusively handles shared shopping list data operations:
/// - **Shared Shopping List Storage**: Complete CRUD operations for shared shopping lists in Firestore
/// - **Status Management**: Read/unread, joined/dismissed status tracking with atomic updates
/// - **Permission Validation**: Comprehensive access control for shared shopping list operations
/// - **Query Operations**: Efficient retrieval of shared lists with user-specific filtering
///
/// **What This Repository Does NOT Handle:**
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Business logic and validation (handled by services and business layer)
/// - Collaborative list creation (handled by shopping services)
/// - User authentication (handled by auth services)
///
/// **Shared Shopping Repository Features:**
/// - **Consistent API**: Unified operations matching SharedRecipe and SharedMenu patterns
/// - **Status Tracking**: Read/unread, joined/dismissed status with efficient batch updates
/// - **Permission Security**: Comprehensive access validation with audit logging
/// - **Query Optimization**: Efficient Firestore queries with user-specific filtering
/// - **Error Handling**: Robust exception handling with meaningful error messages
///
/// **Usage Examples:**
/// ```dart
/// // Initialize repository
/// final sharedShoppingRepo = FirebaseSharedShoppingRepository();
///
/// // Create shared shopping list
/// final sharedList = SharedShoppingList.create(
///   sharedByUserId: currentUserId,
///   sharedByDisplayName: 'Anna Andersson',
///   sharedToUserIds: [friend1Id, friend2Id],
///   shareMessage: 'Min veckohandling',
///   listName: 'Veckohandling v.45',
///   listItems: items,
/// );
/// await sharedShoppingRepo.createSharedShoppingList(sharedList);
///
/// // Get shared lists for user
/// final sharedLists = await sharedShoppingRepo.getSharedShoppingListsForUser(userId);
///
/// // Update status
/// await sharedShoppingRepo.markAsViewed(listId, userId);
/// await sharedShoppingRepo.markAsJoined(listId, userId);
/// await sharedShoppingRepo.markAsDismissed(listId, userId);
/// ```

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/repositories/firebase/base_shared_content_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/core/utils/logger.dart';

/// Firebase repository for shared shopping list operations with consistent API patterns
class FirebaseSharedShoppingRepository
    extends BaseSharedContentRepository<SharedShoppingList> {
  FirebaseSharedShoppingRepository({
    super.firestore,
    AuthRepository? authRepository,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  @override
  String get collectionName => 'shared_shopping_lists';

  // ===== BASE SHARED CONTENT REPOSITORY IMPLEMENTATIONS =====

  @override
  String get contentTypeName => 'shopping_list';

  @override
  String get resourceType => 'shared_shopping_list';

  @override
  List<String> get createRequiredFields => ['listItems', 'listName'];

  @override
  String getContentTitle(SharedShoppingList entity) => entity.listName;

  @override
  String get importAction => 'joined';

  @override
  String get importField => 'joinedByUserIds';

  @override
  bool get supportsCollaboration => true;

  @override
  bool get tracksCounts => false; // Shopping lists don't track view/join counts

  // ===== COLLECTION REFERENCE =====

  @override
  CollectionReference<Map<String, dynamic>> getCollectionRef() {
    return firestore.collection('shared_shopping_lists');
  }

  // ===== SERIALIZATION METHODS =====

  @override
  SharedShoppingList fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return SharedShoppingList.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore(SharedShoppingList entity) {
    return entity.toFirestore();
  }

  @override
  String getId(SharedShoppingList entity) => entity.id;

  // ===== FILTERING METHOD IMPLEMENTATIONS =====

  @override
  bool shouldShowToUser(SharedShoppingList content, String userId) {
    return content.shouldBeShownTo(userId); // Shopping lists use shouldBeShownTo instead of canBeViewedBy && !isDismissedBy
  }

  @override
  bool isViewedByUser(SharedShoppingList content, String userId) {
    return content.isViewedBy(userId);
  }

  @override
  bool isCreatedBy(SharedShoppingList content, String userId) {
    return content.sharedByUserId == userId;
  }

  // ===== SHARED SHOPPING LIST OPERATIONS =====

  /// Create new shared shopping list with comprehensive validation
  Future<String> createSharedShoppingList(
      SharedShoppingList sharedShoppingList) async {
    final uid = requireCurrentUserId();

    // Shopping list-specific validations
    if (sharedShoppingList.sharedByUserId != uid) {
      throw PermissionDeniedException(
          'Cannot create shared shopping list for another user');
    }

    if (sharedShoppingList.sharedToUserIds.isEmpty) {
      throw ArgumentError('Must specify at least one recipient');
    }

    // Delegate to base class method with all validation and creation logic
    return await createSharedContent(sharedShoppingList);
  }

  /// Get all shared shopping lists for a specific user
  Future<List<SharedShoppingList>> getSharedShoppingListsForUser(
      String userId) async {
    // Delegate to base class method with all validation and query logic
    return await getSharedContentForUser(userId);
  }

  /// Get specific shared shopping list by ID
  Future<SharedShoppingList?> getSharedShoppingList(String listId) async {
    final uid = requireCurrentUserId();

    // Use base class method for retrieval
    final sharedList = await read(listId);
    
    if (sharedList == null) {
      return null;
    }

    // Shopping list-specific permission validation
    if (!sharedList.canBeViewedBy(uid)) {
      throw PermissionDeniedException(
          'Cannot access this shared shopping list');
    }

    // Shopping list-specific logging
    logPermissionCheck(
      userId: uid,
      resource: 'shared_shopping_list',
      operation: 'read',
      granted: true,
      details: 'List: "${sharedList.listName}" ($listId)',
    );

    return sharedList;
  }

  // ===== STATUS MANAGEMENT =====

  /// Mark shared shopping list as viewed by user
  @override
  Future<void> markAsViewed(String listId, String userId) async {
    // Delegate to base class method
    return await super.markAsViewed(listId, userId);
  }

  /// Mark shared shopping list as joined by user
  Future<void> markAsJoined(String listId, String userId) async {
    // Delegate to base class method with unified import/join handling
    return await markAsImportedOrJoined(listId, userId);
  }

  /// Mark shared shopping list as dismissed by user
  @override
  Future<void> markAsDismissed(String listId, String userId) async {
    // Delegate to base class method
    return await super.markAsDismissed(listId, userId);
  }

  /// Remove dismissal status for user (restore visibility)
  @override
  Future<void> undismiss(String listId, String userId) async {
    // Delegate to base class method
    return await super.undismiss(listId, userId);
  }

  /// Delete shared shopping list (only by creator)
  Future<void> deleteSharedShoppingList(String listId) async {
    // Delegate to base class method
    return await deleteSharedContent(listId);
  }

  // ===== QUERY METHODS (DELEGATED TO BASE CLASS) =====

  /// Get unread shared shopping lists count for user
  @override
  Future<int> getUnreadCountForUser(String userId) async {
    // Delegate to base class method
    return await super.getUnreadCountForUser(userId);
  }

  // ===== CONTENT-SPECIFIC METHODS =====

  /// Get joined shared shopping lists for user
  Future<List<SharedShoppingList>> getJoinedShoppingListsForUser(String userId) async {
    final uid = requireCurrentUserId();

    if (userId != uid) {
      throw PermissionDeniedException(
          'Cannot get joined lists for another user');
    }

    try {
      // Get all shared shopping lists and filter for joined ones
      final allSharedLists = await getSharedShoppingListsForUser(userId);
      return allSharedLists.where((list) => list.isJoinedBy(userId)).toList();
    } catch (e) {
      AppLogger.error('Failed to get joined shopping lists for user $userId: $e');
      throw RepositoryException('Failed to retrieve joined shopping lists: $e');
    }
  }
}

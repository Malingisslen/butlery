/// Firebase repository for shared menu management with consistent invitation patterns.
///
/// This repository implements unified menu sharing functionality following Single Responsibility Principle,
/// matching the patterns established by SharedShoppingList and SharedRecipe repositories for consistent API design.
/// It provides complete shared menu operations while maintaining clean separation from
/// business logic and ensuring consistent behavior across all shared content types.
///
/// **Single Responsibility Focus:**
/// This repository exclusively handles shared menu data operations:
/// - **Shared Menu Storage**: Complete CRUD operations for shared menus in Firestore
/// - **Status Management**: Read/unread, imported/dismissed status tracking with atomic updates
/// - **Permission Validation**: Comprehensive access control for shared menu operations
/// - **Query Operations**: Efficient retrieval of shared menus with user-specific filtering
///
/// **What This Repository Does NOT Handle:**
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Business logic and validation (handled by services and business layer)
/// - Menu creation and editing (handled by menu services)
/// - User authentication (handled by auth services)
///
/// **Shared Menu Repository Features:**
/// - **Consistent API**: Unified operations matching SharedRecipe and SharedShoppingList patterns
/// - **Status Tracking**: Read/unread, imported/dismissed status with efficient batch updates
/// - **Permission Security**: Comprehensive access validation with audit logging
/// - **Query Optimization**: Efficient Firestore queries with user-specific filtering
/// - **Error Handling**: Robust exception handling with meaningful error messages
///
/// **Usage Examples:**
/// ```dart
/// // Initialize repository
/// final sharedMenuRepo = FirebaseSharedMenuRepository();
///
/// // Create shared menu
/// final sharedMenu = SharedMenu.create(
///   sharedByUserId: currentUserId,
///   sharedByDisplayName: 'Anna Andersson',
///   sharedToUserIds: [friend1Id, friend2Id],
///   shareMessage: 'Min veckomeny för nästa vecka!',
///   menuTitle: 'Annas veckomeny v.45',
///   menuSnapshot: weeklyMenu,
/// );
/// await sharedMenuRepo.createSharedMenu(sharedMenu);
///
/// // Get shared menus for user
/// final sharedMenus = await sharedMenuRepo.getSharedMenusForUser(userId);
///
/// // Update status
/// await sharedMenuRepo.markAsViewed(menuId, userId);
/// await sharedMenuRepo.markAsImported(menuId, userId);
/// await sharedMenuRepo.markAsDismissed(menuId, userId);
/// ```

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/repositories/firebase/base_shared_content_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/core/utils/logger.dart';

/// Firebase repository for shared menu operations with consistent API patterns
class FirebaseSharedMenuRepository
    extends BaseSharedContentRepository<SharedMenu> {
  FirebaseSharedMenuRepository({
    super.firestore,
    AuthRepository? authRepository,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  @override
  String get collectionName => 'shared_menus';

  // ===== BASE SHARED CONTENT REPOSITORY IMPLEMENTATIONS =====

  @override
  String get contentTypeName => 'menu';

  @override
  String get resourceType => 'shared_menu';

  @override
  List<String> get createRequiredFields => ['menuSnapshot'];

  @override
  String getContentTitle(SharedMenu entity) => entity.menuTitle;

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
    return firestore.collection('shared_menus');
  }

  // ===== SERIALIZATION METHODS =====

  @override
  SharedMenu fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return SharedMenu.fromFirestore(doc.data()!, doc.id);
  }

  @override
  Map<String, dynamic> toFirestore(SharedMenu entity) {
    return entity.toFirestore();
  }

  @override
  String getId(SharedMenu entity) => entity.id;

  // ===== FILTERING METHOD IMPLEMENTATIONS =====

  @override
  bool shouldShowToUser(SharedMenu content, String userId) {
    return content.canBeViewedBy(userId) && !content.isDismissedBy(userId);
  }

  @override
  bool isViewedByUser(SharedMenu content, String userId) {
    return content.isViewedBy(userId);
  }

  @override
  bool isCreatedBy(SharedMenu content, String userId) {
    return content.sharedByUserId == userId;
  }

  // ===== SHARED MENU OPERATIONS =====

  /// Create new shared menu with comprehensive validation
  Future<String> createSharedMenu(SharedMenu sharedMenu) async {
    final uid = requireCurrentUserId();

    // Menu-specific validations
    if (sharedMenu.sharedByUserId != uid) {
      throw PermissionDeniedException(
          'Cannot create shared menu for another user');
    }

    if (sharedMenu.sharedToUserIds.isEmpty) {
      throw ArgumentError('Must specify at least one recipient');
    }

    // Delegate to base class method with all validation and creation logic
    return await createSharedContent(sharedMenu);
  }

  /// Get all shared menus for a specific user
  Future<List<SharedMenu>> getSharedMenusForUser(String userId) async {
    // Delegate to base class method with all validation and query logic
    return await getSharedContentForUser(userId);
  }

  /// Get specific shared menu by ID
  Future<SharedMenu?> getSharedMenu(String menuId) async {
    final uid = requireCurrentUserId();

    // Use base class method for retrieval
    final sharedMenu = await read(menuId);
    
    if (sharedMenu == null) {
      return null;
    }

    // Menu-specific permission validation
    if (!sharedMenu.canBeViewedBy(uid)) {
      throw PermissionDeniedException('Cannot access this shared menu');
    }

    // Menu-specific logging
    logPermissionCheck(
      userId: uid,
      resource: 'shared_menu',
      operation: 'read',
      granted: true,
      details: 'Menu: "${sharedMenu.menuTitle}" ($menuId)',
    );

    return sharedMenu;
  }

  // ===== STATUS MANAGEMENT (DELEGATED TO BASE CLASS) =====

  /// Mark shared menu as viewed by user
  @override
  Future<void> markAsViewed(String menuId, String userId) async {
    // Delegate to base class method
    return await super.markAsViewed(menuId, userId);
  }

  /// Mark shared menu as imported by user (copy-on-write)
  Future<void> markAsImported(String menuId, String userId) async {
    // Delegate to base class method with unified import/join handling
    return await markAsImportedOrJoined(menuId, userId);
  }

  /// Mark shared menu as dismissed by user
  @override
  Future<void> markAsDismissed(String menuId, String userId) async {
    // Delegate to base class method
    return await super.markAsDismissed(menuId, userId);
  }

  /// Remove dismissal status for user (restore visibility)
  @override
  Future<void> undismiss(String menuId, String userId) async {
    // Delegate to base class method
    return await super.undismiss(menuId, userId);
  }

  /// Delete shared menu (only by creator)
  Future<void> deleteSharedMenu(String menuId) async {
    // Delegate to base class method
    return await deleteSharedContent(menuId);
  }

  // ===== QUERY METHODS (DELEGATED TO BASE CLASS) =====

  /// Get unread shared menus count for user
  @override
  Future<int> getUnreadCountForUser(String userId) async {
    // Delegate to base class method
    return await super.getUnreadCountForUser(userId);
  }

  /// Get imported shared menus for user
  Future<List<SharedMenu>> getImportedMenusForUser(String userId) async {
    final uid = requireCurrentUserId();

    if (userId != uid) {
      throw PermissionDeniedException(
          'Cannot get imported menus for another user');
    }

    try {
      final allSharedMenus = await getSharedMenusForUser(userId);

      final importedMenus =
          allSharedMenus.where((menu) => menu.isImportedBy(userId)).toList();

      AppLogger.info(
          '📋 User $userId has imported ${importedMenus.length} shared menus');
      return importedMenus;
    } catch (e) {
      AppLogger.error('Failed to get imported menus for user $userId: $e');
      throw RepositoryException('Failed to get imported menus: $e');
    }
  }
}
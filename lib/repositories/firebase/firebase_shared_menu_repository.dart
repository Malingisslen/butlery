/// Firebase repository for shared menu management with consistent invitation patterns.
/// This repository implements unified menu sharing functionality following Single Responsibility Principle,
/// matching the patterns established by SharedShoppingList and SharedRecipe repositories for consistent API design.
/// It provides complete shared menu operations while maintaining clean separation from
/// business logic and ensuring consistent behavior across all shared content types.
/// **Single Responsibility Focus:**
/// This repository exclusively handles shared menu data operations:
/// - **Shared Menu Storage**: Complete CRUD operations for shared menus in Firestore
/// - **Status Management**: Read/unread, imported/dismissed status tracking with atomic updates
/// - **Permission Validation**: Comprehensive access control for shared menu operations
/// - **Query Operations**: Efficient retrieval of shared menus with user-specific filtering
/// **What This Repository Does NOT Handle:**
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Business logic and validation (handled by services and business layer)
/// - Menu creation and editing (handled by menu services)
/// - User authentication (handled by auth services)
/// **Shared Menu Repository Features:**
/// - **Consistent API**: Unified operations matching SharedRecipe and SharedShoppingList patterns
/// - **Status Tracking**: Read/unread, imported/dismissed status with efficient batch updates
/// - **Permission Security**: Comprehensive access validation with audit logging
/// - **Query Optimization**: Efficient Firestore queries with user-specific filtering
/// - **Error Handling**: Robust exception handling with meaningful error messages
/// **Usage Examples:**
/// ```dart
/// // Initialize repository
/// final sharedMenuRepo = FirebaseSharedMenuRepository();
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
/// // Get shared menus for user
/// final sharedMenus = await sharedMenuRepo.getSharedMenusForUser(userId);
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
import 'package:butlery/repositories/firebase/base_view_repository.dart';
import 'package:butlery/repositories/firebase/base_engagement_repository.dart';
import 'package:butlery/repositories/firebase/base_dismissal_repository.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_menu_view_repository.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_menu_engagement_repository.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_menu_dismissal_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/core/utils/logger.dart';

/// Firebase repository for shared menu operations with consistent API patterns
class FirebaseSharedMenuRepository
    extends BaseSharedContentRepository<SharedMenu> {
  final SharedMenuViewRepository _viewRepository;
  final SharedMenuEngagementRepository _engagementRepository;
  final SharedMenuDismissalRepository _dismissalRepository;

  FirebaseSharedMenuRepository({
    super.firestore,
    AuthRepository? authRepository,
    SharedMenuViewRepository? viewRepository,
    SharedMenuEngagementRepository? engagementRepository,
    SharedMenuDismissalRepository? dismissalRepository,
  })  : _viewRepository = viewRepository ??
            SharedMenuViewRepository(
              authRepository: authRepository ?? FirebaseAuthRepository(),
            ),
        _engagementRepository = engagementRepository ??
            SharedMenuEngagementRepository(
              authRepository: authRepository ?? FirebaseAuthRepository(),
            ),
        _dismissalRepository = dismissalRepository ??
            SharedMenuDismissalRepository(
              authRepository: authRepository ?? FirebaseAuthRepository(),
            ),
        super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  @override
  String get collectionName => 'shared_menus';

  // ===== METADATA REPOSITORY GETTERS =====

  @override
  BaseViewRepository get viewRepository => _viewRepository;

  @override
  BaseEngagementRepository get engagementRepository => _engagementRepository;

  @override
  BaseDismissalRepository get dismissalRepository => _dismissalRepository;

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
    // Issue #014 Migration: If content was found via subcollection query,
    // the user is already verified as a member. Always show.
    // The query itself (members subcollection) handles access control.
    return true;
  }

  @override
  bool isViewedByUser(SharedMenu content, String userId) {
    // Note (Issue #014): Array-based status removed.
    // Use hasViewed() repository method for actual viewed status.
    // This sync method defaults to false; call hasViewed() for accurate status.
    return false;
  }

  @override
  bool isCreatedBy(SharedMenu content, String userId) {
    return content.sharedByUserId == userId;
  }

  // ===== SHARED MENU OPERATIONS =====

  /// Create new shared menu with comprehensive validation
  /// Note (Issue #014): recipientIds must be passed separately as sharedToUserIds
  /// is no longer stored in the model (tracked in Firestore subcollections instead).
  Future<String> createSharedMenu(
    SharedMenu sharedMenu, {
    required List<String> recipientIds,
  }) async {
    AppLogger.info('🔍🔍🔍 DEBUG REPO: createSharedMenu called with ${recipientIds.length} recipients');
    final uid = requireCurrentUserId();
    AppLogger.info('🔍 DEBUG REPO: Current user ID: $uid');

    // Menu-specific validations
    if (sharedMenu.sharedByUserId != uid) {
      throw PermissionDeniedException(
          'Cannot create shared menu for another user');
    }

    if (recipientIds.isEmpty) {
      throw ArgumentError('Must specify at least one recipient');
    }

    // Create the shared menu document
    final menuId = await createSharedContent(sharedMenu);

    // Add all recipients to members subcollection (Issue #014: Unlimited sharing)
    AppLogger.info('🔍 DEBUG REPO: About to add ${recipientIds.length} members for menu $menuId');
    for (final recipientId in recipientIds) {
      AppLogger.info('🔍 DEBUG REPO: Adding member $recipientId to menu $menuId');
      await addMember(menuId, recipientId, addedBy: uid);
      AppLogger.info('🔍 DEBUG REPO: Member $recipientId added successfully');
    }

    AppLogger.success(
        '✅ Created shared menu with ${recipientIds.length} members in subcollection');

    return menuId;
  }

  /// Get all shared menus for a specific user
  Future<List<SharedMenu>> getSharedMenusForUser(String userId) async {
    // Use subcollection-based query (Issue #014: Unlimited sharing support)
    return await getSharedContentForUserViaSubcollection(userId);
  }

  /// Get specific shared menu by ID
  Future<SharedMenu?> getSharedMenu(String menuId) async {
    final uid = requireCurrentUserId();

    // Fetch document directly without base class permission check (Issue #014)
    // We need to check members subcollection, which requires async call
    final doc = await getCollectionRef().doc(menuId).get();

    if (!doc.exists) {
      return null;
    }

    final sharedMenu = fromFirestore(doc);

    // Menu-specific permission validation (Issue #014)
    // Check if user is owner or member via subcollection
    final isOwner = sharedMenu.sharedByUserId == uid;
    final isMember = await this.isMember(menuId, uid);
    final canAccess = isOwner || isMember || sharedMenu.isCollaborative;

    if (!canAccess) {
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

  // ===== STATUS MANAGEMENT (SUBCOLLECTION-BASED) =====

  /// Mark shared menu as viewed by user
  @override
  Future<void> markAsViewed(String menuId, String userId) async {
    // Use subcollection method (Issue #014: Unlimited views support)
    return await addView(menuId, userId);
  }

  /// Mark shared menu as imported by user (copy-on-write)
  Future<void> markAsImported(String menuId, String userId) async {
    // Use subcollection method (Issue #014: Unlimited imports support)
    return await addEngagement(menuId, userId, action: 'import');
  }

  /// Mark shared menu as dismissed by user
  @override
  Future<void> markAsDismissed(String menuId, String userId) async {
    // Use subcollection method (Issue #014: Unlimited dismissals support)
    return await addDismissal(menuId, userId);
  }

  /// Remove dismissal status for user (restore visibility)
  @override
  Future<void> undismiss(String menuId, String userId) async {
    // Use subcollection method (Issue #014)
    return await removeDismissal(menuId, userId);
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
      // Query engagements subcollection (Issue #014: Unlimited imports support)
      final engagementsSnapshot = await firestore
          .collectionGroup('engagements')
          .where('userId', isEqualTo: userId)
          .where('action', isEqualTo: 'import')
          .get();

      if (engagementsSnapshot.docs.isEmpty) {
        AppLogger.info('📋 User $userId has no imported menus');
        return [];
      }

      // Extract menu IDs from engagement documents
      final menuIds = <String>{};
      for (final engagementDoc in engagementsSnapshot.docs) {
        final menuId = engagementDoc.reference.parent.parent?.id;
        if (menuId != null) {
          menuIds.add(menuId);
        }
      }

      // Batch fetch menu documents (max 10 per query)
      final importedMenus = <SharedMenu>[];
      final menuIdList = menuIds.toList();
      for (var i = 0; i < menuIdList.length; i += 10) {
        final end = (i + 10 < menuIdList.length) ? i + 10 : menuIdList.length;
        final batch = menuIdList.sublist(i, end);

        final batchSnapshot = await getCollectionRef()
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        importedMenus.addAll(
          batchSnapshot.docs.map((doc) => fromFirestore(doc)),
        );
      }

      AppLogger.info(
          '📋 User $userId has imported ${importedMenus.length} shared menus');
      return importedMenus;
    } catch (e) {
      AppLogger.error('Failed to get imported menus for user $userId: $e');
      throw RepositoryException('Failed to get imported menus: $e');
    }
  }
}

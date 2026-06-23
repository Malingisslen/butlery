/// Base class for social content coordinators providing common invitation and sharing patterns.
/// This base class consolidates duplicate coordination patterns found across:
/// - SocialRecipeCoordinator
/// - SocialMenuCoordinator (to be implemented)
/// - SocialShoppingCoordinator (to be implemented)
/// **Architectural Benefits:**
/// - **Unified Invitation System**: Standardized invitation creation, import, and dismissal
/// - **Consistent API**: Common patterns for all social content types
/// - **Service Delegation**: Template method pattern for focused service coordination
/// - **Repository Integration**: Unified shared content repository interactions
/// - **Notification Coordination**: Standardized notification patterns
/// **Design Pattern:**
/// Uses Template Method pattern where base class provides common algorithms
/// and concrete subclasses customize behavior through abstract methods.
/// **Usage Example:**
/// ```dart
/// class SocialRecipeCoordinator extends BaseSocialCoordinator<Recipe, SharedRecipe> {
///   @override
///   String get contentTypeName => 'recipe';
///   @override
///   String getContentTitle(Recipe content) => content.title;
///   @override
///   BaseSharedContentRepository<SharedRecipe> get sharedRepository => _sharedRecipeRepository;
/// }
/// ```

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/error_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firebase/base_shared_content_repository.dart';
import 'package:butlery/services/user_service.dart' as user_service;

/// Abstract base coordinator for social content operations
/// Provides common patterns for invitation creation, content sharing,
/// import operations, and notification coordination across all content types.
abstract class BaseSocialCoordinator<TContent, TSharedContent>
    extends BaseService
    with UserContextMixin {
  // Core dependencies
  final String? Function() _getCurrentUserId;
  final String? Function() _getCurrentUserDisplayName;
  final void Function(String) _rawSetError;
  final void Function() _rawNotifyListeners;

  // BUT-1110: guards against a slow Firestore round-trip resolving after the
  // coordinator (and its parent ViewModel) is disposed. Without this, the late
  // continuation would call notifyListeners()/setError on a dead ViewModel.
  bool _disposed = false;

  BaseSocialCoordinator({
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required void Function(String) setError,
    required void Function() notifyListeners,
  }) : _getCurrentUserId = getCurrentUserId,
       _getCurrentUserDisplayName = getCurrentUserDisplayName,
       _rawSetError = setError,
       _rawNotifyListeners = notifyListeners {
    // Set the user ID provider for the mixin
    setUserIdProvider(getCurrentUserId);
  }

  @override
  Future<void> onDispose() async {
    _disposed = true;
    await super.onDispose();
  }

  /// Notify listeners unless disposed (BUT-1110).
  void _notifyListeners() {
    if (_disposed) return;
    _rawNotifyListeners();
  }

  /// Surface an error unless disposed (BUT-1110).
  void _setError(String message) {
    if (_disposed) return;
    _rawSetError(message);
  }

  /// Content type name for logging (e.g., 'recipe', 'menu', 'shopping_list')
  String get contentTypeName;

  /// Extract title from content for logging purposes
  String getContentTitle(TContent content);

  /// Get shared content repository for this content type
  BaseSharedContentRepository<TSharedContent> get sharedRepository;

  /// Get content by ID from the underlying service
  Future<TContent?> getContentById(String contentId);

  /// Create shared content model from content and invitation parameters
  TSharedContent createSharedContentModel({
    required String originalContentId,
    required String sharedByUserId,
    required String sharedByDisplayName,
    required List<String> sharedToUserIds,
    String? shareMessage,
    required TContent contentSnapshot,
    Map<String, dynamic>? additionalData,
  });

  /// Create imported content from shared content
  TContent createImportedContent({
    required TSharedContent sharedContent,
    required String newOwnerId,
    String? newTitle,
  });

  /// Save imported content to the underlying service
  Future<String?> saveImportedContent(TContent content);

  /// Create invitation using shared content model for universal invitation system
  Future<String?> createInvitation({
    required String contentId,
    required List<String> inviteeUserIds,
    String? message,
    Map<String, dynamic>? additionalData,
  }) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.error(
        'Cannot create $contentTypeName invitation: No authenticated user',
      );
      return null;
    }

    try {
      AppLogger.info(
        '📨 Creating $contentTypeName invitation for $contentId to ${inviteeUserIds.length} users',
      );

      // Get the content to create snapshot
      final content = await getContentById(contentId);
      if (content == null) {
        AppLogger.error(
          '${_capitalize(contentTypeName)} not found: $contentId',
        );
        return null;
      }

      // Get current user's display name
      final userService = ServiceLocator.get<user_service.UserService>();
      final currentUserProfile = userService.currentUserProfile;
      if (currentUserProfile == null) {
        AppLogger.error('Cannot get current user profile for invitation');
        return null;
      }

      // Create shared content invitation
      final sharedContent = createSharedContentModel(
        originalContentId: contentId,
        sharedByUserId: currentUserId,
        sharedByDisplayName: currentUserProfile.displayName,
        sharedToUserIds: inviteeUserIds,
        shareMessage: message,
        contentSnapshot: content,
        additionalData: additionalData,
      );

      // Save invitation to Firebase
      final invitationId = await sharedRepository.createSharedContent(
        sharedContent,
      );

      // Add invitees as members to the subcollection (Issue #014 migration fix)
      // This enables collectionGroup('members') queries to find content for recipients
      // Fetch user profiles for denormalized member info (V1-QP-001 fix)
      AppLogger.info(
        '🔍 DEBUG: Adding ${inviteeUserIds.length} members to subcollection for $invitationId',
      );
      final inviteeProfiles = await userService.getUserProfiles(inviteeUserIds);
      final profileMap = {for (final p in inviteeProfiles) p.uid: p};

      for (final inviteeId in inviteeUserIds) {
        AppLogger.info('🔍 DEBUG: Adding member $inviteeId to $invitationId');
        final profile = profileMap[inviteeId];
        await sharedRepository.addMember(
          invitationId,
          inviteeId,
          addedBy: currentUserId,
          displayName: profile?.displayName ?? '?',
          avatarUrl: profile?.avatarUrl,
        );
        AppLogger.info('🔍 DEBUG: Member $inviteeId added successfully');
      }

      AppLogger.success(
        '✅ ${_capitalize(contentTypeName)} invitation created with ${inviteeUserIds.length} members: $invitationId',
      );
      AppLogger.info(
        '📥 Recipients will see invitation in "Delat med mig" view',
      );

      // Send notifications (placeholder for future implementation)
      await sendInvitationNotifications(contentId, inviteeUserIds);

      return invitationId;
    } catch (e) {
      AppLogger.error('Failed to create $contentTypeName invitation: $e');
      _setError(sanitizeErrorForUser(e));
      return null;
    }
  }

  /// Share content with friends using invitation system
  Future<bool> shareWithFriends({
    required String contentId,
    required List<String> friendIds,
    String? message,
    Map<String, dynamic>? additionalData,
  }) async {
    final invitationId = await createInvitation(
      contentId: contentId,
      inviteeUserIds: friendIds,
      message: message,
      additionalData: additionalData,
    );

    return invitationId != null;
  }

  /// Get invitations received by current user with pagination
  /// [limit] Maximum number of invitations to return (default: 25)
  /// [startAfter] Document snapshot to start after for cursor-based pagination
  Future<List<TSharedContent>> getReceivedInvitations({
    int limit = 25,
    DocumentSnapshot? startAfter,
  }) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.warning(
        'Cannot get received invitations: No authenticated user',
      );
      return [];
    }

    try {
      AppLogger.info(
        '📥 Getting received $contentTypeName invitations for user $currentUserId (limit: $limit)',
      );
      return await sharedRepository.getSharedContentForUser(
        currentUserId,
        limit: limit,
        startAfter: startAfter,
      );
    } catch (e) {
      AppLogger.error(
        'Failed to get received $contentTypeName invitations: $e',
      );
      _setError(sanitizeErrorForUser(e));
      return [];
    }
  }

  /// Join shared content for viewing (true copy-on-write pattern)
  /// This method implements TRUE copy-on-write:
  /// - Initially joins as viewer of original content (no copy created)
  /// - Copy-on-write is triggered later when user attempts first edit
  Future<String?> importSharedContent({
    required String sharedContentId,
    String? newTitle,
  }) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.error('Cannot join $contentTypeName: No authenticated user');
      return null;
    }

    try {
      AppLogger.info(
        '📥 Joining shared $contentTypeName $sharedContentId for viewing',
      );

      // Get shared content
      final sharedContent = await sharedRepository.read(sharedContentId);
      if (sharedContent == null) {
        AppLogger.error('Shared $contentTypeName not found: $sharedContentId');
        return null;
      }

      // For true copy-on-write: Just mark as joined/imported (viewer status)
      // No actual copy is created until first edit attempt
      await sharedRepository.markAsImportedOrJoined(
        sharedContentId,
        currentUserId,
      );

      AppLogger.success(
        '✅ Joined shared $contentTypeName as viewer (copy-on-write ready)',
      );
      AppLogger.info(
        '💡 Copy will be created when you first edit the $contentTypeName',
      );
      _notifyListeners();

      // Return the shared content ID (user views original until CoW triggers)
      return sharedContentId;
    } catch (e) {
      AppLogger.error('Failed to join shared $contentTypeName: $e');
      _setError(sanitizeErrorForUser(e));
      return null;
    }
  }

  /// Trigger copy-on-write when user attempts first edit
  /// This method implements the CoW trigger logic:
  /// 1. Creates static copy for original owner
  /// 2. Converts shared version to collaborative mode
  /// 3. Adds editing user to active collaborators
  Future<String?> triggerCopyOnWrite({
    required String sharedContentId,
    required String editingUserId,
  }) async {
    try {
      AppLogger.info(
        '🔄 Triggering copy-on-write for shared $contentTypeName $sharedContentId',
      );

      // Get current shared content
      final sharedContent = await sharedRepository.read(sharedContentId);
      if (sharedContent == null) {
        AppLogger.error('Shared $contentTypeName not found: $sharedContentId');
        return null;
      }

      // Create static copy for original owner
      final originalContent = getOriginalContentFromShared(sharedContent);
      final staticCopyId = await createStaticCopyForOwner(
        originalContent,
        getSharedByUserId(sharedContent),
      );

      if (staticCopyId == null) {
        AppLogger.error('Failed to create static copy for original owner');
        return null;
      }

      // Update shared content to collaborative mode using abstract method
      final collaborativeVersion = triggerCopyOnWriteForContent(
        sharedContent: sharedContent,
        editingUserId: editingUserId,
        staticCopyId: staticCopyId,
      );

      if (collaborativeVersion == null) {
        AppLogger.error('Failed to create collaborative version');
        return null;
      }

      // Save updated shared content (using proper repository method)
      await updateSharedContent(collaborativeVersion);

      AppLogger.success('✅ Copy-on-write triggered successfully');
      AppLogger.info(
        '📄 Static copy created for original owner: $staticCopyId',
      );
      AppLogger.info('👥 Shared version is now collaborative');
      _notifyListeners();

      return sharedContentId; // Return collaborative version ID
    } catch (e) {
      AppLogger.error('Failed to trigger copy-on-write: $e');
      _setError(sanitizeErrorForUser(e));
      return null;
    }
  }

  /// Extract original content from shared content for static copy creation
  dynamic getOriginalContentFromShared(TSharedContent sharedContent);

  /// Create static copy for original owner when CoW triggers
  Future<String?> createStaticCopyForOwner(
    dynamic originalContent,
    String ownerId,
  );

  /// Get shared by user ID from shared content (content-specific)
  String getSharedByUserId(TSharedContent sharedContent);

  /// Trigger copy-on-write on the content-specific model
  TSharedContent? triggerCopyOnWriteForContent({
    required TSharedContent sharedContent,
    required String editingUserId,
    required String staticCopyId,
  });

  /// Update shared content in repository (content-specific)
  Future<void> updateSharedContent(TSharedContent sharedContent);

  /// Dismiss shared content from user's list
  Future<bool> dismissSharedContent(String sharedContentId) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.error('Cannot dismiss $contentTypeName: No authenticated user');
      return false;
    }

    try {
      AppLogger.info('🗑️ Dismissing shared $contentTypeName $sharedContentId');
      await sharedRepository.markAsDismissed(sharedContentId, currentUserId);
      AppLogger.success('✅ Shared $contentTypeName dismissed');
      _notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('Failed to dismiss shared $contentTypeName: $e');
      _setError(sanitizeErrorForUser(e));
      return false;
    }
  }

  /// Restore dismissed shared content
  Future<bool> restoreSharedContent(String sharedContentId) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.error('Cannot restore $contentTypeName: No authenticated user');
      return false;
    }

    try {
      AppLogger.info('♻️ Restoring shared $contentTypeName $sharedContentId');
      await sharedRepository.undismiss(sharedContentId, currentUserId);
      AppLogger.success('✅ Shared $contentTypeName restored');
      _notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('Failed to restore shared $contentTypeName: $e');
      _setError(sanitizeErrorForUser(e));
      return false;
    }
  }

  /// Mark shared content as viewed
  Future<bool> markAsViewed(String sharedContentId) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.error(
        'Cannot mark $contentTypeName as viewed: No authenticated user',
      );
      return false;
    }

    try {
      await sharedRepository.markAsViewed(sharedContentId, currentUserId);
      AppLogger.info(
        '👁️ Marked shared $contentTypeName $sharedContentId as viewed',
      );
      _notifyListeners();
      return true;
    } catch (e) {
      // BUT-1094: populate _error so the UI's hasError-gated banner
      // surfaces this failure consistently with dismiss/restore/import.
      AppLogger.error('Failed to mark shared $contentTypeName as viewed: $e');
      _setError(sanitizeErrorForUser(e));
      return false;
    }
  }

  /// Get unread shared content count
  Future<int> getUnreadCount() async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.warning('Cannot get unread count: No authenticated user');
      return 0;
    }

    try {
      return await sharedRepository.getUnreadCountForUser(currentUserId);
    } catch (e) {
      // BUT-1094: populate _error so failed inbox counts surface in the UI.
      AppLogger.error('Failed to get unread $contentTypeName count: $e');
      _setError(sanitizeErrorForUser(e));
      return 0;
    }
  }

  /// Send invitation notifications (placeholder for future implementation)
  Future<void> sendInvitationNotifications(
    String contentId,
    List<String> inviteeUserIds,
  ) async {
    AppLogger.info(
      '📧 Sending $contentTypeName invitation notifications to ${inviteeUserIds.length} users for $contentId',
    );
    // Note: Notification system implementation would be integrated here
    // when NotificationService dependency is available in coordinators
  }

  /// Send sharing notifications (placeholder for future implementation)
  Future<void> sendSharingNotifications(
    String contentId,
    List<String> sharedWithUserIds,
  ) async {
    AppLogger.info(
      '📧 Sending $contentTypeName sharing notifications to ${sharedWithUserIds.length} users for $contentId',
    );
    // Note: Notification system implementation would be integrated here
    // when NotificationService dependency is available in coordinators
  }

  /// Get current user ID safely
  String? get currentUserId => _getCurrentUserId();

  /// Get current user display name safely
  String? get currentUserDisplayName => _getCurrentUserDisplayName();

  /// Notify listeners of state changes
  void notifyStateChanged() => _notifyListeners();

  /// Set error message
  void setError(String error) => _setError(error);

  /// Helper method to capitalize strings
  String _capitalize(String str) {
    if (str.isEmpty) return str;
    return '${str[0].toUpperCase()}${str.substring(1)}';
  }
}

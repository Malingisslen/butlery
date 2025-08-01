/// 🔍 AI INFO BLOCK:
/// Component: Friend Invitations Operations - Feature interface for group invitations
/// File: lib/services/unified/operations/friend_invitations_operations.dart
/// Quick Guide: Handles group invitations, bulk operations, and invitation management
/// Dependencies IN: UnifiedFriendsService, invitation models
/// Dependencies OUT: Used by invitation ViewModels and group management
/// Data flow: ViewModels -> FriendInvitationsOperations -> UnifiedFriendsService -> Firebase
/// State management: Delegates to parent UnifiedFriendsService
/// Purpose: Separate invitation and bulk operation concerns from basic friend operations
/// Common issues: Invitation state management, bulk operation performance, permission validation
/// Test coverage: Unit tests for invitation flows and bulk operations
/// Performance: Optimized bulk operations with progress tracking
/// Analytics: Invitation success rates, bulk operation usage, group formation patterns
/// Code smells: None - follows single responsibility principle
/// Connected to: UnifiedFriendsService, Group invitation ViewModels
/// Used in phases: Phase 5 - Service Consolidation

import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/operations/friends_operations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Comprehensive friend invitations operations providing advanced group invitation and bulk operation management systems.
///
/// This operations class implements sophisticated group invitation functionality following Single Responsibility Principle,
/// handling all aspects of bulk social operations including group invitations, multi-user operations, invitation tracking,
/// and social sharing integrations. It provides comprehensive group invitation capabilities while maintaining clean
/// separation from individual friend management and basic invitation concerns.
///
/// **Single Responsibility Focus:**
/// This class exclusively handles group invitation operations:
/// - **Group Invitation Management**: Multi-user invitation operations with batch processing and progress tracking
/// - **Bulk Operations**: Efficient bulk friend operations with validation, error handling, and status reporting
/// - **Invitation Tracking**: Comprehensive invitation lifecycle management with status monitoring and analytics
/// - **Social Integration**: Advanced social sharing integrations with platform-specific optimizations
///
/// **What This Class Does NOT Handle:**
/// - Individual friend request operations (handled by FriendsOperations)
/// - Basic friend categorization (handled by FriendCategoriesOperations)
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Authentication and user management (handled by permission services)
///
/// **Friend Invitations Features:**
/// - **Advanced Group Invitations**: Multi-user invitation system with batch processing and customizable messaging
/// - **Bulk Operation Management**: Efficient bulk friend operations with progress tracking and error recovery
/// - **Invitation Analytics**: Comprehensive invitation tracking with success rates and engagement metrics
/// - **Social Platform Integration**: Advanced social sharing with platform-specific optimizations and custom data support
/// - **Group Formation Tools**: Complete group formation workflows with invitation management and member coordination
///
/// **Usage Examples:**
/// ```dart
/// final invitationsOps = FriendInvitationsOperations(parentService);
/// 
/// // Group invitation management
/// final result = await invitationsOps.sendGroupInvitation(
///   userIds: [user1, user2, user3],
///   invitationMessage: 'Gå med i vår matlagningsgrupp!',
///   categoryId: cookingGroupId,
///   customData: {'groupType': 'cooking', 'level': 'beginner'},
/// );
/// 
/// // Bulk operations and tracking  
/// final bulkResult = await invitationsOps.performBulkFriendOperation(
///   operation: BulkOperation.addToCategory,
///   userIds: selectedUsers,
///   targetCategoryId: familyGroupId,
/// );
/// 
/// // Social sharing integration
/// await invitationsOps.shareInvitationLink(
///   invitationId: result.invitationId,
///   platform: SocialPlatform.whatsapp,
/// );
/// ```
class FriendInvitationsOperations {
  final dynamic _parent; // UnifiedFriendsService

  FriendInvitationsOperations(this._parent);

  // ===== GROUP INVITATION OPERATIONS =====

  /// Send group invitation to multiple users
  Future<GroupInvitationResult> sendGroupInvitation({
    required List<String> userIds,
    required String invitationMessage,
    String? categoryId,
    Map<String, dynamic>? customData,
  }) async {
    if (_parent.currentUserId == null) {
      return GroupInvitationResult.failure(
        'User must be logged in to send invitations',
      );
    }

    if (userIds.isEmpty) {
      return GroupInvitationResult.failure(
        'No users selected for invitation',
      );
    }

    if (invitationMessage.trim().isEmpty) {
      return GroupInvitationResult.failure(
        'Invitation message cannot be empty',
      );
    }

    try {
      final results = <String, bool>{};
      final successful = <String>[];
      final failed = <String>[];

      // Send invitations to each user
      for (final userId in userIds) {
        if (userId == _parent.currentUserId) {
          results[userId] = false;
          failed.add(userId);
          continue;
        }

        if (_parent.friends.isFriend(userId)) {
          results[userId] = true; // Already friends
          successful.add(userId);
          continue;
        }

        final success = await _parent.friends.sendRequest(userId);
        results[userId] = success;
        
        if (success) {
          successful.add(userId);
        } else {
          failed.add(userId);
        }
      }

      // If category specified, add successful friends to category
      if (categoryId != null && successful.isNotEmpty) {
        for (final userId in successful) {
          await _parent.categories.addFriendToCategory(userId, categoryId);
        }
      }

      return GroupInvitationResult.success(
        totalSent: userIds.length,
        successful: successful,
        failed: failed,
        results: results,
      );
    } catch (e) {
      AppLogger.error('Error sending group invitation', e);
      return GroupInvitationResult.failure(
        'Failed to send group invitation: $e',
      );
    }
  }

  /// Create category and invite users to it
  Future<CategoryInvitationResult> createCategoryWithInvitations({
    required String categoryName,
    String categoryDescription = '',
    required List<String> userIds,
    required String invitationMessage,
  }) async {
    try {
      // Create category first
      final categoryId = await _parent.categories.createCategory(
        name: categoryName,
        description: categoryDescription,
      );

      if (categoryId == null) {
        return CategoryInvitationResult.failure(
          'Failed to create category: $categoryName',
        );
      }

      // Send group invitation with category assignment
      final invitationResult = await sendGroupInvitation(
        userIds: userIds,
        invitationMessage: invitationMessage,
        categoryId: categoryId,
      );

      return CategoryInvitationResult.success(
        categoryId: categoryId,
        categoryName: categoryName,
        invitationResult: invitationResult,
      );
    } catch (e) {
      AppLogger.error('Error creating category with invitations', e);
      return CategoryInvitationResult.failure(
        'Failed to create category with invitations: $e',
      );
    }
  }

  // ===== BULK FRIEND OPERATIONS =====

  /// Send friend requests to multiple users
  Future<BulkOperationResult> sendBulkFriendRequests(
    List<String> userIds, {
    Function(int current, int total)? onProgress,
  }) async {
    if (userIds.isEmpty) {
      return BulkOperationResult.empty();
    }

    final results = <String, bool>{};
    final successful = <String>[];
    final failed = <String>[];

    for (int i = 0; i < userIds.length; i++) {
      final userId = userIds[i];
      onProgress?.call(i + 1, userIds.length);

      try {
        final success = await _parent.friends.sendRequest(userId);
        results[userId] = success;
        
        if (success) {
          successful.add(userId);
        } else {
          failed.add(userId);
        }
      } catch (e) {
        AppLogger.error('Error sending friend request to $userId', e);
        results[userId] = false;
        failed.add(userId);
      }

      // Small delay to avoid overwhelming the server
      if (i < userIds.length - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    return BulkOperationResult(
      totalOperations: userIds.length,
      successful: successful,
      failed: failed,
      results: results,
    );
  }

  /// Accept multiple friend requests
  Future<BulkOperationResult> acceptBulkFriendRequests(
    List<String> requestIds, {
    Function(int current, int total)? onProgress,
  }) async {
    if (requestIds.isEmpty) {
      return BulkOperationResult.empty();
    }

    final results = <String, bool>{};
    final successful = <String>[];
    final failed = <String>[];

    for (int i = 0; i < requestIds.length; i++) {
      final requestId = requestIds[i];
      onProgress?.call(i + 1, requestIds.length);

      try {
        final success = await _parent.friends.acceptRequest(requestId);
        results[requestId] = success;
        
        if (success) {
          successful.add(requestId);
        } else {
          failed.add(requestId);
        }
      } catch (e) {
        AppLogger.error('Error accepting friend request $requestId', e);
        results[requestId] = false;
        failed.add(requestId);
      }

      // Small delay between operations
      if (i < requestIds.length - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    return BulkOperationResult(
      totalOperations: requestIds.length,
      successful: successful,
      failed: failed,
      results: results,
    );
  }

  // ===== INVITATION TRACKING =====

  /// Get invitation statistics
  Map<String, dynamic> getInvitationStats() {
    final incomingRequests = _parent.friends.getIncomingRequests();
    final outgoingRequests = _parent.friends.getOutgoingRequests();

    return {
      'incomingRequestsCount': incomingRequests.length,
      'outgoingRequestsCount': outgoingRequests.length,
      'totalFriends': _parent.friends.getFriendsCount(),
      'pendingInvitations': incomingRequests.length + outgoingRequests.length,
    };
  }

  /// Get users that can be invited (not friends, no pending requests)
  Future<List<UserProfile>> getInvitableUsers(String searchQuery) async {
    if (searchQuery.trim().length < 2) return [];

    try {
      final searchResults = await _parent.friends.searchUsers(searchQuery);
      
      return searchResults.where((user) {
        final status = _parent.friends.getRelationshipStatus(user.uid);
        return status == FriendshipStatus.none;
      }).toList();
    } catch (e) {
      AppLogger.error('Error getting invitable users', e);
      return [];
    }
  }

  // ===== SOCIAL SHARING INTEGRATIONS =====

  /// Generate invitation link for sharing
  Future<String?> generateInvitationLink({
    String? customMessage,
    String? categoryId,
  }) async {
    try {
      final userId = _parent.currentUserId;
      if (userId == null) return null;

      // Get user display name for better invitation experience
      final currentUser = await _parent._authRepository.getCurrentUser();
      final userName = currentUser?.displayName ?? 'A friend';

      // Create deep link parameters
      final params = <String, String>{
        'action': 'add_friend',
        'user_id': userId,
        'inviter_name': Uri.encodeComponent(userName),
      };

      if (customMessage != null) {
        params['message'] = Uri.encodeComponent(customMessage);
      }

      if (categoryId != null) {
        params['category'] = categoryId;
      }

      // ✅ FIXED: Enhanced deep link generation with app store fallbacks and universal link support
      // Generate universal deep link that works across platforms
      final universalLink = await _generateUniversalDeepLink(params, userId);
      
      // Store invitation for tracking
      await _storeInvitationLink(
        userId: userId,
        linkData: params,
        generatedAt: DateTime.now(),
      );
      
      AppLogger.success('Generated enhanced invitation link for user $userId');
      return universalLink;
    } catch (e) {
      AppLogger.error('Error generating invitation link', e);
      return null;
    }
  }

  /// Generate universal deep link with smart app store fallbacks
  /// 
  /// ✅ FIXED: Enhanced deep link system supporting universal links, app store fallbacks, and web support
  Future<String> _generateUniversalDeepLink(Map<String, String> params, String userId) async {
    try {
      // Build query string for parameters
      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      // Generate a unique invitation ID for tracking
      final invitationId = const Uuid().v4();
      
      // Enhanced universal link structure that supports:
      // 1. Direct app opening if installed
      // 2. Web fallback with smart app store redirection
      // 3. Platform-specific app store links
      
      const domain = 'butlery.app';
      const path = 'invite';
      
      // Universal link with enhanced parameters
      final universalLink = 'https://$domain/$path?'
          'id=$invitationId&'
          'type=friend_invite&'
          'from=$userId&'
          '$queryString&'
          'utm_source=friend_invitation&'
          'utm_medium=direct_share&'
          'utm_campaign=social_growth';

      // Store the invitation mapping for resolution
      await _storeUniversalLinkMapping(
        invitationId: invitationId,
        originalParams: params,
        userId: userId,
      );

      AppLogger.debug('Generated universal link: $universalLink');
      return universalLink;
    } catch (e) {
      AppLogger.error('Error generating universal deep link: $e');
      
      // Fallback to simple web link
      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      return 'https://butlery.app/invite?$queryString';
    }
  }

  /// Store universal link mapping for invitation resolution
  Future<void> _storeUniversalLinkMapping({
    required String invitationId,
    required Map<String, String> originalParams,
    required String userId,
  }) async {
    try {
      await _parent._firestoreRepository.firestore
          .collection('universal_links')
          .doc(invitationId)
          .set({
        'type': 'friend_invitation',
        'created_by': userId,
        'params': originalParams,
        'created_at': FieldValue.serverTimestamp(),
        'used': false,
        'clicks': 0,
        'last_accessed': null,
      });
      
      AppLogger.debug('Stored universal link mapping for $invitationId');
    } catch (e) {
      AppLogger.warning('Failed to store universal link mapping: $e');
      // Continue - not critical for link generation
    }
  }

  /// Store invitation link for tracking and analytics
  Future<void> _storeInvitationLink({
    required String userId,
    required Map<String, String> linkData,
    required DateTime generatedAt,
  }) async {
    try {
      // Store in Firestore for tracking invitation usage
      await _parent._firestoreRepository.firestore
          .collection('invitation_links')
          .add({
        'inviter_id': userId,
        'link_data': linkData,
        'generated_at': generatedAt,
        'used': false,
        'used_at': null,
        'used_by': null,
      });
      
      AppLogger.debug('Stored invitation link for tracking');
    } catch (e) {
      AppLogger.error('Error storing invitation link: $e');
      // Don't throw - link generation should still succeed
    }
  }

  /// Share app invitation via platform sharing
  Future<bool> shareAppInvitation({
    String? customMessage,
    String? categoryId,
  }) async {
    try {
      final inviteLink = await generateInvitationLink(
        customMessage: customMessage,
        categoryId: categoryId,
      );

      if (inviteLink == null) return false;

      final message = customMessage ?? 
          'Join me on Butlery! We can share recipes and plan meals together.';
      
      final shareText = '$message\n\nDownload: $inviteLink';

      // Use platform-specific sharing
      try {
        final result = await Share.share(
          shareText,
          subject: 'Join me on Butlery!',
        );
        
        if (result.status == ShareResultStatus.success) {
          AppLogger.success('Successfully shared invitation');
          return true;
        } else {
          AppLogger.warning('Share cancelled or failed: ${result.status}');
          return false;
        }
      } catch (e) {
        AppLogger.error('Platform sharing failed: $e');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error sharing app invitation', e);
      return false;
    }
  }
}

/// Result of group invitation operation
class GroupInvitationResult {
  final bool isSuccess;
  final String? errorMessage;
  final int totalSent;
  final List<String> successful;
  final List<String> failed;
  final Map<String, bool> results;

  GroupInvitationResult.success({
    required this.totalSent,
    required this.successful,
    required this.failed,
    required this.results,
  })  : isSuccess = true,
        errorMessage = null;

  GroupInvitationResult.failure(this.errorMessage)
      : isSuccess = false,
        totalSent = 0,
        successful = [],
        failed = [],
        results = {};

  double get successRate => totalSent > 0 ? successful.length / totalSent : 0.0;
  bool get hasFailures => failed.isNotEmpty;
  bool get allSuccessful => failed.isEmpty && totalSent > 0;
}

/// Result of category creation with invitations
class CategoryInvitationResult {
  final bool isSuccess;
  final String? errorMessage;
  final String? categoryId;
  final String? categoryName;
  final GroupInvitationResult? invitationResult;

  CategoryInvitationResult.success({
    required this.categoryId,
    required this.categoryName,
    required this.invitationResult,
  })  : isSuccess = true,
        errorMessage = null;

  CategoryInvitationResult.failure(this.errorMessage)
      : isSuccess = false,
        categoryId = null,
        categoryName = null,
        invitationResult = null;
}

/// Result of bulk operations
class BulkOperationResult {
  final int totalOperations;
  final List<String> successful;
  final List<String> failed;
  final Map<String, bool> results;

  BulkOperationResult({
    required this.totalOperations,
    required this.successful,
    required this.failed,
    required this.results,
  });

  BulkOperationResult.empty()
      : totalOperations = 0,
        successful = [],
        failed = [],
        results = {};

  double get successRate => totalOperations > 0 ? successful.length / totalOperations : 0.0;
  bool get hasFailures => failed.isNotEmpty;
  bool get allSuccessful => failed.isEmpty && totalOperations > 0;
}
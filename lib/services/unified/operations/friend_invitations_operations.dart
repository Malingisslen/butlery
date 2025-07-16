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

import '../../../models/user_profile.dart';
import '../../../core/utils/logger.dart';
import 'friends_operations.dart';
import 'package:share_plus/share_plus.dart';

/// Friend invitations operations feature interface
/// 
/// Handles all group invitation and bulk operation features:
/// - Group invitations to multiple users
/// - Bulk friend operations
/// - Invitation tracking and management
/// - Group formation workflows
/// - Social sharing integrations
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
        await Future.delayed(Duration(milliseconds: 100));
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
        await Future.delayed(Duration(milliseconds: 100));
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
      // TODO: Implement deep link generation for app invitations
      // This would create a shareable link that opens the app and prompts to add the user as a friend
      
      final userId = _parent.currentUserId;
      if (userId == null) return null;

      final baseUrl = 'https://butlery.app/invite';
      final params = <String, String>{
        'user': userId,
      };

      if (customMessage != null) {
        params['message'] = Uri.encodeComponent(customMessage);
      }

      if (categoryId != null) {
        params['category'] = categoryId;
      }

      final queryString = params.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');

      return '$baseUrl?$queryString';
    } catch (e) {
      AppLogger.error('Error generating invitation link', e);
      return null;
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
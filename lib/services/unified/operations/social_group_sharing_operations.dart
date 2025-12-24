import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/shared_content.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/repositories/interfaces/social_sharing_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/operations/modules/group_sharing_bulk_operations_module.dart';
import 'package:butlery/services/unified/operations/modules/group_sharing_validation_module.dart';

/// Social group sharing operations for group-based content sharing and bulk operations.
/// Handles group sharing, member resolution, validation, and bulk operations with progress tracking.
class SocialGroupSharingOperations {
  final UnifiedFriendsService _parent;

  // Modules
  late final GroupSharingBulkOperationsModule _bulkOperations;
  late final GroupSharingValidationModule _validation;

  SocialGroupSharingOperations(this._parent) {
    _bulkOperations = GroupSharingBulkOperationsModule(
      shareToGroup: (groupId, content) =>
          shareContentToGroup(groupId: groupId, content: content),
      getAllCategories: () => _parent.getAllCategoriesInternal(),
      getCurrentUserId: () => _parent.currentUserId,
    );
    _validation = GroupSharingValidationModule(
      getCategoryById: _parent.getCategoryByIdInternal,
      getCurrentUserId: () => _parent.currentUserId,
    );
  }

  // ===== GROUP CONTENT SHARING =====

  /// Share content to a group
  Future<bool> shareContentToGroup({
    required String groupId,
    required SharedContent content,
  }) async {
    try {
      final group = _parent.getCategoryByIdInternal(groupId);
      if (group == null) {
        AppLogger.error('Group not found for sharing: $groupId');
        return false;
      }

      // Validate user owns the content
      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) {
        AppLogger.error('No current user for group sharing');
        return false;
      }

      if (content.ownerId != currentUserId) {
        AppLogger.error('User does not own content for group sharing');
        return false;
      }

      // Use the social sharing repository to share to group
      final sharingRepository = ServiceLocator.get<SocialSharingRepository>();
      await sharingRepository.shareToGroup(groupId, content);

      AppLogger.success('Content shared to group: ${group.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to share content to group', e);
      return false;
    }
  }

  /// Share content to multiple groups
  Future<bool> shareContentToGroups({
    required List<String> groupIds,
    required SharedContent content,
  }) async {
    try {
      bool allSuccessful = true;

      for (final groupId in groupIds) {
        final success = await shareContentToGroup(
          groupId: groupId,
          content: content,
        );
        if (!success) {
          allSuccessful = false;
        }
      }

      if (allSuccessful) {
        AppLogger.success(
            'Content shared to ${groupIds.length} groups successfully');
      } else {
        AppLogger.warning('Some group sharing operations failed');
      }

      return allSuccessful;
    } catch (e) {
      AppLogger.error('Failed to share content to multiple groups', e);
      return false;
    }
  }

  /// Get all groups that content is shared with
  List<FriendCategory> getGroupsForSharedContent(String contentId) {
    try {
      // This would require querying SharedContent to get sharedWithGroupIds
      // For now, return empty list as implementation depends on content repository
      return [];
    } catch (e) {
      AppLogger.error('Failed to get groups for shared content', e);
      return [];
    }
  }

  // ===== GROUP MEMBER RESOLUTION =====

  /// Get all user IDs from a group for sharing purposes
  List<String> resolveGroupMembers(String groupId) {
    try {
      final group = _parent.getCategoryByIdInternal(groupId);
      if (group == null) {
        AppLogger.error('Group not found for member resolution: $groupId');
        return [];
      }

      // Return the friendUserIds from the group
      return List<String>.from(group.friendUserIds);
    } catch (e) {
      AppLogger.error('Failed to resolve group members', e);
      return [];
    }
  }

  /// Get UserProfile objects for all members in a group
  List<UserProfile> resolveGroupMemberProfiles(String groupId) {
    try {
      final memberIds = resolveGroupMembers(groupId);
      final friends = _parent.friendsInternal;

      return friends.where((friend) => memberIds.contains(friend.uid)).toList();
    } catch (e) {
      AppLogger.error('Failed to resolve group member profiles', e);
      return [];
    }
  }

  /// Resolve multiple groups to get all unique member IDs
  List<String> resolveMultipleGroupMembers(List<String> groupIds) {
    try {
      final Set<String> allMemberIds = {};

      for (final groupId in groupIds) {
        final memberIds = resolveGroupMembers(groupId);
        allMemberIds.addAll(memberIds);
      }

      return allMemberIds.toList();
    } catch (e) {
      AppLogger.error('Failed to resolve multiple group members', e);
      return [];
    }
  }

  // ===== GROUP SHARING VALIDATION =====

  bool canShareToGroup(String groupId, String userId) =>
      _validation.canShareToGroup(groupId, userId);
  bool canShareToGroups(List<String> groupIds, String userId) =>
      _validation.canShareToGroups(groupIds, userId);
  bool isGroupAccessible(String groupId) =>
      _validation.isGroupAccessible(groupId);

  // ===== GROUP SHARING STATISTICS =====

  /// Get sharing statistics for a group
  Map<String, dynamic> getGroupSharingStats(String groupId) {
    try {
      final group = _parent.getCategoryByIdInternal(groupId);
      if (group == null) {
        return {
          'groupName': 'Unknown',
          'memberCount': 0,
          'contentSharedToGroup': 0,
          'contentSharedByMembers': 0,
        };
      }

      // Basic stats - real implementation would query shared content
      return {
        'groupName': group.name,
        'memberCount': group.friendUserIds.length,
        'contentSharedToGroup': 0, // Would query SharedContent collection
        'contentSharedByMembers': 0, // Would aggregate member sharing
        'groupEmoji': group.emoji,
        'createdAt': group.createdAt,
        'isOwner': group.ownerId == _parent.currentUserId,
      };
    } catch (e) {
      AppLogger.error('Failed to get group sharing stats', e);
      return {
        'groupName': 'Error',
        'memberCount': 0,
        'contentSharedToGroup': 0,
        'contentSharedByMembers': 0,
      };
    }
  }

  /// Get sharing statistics for multiple groups
  Map<String, Map<String, dynamic>> getMultipleGroupSharingStats(
      List<String> groupIds) {
    try {
      final Map<String, Map<String, dynamic>> stats = {};

      for (final groupId in groupIds) {
        stats[groupId] = getGroupSharingStats(groupId);
      }

      return stats;
    } catch (e) {
      AppLogger.error('Failed to get multiple group sharing stats', e);
      return {};
    }
  }

  // ===== GROUP CONTENT DISCOVERY =====

  /// Retrieves all content that has been shared to a specific group.
  /// Queries the SharedContent repository to find all recipes, menus, and
  /// shopping lists that have been shared to the specified group. This method
  /// provides the foundation for group content feeds and activity timelines.
  /// @param [groupId] The unique identifier of the friend group
  /// @returns List of SharedContent objects shared to the group
  /// @throws Exception if repository access fails
  Future<List<SharedContent>> getContentSharedToGroup(String groupId) async {
    try {
      // Implementation pending SharedContent repository integration
      // Will query SharedContent collection filtered by group membership
      AppLogger.info('Getting content shared to group: $groupId');
      return [];
    } catch (e) {
      AppLogger.error('Failed to get content shared to group', e);
      return [];
    }
  }

  /// Retrieves all friend groups that contain content shared by a specific user.
  /// Queries the SharedContent repository to identify groups where the specified
  /// user has shared content. This enables users to track their sharing activity
  /// and manage content distribution across their social network.
  /// @param [userId] The unique identifier of the content owner
  /// @returns List of FriendCategory objects containing user's shared content
  /// @throws Exception if repository access fails
  Future<List<FriendCategory>> getGroupsWithSharedContent(String userId) async {
    try {
      // Implementation pending SharedContent repository integration
      // Will query SharedContent by owner and resolve associated groups
      AppLogger.info('Getting groups with shared content for user: $userId');
      return [];
    } catch (e) {
      AppLogger.error('Failed to get groups with shared content', e);
      return [];
    }
  }

  // ===== HELPER METHODS =====

  /// Get group by ID with error handling
  FriendCategory? getGroupById(String groupId) {
    return _parent.getCategoryByIdInternal(groupId);
  }

  /// Get all available groups for sharing
  List<FriendCategory> getAvailableGroupsForSharing() {
    try {
      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) return [];

      // Return groups that user owns or is a member of
      return _parent.getAllCategoriesInternal().where((group) {
        return group.ownerId == currentUserId ||
            group.friendUserIds.contains(currentUserId);
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get available groups for sharing', e);
      return [];
    }
  }

  /// Get group display information for UI
  Map<String, String> getGroupDisplayInfo(String groupId) {
    try {
      final group = _parent.getCategoryByIdInternal(groupId);
      if (group == null) {
        return {
          'name': 'Unknown Group',
          'emoji': '❓',
          'memberCount': '0',
        };
      }

      return {
        'name': group.name,
        'emoji': group.emoji ?? '👥',
        'memberCount': group.friendUserIds.length.toString(),
      };
    } catch (e) {
      AppLogger.error('Failed to get group display info', e);
      return {
        'name': 'Error',
        'emoji': '❌',
        'memberCount': '0',
      };
    }
  }

  // ===== BULK OPERATIONS =====

  Future<bool> shareContentToAllOwnedGroups({required SharedContent content}) =>
      _bulkOperations.shareContentToAllOwnedGroups(content);

  Future<Map<String, bool>> shareMultipleContentToGroup({
    required String groupId,
    required List<SharedContent> contentList,
  }) =>
      _bulkOperations.shareMultipleContentToGroup(
          groupId: groupId, contentList: contentList);

  Future<Map<String, bool>> shareContentToMultipleGroups({
    required List<String> groupIds,
    required SharedContent content,
    Function(String groupId, bool success)? onGroupComplete,
  }) =>
      _bulkOperations.shareContentToMultipleGroups(
          groupIds: groupIds,
          content: content,
          onGroupComplete: onGroupComplete);

  Future<Map<String, Map<String, bool>>> bulkShareContentToGroups({
    required List<String> groupIds,
    required List<SharedContent> contentList,
    Function(int completed, int total)? onProgress,
  }) =>
      _bulkOperations.bulkShareContentToGroups(
          groupIds: groupIds, contentList: contentList, onProgress: onProgress);

  Future<Map<String, bool>> removeContentFromGroups({
    required String contentId,
    required List<String> groupIds,
  }) =>
      _bulkOperations.removeContentFromGroups(
          contentId: contentId, groupIds: groupIds);

  Future<bool> removeContentFromAllGroups({required String contentId}) =>
      _bulkOperations.removeContentFromAllGroups(contentId);

  // ===== BULK OPERATION UTILITIES =====

  Map<String, dynamic> getBulkSharingSummary({
    required List<String> groupIds,
    required List<SharedContent> contentList,
  }) =>
      _validation.getBulkSharingSummary(
          groupIds: groupIds, contentList: contentList);

  Future<Map<String, dynamic>> validateBulkSharing({
    required List<String> groupIds,
    required List<SharedContent> contentList,
  }) =>
      _validation.validateBulkSharing(
          groupIds: groupIds, contentList: contentList);
}

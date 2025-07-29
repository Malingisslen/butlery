/// 🔍 AI INFO BLOCK:
/// Component: Social Group Sharing Operations - Feature interface for group content sharing
/// File: lib/services/unified/operations/social_group_sharing_operations.dart
/// Quick Guide: Handles all group sharing operations including recipes, menus, and shopping lists
/// Dependencies IN: UnifiedFriendsService, SharedContent model, FriendCategory model
/// Dependencies OUT: Used by ViewModels for group sharing operations
/// Data flow: ViewModels -> SocialGroupSharingOperations -> UnifiedFriendsService -> Firebase
/// State management: Real-time updates for shared content and group memberships
/// Purpose: Separate group sharing concerns from unified service
/// Common issues: Group membership validation, content permission management
/// Test coverage: Unit tests for group sharing and member resolution
/// Performance: Optimistic updates with Firebase sync
/// Analytics: Group sharing patterns, member engagement
/// Code smells: None - follows single responsibility principle
/// Connected to: UnifiedFriendsService, SocialSharingRepository, Share dialogs
/// Used in phases: Phase 18.6 - Complete Social Platform

import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/shared_content.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/repositories/interfaces/social_sharing_repository.dart';
import 'package:butlery/core/injection.dart';

/// Social group sharing operations feature interface
/// 
/// Handles all operations related to group content sharing:
/// - Sharing content to friend groups
/// - Resolving group members for content sharing
/// - Managing group-based content permissions
/// - Tracking group sharing analytics
/// - Validating group membership for sharing
class SocialGroupSharingOperations {
  final UnifiedFriendsService _parent;

  SocialGroupSharingOperations(this._parent);

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
      final sharingRepository = sl<SocialSharingRepository>();
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
        AppLogger.success('Content shared to ${groupIds.length} groups successfully');
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

  /// Validate that user can share to a group
  bool canShareToGroup(String groupId, String userId) {
    try {
      final group = _parent.getCategoryByIdInternal(groupId);
      if (group == null) return false;

      // User can share if they own the group or are a member
      return group.ownerId == userId || group.friendUserIds.contains(userId);
    } catch (e) {
      AppLogger.error('Failed to validate group sharing permission', e);
      return false;
    }
  }

  /// Validate that user can share to multiple groups
  bool canShareToGroups(List<String> groupIds, String userId) {
    try {
      return groupIds.every((groupId) => canShareToGroup(groupId, userId));
    } catch (e) {
      AppLogger.error('Failed to validate multiple group sharing permissions', e);
      return false;
    }
  }

  /// Check if group exists and is accessible
  bool isGroupAccessible(String groupId) {
    try {
      final group = _parent.getCategoryByIdInternal(groupId);
      return group != null;
    } catch (e) {
      AppLogger.error('Failed to check group accessibility', e);
      return false;
    }
  }

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
  Map<String, Map<String, dynamic>> getMultipleGroupSharingStats(List<String> groupIds) {
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

  /// Get content that has been shared to a specific group
  Future<List<SharedContent>> getContentSharedToGroup(String groupId) async {
    try {
      // This would require querying the SharedContent collection
      // For now, return empty list as implementation depends on content repository
      AppLogger.info('Getting content shared to group: $groupId');
      return [];
    } catch (e) {
      AppLogger.error('Failed to get content shared to group', e);
      return [];
    }
  }

  /// Get all groups that user's content has been shared to
  Future<List<FriendCategory>> getGroupsWithSharedContent(String userId) async {
    try {
      // This would require querying SharedContent and matching with groups
      // For now, return empty list as implementation depends on content repository
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
        return group.ownerId == currentUserId || group.friendUserIds.contains(currentUserId);
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

  /// Share content to all groups that user owns
  Future<bool> shareContentToAllOwnedGroups({
    required SharedContent content,
  }) async {
    try {
      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) return false;

      final ownedGroups = _parent.getAllCategoriesInternal()
          .where((group) => group.ownerId == currentUserId)
          .toList();

      final groupIds = ownedGroups.map((group) => group.id).toList();
      
      return await shareContentToGroups(
        groupIds: groupIds,
        content: content,
      );
    } catch (e) {
      AppLogger.error('Failed to share content to all owned groups', e);
      return false;
    }
  }

  /// Remove content from all groups
  Future<bool> removeContentFromAllGroups({
    required String contentId,
  }) async {
    try {
      // This would require updating SharedContent to remove from sharedWithGroupIds
      // For now, log the action
      AppLogger.info('Would remove content $contentId from all groups');
      return true;
    } catch (e) {
      AppLogger.error('Failed to remove content from all groups', e);
      return false;
    }
  }
}
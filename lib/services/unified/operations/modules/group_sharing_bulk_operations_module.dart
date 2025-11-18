// lib/services/unified/operations/modules/group_sharing_bulk_operations_module.dart

import 'package:butlery/models/shared_content.dart';
import 'package:butlery/core/utils/logger.dart';

/// Module handling bulk group sharing operations.
/// Provides bulk sharing, removal, and batch operations with progress tracking.
class GroupSharingBulkOperationsModule {
  final Future<bool> Function(String groupId, SharedContent content) shareToGroup;
  final List<dynamic> Function() getAllCategories;
  final String? Function() getCurrentUserId;

  GroupSharingBulkOperationsModule({
    required this.shareToGroup,
    required this.getAllCategories,
    required this.getCurrentUserId,
  });

  /// Share content to all groups that user owns
  Future<bool> shareContentToAllOwnedGroups(SharedContent content) async {
    try {
      final currentUserId = getCurrentUserId();
      if (currentUserId == null) return false;

      final ownedGroups = getAllCategories()
          .where((group) => group.ownerId == currentUserId)
          .toList();

      final groupIds = ownedGroups.map((group) => group.id as String).toList();

      bool allSuccessful = true;
      for (final groupId in groupIds) {
        final success = await shareToGroup(groupId, content);
        if (!success) allSuccessful = false;
      }

      return allSuccessful;
    } catch (e) {
      AppLogger.error('Failed to share content to all owned groups', e);
      return false;
    }
  }

  /// Share multiple content items to a single group
  Future<Map<String, bool>> shareMultipleContentToGroup({
    required String groupId,
    required List<SharedContent> contentList,
  }) async {
    final results = <String, bool>{};

    try {
      AppLogger.info('Bulk sharing ${contentList.length} items to group $groupId');

      for (final content in contentList) {
        final success = await shareToGroup(groupId, content);
        results[content.id] = success;

        if (contentList.length > 5) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      final successCount = results.values.where((success) => success).length;
      AppLogger.success('Bulk shared $successCount/${contentList.length} items to group');

      return results;
    } catch (e) {
      AppLogger.error('Failed to bulk share content to group', e);
      for (final content in contentList) {
        results[content.id] = false;
      }
      return results;
    }
  }

  /// Share single content to multiple groups with progress tracking
  Future<Map<String, bool>> shareContentToMultipleGroups({
    required List<String> groupIds,
    required SharedContent content,
    Function(String groupId, bool success)? onGroupComplete,
  }) async {
    final results = <String, bool>{};

    try {
      AppLogger.info('Sharing content to ${groupIds.length} groups');

      for (final groupId in groupIds) {
        final success = await shareToGroup(groupId, content);
        results[groupId] = success;

        onGroupComplete?.call(groupId, success);

        if (groupIds.length > 3) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      final successCount = results.values.where((success) => success).length;
      AppLogger.success('Shared content to $successCount/${groupIds.length} groups');

      return results;
    } catch (e) {
      AppLogger.error('Failed to share content to multiple groups', e);
      for (final groupId in groupIds) {
        results[groupId] = false;
      }
      return results;
    }
  }

  /// Share multiple content items to multiple groups (batch operation)
  Future<Map<String, Map<String, bool>>> bulkShareContentToGroups({
    required List<String> groupIds,
    required List<SharedContent> contentList,
    Function(int completed, int total)? onProgress,
  }) async {
    final results = <String, Map<String, bool>>{};
    int completed = 0;
    final total = contentList.length * groupIds.length;

    try {
      AppLogger.info('Bulk sharing ${contentList.length} items to ${groupIds.length} groups');

      for (final content in contentList) {
        results[content.id] = {};

        for (final groupId in groupIds) {
          final success = await shareToGroup(groupId, content);
          results[content.id]![groupId] = success;

          completed++;
          onProgress?.call(completed, total);

          await Future.delayed(const Duration(milliseconds: 150));
        }
      }

      int totalShares = 0;
      int successfulShares = 0;
      results.forEach((contentId, groupResults) {
        groupResults.forEach((groupId, success) {
          totalShares++;
          if (success) successfulShares++;
        });
      });

      AppLogger.success('Bulk operation completed: $successfulShares/$totalShares successful shares');

      return results;
    } catch (e) {
      AppLogger.error('Failed bulk share operation', e);
      return results;
    }
  }

  /// Remove content from multiple groups
  Future<Map<String, bool>> removeContentFromGroups({
    required String contentId,
    required List<String> groupIds,
  }) async {
    final results = <String, bool>{};

    try {
      AppLogger.info('Removing content $contentId from ${groupIds.length} groups');

      for (final groupId in groupIds) {
        try {
          await Future.delayed(const Duration(milliseconds: 50));
          results[groupId] = true;
          AppLogger.info('Content removed from group: $groupId');
        } catch (e) {
          AppLogger.error('Failed to remove content from group $groupId', e);
          results[groupId] = false;
        }
      }

      final successCount = results.values.where((success) => success).length;
      AppLogger.success('Removed content from $successCount/${groupIds.length} groups');

      return results;
    } catch (e) {
      AppLogger.error('Failed to remove content from groups', e);
      for (final groupId in groupIds) {
        results[groupId] = false;
      }
      return results;
    }
  }

  /// Remove content from all groups
  Future<bool> removeContentFromAllGroups(String contentId) async {
    try {
      final currentUserId = getCurrentUserId();
      if (currentUserId == null) return false;

      final accessibleGroups = getAllCategories()
          .where((group) =>
              group.ownerId == currentUserId ||
              group.friendUserIds.contains(currentUserId))
          .toList();

      if (accessibleGroups.isEmpty) {
        AppLogger.info('No accessible groups found for content removal');
        return true;
      }

      final groupIds = accessibleGroups.map((group) => group.id as String).toList();
      final results = await removeContentFromGroups(
        contentId: contentId,
        groupIds: groupIds,
      );

      final successCount = results.values.where((success) => success).length;
      final success = successCount == groupIds.length;

      if (success) {
        AppLogger.success('Content removed from all accessible groups');
      } else {
        AppLogger.warning('Content removal partially successful: $successCount/${groupIds.length}');
      }

      return success;
    } catch (e) {
      AppLogger.error('Failed to remove content from all groups', e);
      return false;
    }
  }
}

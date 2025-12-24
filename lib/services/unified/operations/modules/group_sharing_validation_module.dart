// lib/services/unified/operations/modules/group_sharing_validation_module.dart

import 'package:butlery/models/shared_content.dart';
import 'package:butlery/core/utils/logger.dart';

/// Module handling group sharing validation and utilities.
/// Provides permission validation, bulk sharing validation, and summary generation.
class GroupSharingValidationModule {
  final dynamic Function(String groupId) getCategoryById;
  final String? Function() getCurrentUserId;

  GroupSharingValidationModule({
    required this.getCategoryById,
    required this.getCurrentUserId,
  });

  /// Validate that user can share to a group
  bool canShareToGroup(String groupId, String userId) {
    try {
      final group = getCategoryById(groupId);
      if (group == null) return false;

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
      AppLogger.error(
          'Failed to validate multiple group sharing permissions', e);
      return false;
    }
  }

  /// Check if group exists and is accessible
  bool isGroupAccessible(String groupId) {
    try {
      final group = getCategoryById(groupId);
      return group != null;
    } catch (e) {
      AppLogger.error('Failed to check group accessibility', e);
      return false;
    }
  }

  /// Get sharing summary for bulk operations
  Map<String, dynamic> getBulkSharingSummary({
    required List<String> groupIds,
    required List<SharedContent> contentList,
  }) {
    try {
      final groupDetails = groupIds.map((groupId) {
        final group = getCategoryById(groupId);
        return {
          'id': groupId,
          'name': group?.name ?? 'Okänd grupp',
          'memberCount': group?.friendCount ?? 0,
          'accessible': group != null,
        };
      }).toList();

      final totalOperations = groupIds.length * contentList.length;
      final estimatedTime = (totalOperations * 0.2).round();

      return {
        'groupCount': groupIds.length,
        'contentCount': contentList.length,
        'totalOperations': totalOperations,
        'estimatedTimeSeconds': estimatedTime,
        'groupDetails': groupDetails,
        'contentTypes': _getContentTypeSummary(contentList),
        'accessibleGroups':
            groupDetails.where((g) => g['accessible'] == true).length,
        'inaccessibleGroups':
            groupDetails.where((g) => g['accessible'] == false).length,
      };
    } catch (e) {
      AppLogger.error('Failed to get bulk sharing summary', e);
      return {
        'error': 'Failed to analyze bulk sharing operation',
        'groupCount': groupIds.length,
        'contentCount': contentList.length,
      };
    }
  }

  /// Get content type summary for bulk operations
  Map<String, int> _getContentTypeSummary(List<SharedContent> contentList) {
    final summary = <String, int>{};
    for (final content in contentList) {
      summary[content.contentType] = (summary[content.contentType] ?? 0) + 1;
    }
    return summary;
  }

  /// Validate bulk sharing operation before execution
  Future<Map<String, dynamic>> validateBulkSharing({
    required List<String> groupIds,
    required List<SharedContent> contentList,
  }) async {
    try {
      final currentUserId = getCurrentUserId();
      if (currentUserId == null) {
        return {
          'valid': false,
          'error': 'User not authenticated',
        };
      }

      final invalidGroupIds = <String>[];
      final inaccessibleGroupIds = <String>[];

      for (final groupId in groupIds) {
        final group = getCategoryById(groupId);
        if (group == null) {
          invalidGroupIds.add(groupId);
        } else if (!canShareToGroup(groupId, currentUserId)) {
          inaccessibleGroupIds.add(groupId);
        }
      }

      final unauthorizedContentIds = <String>[];
      for (final content in contentList) {
        if (content.ownerId != currentUserId) {
          unauthorizedContentIds.add(content.id);
        }
      }

      final isValid = invalidGroupIds.isEmpty &&
          inaccessibleGroupIds.isEmpty &&
          unauthorizedContentIds.isEmpty;

      return {
        'valid': isValid,
        'invalidGroups': invalidGroupIds,
        'inaccessibleGroups': inaccessibleGroupIds,
        'unauthorizedContent': unauthorizedContentIds,
        'validOperations': isValid ? groupIds.length * contentList.length : 0,
        'warnings': _generateValidationWarnings(groupIds, contentList),
      };
    } catch (e) {
      AppLogger.error('Failed to validate bulk sharing', e);
      return {
        'valid': false,
        'error': 'Validation failed: ${e.toString()}',
      };
    }
  }

  /// Generate validation warnings for bulk operations
  List<String> _generateValidationWarnings(
      List<String> groupIds, List<SharedContent> contentList) {
    final warnings = <String>[];

    if (groupIds.length > 10) {
      warnings.add(
          'Delning till många grupper (${groupIds.length}) kan ta lång tid');
    }

    if (contentList.length > 20) {
      warnings.add(
          'Delning av mycket innehåll (${contentList.length} objekt) kan ta lång tid');
    }

    final totalOperations = groupIds.length * contentList.length;
    if (totalOperations > 100) {
      warnings.add(
          'Stor operation ($totalOperations delningar) - överväg att dela upp den');
    }

    return warnings;
  }
}

// lib/services/unified/operations/realtime_recipe/realtime_notification_module.dart

import '../../../../models/recipe_unified.dart';
import '../../../../core/utils/logger.dart';
import '../../../notifications/notification_service.dart';
import '../../../notifications/notification_types.dart';
import 'shared/realtime_recipe_utils.dart';

/// Realtime notification module
/// 
/// This module handles ONLY collaboration notification operations:
/// - Send collaboration joined/left notifications
/// - Send real-time edit notifications
/// - Send collaboration enabled/disabled notifications
/// - Manage notification preferences and delivery
/// 
/// ❌ DOES NOT CONTAIN: Watching, editing, presence, collaboration management
class RealtimeNotificationModule {
  final dynamic _parent; // UnifiedRecipeService
  final NotificationService? _notificationService;

  RealtimeNotificationModule(this._parent) : _notificationService = _initializeNotificationService(_parent);

  /// Initialize notification service
  static NotificationService? _initializeNotificationService(dynamic parent) {
    try {
      final currentUserId = parent.currentUserId;
      if (currentUserId != null) {
        final service = NotificationService(
          firestore: parent.firestore,
          userId: currentUserId,
        );
        service.initialize();
        return service;
      }
      return null;
    } catch (e) {
      AppLogger.warning('⚠️ Could not initialize notification service: $e');
      return null;
    }
  }

  // ===== COLLABORATION JOIN/LEAVE NOTIFICATIONS =====

  /// Send notification when user joins collaborative editing session
  Future<void> sendCollaborationJoinedNotification(Recipe recipe) async {
    if (_notificationService == null || !recipe.isCollaborative) {
      AppLogger.debug('Notification service not available or recipe not collaborative - skipping collaboration joined notification');
      return;
    }

    final currentUserId = _parent.currentUserId;
    final currentUserDisplayName = _parent.currentUserDisplayName ?? 'Unknown User';

    if (currentUserId == null || recipe.socialData?.memberPermissions == null) return;

    try {
      // Notify all other members that someone joined the collaboration
      for (final memberId in recipe.socialData?.memberPermissions?.keys ?? <String>[]) {
        if (memberId == currentUserId) continue; // Don't notify the user joining

        await _notificationService.sendSilentNotification(
          targetUserIds: [memberId],
          data: {
            'type': 'collaboration_joined',
            'recipeId': recipe.id,
            'recipeTitle': recipe.title,
            'joinerUserId': currentUserId,
            'joinerDisplayName': currentUserDisplayName,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      AppLogger.success('Collaboration joined notifications sent for recipe: ${recipe.title}');
    } catch (e) {
      AppLogger.warning('Failed to send collaboration joined notifications: $e');
    }
  }

  /// Send notification when user leaves collaborative editing session
  Future<void> sendCollaborationLeftNotification(Recipe recipe) async {
    if (_notificationService == null || !recipe.isCollaborative) {
      AppLogger.debug('Notification service not available or recipe not collaborative - skipping collaboration left notification');
      return;
    }

    final currentUserId = _parent.currentUserId;
    final currentUserDisplayName = _parent.currentUserDisplayName ?? 'Unknown User';

    if (currentUserId == null || recipe.socialData?.memberPermissions == null) return;

    try {
      // Notify all other members that someone left the collaboration
      for (final memberId in recipe.socialData?.memberPermissions?.keys ?? <String>[]) {
        if (memberId == currentUserId) continue; // Don't notify the user leaving

        await _notificationService.sendSilentNotification(
          targetUserIds: [memberId],
          data: {
            'type': 'collaboration_left',
            'recipeId': recipe.id,
            'recipeTitle': recipe.title,
            'leaverUserId': currentUserId,
            'leaverDisplayName': currentUserDisplayName,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      AppLogger.success('Collaboration left notifications sent for recipe: ${recipe.title}');
    } catch (e) {
      AppLogger.warning('Failed to send collaboration left notifications: $e');
    }
  }

  // ===== REAL-TIME EDIT NOTIFICATIONS =====

  /// Send notification about real-time edit to recipe
  Future<void> sendRealtimeEditNotification(
    Recipe recipe,
    Map<String, dynamic> changes,
    String? editDescription,
  ) async {
    if (_notificationService == null || !recipe.isCollaborative) {
      AppLogger.debug('Notification service not available or recipe not collaborative - skipping realtime edit notification');
      return;
    }

    final currentUserId = _parent.currentUserId;
    final currentUserDisplayName = _parent.currentUserDisplayName ?? 'Unknown User';

    if (currentUserId == null || recipe.socialData?.memberPermissions == null) return;

    try {
      // Determine what was changed for the notification
      final changeDescription = RealtimeRecipeUtils.getChangeDescription(changes);

      // Notify all other members about the real-time edit
      for (final memberId in recipe.socialData?.memberPermissions?.keys ?? <String>[]) {
        if (memberId == currentUserId) continue; // Don't notify the editor

        await _notificationService.sendSilentNotification(
          targetUserIds: [memberId],
          data: {
            'type': 'realtime_edit',
            'recipeId': recipe.id,
            'recipeTitle': recipe.title,
            'editorUserId': currentUserId,
            'editorDisplayName': currentUserDisplayName,
            'changeDescription': changeDescription,
            'editDescription': editDescription ?? '',
            'changes': changes,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      AppLogger.success('Realtime edit notifications sent for recipe: ${recipe.title}');
    } catch (e) {
      AppLogger.warning('Failed to send realtime edit notifications: $e');
    }
  }

  /// Send batch notification for multiple edits
  Future<void> sendBatchEditNotification(
    Recipe recipe,
    List<Map<String, dynamic>> changeList,
    String? batchDescription,
  ) async {
    if (_notificationService == null || !recipe.isCollaborative) return;

    final currentUserId = _parent.currentUserId;
    final currentUserDisplayName = _parent.currentUserDisplayName ?? 'Unknown User';

    if (currentUserId == null || recipe.socialData?.memberPermissions == null) return;

    try {
      // Combine all changes for description
      final allChanges = <String, dynamic>{};
      for (final changes in changeList) {
        allChanges.addAll(changes);
      }

      final changeDescription = RealtimeRecipeUtils.getChangeDescription(allChanges);

      // Notify all other members about the batch edit
      for (final memberId in recipe.socialData?.memberPermissions?.keys ?? <String>[]) {
        if (memberId == currentUserId) continue; // Don't notify the editor

        await _notificationService.sendSilentNotification(
          targetUserIds: [memberId],
          data: {
            'type': 'batch_edit',
            'recipeId': recipe.id,
            'recipeTitle': recipe.title,
            'editorUserId': currentUserId,
            'editorDisplayName': currentUserDisplayName,
            'changeDescription': changeDescription,
            'batchDescription': batchDescription ?? 'Flera ändringar',
            'editCount': changeList.length,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      AppLogger.success('Batch edit notifications sent for recipe: ${recipe.title}');
    } catch (e) {
      AppLogger.warning('Failed to send batch edit notifications: $e');
    }
  }

  // ===== COLLABORATION LIFECYCLE NOTIFICATIONS =====

  /// Send notification when collaborative editing is enabled for a recipe
  Future<void> sendCollaborationEnabledNotification(Recipe recipe, List<String> memberIds) async {
    if (_notificationService == null) {
      AppLogger.debug('Notification service not available - skipping collaboration enabled notification');
      return;
    }

    final currentUserId = _parent.currentUserId;
    final currentUserDisplayName = _parent.currentUserDisplayName ?? 'Unknown User';

    if (currentUserId == null) return;

    try {
      // Notify all invited members that collaborative editing has been enabled
      for (final memberId in memberIds) {
        if (memberId == currentUserId) continue; // Don't notify the owner

        await _notificationService.sendImmediateNotification(
          targetUserIds: [memberId],
          strategy: NotificationStrategy.collaborationEnabled,
          variables: {
            'enablerName': currentUserDisplayName,
            'recipeTitle': recipe.title,
          },
          additionalData: {
            'recipeId': recipe.id,
            'enablerUserId': currentUserId,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      AppLogger.success('Collaboration enabled notifications sent to ${memberIds.length} members');
    } catch (e) {
      AppLogger.warning('Failed to send collaboration enabled notifications: $e');
    }
  }

  /// Send notification when collaborative editing is disabled for a recipe
  Future<void> sendCollaborationDisabledNotification(Recipe recipe) async {
    if (_notificationService == null || !recipe.isCollaborative) return;

    final currentUserId = _parent.currentUserId;
    final currentUserDisplayName = _parent.currentUserDisplayName ?? 'Unknown User';

    if (currentUserId == null || recipe.socialData?.memberPermissions == null) return;

    try {
      // Notify all members that collaborative editing has been disabled
      for (final memberId in recipe.socialData?.memberPermissions?.keys ?? <String>[]) {
        if (memberId == currentUserId) continue; // Don't notify the owner

        await _notificationService.sendImmediateNotification(
          targetUserIds: [memberId],
          strategy: NotificationStrategy.collaborationEnabled, // Placeholder - would be collaborationDisabled
          variables: {
            'disablerName': currentUserDisplayName,
            'recipeTitle': recipe.title,
          },
          additionalData: {
            'recipeId': recipe.id,
            'disablerUserId': currentUserId,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      AppLogger.success('Collaboration disabled notifications sent for recipe: ${recipe.title}');
    } catch (e) {
      AppLogger.warning('Failed to send collaboration disabled notifications: $e');
    }
  }

  // ===== CONFLICT RESOLUTION NOTIFICATIONS =====

  /// Send notification when conflict occurs
  Future<void> sendConflictNotification(
    Recipe recipe,
    String conflictDescription,
    List<String> affectedUserIds,
  ) async {
    if (_notificationService == null || !recipe.isCollaborative) return;

    final currentUserId = _parent.currentUserId;
    final currentUserDisplayName = _parent.currentUserDisplayName ?? 'Unknown User';

    if (currentUserId == null) return;

    try {
      // Notify affected users about the conflict
      for (final userId in affectedUserIds) {
        await _notificationService.sendSilentNotification(
          targetUserIds: [userId],
          data: {
            'type': 'edit_conflict',
            'recipeId': recipe.id,
            'recipeTitle': recipe.title,
            'conflictDescription': conflictDescription,
            'reporterUserId': currentUserId,
            'reporterDisplayName': currentUserDisplayName,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      AppLogger.success('Conflict notifications sent to ${affectedUserIds.length} users');
    } catch (e) {
      AppLogger.warning('Failed to send conflict notifications: $e');
    }
  }

  /// Send notification when conflict is resolved
  Future<void> sendConflictResolvedNotification(
    Recipe recipe,
    String resolutionStrategy,
    List<String> affectedUserIds,
  ) async {
    if (_notificationService == null || !recipe.isCollaborative) return;

    final currentUserId = _parent.currentUserId;
    final currentUserDisplayName = _parent.currentUserDisplayName ?? 'Unknown User';

    if (currentUserId == null) return;

    try {
      // Notify affected users that conflict has been resolved
      for (final userId in affectedUserIds) {
        await _notificationService.sendSilentNotification(
          targetUserIds: [userId],
          data: {
            'type': 'conflict_resolved',
            'recipeId': recipe.id,
            'recipeTitle': recipe.title,
            'resolutionStrategy': resolutionStrategy,
            'resolverUserId': currentUserId,
            'resolverDisplayName': currentUserDisplayName,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      AppLogger.success('Conflict resolved notifications sent to ${affectedUserIds.length} users');
    } catch (e) {
      AppLogger.warning('Failed to send conflict resolved notifications: $e');
    }
  }

  // ===== MEMBER MANAGEMENT NOTIFICATIONS =====

  /// Send notification when members are added to collaboration
  Future<void> sendMembersAddedNotification(
    Recipe recipe,
    List<String> addedMemberIds,
  ) async {
    if (_notificationService == null || !recipe.isCollaborative) return;

    final currentUserId = _parent.currentUserId;
    final currentUserDisplayName = _parent.currentUserDisplayName ?? 'Unknown User';

    if (currentUserId == null) return;

    try {
      // Notify existing members about new additions
      final existingMembers = recipe.socialData?.memberPermissions?.keys.toList() ?? [];
      for (final memberId in existingMembers) {
        if (memberId == currentUserId || addedMemberIds.contains(memberId)) continue;

        await _notificationService.sendSilentNotification(
          targetUserIds: [memberId],
          data: {
            'type': 'members_added',
            'recipeId': recipe.id,
            'recipeTitle': recipe.title,
            'adderUserId': currentUserId,
            'adderDisplayName': currentUserDisplayName,
            'addedMemberCount': addedMemberIds.length,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      // Notify new members about being added
      for (final memberId in addedMemberIds) {
        await _notificationService.sendImmediateNotification(
          targetUserIds: [memberId],
          strategy: NotificationStrategy.collaborationEnabled, // Placeholder - would be addedToCollaboration
          variables: {
            'adderName': currentUserDisplayName,
            'recipeTitle': recipe.title,
          },
          additionalData: {
            'recipeId': recipe.id,
            'adderUserId': currentUserId,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      AppLogger.success('Members added notifications sent for recipe: ${recipe.title}');
    } catch (e) {
      AppLogger.warning('Failed to send members added notifications: $e');
    }
  }

  /// Send notification when members are removed from collaboration
  Future<void> sendMembersRemovedNotification(
    Recipe recipe,
    List<String> removedMemberIds,
  ) async {
    if (_notificationService == null || !recipe.isCollaborative) return;

    final currentUserId = _parent.currentUserId;
    final currentUserDisplayName = _parent.currentUserDisplayName ?? 'Unknown User';

    if (currentUserId == null) return;

    try {
      // Notify remaining members about removals
      final remainingMembers = recipe.socialData?.memberPermissions?.keys
          .where((id) => !removedMemberIds.contains(id))
          .toList() ?? [];
          
      for (final memberId in remainingMembers) {
        if (memberId == currentUserId) continue;

        await _notificationService.sendSilentNotification(
          targetUserIds: [memberId],
          data: {
            'type': 'members_removed',
            'recipeId': recipe.id,
            'recipeTitle': recipe.title,
            'removerUserId': currentUserId,
            'removerDisplayName': currentUserDisplayName,
            'removedMemberCount': removedMemberIds.length,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      // Notify removed members
      for (final memberId in removedMemberIds) {
        await _notificationService.sendImmediateNotification(
          targetUserIds: [memberId],
          strategy: NotificationStrategy.collaborationEnabled, // Placeholder - would be removedFromCollaboration
          variables: {
            'removerName': currentUserDisplayName,
            'recipeTitle': recipe.title,
          },
          additionalData: {
            'recipeId': recipe.id,
            'removerUserId': currentUserId,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      AppLogger.success('Members removed notifications sent for recipe: ${recipe.title}');
    } catch (e) {
      AppLogger.warning('Failed to send members removed notifications: $e');
    }
  }

  // ===== NOTIFICATION UTILITIES =====

  /// Send custom realtime notification
  Future<void> sendCustomRealtimeNotification({
    required Recipe recipe,
    required String notificationType,
    required Map<String, dynamic> data,
    List<String>? targetMemberIds,
  }) async {
    if (_notificationService == null || !recipe.isCollaborative) return;

    final currentUserId = _parent.currentUserId;
    if (currentUserId == null) return;

    try {
      final members = targetMemberIds ?? 
          recipe.socialData?.memberPermissions?.keys.toList() ?? [];

      for (final memberId in members) {
        if (memberId == currentUserId) continue; // Don't notify sender

        await _notificationService.sendSilentNotification(
          targetUserIds: [memberId],
          data: {
            'type': notificationType,
            'recipeId': recipe.id,
            'recipeTitle': recipe.title,
            'senderUserId': currentUserId,
            'timestamp': DateTime.now().toIso8601String(),
            ...data,
          },
        );
      }

      AppLogger.success('Custom realtime notification sent: $notificationType');
    } catch (e) {
      AppLogger.warning('Failed to send custom realtime notification: $e');
    }
  }

  /// Get notification statistics
  Map<String, dynamic> getNotificationStatistics() {
    return {
      'hasNotificationService': _notificationService != null,
      'isInitialized': _notificationService != null, // Simplified check
      'currentUserId': _parent.currentUserId,
      'notificationServiceType': _notificationService?.runtimeType.toString(),
    };
  }

  /// Check if notifications are available
  bool get isNotificationAvailable => _notificationService != null;

  /// Get notification preferences (placeholder for future implementation)
  Map<String, bool> getNotificationPreferences() {
    return {
      'collaborationJoined': true,
      'collaborationLeft': true,
      'realtimeEdit': true,
      'batchEdit': true,
      'collaborationEnabled': true,
      'collaborationDisabled': true,
      'editConflict': true,
      'conflictResolved': true,
      'membersAdded': true,
      'membersRemoved': true,
    };
  }

  /// Update notification preferences (placeholder for future implementation)
  Future<bool> updateNotificationPreferences(Map<String, bool> preferences) async {
    try {
      // This would update user notification preferences in Firebase
      AppLogger.info('Updated notification preferences: ${preferences.length} settings');
      return true;
    } catch (e) {
      AppLogger.error('Failed to update notification preferences', e);
      return false;
    }
  }
}
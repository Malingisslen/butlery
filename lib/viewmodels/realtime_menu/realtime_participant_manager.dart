// lib/viewmodels/realtime_menu/realtime_participant_manager.dart

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/realtime/participant_tracker.dart';

/// Focused module for realtime menu participant management
/// 
/// This module handles ONLY participant operations:
/// - Adding and removing participants
/// - Permission management
/// - Participant tracking and activity
/// - Permission validation
/// 
/// ❌ DOES NOT CONTAIN: UI state, menu content operations, streaming
class RealtimeParticipantManager {
  final RealtimeMenuService _menuService;
  final ParticipantTracker _participantTracker;
  final PermissionService _permissionService;

  RealtimeParticipantManager({
    required RealtimeMenuService menuService,
    required ParticipantTracker participantTracker,
  }) : _menuService = menuService,
       _participantTracker = participantTracker,
       _permissionService = ServiceLocator.get<PermissionService>();

  // ===== PERMISSION GETTERS =====

  /// Current user ID
  String? get currentUserId => _permissionService.currentUserId;

  /// Check if current user can edit menu
  bool canEdit(String menuId) {
    return _permissionService.canEditRecipe(menuId);
  }

  /// Check if current user can manage participants
  bool canManageParticipants(String menuId) {
    return _permissionService.canInviteToRecipe(menuId);
  }

  /// Check if current user can delete menu
  bool canDeleteMenu(String menuId) {
    // Assuming owner or admin rights needed for deletion
    return _permissionService.canInviteToRecipe(menuId);
  }

  // ===== PARTICIPANT OPERATIONS =====

  /// Add participant to menu
  Future<void> addParticipant({
    required String menuId,
    required String userId,
    required String userDisplayName,
    required ResourcePermission permission,
  }) async {
    if (!canManageParticipants(menuId)) {
      throw Exception('Ingen behörighet att hantera deltagare');
    }

    AppLogger.info('👤 Adding participant: $userDisplayName ($permission)');

    try {
      await _menuService.addParticipant(
        resourceId: menuId,
        userId: userId,
        userDisplayName: userDisplayName,
        permission: permission,
      );

      // Update participant tracker
      _participantTracker.updateDisplayName(userId, userDisplayName);

      AppLogger.success('✅ Participant added: $userDisplayName');
    } catch (e) {
      AppLogger.error('❌ Failed to add participant: $userDisplayName', e);
      rethrow;
    }
  }

  /// Remove participant from menu
  Future<void> removeParticipant({
    required String menuId,
    required String userId,
  }) async {
    if (!canManageParticipants(menuId)) {
      throw Exception('Ingen behörighet att hantera deltagare');
    }

    if (userId == currentUserId) {
      throw Exception('Kan inte ta bort sig själv som deltagare');
    }

    AppLogger.info('👤 Removing participant: $userId');

    try {
      await _menuService.removeParticipant(
        resourceId: menuId,
        userId: userId,
      );

      // Remove from participant tracker
      _participantTracker.removeParticipant(userId);

      AppLogger.success('✅ Participant removed');
    } catch (e) {
      AppLogger.error('❌ Failed to remove participant', e);
      rethrow;
    }
  }

  /// Update participant permission
  Future<void> updateParticipantPermission({
    required String menuId,
    required String userId,
    required ResourcePermission newPermission,
  }) async {
    if (!canManageParticipants(menuId)) {
      throw Exception('Ingen behörighet att hantera deltagare');
    }

    if (userId == currentUserId) {
      throw Exception('Kan inte ändra sina egna behörigheter');
    }

    AppLogger.info('👤 Updating participant permission: $userId -> $newPermission');

    try {
      await _menuService.updateParticipantPermission(
        resourceId: menuId,
        userId: userId,
        newPermission: newPermission,
      );

      AppLogger.success('✅ Participant permission updated');
    } catch (e) {
      AppLogger.error('❌ Failed to update participant permission', e);
      rethrow;
    }
  }

  /// Leave menu as participant
  Future<void> leaveMenu({
    required String menuId,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('Ingen användar-ID tillgänglig');
    }

    AppLogger.info('👤 Leaving menu: $menuId');

    try {
      await _menuService.removeParticipant(
        resourceId: menuId,
        userId: userId,
      );

      AppLogger.success('✅ Left menu successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to leave menu', e);
      rethrow;
    }
  }

  // ===== PARTICIPANT TRACKING =====

  /// Get active participant count
  int get activeParticipantCount => _participantTracker.activeCount;

  /// Get all participant activities
  List<ParticipantActivity> get participantActivities =>
      _participantTracker.allActivities;

  /// Get online participants
  List<String> get onlineParticipants => _participantTracker.onlineParticipants;

  /// Update participant tracker from menu
  void updateFromMenu(RealtimeMenu menu) {
    _participantTracker.updateFromMenu(menu);
  }

  /// Update participant display name
  void updateParticipantDisplayName(String userId, String displayName) {
    _participantTracker.updateDisplayName(userId, displayName);
  }

  /// Remove participant from tracker
  void removeParticipantFromTracker(String userId) {
    _participantTracker.removeParticipant(userId);
  }

  // ===== PARTICIPANT VALIDATION =====

  /// Validate user ID for participant operations
  bool validateUserId(String? userId) {
    if (userId == null || userId.isEmpty) {
      AppLogger.warning('⚠️ Invalid user ID provided');
      return false;
    }
    return true;
  }

  /// Validate display name
  bool validateDisplayName(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) {
      AppLogger.warning('⚠️ Invalid display name provided');
      return false;
    }
    return true;
  }

  /// Validate permission level
  bool validatePermission(ResourcePermission? permission) {
    if (permission == null) {
      AppLogger.warning('⚠️ Invalid permission provided');
      return false;
    }
    return true;
  }

  /// Check if user is already a participant
  bool isUserParticipant(String userId, RealtimeMenu menu) {
    return menu.participants.containsKey(userId);
  }

  /// Check if adding participant would exceed limits
  bool canAddMoreParticipants(RealtimeMenu menu, {int maxParticipants = 50}) {
    return menu.participants.length < maxParticipants;
  }

  // ===== PERMISSION ANALYSIS =====

  /// Get participant permission level
  ResourcePermission? getParticipantPermission(String userId, RealtimeMenu menu) {
    return menu.participants[userId];
  }

  /// Get all participants with specific permission
  List<String> getParticipantsWithPermission(
    RealtimeMenu menu, 
    ResourcePermission permission,
  ) {
    return menu.participants.entries
        .where((entry) => entry.value == permission)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get participants by permission level
  Map<ResourcePermission, List<String>> groupParticipantsByPermission(
    RealtimeMenu menu,
  ) {
    final grouped = <ResourcePermission, List<String>>{};
    
    for (final entry in menu.participants.entries) {
      grouped.putIfAbsent(entry.value, () => []).add(entry.key);
    }
    
    return grouped;
  }

  /// Count participants by permission
  Map<ResourcePermission, int> countParticipantsByPermission(
    RealtimeMenu menu,
  ) {
    final counts = <ResourcePermission, int>{};
    
    for (final permission in menu.participants.values) {
      counts[permission] = (counts[permission] ?? 0) + 1;
    }
    
    return counts;
  }

  // ===== PARTICIPANT STATISTICS =====

  /// Get participant statistics
  Map<String, dynamic> getParticipantStats(RealtimeMenu menu) {
    final permissionCounts = countParticipantsByPermission(menu);
    
    return {
      'totalParticipants': menu.participants.length,
      'owners': permissionCounts[ResourcePermission.owner] ?? 0,
      'admins': permissionCounts[ResourcePermission.admin] ?? 0,
      'editors': permissionCounts[ResourcePermission.editor] ?? 0,
      'viewers': permissionCounts[ResourcePermission.viewer] ?? 0,
      'activeParticipants': activeParticipantCount,
      'onlineParticipants': onlineParticipants.length,
    };
  }

  /// Get participation summary for display
  String getParticipationSummary(RealtimeMenu menu) {
    final total = menu.participants.length;
    final online = onlineParticipants.length;
    
    if (total == 1) {
      return 'Bara du';
    } else if (online == total) {
      return '$total deltagare (alla online)';
    } else if (online == 0) {
      return '$total deltagare (alla offline)';
    } else {
      return '$total deltagare ($online online)';
    }
  }

  // ===== BULK OPERATIONS =====

  /// Add multiple participants at once
  Future<void> addMultipleParticipants({
    required String menuId,
    required List<Map<String, dynamic>> participants,
  }) async {
    if (!canManageParticipants(menuId)) {
      throw Exception('Ingen behörighet att hantera deltagare');
    }

    AppLogger.info('👥 Adding ${participants.length} participants');

    try {
      for (final participant in participants) {
        await addParticipant(
          menuId: menuId,
          userId: participant['userId'] as String,
          userDisplayName: participant['displayName'] as String,
          permission: participant['permission'] as ResourcePermission,
        );
      }
      
      AppLogger.success('✅ ${participants.length} participants added');
    } catch (e) {
      AppLogger.error('❌ Failed to add multiple participants', e);
      rethrow;
    }
  }

  /// Remove multiple participants at once
  Future<void> removeMultipleParticipants({
    required String menuId,
    required List<String> userIds,
  }) async {
    if (!canManageParticipants(menuId)) {
      throw Exception('Ingen behörighet att hantera deltagare');
    }

    // Filter out current user
    final filteredIds = userIds.where((id) => id != currentUserId).toList();
    
    if (filteredIds.isEmpty) {
      AppLogger.warning('⚠️ No valid participants to remove');
      return;
    }

    AppLogger.info('👥 Removing ${filteredIds.length} participants');

    try {
      for (final userId in filteredIds) {
        await removeParticipant(menuId: menuId, userId: userId);
      }
      
      AppLogger.success('✅ ${filteredIds.length} participants removed');
    } catch (e) {
      AppLogger.error('❌ Failed to remove multiple participants', e);
      rethrow;
    }
  }

  // ===== CLEANUP =====

  /// Dispose and cleanup resources
  void dispose() {
    _participantTracker.dispose();
  }
}
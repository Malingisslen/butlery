// lib/services/unified/operations/realtime_recipe/shared/realtime_diagnostics_helper.dart

/// Diagnostics helper for realtime recipe operations.
class RealtimeDiagnosticsHelper {
  /// Get module status information
  static Map<String, dynamic> getModuleStatus({
    required dynamic watchingModule,
    required dynamic presenceModule,
    required dynamic notificationModule,
  }) {
    return {
      'watchingModule': {
        'isAvailable': watchingModule.isWatchingAvailable(),
        'capabilities': watchingModule.getWatchingCapabilities(),
        'isConnected': watchingModule.isConnected,
      },
      'editingModule': {
        'isInitialized': true,
      },
      'collaborationModule': {
        'isInitialized': true,
      },
      'presenceModule': {
        'statistics': presenceModule.getPresenceStatistics(),
      },
      'notificationModule': {
        'isAvailable': notificationModule.isNotificationAvailable,
        'statistics': notificationModule.getNotificationStatistics(),
      },
    };
  }

  /// Get comprehensive realtime operations status
  static Map<String, dynamic> getRealtimeOperationsStatus({
    required bool hasRealtimeService,
    required bool isConnected,
    required Map<String, dynamic> moduleStatus,
    required String? currentUserId,
  }) {
    return {
      'hasRealtimeService': hasRealtimeService,
      'isConnected': isConnected,
      'moduleStatus': moduleStatus,
      'currentUserId': currentUserId,
      'architecture': 'modular',
      'version': '2.0',
    };
  }
}

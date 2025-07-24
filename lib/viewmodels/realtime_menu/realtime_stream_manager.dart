// lib/viewmodels/realtime_menu/realtime_stream_manager.dart

import 'dart:async';
import '../../models/realtime/realtime_menu.dart';
import '../../services/realtime/realtime_menu_service.dart';
import '../../core/utils/logger.dart';

/// Focused module for realtime menu streaming
/// 
/// This module handles ONLY streaming and connection management:
/// - Real-time menu subscription management
/// - Stream lifecycle (start/stop/pause)
/// - Connection monitoring and error handling
/// - Stream state validation
/// 
/// ❌ DOES NOT CONTAIN: UI state, menu operations, participant management
class RealtimeStreamManager {
  final RealtimeMenuService _menuService;
  
  StreamSubscription<RealtimeMenu>? _menuSubscription;
  String? _currentMenuId;
  bool _isStreaming = false;

  // Callbacks for communicating with parent
  final void Function(RealtimeMenu) onMenuUpdated;
  final void Function(dynamic) onMenuError;
  final void Function() onStreamStarted;
  final void Function() onStreamStopped;

  RealtimeStreamManager({
    required RealtimeMenuService menuService,
    required this.onMenuUpdated,
    required this.onMenuError,
    required this.onStreamStarted,
    required this.onStreamStopped,
  }) : _menuService = menuService;

  // ===== STREAM STATE =====

  bool get isStreaming => _isStreaming;
  String? get currentMenuId => _currentMenuId;
  bool get hasActiveSubscription => _menuSubscription != null;

  // ===== STREAM OPERATIONS =====

  /// Start watching a realtime menu
  Future<void> startWatching(String menuId) async {
    if (_isStreaming && _currentMenuId == menuId) {
      AppLogger.info('🔄 Already watching menu: $menuId');
      return;
    }

    // Stop any existing stream first
    await stopWatching();

    try {
      AppLogger.info('🎮 Starting to watch menu: $menuId');

      _currentMenuId = menuId;
      _menuSubscription = _menuService.watchRealtimeMenu(menuId).listen(
        _handleMenuUpdate,
        onError: _handleMenuError,
        onDone: _handleStreamDone,
      );

      _isStreaming = true;
      onStreamStarted();
      
      AppLogger.success('✅ Stream started for menu: $menuId');
    } catch (e) {
      AppLogger.error('❌ Failed to start watching menu', e);
      await _cleanup();
      rethrow;
    }
  }

  /// Stop watching the current menu
  Future<void> stopWatching() async {
    if (!_isStreaming) return;

    AppLogger.info('🛑 Stopping menu watch for: $_currentMenuId');

    await _cleanup();
    onStreamStopped();

    AppLogger.success('✅ Stream stopped');
  }

  /// Pause streaming (keeps subscription but ignores updates)
  void pauseStreaming() {
    if (_isStreaming) {
      _isStreaming = false;
      AppLogger.info('⏸️ Stream paused for: $_currentMenuId');
    }
  }

  /// Resume streaming
  void resumeStreaming() {
    if (!_isStreaming && _menuSubscription != null) {
      _isStreaming = true;
      AppLogger.info('▶️ Stream resumed for: $_currentMenuId');
    }
  }

  // ===== CONNECTION MANAGEMENT =====

  /// Check if stream is healthy
  bool isStreamHealthy() {
    return _isStreaming && 
           _menuSubscription != null && 
           _currentMenuId != null;
  }

  /// Restart stream with current menu ID
  Future<void> restartStream() async {
    if (_currentMenuId == null) {
      AppLogger.warning('⚠️ Cannot restart stream - no menu ID');
      return;
    }

    final menuId = _currentMenuId!;
    AppLogger.info('🔄 Restarting stream for: $menuId');
    
    await stopWatching();
    await startWatching(menuId);
  }

  /// Force reconnection
  Future<void> forceReconnect() async {
    AppLogger.info('🔄 Forcing stream reconnection');
    
    if (_currentMenuId != null) {
      await restartStream();
    } else {
      AppLogger.warning('⚠️ Cannot reconnect - no active menu');
    }
  }

  // ===== STREAM EVENT HANDLERS =====

  void _handleMenuUpdate(RealtimeMenu menu) {
    if (!_isStreaming) {
      AppLogger.info('📥 Ignoring menu update - stream paused');
      return;
    }

    AppLogger.info('📥 Menu update received: ${menu.menuTitle}');
    onMenuUpdated(menu);
  }

  void _handleMenuError(dynamic error) {
    AppLogger.error('❌ Stream error for menu: $_currentMenuId', error);
    
    // Don't clean up immediately - let the parent decide
    onMenuError(error);
  }

  void _handleStreamDone() {
    AppLogger.info('🏁 Stream completed for menu: $_currentMenuId');
    _isStreaming = false;
    onStreamStopped();
  }

  /// Internal cleanup without callbacks
  Future<void> _cleanup() async {
    try {
      await _menuSubscription?.cancel();
    } catch (e) {
      AppLogger.warning('⚠️ Error cancelling subscription: $e');
    }
    
    _menuSubscription = null;
    _currentMenuId = null;
    _isStreaming = false;
  }

  // ===== STREAM VALIDATION =====

  /// Validate menu ID before starting stream
  bool validateMenuId(String? menuId) {
    if (menuId == null || menuId.isEmpty) {
      AppLogger.error('❌ Invalid menu ID provided');
      return false;
    }
    return true;
  }

  /// Check if we can start streaming
  bool canStartStreaming(String menuId) {
    if (!validateMenuId(menuId)) return false;
    
    // Allow restart of same menu
    if (_isStreaming && _currentMenuId == menuId) {
      return true;
    }
    
    return true;
  }

  // ===== STREAM STATISTICS =====

  /// Get stream duration if active
  Duration? getStreamDuration() {
    // This would require tracking start time
    // Implementation depends on whether you need this feature
    return null;
  }

  /// Get connection statistics
  Map<String, dynamic> getConnectionStats() {
    return {
      'isStreaming': _isStreaming,
      'hasSubscription': _menuSubscription != null,
      'currentMenuId': _currentMenuId,
      'isHealthy': isStreamHealthy(),
    };
  }

  // ===== CLEANUP =====

  /// Dispose and cleanup all resources
  Future<void> dispose() async {
    AppLogger.info('🗑️ Disposing stream manager');
    await _cleanup();
  }
}
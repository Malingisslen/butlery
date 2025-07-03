// lib/viewmodels/realtime/connection_monitor.dart

import 'dart:async';
import '../../services/realtime_sync_service.dart';
import '../../core/utils/logger.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Connection Monitor - SINGLE RESPONSIBILITY för connection status tracking
/// File: viewmodels/realtime/connection_monitor.dart
/// Quick Guide: Delegated ansvar från ViewModel - bara connection monitoring
/// Dependencies IN: RealtimeSyncService, logger
/// Dependencies OUT: RealtimeMenuViewModel
/// Data flow: Firebase connection → Stream monitoring → Status change → Notify
/// State management: Internal connection state med debounced notifications
/// Purpose: BARA hantera online/offline status och connection events
/// Common issues: Connection flapping, memory leaks från StreamSubscription
/// Test coverage: 0% (ny komponent)
/// Performance: ⚡ Minimal overhead, debounced status changes
/// Analytics: Connection stability, offline duration, reconnection patterns
/// Code smells: ✅ Clean single responsibility - bara connection logic
/// Connected to: RealtimeMenuViewModel
/// Used in phases: Fas 3 (SRP refactoring) - Clean architecture delegation

/// Status för connection monitoring
enum ConnectionStatus {
  unknown,
  connecting,
  connected,
  disconnected,
  reconnecting,
}

/// Monitor för real-time connection status
class ConnectionMonitor {
  final RealtimeSyncService _syncService;
  StreamSubscription<bool>? _connectionSubscription;

  bool _isConnectionStable = true;
  ConnectionStatus _status = ConnectionStatus.unknown;
  DateTime? _lastConnectionChange;
  Timer? _debounceTimer;

  /// Callback när connection status ändras
  final void Function(bool isOnline)? onConnectionChanged;
  final void Function(ConnectionStatus status)? onStatusChanged;

  ConnectionMonitor({
    required RealtimeSyncService syncService,
    this.onConnectionChanged,
    this.onStatusChanged,
  }) : _syncService = syncService {
    _startMonitoring();
  }

  /// Är vi online och anslutna?
  bool get isOnline => _isConnectionStable && _syncService.isConnected;

  /// Aktuell connection status
  ConnectionStatus get status => _status;

  /// Senaste connection change
  DateTime? get lastConnectionChange => _lastConnectionChange;

  /// Har vi varit online kontinuerligt senaste X minuter?
  bool hasBeenStableFor(Duration duration) {
    if (!isOnline || _lastConnectionChange == null) return false;
    return DateTime.now().difference(_lastConnectionChange!) >= duration;
  }

  /// Connection uptime (hur länge vi varit online)
  Duration? get connectionUptime {
    if (!isOnline || _lastConnectionChange == null) return null;
    return DateTime.now().difference(_lastConnectionChange!);
  }

  /// Starta övervakning av connection status
  void _startMonitoring() {
    AppLogger.info('🔌 Startar connection monitoring');

    _connectionSubscription = _syncService.connectionStream.listen(
      (isConnected) {
        _onConnectionStatusChanged(isConnected);
      },
      onError: (error) {
        AppLogger.error('❌ Connection stream fel', error);
        _setStatus(ConnectionStatus.disconnected);
      },
    );

    // Initial status check
    _onConnectionStatusChanged(_syncService.isConnected);
  }

  /// Hantera connection status ändringar med debouncing
  void _onConnectionStatusChanged(bool isConnected) {
    final wasOnline = isOnline;
    _isConnectionStable = isConnected;

    // Debounce rapid connection changes (ignorera flapping)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _processConnectionChange(wasOnline, isOnline, isConnected);
    });
  }

  void _processConnectionChange(
      bool wasOnline, bool isNowOnline, bool isConnected) {
    if (wasOnline != isNowOnline) {
      _lastConnectionChange = DateTime.now();

      // Uppdatera status
      if (isNowOnline) {
        _setStatus(ConnectionStatus.connected);
        AppLogger.success('🌐 Connection ONLINE - stabil anslutning');
      } else {
        _setStatus(ConnectionStatus.disconnected);
        AppLogger.warning('📡 Connection OFFLINE - försöker återansluta...');
      }

      // Notifiera lyssnare
      onConnectionChanged?.call(isNowOnline);
    }

    // Detaljerad status tracking
    if (isConnected) {
      if (_status == ConnectionStatus.reconnecting) {
        _setStatus(ConnectionStatus.connected);
        AppLogger.success('🔄 Återanslutning lyckad');
      } else if (_status == ConnectionStatus.unknown) {
        _setStatus(ConnectionStatus.connected);
      }
    } else {
      if (_status == ConnectionStatus.connected) {
        _setStatus(ConnectionStatus.reconnecting);
        AppLogger.info('🔄 Försöker återansluta...');
      }
    }
  }

  void _setStatus(ConnectionStatus newStatus) {
    if (_status != newStatus) {
      final oldStatus = _status;
      _status = newStatus;
      onStatusChanged?.call(_status);
      AppLogger.debug('📶 Connection status: $oldStatus → $newStatus');
    }
  }

  /// Tvinga en connection check
  void forceConnectionCheck() {
    AppLogger.info('🔍 Tvingar connection check');
    _onConnectionStatusChanged(_syncService.isConnected);
  }

  /// Få human-readable connection status
  String get statusDescription {
    switch (_status) {
      case ConnectionStatus.unknown:
        return 'Kontrollerar anslutning...';
      case ConnectionStatus.connecting:
        return 'Ansluter...';
      case ConnectionStatus.connected:
        return 'Ansluten';
      case ConnectionStatus.disconnected:
        return 'Frånkopplad';
      case ConnectionStatus.reconnecting:
        return 'Återansluter...';
    }
  }

  /// Få emoji för connection status
  String get statusEmoji {
    switch (_status) {
      case ConnectionStatus.unknown:
        return '❓';
      case ConnectionStatus.connecting:
        return '🔄';
      case ConnectionStatus.connected:
        return '🟢';
      case ConnectionStatus.disconnected:
        return '🔴';
      case ConnectionStatus.reconnecting:
        return '🟡';
    }
  }

  /// Statistik för debugging
  Map<String, dynamic> get debugInfo {
    return {
      'isOnline': isOnline,
      'status': status.name,
      'lastChange': _lastConnectionChange?.toIso8601String(),
      'uptime': connectionUptime?.inSeconds,
      'stable': hasBeenStableFor(const Duration(minutes: 1)),
    };
  }

  void dispose() {
    AppLogger.info('🗑️ ConnectionMonitor disposing');

    _debounceTimer?.cancel();
    _connectionSubscription?.cancel();

    AppLogger.debug('🗑️ ConnectionMonitor disposed');
  }
}

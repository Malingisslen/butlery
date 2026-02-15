// lib/viewmodels/realtime/connection_monitor.dart

import 'dart:async';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/l10n/app_locale.dart';

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
    _debounceTimer = Timer(AppDimensions.animationDurationSlow, () {
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
        return AppLocale.current.statusCheckingConnection;
      case ConnectionStatus.connecting:
        return AppLocale.current.statusConnecting;
      case ConnectionStatus.connected:
        return AppLocale.current.statusConnecting;
      case ConnectionStatus.disconnected:
        return AppLocale.current.errorNoInternetConnection;
      case ConnectionStatus.reconnecting:
        return AppLocale.current.statusReconnecting;
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

  Future<void> dispose() async {
    AppLogger.info('🗑️ ConnectionMonitor disposing');

    _debounceTimer?.cancel();
    _debounceTimer = null;

    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    AppLogger.debug('🗑️ ConnectionMonitor disposed');
  }
}

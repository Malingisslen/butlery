/// Real-time synchronization service for Firebase-based collaborative editing with conflict resolution.
/// Provides realtime document streams, intelligent conflict resolution, and connection management.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/cache/lru_map.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';

// Realtime modules
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime/connection_state_module.dart';
import 'package:butlery/services/realtime/resource_parser_module.dart';
import 'package:butlery/services/realtime/conflict_resolution_module.dart';

/// Real-time synchronization service with modular connection, parsing, and conflict resolution.
class RealtimeSyncService extends BaseService with StreamManagementMixin {
  @override
  String get serviceName => 'RealtimeSyncService';
  final FirestoreRepository _firestoreRepository;
  final auth.AuthRepository _authRepository;

  // Modules
  late final ConnectionStateModule _connectionModule;
  late final ResourceParserModule _parserModule;
  late final ConflictResolutionModule _conflictModule;

  RealtimeSyncService({
    required FirestoreRepository firestoreRepository,
    required auth.AuthRepository authRepository,
  })  : _firestoreRepository = firestoreRepository,
        _authRepository = authRepository {
    // Initialize StreamControllers using StreamManagementMixin
    _connectionController =
        createBroadcastController<bool>(name: 'connection_state');
    _errorController =
        createBroadcastController<SyncError>(name: 'sync_errors');

    // Initialize modules
    _initializeModules();
  }

  // ignore: close_sinks - Disposed in onDispose() via disposeStreamResources()
  late final StreamController<bool> _connectionController;
  // ignore: close_sinks - Disposed in onDispose() via disposeStreamResources()
  late final StreamController<SyncError> _errorController;
  final Map<String, StreamSubscription<DocumentSnapshot>> _activeListeners = {};

  /// BUT-779: bounded so power-user sessions don't grow this map linearly
  /// with activity. 200 covers typical sessions (50-100 resources observed)
  /// with headroom; eviction telemetry surfaces if the bound is too tight.
  static const int _cachedResourcesMaxSize = 200;
  late final LruMap<String, RealtimeResource> _cachedResources = LruMap(
    maxSize: _cachedResourcesMaxSize,
    // BUT-779 review: info-level so the bound-tuning signal is visible in
    // production logs (debug is silenced/stripped in release builds, defeating
    // the whole purpose of the eviction telemetry).
    onEvict: (key, _) => AppLogger.info(
        'cache_eviction service=$serviceName key=$key bound=$_cachedResourcesMaxSize'),
  );
  SyncError? _lastError;
  void _initializeModules() {
    _connectionModule = ConnectionStateModule(
      firestoreRepository: _firestoreRepository,
      authRepository: _authRepository,
      connectionController: _connectionController,
      onConnectionStateChanged: (_) {},
      notifyListeners: () => notifyListeners(),
      onUserLoggedOut: () {
        _closeAllListeners();
        _cachedResources.clear();
      },
    );

    _parserModule = ResourceParserModule(
      firestoreRepository: _firestoreRepository,
    );

    _conflictModule = ConflictResolutionModule(
      firestoreRepository: _firestoreRepository,
      getLatestResource: _parserModule.getLatestResource,
    );
  }

  /// Are we connected to Firebase?
  bool get isConnected => _connectionModule.isConnected;

  /// Stream for connection status
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Senaste synkroniseringsfel
  SyncError? get lastError => _lastError;

  /// Stream for synchronization errors
  Stream<SyncError> get errorStream => _errorController.stream;

  /// Number of active listeners (for debugging)
  int get activeListenersCount => _activeListeners.length;

  /// Current user
  String? get _currentUserId => _authRepository.currentUserId;

  /// Add listener for state changes
  void addListener(VoidCallback listener) {
    _connectionModule.addListener(listener);
  }

  /// Remove listener for state changes
  void removeListener(VoidCallback listener) {
    _connectionModule.removeListener(listener);
  }

  /// Notify all listeners of state changes
  void notifyListeners() {
    _connectionModule.notifyAllListeners();
  }

  /// Initialize the service
  @override
  Future<void> initialize() async {
    await safeExecute(
      () async {
        AppLogger.info('🔄 Initialiserar RealtimeSyncService...');

        // Start connection monitoring and auth listeners via module
        _connectionModule.startConnectionMonitoring(_handleError);
        _connectionModule.setupAuthStateListener();

        AppLogger.success('✅ RealtimeSyncService initierad');
      },
      operationName: 'Initialize RealtimeSync Service',
      customErrorMessage: 'Could not initialize realtime sync service',
    );
  }

  /// Watch a resource for real-time updates
  Stream<T> watchResource<T extends RealtimeResource>(String resourceId) {
    if (_currentUserId == null) {
      return Stream.error(
        SyncError(
          type: SyncErrorType.permissionDenied,
          message: AppLocale.current.errorUserNotLoggedIn,
          resourceId: resourceId,
        ),
      );
    }

    AppLogger.info('👀 Startar watching av resurs: $resourceId');

    final docRef = _parserModule.getResourceDocRef(resourceId);

    return docRef.snapshots().map<T>((snapshot) {
      if (!snapshot.exists) {
        throw SyncError(
          type: SyncErrorType.documentNotFound,
          message: AppLocale.current.errorResourceNotFound,
          resourceId: resourceId,
        );
      }

      try {
        // Parse generic resource from snapshot using module
        final resource = _parserModule.parseResourceFromSnapshot<T>(snapshot);

        // Cache resource locally
        _cachedResources[resourceId] = resource;

        AppLogger.info(
            '📥 Resurs uppdaterad: $resourceId (${resource.runtimeType})');
        return resource;
      } catch (e) {
        AppLogger.error('❌ Kunde inte parsa resurs $resourceId', e);
        throw SyncError(
          type: SyncErrorType.firestoreError,
          message: AppLocale.current.syncErrorParsingResource,
          resourceId: resourceId,
          originalError: e,
        );
      }
    }).transform(
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, stackTrace, sink) {
          _handleError(
            SyncErrorType.firestoreError,
            AppLocale.current.syncErrorWatchingResource(resourceId),
            resourceId: resourceId,
            originalError: error,
          );
          sink.addError(error, stackTrace);
        },
      ),
    );
  }

  /// Update a resource with conflict resolution
  Future<void> updateResource<T extends RealtimeResource>(T resource) async {
    if (_currentUserId == null) {
      throw SyncError(
        type: SyncErrorType.permissionDenied,
        message: AppLocale.current.errorUserNotLoggedIn,
        resourceId: resource.id,
        resourceType: resource.type,
      );
    }

    AppLogger.info(
        '💾 Uppdaterar resurs: ${resource.id} (${resource.runtimeType})');

    try {
      // Check permission (from the model, not business logic here)
      if (!resource.canUserEdit(_currentUserId!)) {
        throw SyncError(
          type: SyncErrorType.permissionDenied,
          message: AppLocale.current.errorNoEditPermission,
          resourceId: resource.id,
          resourceType: resource.type,
        );
      }

      final docRef = _parserModule.getResourceDocRef(resource.id);

      // Check if conflict resolution is needed
      final shouldResolveConflict =
          await _conflictModule.shouldResolveConflict(resource);

      if (shouldResolveConflict) {
        final remote = await _parserModule.getLatestResource<T>(resource.id);
        final resolvedResource =
            await _conflictModule.resolveConflict<T>(resource, remote);
        await _conflictModule.performUpdate(docRef, resolvedResource);
      } else {
        await _conflictModule.performUpdate(docRef, resource);
      }

      // Update local cache and tracking
      _cachedResources[resource.id] = resource;
      _conflictModule.recordLocalUpdate(resource.id);

      AppLogger.success('✅ Resurs uppdaterad: ${resource.id}');
    } catch (e) {
      AppLogger.error('❌ Kunde inte uppdatera resurs ${resource.id}', e);

      if (e is SyncError) {
        _handleError(e.type, e.message,
            resourceId: resource.id,
            resourceType: resource.type,
            originalError: e.originalError);
      } else {
        _handleError(SyncErrorType.firestoreError, 'Uppdateringsfel: $e',
            resourceId: resource.id,
            resourceType: resource.type,
            originalError: e);
      }
      rethrow;
    }
  }

  /// Ta bort en realtidsresurs
  Future<void> deleteResource(
      String resourceId, RealtimeResourceType type) async {
    if (_currentUserId == null) {
      throw SyncError(
        type: SyncErrorType.permissionDenied,
        message: AppLocale.current.errorUserNotLoggedIn,
        resourceId: resourceId,
        resourceType: type,
      );
    }

    AppLogger.info('🗑️ Tar bort resurs: $resourceId ($type)');

    try {
      // Fetch resource to check permissions
      final resource =
          await _parserModule.getLatestResource<RealtimeResource>(resourceId);

      if (!resource.canUserDelete(_currentUserId!)) {
        throw SyncError(
          type: SyncErrorType.permissionDenied,
          message: AppLocale.current.errorNoDeletePermission,
          resourceId: resourceId,
          resourceType: type,
        );
      }

      final docRef = _parserModule.getResourceDocRef(resourceId);
      await _firestoreRepository.deleteDocument(docRef);

      // Clear local cache and tracking
      _cachedResources.remove(resourceId);
      _conflictModule.removeTracking(resourceId);

      // Close active listener
      await _closeListener(resourceId);

      AppLogger.success('✅ Resurs borttagen: $resourceId');
    } catch (e) {
      AppLogger.error('❌ Kunde inte ta bort resurs $resourceId', e);

      if (e is SyncError) {
        _handleError(e.type, e.message,
            resourceId: resourceId,
            resourceType: type,
            originalError: e.originalError);
      } else {
        _handleError(SyncErrorType.firestoreError, 'Borttagningsfel: $e',
            resourceId: resourceId, resourceType: type, originalError: e);
      }
      rethrow;
    }
  }

  /// Resolve conflicts using edit count and timestamp strategy
  Future<T> resolveConflict<T extends RealtimeResource>(
      T local, T remote) async {
    AppLogger.info('⚠️ Löser konflikt för resurs: ${local.id}');

    try {
      // Standard conflict resolution: senaste editCount vinner
      if (local.editCount > remote.editCount) {
        AppLogger.info(
            '📝 Lokal version vinner (editCount: ${local.editCount} > ${remote.editCount})');
        return local;
      } else if (remote.editCount > local.editCount) {
        AppLogger.info(
            '☁️ Remote version vinner (editCount: ${remote.editCount} > ${local.editCount})');
        return remote;
      } else {
        // Same editCount - use timestamp
        if (local.lastEditedAt.isAfter(remote.lastEditedAt)) {
          AppLogger.info('📝 Lokal version vinner (nyare timestamp)');
          return local;
        } else {
          AppLogger.info('☁️ Remote version vinner (nyare timestamp)');
          return remote;
        }
      }
    } catch (e) {
      AppLogger.error('❌ Fel vid conflict resolution för ${local.id}', e);

      // On conflict resolution error, choose remote version (safer)
      AppLogger.warning(
          '🛡️ Väljer remote version vid conflict resolution-fel');
      return remote;
    }
  }

  /// Close specific listener
  Future<void> _closeListener(String resourceId) async {
    final subscription = _activeListeners.remove(resourceId);
    await subscription?.cancel();
  }

  /// Close all active listeners
  void _closeAllListeners() {
    for (final subscription in _activeListeners.values) {
      subscription.cancel();
    }
    _activeListeners.clear();
    AppLogger.info('🔒 Alla listeners stängda');
  }

  /// Hantera fel och notifiera lyssnare
  void _handleError(
    SyncErrorType type,
    String message, {
    String? resourceId,
    RealtimeResourceType? resourceType,
    dynamic originalError,
  }) {
    _lastError = SyncError(
      type: type,
      message: message,
      resourceId: resourceId,
      resourceType: resourceType,
      originalError: originalError,
    );

    _errorController.add(_lastError!);
    AppLogger.error('🔥 SyncError: $message', originalError);
    notifyListeners();
  }

  /// Rensa felstatus
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  /// Force update of all active listeners (for refresh)
  void refreshAllResources() {
    AppLogger.info('🔄 Tvinga refresh av alla aktiva resurser');
    // Listeners uppdateras automatiskt via Firebase snapshots
    notifyListeners();
  }

  /// Get cached version of resource (without Firebase call)
  T? getCachedResource<T extends RealtimeResource>(String resourceId) {
    return _cachedResources[resourceId] as T?;
  }

  /// Fetch the latest version of a resource directly from Firestore (bypasses cache).
  /// Use this before read-modify-write operations to avoid stale data.
  Future<T?> fetchLatestResource<T extends RealtimeResource>(
      String resourceId) async {
    try {
      return await _parserModule.getLatestResource<T>(resourceId);
    } catch (e) {
      AppLogger.error('Failed to fetch latest resource: $resourceId', e);
      return null;
    }
  }

  /// Check if resource is actively watched
  bool isResourceWatched(String resourceId) {
    return _activeListeners.containsKey(resourceId);
  }

  @override
  Future<void> onDispose() async {
    _closeAllListeners();
    await disposeStreamResources(); // StreamManagementMixin handles controllers and subscriptions
    _cachedResources.clear();
    _conflictModule.clearTracking();
    _connectionModule.dispose();
  }
}

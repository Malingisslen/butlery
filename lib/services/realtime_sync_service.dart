/// Real-time synchronization service for Firebase-based collaborative editing with conflict resolution.
/// Provides realtime document streams, intelligent conflict resolution, and connection management.

import 'dart:async';
import 'package:clock/clock.dart';
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
  }) : _firestoreRepository = firestoreRepository,
       _authRepository = authRepository {
    // Initialize StreamControllers using StreamManagementMixin
    _connectionController = createBroadcastController<bool>(
      name: 'connection_state',
    );
    _errorController = createBroadcastController<SyncError>(
      name: 'sync_errors',
    );
    _conflictController = createBroadcastController<ConflictEvent>(
      name: 'sync_conflicts',
    );

    // Initialize modules
    _initializeModules();
  }

  // ignore: close_sinks - Disposed in onDispose() via disposeStreamResources()
  late final StreamController<bool> _connectionController;
  // ignore: close_sinks - Disposed in onDispose() via disposeStreamResources()
  late final StreamController<SyncError> _errorController;
  // ignore: close_sinks - Disposed in onDispose() via disposeStreamResources()
  late final StreamController<ConflictEvent> _conflictController;

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
      'cache_eviction service=$serviceName key=$key bound=$_cachedResourcesMaxSize',
    ),
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
        _cachedResources.clear();
      },
    );

    _parserModule = ResourceParserModule(
      firestoreRepository: _firestoreRepository,
    );

    _conflictModule = ConflictResolutionModule(
      firestoreRepository: _firestoreRepository,
      getLatestResource: _parserModule.getLatestResource,
      // BUT-1031: route resolved conflicts onto the broadcast stream so the
      // ConflictBanner widget can surface silent last-write-wins picks.
      onConflict: (event) {
        if (!_conflictController.isClosed) {
          _conflictController.add(event);
        }
      },
    );
  }

  /// Are we connected to Firebase?
  bool get isConnected => _connectionModule.isConnected;

  /// Stream for connection status
  Stream<bool> get connectionStream => _connectionController.stream;

  /// BUT-1031: broadcast stream of collaborative-edit conflicts the resolver
  /// has settled. UI surfaces (e.g. `ConflictBanner`) subscribe to render a
  /// non-blocking banner so users notice when their edit was overwritten.
  Stream<ConflictEvent> get conflictStream => _conflictController.stream;

  /// Senaste synkroniseringsfel
  SyncError? get lastError => _lastError;

  /// Global side-channel of synchronization errors.
  ///
  /// BUT-1069 made `watchResource` propagate errors on BOTH the main stream
  /// AND this side-channel. BUT-1082 explicitly chose NOT to re-expose this
  /// stream through downstream wrappers (`RealtimeRecipeService`,
  /// `realtime_watching_module`) because zero production consumers exist
  /// today; speculative wrapper-forwarding plumbing was deferred until a
  /// real consumer arrives. If you need global error logging, subscribe
  /// to this getter directly on the underlying `RealtimeSyncService`.
  Stream<SyncError> get errorStream => _errorController.stream;

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

    return docRef
        .snapshots()
        .map<T>((snapshot) {
          if (!snapshot.exists) {
            throw SyncError(
              type: SyncErrorType.documentNotFound,
              message: AppLocale.current.errorResourceNotFound,
              resourceId: resourceId,
            );
          }

          try {
            // Parse generic resource from snapshot using module
            final resource = _parserModule.parseResourceFromSnapshot<T>(
              snapshot,
            );

            // Cache resource locally
            _cachedResources[resourceId] = resource;

            AppLogger.info(
              '📥 Resurs uppdaterad: $resourceId (${resource.runtimeType})',
            );
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
        })
        .transform(
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
      '💾 Uppdaterar resurs: ${resource.id} (${resource.runtimeType})',
    );

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
      final shouldResolveConflict = await _conflictModule.shouldResolveConflict(
        resource,
      );

      // Track which version actually reached Firestore so the local cache
      // stays coherent with persisted state. When conflict resolution picks
      // the REMOTE (the local edit lost), caching `resource` would leave
      // getCachedResource handing out the user's discarded edit while
      // Firestore holds the winner — a silent cache/disk divergence that
      // confuses any read-modify-write keyed off the cache.
      final T persisted;
      if (shouldResolveConflict) {
        final remote = await _parserModule.getLatestResource<T>(resource.id);
        persisted = await _conflictModule.resolveConflict<T>(resource, remote);
        await _conflictModule.performUpdate(docRef, persisted);
      } else {
        persisted = resource;
        await _conflictModule.performUpdate(docRef, resource);
      }

      // Update local cache and tracking with the version that won.
      _cachedResources[resource.id] = persisted;
      _conflictModule.recordLocalUpdate(resource.id);

      AppLogger.success('✅ Resurs uppdaterad: ${resource.id}');
    } catch (e) {
      AppLogger.error('❌ Kunde inte uppdatera resurs ${resource.id}', e);

      if (e is SyncError) {
        _handleError(
          e.type,
          e.message,
          resourceId: resource.id,
          resourceType: resource.type,
          originalError: e.originalError,
        );
      } else {
        _handleError(
          SyncErrorType.firestoreError,
          'Uppdateringsfel: $e',
          resourceId: resource.id,
          resourceType: resource.type,
          originalError: e,
        );
      }
      rethrow;
    }
  }

  /// BUT-1163: re-apply a local snapshot that LOST a conflict so it wins the
  /// next round, used by the conflict-recovery screen ("Behåll min version").
  ///
  /// Re-persisting the captured snapshot verbatim would write back its stale
  /// `editCount` (which was <= the remote's — that's *why* it lost). The very
  /// next concurrent edit would then compare against that stale counter and
  /// silently discard the just-recovered version again. So we rebuild the
  /// local content on top of the latest remote's `editCount + 1` and a fresh
  /// `lastEditedAt`, making the recovered version legitimately win subsequent
  /// `resolveConflict` comparisons.
  Future<void> recoverLocalVersion<T extends RealtimeResource>(T local) async {
    // Base the bump on the current remote so the recovered version outranks
    // whatever overwrote it. If the remote can't be read, fall back to the
    // local snapshot's own counter — still bumped below, never regressed.
    int baseEditCount = local.editCount;
    try {
      final remote = await _parserModule.getLatestResource<T>(local.id);
      if (remote.editCount > baseEditCount) {
        baseEditCount = remote.editCount;
      }
    } catch (e) {
      AppLogger.warning(
        '⚠️ Kunde inte hämta remote-version vid återställning ${local.id}: $e',
      );
    }

    final recovered =
        local.copyWithMetadata(
              editCount: baseEditCount + 1,
              lastEditedAt: clock.now(),
              lastEditedBy: _currentUserId ?? local.lastEditedBy,
            )
            as T;

    await updateResource<T>(recovered);
  }

  /// Ta bort en realtidsresurs
  Future<void> deleteResource(
    String resourceId,
    RealtimeResourceType type,
  ) async {
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
      final resource = await _parserModule.getLatestResource<RealtimeResource>(
        resourceId,
      );

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

      AppLogger.success('✅ Resurs borttagen: $resourceId');
    } catch (e) {
      AppLogger.error('❌ Kunde inte ta bort resurs $resourceId', e);

      if (e is SyncError) {
        _handleError(
          e.type,
          e.message,
          resourceId: resourceId,
          resourceType: type,
          originalError: e.originalError,
        );
      } else {
        _handleError(
          SyncErrorType.firestoreError,
          'Borttagningsfel: $e',
          resourceId: resourceId,
          resourceType: type,
          originalError: e,
        );
      }
      rethrow;
    }
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
    String resourceId,
  ) async {
    try {
      return await _parserModule.getLatestResource<T>(resourceId);
    } catch (e) {
      AppLogger.error('Failed to fetch latest resource: $resourceId', e);
      return null;
    }
  }

  @override
  Future<void> onDispose() async {
    await disposeStreamResources(); // StreamManagementMixin handles controllers and subscriptions
    _cachedResources.clear();
    _conflictModule.clearTracking();
    _connectionModule.dispose();
  }
}

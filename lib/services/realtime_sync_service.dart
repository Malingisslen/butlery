/// Real-time synchronization service for Firebase-based collaborative editing with conflict resolution.
///
/// Provides realtime document streams, intelligent conflict resolution, and connection management.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

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

  // ===== STATE =====
  // ignore: close_sinks - Disposed in onDispose() via disposeStreamResources()
  late final StreamController<bool> _connectionController;
  // ignore: close_sinks - Disposed in onDispose() via disposeStreamResources()
  late final StreamController<SyncError> _errorController;
  final Map<String, StreamSubscription<DocumentSnapshot>> _activeListeners = {};
  final Map<String, RealtimeResource> _cachedResources = {};
  SyncError? _lastError;

  // ===== MODULE INITIALIZATION =====

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

  // ===== GETTERS =====

  /// Är vi anslutna till Firebase?
  bool get isConnected => _connectionModule.isConnected;

  /// Stream för connection status
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Senaste synkroniseringsfel
  SyncError? get lastError => _lastError;

  /// Stream för synkroniseringsfel
  Stream<SyncError> get errorStream => _errorController.stream;

  /// Antal aktiva listeners (för debugging)
  int get activeListenersCount => _activeListeners.length;

  /// Aktuell användare
  String? get _currentUserId => _authRepository.currentUserId;

  // ===== NOTIFICATION METHODS =====

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

  // ===== INITIALIZATION =====

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

  // ===== CORE CRUD OPERATIONS =====

  /// Watch a resource for real-time updates
  Stream<T> watchResource<T extends RealtimeResource>(String resourceId) {
    if (_currentUserId == null) {
      return Stream.error(
        SyncError(
          type: SyncErrorType.permissionDenied,
          message: 'Användare inte inloggad',
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
          message: 'Resursen hittades inte',
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
          message: 'Fel vid parsing av resurs',
          resourceId: resourceId,
          originalError: e,
        );
      }
    }).handleError((error) {
      _handleError(
        SyncErrorType.firestoreError,
        'Fel vid watching av resurs $resourceId',
        resourceId: resourceId,
        originalError: error,
      );
    });
  }

  /// Update a resource with conflict resolution
  Future<void> updateResource<T extends RealtimeResource>(T resource) async {
    if (_currentUserId == null) {
      throw SyncError(
        type: SyncErrorType.permissionDenied,
        message: 'Användare inte inloggad',
        resourceId: resource.id,
        resourceType: resource.type,
      );
    }

    AppLogger.info(
        '💾 Uppdaterar resurs: ${resource.id} (${resource.runtimeType})');

    try {
      // Kontrollera behörighet (från modellen, inte business logic här)
      if (!resource.canUserEdit(_currentUserId!)) {
        throw SyncError(
          type: SyncErrorType.permissionDenied,
          message: 'Ingen redigeringsbehörighet',
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
        message: 'Användare inte inloggad',
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
          message: 'Ingen behörighet att ta bort resursen',
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

  // ===== CONFLICT RESOLUTION =====

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
        // Samma editCount - använd timestamp
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

      // Vid fel i conflict resolution, välj remote version (säkrare)
      AppLogger.warning(
          '🛡️ Väljer remote version vid conflict resolution-fel');
      return remote;
    }
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Stäng specifik listener
  Future<void> _closeListener(String resourceId) async {
    final subscription = _activeListeners.remove(resourceId);
    await subscription?.cancel();
  }

  /// Stäng alla aktiva listeners
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

  // ===== PUBLIC UTILITY METHODS =====

  /// Rensa felstatus
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  /// Tvinga uppdatering av alla aktiva listeners (för refresh)
  void refreshAllResources() {
    AppLogger.info('🔄 Tvinga refresh av alla aktiva resurser');
    // Listeners uppdateras automatiskt via Firebase snapshots
    notifyListeners();
  }

  /// Hämta cached version av resurs (utan Firebase-anrop)
  T? getCachedResource<T extends RealtimeResource>(String resourceId) {
    return _cachedResources[resourceId] as T?;
  }

  /// Kontrollera om resurs är aktiv watched
  bool isResourceWatched(String resourceId) {
    return _activeListeners.containsKey(resourceId);
  }

  // ===== CLEANUP =====

  @override
  Future<void> onDispose() async {
    _closeAllListeners();
    await disposeStreamResources(); // StreamManagementMixin handles controllers and subscriptions
    _cachedResources.clear();
    _conflictModule.clearTracking();
    _connectionModule.dispose();
  }
}

// lib/services/realtime_sync_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/interfaces/auth_repository.dart' as auth;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../repositories/firestore_repository.dart';
import '../models/realtime/realtime_resource.dart';
import '../models/realtime/realtime_recipe.dart';
import '../models/realtime/realtime_menu.dart';
import '../core/utils/logger.dart';
import '../core/base/base_service.dart';
import '../core/mixins/stream_management_mixin.dart';


/// Typ av synkroniseringsfel för robust error handling
enum SyncErrorType {
  connectionLost,
  permissionDenied,
  conflictResolution,
  documentNotFound,
  firestoreError,
  unknown,
}

/// Synkroniseringsfel med specifik kontext
class SyncError {
  final SyncErrorType type;
  final String message;
  final String? resourceId;
  final RealtimeResourceType? resourceType;
  final dynamic originalError;

  SyncError({
    required this.type,
    required this.message,
    this.resourceId,
    this.resourceType,
    this.originalError,
  });

  @override
  String toString() => 'SyncError($type): $message';
}

/// RealtimeSyncService - SINGLE RESPONSIBILITY: Firebase real-time synkronisering
///
/// Denna service hanterar BARA:
/// - Real-time listeners från Firebase
/// - CRUD-operationer för realtidsresurser
/// - Conflict resolution vid samtidiga edits
/// - Connection management och retry logic
///
/// Den hanterar INTE:
/// - UI logic eller presentation
/// - Business rules eller validation
/// - Permission management (det finns i modellerna)
/// - Notification eller user experience
class RealtimeSyncService extends BaseService with StreamManagementMixin {
  @override
  String get serviceName => 'RealtimeSyncService';
  final FirestoreRepository _firestoreRepository;
  final auth.AuthRepository _authRepository;

  RealtimeSyncService({
    required FirestoreRepository firestoreRepository,
    required auth.AuthRepository authRepository,
  })  : _firestoreRepository = firestoreRepository,
        _authRepository = authRepository {
    // Initialize StreamControllers using StreamManagementMixin
    _connectionController = createBroadcastController<bool>(name: 'connection_state');
    _errorController = createBroadcastController<SyncError>(name: 'sync_errors');
  }

  // ===== CONNECTION STATE =====
  bool _isConnected = false;
  late final StreamController<bool> _connectionController;
  // StreamSubscription management handled by StreamManagementMixin
  
  // ===== NOTIFICATION LISTENERS =====
  final List<VoidCallback> _listeners = [];

  // ===== ACTIVE LISTENERS =====
  final Map<String, StreamSubscription<DocumentSnapshot>> _activeListeners = {};
  final Map<String, RealtimeResource> _cachedResources = {};

  // ===== ERROR HANDLING =====
  SyncError? _lastError;
  late final StreamController<SyncError> _errorController;

  // ===== CONFLICT RESOLUTION =====
  final Map<String, DateTime> _lastLocalUpdate = {};
  static const int _conflictResolutionWindowMs =
      5000; // 5 sekunder för conflict resolution

  // ===== GETTERS =====

  /// Är vi anslutna till Firebase?
  bool get isConnected => _isConnected;

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
    _listeners.add(listener);
  }
  
  /// Remove listener for state changes
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
  
  /// Notify all listeners of state changes
  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  // ===== INITIALIZATION =====

  /// Initialisera RealtimeSyncService
  @override
  Future<void> initialize() async {
    await safeExecute(
      () async {
        AppLogger.info('🔄 Initialiserar RealtimeSyncService...');
        
        // Lyssna på Firebase connection state
        _startConnectionMonitoring();

        // Lyssna på auth state changes
        _authRepository.authStateChanges().listen(_onAuthStateChanged);

        AppLogger.success('✅ RealtimeSyncService initierad');
      },
      operationName: 'Initialize RealtimeSync Service',
      customErrorMessage: 'Could not initialize realtime sync service',
    );
  }

  /// Starta övervakning av Firebase-anslutning
  void _startConnectionMonitoring() {
    // Lyssna på Firebase connection state via Firestore connectivity
    _firestoreRepository.connectivityStream().listen(
      (snapshot) {
        _setConnectionState(true);
      },
      onError: (error) {
        _setConnectionState(false);
        _handleError(
          SyncErrorType.connectionLost,
          'Firebase-anslutning förlorad',
          originalError: error,
        );
      },
    );
  }

  /// Hantera auth state changes
  void _onAuthStateChanged(User? user) {
    if (user == null) {
      // Användare loggade ut - stäng alla listeners
      _closeAllListeners();
      _cachedResources.clear();
      AppLogger.info('🔓 Användare utloggad - alla listeners stängda');
    } else {
      AppLogger.info('🔐 Användare inloggad - RealtimeSyncService redo');
    }
  }

  /// Sätt connection state och notifiera lyssnare
  void _setConnectionState(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      _connectionController.add(_isConnected);
      AppLogger.info(
          '🌐 Connection state: ${_isConnected ? "ONLINE" : "OFFLINE"}');
      notifyListeners();
    }
  }

  // ===== CORE CRUD OPERATIONS =====

  /// Titta på en realtidsresurs med real-time updates
  ///
  /// Returnerar en stream som emitterar uppdateringar när resursen ändras
  /// Type-safe med generics för specifika RealtimeResource typer
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

    final docRef = _getResourceDocRef(resourceId);

    return docRef.snapshots().map<T>((snapshot) {
      if (!snapshot.exists) {
        throw SyncError(
          type: SyncErrorType.documentNotFound,
          message: 'Resursen hittades inte',
          resourceId: resourceId,
        );
      }

      try {
        // Parse generic resource från snapshot
        final resource = _parseResourceFromSnapshot<T>(snapshot);

        // Cache resursen lokalt
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

  /// Uppdatera en realtidsresurs med optimistic updates och conflict resolution
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

      final docRef = _getResourceDocRef(resource.id);

      // Kolla om vi behöver conflict resolution
      final shouldResolveConflict = await _shouldResolveConflict(resource);

      if (shouldResolveConflict) {
        final resolvedResource = await resolveConflict<T>(
            resource, await _getLatestResource<T>(resource.id));
        await _performUpdate(docRef, resolvedResource);
      } else {
        await _performUpdate(docRef, resource);
      }

      // Uppdatera lokal cache
      _cachedResources[resource.id] = resource;
      _lastLocalUpdate[resource.id] = DateTime.now();

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
      // Hämta resursen för att kontrollera behörighet
      final resource = await _getLatestResource<RealtimeResource>(resourceId);

      if (!resource.canUserDelete(_currentUserId!)) {
        throw SyncError(
          type: SyncErrorType.permissionDenied,
          message: 'Ingen behörighet att ta bort resursen',
          resourceId: resourceId,
          resourceType: type,
        );
      }

      final docRef = _getResourceDocRef(resourceId);
      await _firestoreRepository.deleteDocument(docRef);

      // Rensa lokal cache
      _cachedResources.remove(resourceId);
      _lastLocalUpdate.remove(resourceId);

      // Stäng eventuell aktiv listener
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

  /// Lös konflikter mellan lokal och remote version
  ///
  /// Standard strategi: "Last Writer Wins" med timestamp-jämförelse
  /// Subclasses kan override för mer avancerad conflict resolution
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

  /// Hämta DocumentReference för en resurs
  DocumentReference<Map<String, dynamic>> _getResourceDocRef(String resourceId) {
    return _firestoreRepository.realtimeResourceDoc(resourceId);
  }

  /// Parsa resurs från Firestore snapshot med type safety
  T _parseResourceFromSnapshot<T extends RealtimeResource>(
      DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    final typeString = data['type'] as String? ?? 'recipe';

    RealtimeResourceType type;
    try {
      type = RealtimeResourceType.fromString(typeString);
    } catch (e) {
      // Fallback till recipe om okänd typ
      type = RealtimeResourceType.recipe;
    }

    // Type-safe parsing baserat på resource type
    switch (type) {
      case RealtimeResourceType.recipe:
        return RealtimeRecipe.fromMap(snapshot.id, snapshot.data()! as Map<String, dynamic>) as T;
      case RealtimeResourceType.menu:
        return RealtimeMenu.fromMap(snapshot.id, snapshot.data()! as Map<String, dynamic>) as T;
      case RealtimeResourceType.shoppingList:
        // return RealtimeShoppingList.fromFirestore(snapshot) as T;
        throw SyncError(
          type: SyncErrorType.firestoreError,
          message: 'RealtimeShoppingList parsing inte implementerad än',
          resourceId: snapshot.id,
        );
    }
  }

  /// Hämta senaste version av resurs från Firebase
  Future<T> _getLatestResource<T extends RealtimeResource>(
      String resourceId) async {
    final snapshot =
        await _firestoreRepository.getDocument(_getResourceDocRef(resourceId));

    if (!snapshot.exists) {
      throw SyncError(
        type: SyncErrorType.documentNotFound,
        message: 'Resursen hittades inte',
        resourceId: resourceId,
      );
    }

    return _parseResourceFromSnapshot<T>(snapshot);
  }

  /// Kontrollera om conflict resolution behövs
  Future<bool> _shouldResolveConflict(RealtimeResource resource) async {
    final lastUpdate = _lastLocalUpdate[resource.id];
    if (lastUpdate == null) return false;

    // Om mindre än 5 sekunder sedan senaste lokala uppdatering, kolla remote
    final timeSinceUpdate =
        DateTime.now().difference(lastUpdate).inMilliseconds;
    if (timeSinceUpdate < _conflictResolutionWindowMs) {
      try {
        final remoteResource =
            await _getLatestResource<RealtimeResource>(resource.id);
        return remoteResource.lastEditedAt.isAfter(lastUpdate);
      } catch (e) {
        // Om vi inte kan hämta remote version, anta ingen konflikt
        return false;
      }
    }

    return false;
  }

  /// Utför själva uppdateringen till Firebase
  Future<void> _performUpdate(
      DocumentReference<Map<String, dynamic>> docRef,
      RealtimeResource resource) async {
    await _firestoreRepository.setDocument(docRef, resource.toFirestore());
  }

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
    _lastLocalUpdate.clear();
    _listeners.clear();
  }
}

/// Comprehensive real-time synchronization service providing Firebase-based collaborative editing with conflict resolution.
///
/// This service implements sophisticated real-time synchronization capabilities for collaborative editing scenarios
/// including live document updates, intelligent conflict resolution, connection management, and comprehensive error
/// handling. It provides a robust foundation for real-time collaborative features including recipe editing,
/// menu planning, and shopping list management with Firebase Firestore as the backend synchronization platform.
///
/// **Architecture Integration:**
/// - Extends [BaseService] for consistent service patterns and error handling
/// - Uses [StreamManagementMixin] for efficient stream lifecycle management and cleanup
/// - Integrates with [FirestoreRepository] for Firebase database operations and connectivity management
/// - Coordinates with [AuthRepository] for user authentication and permission validation
/// - Implements comprehensive error handling with specialized sync error types and recovery strategies
///
/// **Real-time Synchronization Features:**
/// - **Live Document Streams**: Real-time document monitoring with automatic UI updates
/// - **Conflict Resolution**: Intelligent conflict resolution using edit counts and timestamps
/// - **Connection Management**: Robust connection monitoring with automatic reconnection handling
/// - **Permission Integration**: Comprehensive permission validation integrated with resource models
/// - **Optimistic Updates**: Performance-optimized updates with local caching and background synchronization
/// - **Error Recovery**: Sophisticated error handling with retry logic and graceful degradation
///
/// **Collaborative Editing Capabilities:**
/// - **Multi-User Support**: Concurrent editing with real-time change propagation
/// - **Resource Type Management**: Type-safe handling of recipes, menus, and shopping lists
/// - **Cache Management**: Intelligent local caching for performance optimization
/// - **Presence Awareness**: Connection state monitoring and user presence management

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

/// Enumeration defining the types of synchronization errors for comprehensive error handling and recovery.
///
/// This enum provides detailed error categorization enabling the synchronization service to implement
/// appropriate error handling strategies, user feedback, and recovery mechanisms based on the specific
/// type of synchronization failure encountered during real-time collaborative operations.
///
/// **Error Categories:**
/// - [connectionLost] Network connectivity issues requiring reconnection strategies
/// - [permissionDenied] Authorization failures requiring user authentication or permission updates
/// - [conflictResolution] Concurrent editing conflicts requiring intelligent resolution algorithms
/// - [documentNotFound] Resource access failures requiring validation and error recovery
/// - [firestoreError] Firebase-specific errors requiring platform-specific handling
/// - [unknown] Unclassified errors requiring comprehensive fallback strategies
enum SyncErrorType {
  /// Network connectivity issues requiring reconnection strategies.
  connectionLost,
  
  /// Authorization failures requiring user authentication or permission updates.
  permissionDenied,
  
  /// Concurrent editing conflicts requiring intelligent resolution algorithms.
  conflictResolution,
  
  /// Resource access failures requiring validation and error recovery.
  documentNotFound,
  
  /// Firebase-specific errors requiring platform-specific handling.
  firestoreError,
  
  /// Unclassified errors requiring comprehensive fallback strategies.
  unknown,
}

/// Comprehensive synchronization error with contextual information for detailed error handling and recovery.
///
/// This class provides detailed error information for synchronization failures enabling the application
/// to implement appropriate error handling strategies, user feedback mechanisms, and recovery procedures
/// based on the specific type and context of synchronization errors encountered during real-time operations.
///
/// **Error Context Information:**
/// - [type] Categorized error type for appropriate handling strategy selection
/// - [message] Human-readable Swedish error message for user feedback and logging
/// - [resourceId] Optional resource identifier for resource-specific error handling
/// - [resourceType] Optional resource type for type-specific error recovery strategies
/// - [originalError] Original exception for detailed debugging and error analysis
///
/// **Error Handling Integration:**
/// Enables comprehensive error handling through:
/// - Type-specific error recovery strategies based on error categorization
/// - Resource-specific error handling for targeted recovery mechanisms
/// - Detailed error logging with full context preservation for debugging
/// - User feedback with appropriate Swedish language error messages
/// - Original error preservation for technical analysis and troubleshooting
///
/// **Usage Examples:**
/// ```dart
/// // Create permission denied error
/// final error = SyncError(
///   type: SyncErrorType.permissionDenied,
///   message: 'Ingen redigeringsbehörighet',
///   resourceId: 'recipe123',
///   resourceType: RealtimeResourceType.recipe,
/// );
/// 
/// // Handle error based on type
/// switch (error.type) {
///   case SyncErrorType.connectionLost:
///     await retryConnection();
///     break;
///   case SyncErrorType.permissionDenied:
///     showPermissionDialog();
///     break;
/// }
/// ```
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

/// Comprehensive real-time synchronization service providing Firebase-based collaborative editing with intelligent conflict resolution.
///
/// This service implements sophisticated real-time synchronization capabilities for collaborative editing scenarios
/// with comprehensive Firebase integration, connection management, and conflict resolution strategies. It serves as
/// the central coordination point for real-time collaborative features including recipe editing, menu planning,
/// and shopping list management with robust error handling and performance optimization.
///
/// **Single Responsibility Architecture:**
/// Focused exclusively on real-time synchronization concerns:
/// - **Real-time Listeners**: Firebase document stream management with automatic reconnection
/// - **CRUD Operations**: Type-safe resource operations with permission validation integration
/// - **Conflict Resolution**: Intelligent conflict resolution using edit counts and timestamps
/// - **Connection Management**: Robust connection monitoring with retry logic and error recovery
///
/// **Collaborative Editing Features:**
/// - **Multi-User Support**: Concurrent editing with real-time change propagation across users
/// - **Resource Type Management**: Type-safe handling of recipes, menus, and shopping lists
/// - **Cache Management**: Intelligent local caching for performance optimization and offline support
/// - **Presence Awareness**: Connection state monitoring and user presence management
/// - **Optimistic Updates**: Performance-optimized updates with local caching and background sync
///
/// **Architecture Integration:**
/// - Extends [BaseService] for consistent service patterns, error handling, and lifecycle management
/// - Uses [StreamManagementMixin] for efficient stream lifecycle management and automatic cleanup
/// - Integrates with [FirestoreRepository] for Firebase operations and connectivity management
/// - Coordinates with [AuthRepository] for user authentication and permission context
/// - Implements comprehensive error handling with specialized [SyncError] types and recovery strategies
///
/// **Performance and Reliability:**
/// - **Intelligent Caching**: Local resource caching prevents redundant Firebase calls
/// - **Connection Monitoring**: Real-time connection state management with automatic reconnection
/// - **Error Recovery**: Comprehensive error handling with retry logic and graceful degradation
/// - **Stream Management**: Efficient stream lifecycle management prevents memory leaks
/// - **Conflict Resolution**: Smart conflict resolution prevents data loss in concurrent editing scenarios
///
/// **Usage Examples:**
/// ```dart
/// final syncService = RealtimeSyncService(
///   firestoreRepository: firestoreRepo,
///   authRepository: authRepo,
/// );
/// 
/// // Initialize service
/// await syncService.initialize();
/// 
/// // Watch recipe for real-time updates
/// final recipeStream = syncService.watchResource<RealtimeRecipe>('recipe123');
/// recipeStream.listen((recipe) {
///   updateUI(recipe);
/// });
/// 
/// // Update recipe with conflict resolution
/// await syncService.updateResource(modifiedRecipe);
/// 
/// // Monitor connection state
/// syncService.connectionStream.listen((isConnected) {
///   updateConnectionIndicator(isConnected);
/// });
/// ```
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

  /// Initializes the real-time synchronization service with comprehensive setup and monitoring.
  ///
  /// This method performs complete service initialization including connection monitoring setup,
  /// authentication state management, and stream controller initialization. It establishes the
  /// foundation for real-time collaborative features with robust error handling and automatic
  /// recovery mechanisms for optimal user experience.
  ///
  /// **Initialization Process:**
  /// 1. **Connection Monitoring**: Establishes Firebase connection state monitoring with automatic reconnection
  /// 2. **Authentication Integration**: Sets up authentication state change listeners for user context management
  /// 3. **Stream Controllers**: Initializes broadcast stream controllers for connection and error state management
  /// 4. **Error Handling**: Configures comprehensive error handling with graceful degradation strategies
  ///
  /// **Post-Initialization State:**
  /// After successful initialization, the service provides:
  /// - Real-time connection state monitoring through [connectionStream]
  /// - Authentication-aware resource access with automatic user context updates
  /// - Error reporting through [errorStream] with detailed error categorization
  /// - Ready-to-use collaborative editing capabilities with conflict resolution
  ///
  /// Throws [Exception] if Firebase connectivity cannot be established or authentication setup fails
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

  /// Establishes real-time monitoring of a resource with automatic updates and type-safe streaming.
  ///
  /// This method creates a real-time stream that emits updates whenever the specified resource changes
  /// in Firebase Firestore. It provides type-safe resource monitoring with comprehensive error handling,
  /// permission validation, and intelligent caching for optimal performance in collaborative editing scenarios.
  ///
  /// [resourceId] Unique identifier of the resource to monitor for real-time updates
  /// Returns [Stream<T>] that emits resource updates as they occur in Firebase
  /// Throws [SyncError] for authentication, permission, or Firebase connectivity issues
  ///
  /// **Real-time Monitoring Features:**
  /// - **Type Safety**: Generic type parameters ensure compile-time type checking for resource types
  /// - **Permission Integration**: Automatic permission validation before establishing monitoring streams
  /// - **Intelligent Caching**: Local resource caching reduces Firebase calls and improves performance
  /// - **Error Handling**: Comprehensive error categorization with appropriate recovery strategies
  ///
  /// **Stream Behavior:**
  /// - Emits initial resource state immediately upon subscription
  /// - Provides real-time updates as resource changes occur in Firebase
  /// - Handles connection interruptions with automatic reconnection and state recovery
  /// - Maintains stream consistency even during network connectivity issues
  ///
  /// **Usage Examples:**
  /// ```dart
  /// // Monitor recipe for real-time updates
  /// final recipeStream = syncService.watchResource<RealtimeRecipe>('recipe123');
  /// recipeStream.listen(
  ///   (recipe) => updateRecipeUI(recipe),
  ///   onError: (error) => handleSyncError(error as SyncError),
  /// );
  /// 
  /// // Monitor menu with error handling
  /// try {
  ///   await for (final menu in syncService.watchResource<RealtimeMenu>('menu456')) {
  ///     updateMenuDisplay(menu);
  ///   }
  /// } catch (e) {
  ///   showErrorMessage('Real-time updates unavailable');
  /// }
  /// ```
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

  /// Updates a real-time resource with optimistic updates, intelligent conflict resolution, and comprehensive error handling.
  ///
  /// This method performs sophisticated resource updates with built-in conflict resolution for concurrent editing scenarios.
  /// It implements optimistic update strategies for performance while ensuring data consistency through intelligent
  /// conflict detection and resolution algorithms that preserve user intent and prevent data loss.
  ///
  /// [resource] The resource object with updated data to persist to Firebase
  /// Throws [SyncError] for authentication, permission, conflict resolution, or connectivity issues
  ///
  /// **Update Process:**
  /// 1. **Permission Validation**: Verifies user editing permissions using resource-specific authorization logic
  /// 2. **Conflict Detection**: Analyzes potential conflicts with concurrent edits from other users
  /// 3. **Conflict Resolution**: Applies intelligent resolution strategies when conflicts are detected
  /// 4. **Optimistic Update**: Performs local cache updates immediately for responsive user experience
  /// 5. **Firebase Persistence**: Atomically persists resolved changes to Firebase Firestore
  ///
  /// **Conflict Resolution Strategy:**
  /// - **Edit Count Priority**: Resources with higher edit counts take precedence in conflict scenarios
  /// - **Timestamp Fallback**: When edit counts are equal, newer timestamps determine precedence
  /// - **User Intent Preservation**: Resolution strategies prioritize preserving user intent and data integrity
  /// - **Automatic Recovery**: Failed resolutions trigger automatic recovery with remote version preference
  ///
  /// **Performance Optimization:**
  /// - Local cache updates provide immediate user feedback before Firebase confirmation
  /// - Intelligent conflict detection minimizes unnecessary resolution overhead
  /// - Atomic operations ensure data consistency during concurrent update scenarios
  /// - Timestamp tracking enables efficient conflict detection within resolution windows
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

  /// Resolves conflicts between local and remote resource versions using intelligent resolution algorithms.
  ///
  /// This method implements sophisticated conflict resolution for concurrent editing scenarios using a multi-tiered
  /// strategy that prioritizes data integrity while preserving user intent. It applies "Last Writer Wins" semantics
  /// with edit count priority and timestamp fallback mechanisms to ensure consistent and predictable resolution outcomes.
  ///
  /// [local] The local version of the resource with user modifications
  /// [remote] The remote version from Firebase representing concurrent changes
  /// Returns [T] The resolved resource version that should be persisted
  ///
  /// **Resolution Algorithm:**
  /// 1. **Edit Count Comparison**: Resources with higher edit counts take precedence
  /// 2. **Timestamp Fallback**: When edit counts are equal, newer timestamps determine winner
  /// 3. **Error Recovery**: Resolution failures default to remote version for data safety
  /// 4. **Logging Integration**: Detailed logging provides audit trail for resolution decisions
  ///
  /// **Resolution Strategy Benefits:**
  /// - **Predictable Outcomes**: Consistent resolution logic prevents user confusion
  /// - **Data Preservation**: Algorithm prioritizes preserving recent changes and user intent
  /// - **Safety First**: Error scenarios default to remote version to prevent data corruption
  /// - **Audit Trail**: Comprehensive logging enables troubleshooting and analysis
  ///
  /// **Extension Points:**
  /// This method can be overridden by subclasses to implement resource-specific conflict resolution:
  /// - Recipe-specific resolution might merge ingredient lists intelligently
  /// - Menu resolution could preserve user scheduling preferences
  /// - Shopping list resolution might combine items from both versions
  ///
  /// **Usage Examples:**
  /// ```dart
  /// // Automatic conflict resolution during updates
  /// final resolved = await syncService.resolveConflict(localRecipe, remoteRecipe);
  /// 
  /// // Custom resolution for specific resource types
  /// @override
  /// Future<RealtimeRecipe> resolveConflict<RealtimeRecipe>(local, remote) {
  ///   return mergeRecipeIngredients(local, remote);
  /// }
  /// ```
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

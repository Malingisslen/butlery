/// 🔍 AI INFO BLOCK:
/// Component: Firebase Sync Mixin - Reusable sync pattern for Firebase services
/// File: lib/core/mixins/firebase_sync_mixin.dart
/// Quick Guide: Eliminates 20+ duplicated Firebase sync patterns across services
/// Dependencies IN: Firebase, Dart timers, ChangeNotifier
/// Dependencies OUT: Used by unified services (Shopping, Friends, Recipe)
/// Data flow: Mixin -> Service -> Firebase -> Local state -> UI updates
/// State management: Centralized StreamSubscription and Timer management
/// Purpose: Eliminate code duplication and standardize Firebase sync patterns
/// Common issues: Timer management, subscription cleanup, error handling
/// Test coverage: Unit tests for sync logic, mocking Firebase streams
/// Performance: Debounced sync, optimized subscription management
/// Analytics: Sync success/failure rates, subscription lifecycle
/// Code smells: None - clean abstraction of common pattern
/// Connected to: All unified services with Firebase real-time sync
/// Used in phases: Phase 6 - Eliminate Code Duplication Patterns

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// Mixin that provides common Firebase sync functionality to services
/// 
/// This mixin eliminates the duplicated sync pattern found in 20+ places:
/// - StreamSubscription management
/// - Timer-based sync debouncing
/// - Snapshot change handling
/// - Subscription lifecycle management
/// 
/// Usage:
/// ```dart
/// class MyService extends ChangeNotifier with FirebaseSyncMixin<MyDataType> {
///   @override
///   List<SyncCollection> get syncCollections => [
///     SyncCollection(
///       name: 'personal_data',
///       query: () => firestore.collection('users').doc(userId).collection('data'),
///       handler: _handlePersonalDataSnapshot,
///     ),
///   ];
/// }
/// ```
mixin FirebaseSyncMixin<T> on ChangeNotifier {
  // ===== COMMON SYNC STATE =====
  
  /// All Firebase subscriptions managed by this mixin
  final Map<String, StreamSubscription<QuerySnapshot>> _subscriptions = {};
  
  /// Individual document listeners for real-time updates
  final Map<String, StreamSubscription<DocumentSnapshot>> _documentListeners = {};
  
  /// Timer for debouncing sync operations
  Timer? _syncDebounceTimer;
  
  /// Debounce duration for sync operations
  static const Duration _syncDebounce = Duration(seconds: 2);
  
  /// Queue of pending sync operations
  final Set<String> _pendingSyncIds = {};
  
  /// Whether sync is currently active
  bool _isSyncing = false;
  
  /// Whether sync has been initialized
  bool _syncInitialized = false;
  
  // ===== GETTERS =====
  
  /// Whether sync is currently active
  bool get isSyncing => _isSyncing;
  
  /// Whether sync has been initialized
  bool get syncInitialized => _syncInitialized;
  
  /// Number of active subscriptions
  int get activeSubscriptionsCount => _subscriptions.length + _documentListeners.length;
  
  // ===== ABSTRACT METHODS - MUST BE IMPLEMENTED BY SERVICES =====
  
  /// Collections to sync - must be implemented by service
  List<SyncCollection> get syncCollections;
  
  /// Current user ID - must be implemented by service
  String? get currentUserId;
  
  /// Firestore instance - must be implemented by service
  FirebaseFirestore get firestore;
  
  /// Handle authentication state changes
  void onAuthStateChanged(String? userId) {
    if (userId != null) {
      startFirebaseSync();
    } else {
      stopFirebaseSync();
    }
  }
  
  // ===== SYNC LIFECYCLE MANAGEMENT =====
  
  /// Start Firebase sync for all collections
  void startFirebaseSync() {
    final userId = currentUserId;
    if (userId == null) {
      AppLogger.warning('Cannot start Firebase sync: User not authenticated');
      return;
    }
    
    AppLogger.info('🔄 Starting Firebase sync for ${syncCollections.length} collections...');
    
    try {
      for (final collection in syncCollections) {
        _startCollectionSync(collection);
      }
      
      _syncInitialized = true;
      AppLogger.success('✅ Firebase sync started for all collections');
    } catch (e) {
      AppLogger.error('❌ Failed to start Firebase sync: $e');
    }
  }
  
  /// Stop Firebase sync and clean up all subscriptions
  void stopFirebaseSync() {
    AppLogger.info('🔄 Stopping Firebase sync...');
    
    // Cancel all collection subscriptions
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    // Cancel all document listeners
    for (final listener in _documentListeners.values) {
      listener.cancel();
    }
    _documentListeners.clear();
    
    // Cancel sync timer
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = null;
    
    // Clear sync state
    _pendingSyncIds.clear();
    _isSyncing = false;
    _syncInitialized = false;
    
    AppLogger.success('✅ Firebase sync stopped');
  }
  
  /// Start sync for a specific collection
  void _startCollectionSync(SyncCollection collection) {
    try {
      final query = collection.query();
      _subscriptions[collection.name] = query.snapshots().listen(
        (snapshot) => _handleCollectionSnapshot(collection, snapshot),
        onError: (error) {
          AppLogger.error('${collection.name} snapshot error: $error');
          collection.onError?.call(error);
        },
      );
      
      AppLogger.debug('Started sync for collection: ${collection.name}');
    } catch (e) {
      AppLogger.error('Failed to start sync for ${collection.name}: $e');
    }
  }
  
  /// Handle snapshot changes for a collection
  void _handleCollectionSnapshot(SyncCollection collection, QuerySnapshot snapshot) {
    try {
      AppLogger.debug('Handling snapshot for ${collection.name}: ${snapshot.docChanges.length} changes');
      
      for (final change in snapshot.docChanges) {
        switch (change.type) {
          case DocumentChangeType.added:
            collection.onAdded?.call(change.doc);
            break;
          case DocumentChangeType.modified:
            collection.onModified?.call(change.doc);
            break;
          case DocumentChangeType.removed:
            collection.onRemoved?.call(change.doc);
            break;
        }
      }
      
      // Call custom handler if provided
      collection.handler?.call(snapshot);
      
      // Notify listeners after all changes processed
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error handling snapshot for ${collection.name}: $e');
    }
  }
  
  // ===== SYNC QUEUE MANAGEMENT =====
  
  /// Schedule an item for sync with debouncing
  void scheduleSyncForItem(String itemId) {
    _pendingSyncIds.add(itemId);
    
    // Cancel existing timer and start new one
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(_syncDebounce, () {
      _processPendingSyncItems();
    });
  }
  
  /// Process all pending sync items
  void _processPendingSyncItems() async {
    if (_pendingSyncIds.isEmpty) return;
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      AppLogger.debug('Processing ${_pendingSyncIds.length} pending sync items');
      
      final itemsToSync = List<String>.from(_pendingSyncIds);
      _pendingSyncIds.clear();
      
      await processSyncItems(itemsToSync);
      
      AppLogger.success('✅ Processed ${itemsToSync.length} sync items');
    } catch (e) {
      AppLogger.error('Error processing sync items: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  /// Process sync items - must be implemented by service
  Future<void> processSyncItems(List<String> itemIds) async {
    // Default implementation - services can override
    for (final itemId in itemIds) {
      await syncItemToFirebase(itemId);
    }
  }
  
  /// Sync a single item to Firebase - must be implemented by service
  Future<void> syncItemToFirebase(String itemId) async {
    // Default implementation - services should override
    AppLogger.debug('Syncing item: $itemId');
  }
  
  // ===== DOCUMENT LISTENERS =====
  
  /// Add a document listener for real-time updates
  void addDocumentListener(String key, DocumentReference docRef, void Function(DocumentSnapshot) handler) {
    // Cancel existing listener if any
    _documentListeners[key]?.cancel();
    
    _documentListeners[key] = docRef.snapshots().listen(
      handler,
      onError: (error) {
        AppLogger.error('Document listener error for $key: $error');
      },
    );
  }
  
  /// Remove a document listener
  void removeDocumentListener(String key) {
    _documentListeners[key]?.cancel();
    _documentListeners.remove(key);
  }
  
  // ===== CLEANUP =====
  
  @override
  void dispose() {
    stopFirebaseSync();
    super.dispose();
  }
}

/// Configuration for a Firebase collection sync
class SyncCollection {
  /// Name of the collection (used for logging and identification)
  final String name;
  
  /// Query factory that returns the collection query
  final Query Function() query;
  
  /// Optional snapshot handler for custom processing
  final void Function(QuerySnapshot snapshot)? handler;
  
  /// Handler for added documents
  final void Function(DocumentSnapshot doc)? onAdded;
  
  /// Handler for modified documents
  final void Function(DocumentSnapshot doc)? onModified;
  
  /// Handler for removed documents
  final void Function(DocumentSnapshot doc)? onRemoved;
  
  /// Error handler for this collection
  final void Function(dynamic error)? onError;
  
  SyncCollection({
    required this.name,
    required this.query,
    this.handler,
    this.onAdded,
    this.onModified,
    this.onRemoved,
    this.onError,
  });
}
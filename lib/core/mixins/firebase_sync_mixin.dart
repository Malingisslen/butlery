import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/utils/logger.dart';

/// Firebase sync mixin for real-time data synchronization
mixin FirebaseSyncMixin<T> on ChangeNotifier {
  // Sync state
  final Map<String, StreamSubscription<QuerySnapshot>> _subscriptions = {};
  final Map<String, StreamSubscription<DocumentSnapshot>> _documentListeners =
      {};
  Timer? _syncDebounceTimer;
  static const Duration _syncDebounce = Duration(seconds: 2);
  final Set<String> _pendingSyncIds = {};
  bool _isSyncing = false;
  bool _syncInitialized = false;

  // Getters
  bool get isSyncing => _isSyncing;
  bool get syncInitialized => _syncInitialized;
  int get activeSubscriptionsCount =>
      _subscriptions.length + _documentListeners.length;

  // Abstract methods - must be implemented by services
  List<SyncCollection> get syncCollections;
  String? get currentUserId;
  FirebaseFirestore get firestore;

  void onAuthStateChanged(String? userId) {
    if (userId != null) {
      startFirebaseSync();
    } else {
      stopFirebaseSync();
    }
  }

  // Sync lifecycle management
  void startFirebaseSync() {
    final userId = currentUserId;
    if (userId == null) {
      AppLogger.warning('Cannot start Firebase sync: User not authenticated');
      return;
    }

    AppLogger.info(
        '🔄 Starting Firebase sync for ${syncCollections.length} collections...');

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

  void _handleCollectionSnapshot(
      SyncCollection collection, QuerySnapshot snapshot) {
    try {
      AppLogger.debug(
          'Handling snapshot for ${collection.name}: ${snapshot.docChanges.length} changes');

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

  // Sync queue management
  void scheduleSyncForItem(String itemId) {
    _pendingSyncIds.add(itemId);

    // Cancel existing timer and start new one
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(_syncDebounce, () {
      _processPendingSyncItems();
    });
  }

  Future<void> _processPendingSyncItems() async {
    if (_pendingSyncIds.isEmpty) return;

    _isSyncing = true;
    notifyListeners();

    try {
      AppLogger.debug(
          'Processing ${_pendingSyncIds.length} pending sync items');

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

  Future<void> processSyncItems(List<String> itemIds) async {
    // Default implementation - services can override
    for (final itemId in itemIds) {
      await syncItemToFirebase(itemId);
    }
  }

  Future<void> syncItemToFirebase(String itemId) async {
    // Default implementation - services should override
    AppLogger.debug('Syncing item: $itemId');
  }

  // Document listeners
  void addDocumentListener(String key, DocumentReference docRef,
      void Function(DocumentSnapshot) handler) {
    // Cancel existing listener if any
    _documentListeners[key]?.cancel();

    _documentListeners[key] = docRef.snapshots().listen(
      handler,
      onError: (error) {
        AppLogger.error('Document listener error for $key: $error');
      },
    );
  }

  void removeDocumentListener(String key) {
    _documentListeners[key]?.cancel();
    _documentListeners.remove(key);
  }

  @override
  void dispose() {
    stopFirebaseSync();
    super.dispose();
  }
}

/// Configuration for a Firebase collection sync
class SyncCollection {
  final String name;
  final Query Function() query;
  final void Function(QuerySnapshot snapshot)? handler;
  final void Function(DocumentSnapshot doc)? onAdded;
  final void Function(DocumentSnapshot doc)? onModified;
  final void Function(DocumentSnapshot doc)? onRemoved;
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

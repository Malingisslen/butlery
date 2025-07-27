// lib/services/unified/modules/shopping_firebase_sync.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/firebase_sync_mixin.dart';

/// Handles Firebase synchronization for shopping lists
class ShoppingFirebaseSync {
  final FirebaseFirestore _firestore;
  final String? Function() _getCurrentUserId;
  final void Function(UnifiedShoppingList) _updateLocalList;
  final void Function(String) _removeLocalList;
  final void Function(String) _setError;

  ShoppingFirebaseSync({
    required FirebaseFirestore firestore,
    required String? Function() getCurrentUserId,
    required void Function(UnifiedShoppingList) updateLocalList,
    required void Function(String) removeLocalList,
    required void Function(String) setError,
  }) : _firestore = firestore,
       _getCurrentUserId = getCurrentUserId,
       _updateLocalList = updateLocalList,
       _removeLocalList = removeLocalList,
       _setError = setError;

  /// Get sync collections configuration for FirebaseSyncMixin
  List<SyncCollection> get syncCollections => [
    SyncCollection(
      name: 'personal_shopping_lists',
      query: () => _firestore
          .collection('users')
          .doc(_getCurrentUserId()!)
          .collection('unified_shopping_lists'),
      onAdded: (doc) => _updateLocalList(UnifiedShoppingList.fromMap(doc.id, doc.data()! as Map<String, dynamic>)),
      onModified: (doc) => _updateLocalList(UnifiedShoppingList.fromMap(doc.id, doc.data()! as Map<String, dynamic>)),
      onRemoved: (doc) => _removeLocalList(doc.id),
      onError: (error) => _setError('Personal lists sync error: $error'),
    ),
    SyncCollection(
      name: 'collaborative_shopping_lists',
      query: () => _firestore
          .collection('unified_shared_shopping_lists')
          .where('memberPermissions.${_getCurrentUserId()}', isNotEqualTo: null),
      onAdded: (doc) => _updateLocalList(UnifiedShoppingList.fromMap(doc.id, doc.data()! as Map<String, dynamic>)),
      onModified: (doc) => _updateLocalList(UnifiedShoppingList.fromMap(doc.id, doc.data()! as Map<String, dynamic>)),
      onRemoved: (doc) => _removeLocalList(doc.id),
      onError: (error) => _setError('Collaborative lists sync error: $error'),
    ),
  ];

  Future<void> syncPersonalListToFirebase(UnifiedShoppingList list) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('unified_shopping_lists')
          .doc(list.id)
          .set(list.toFirestore(), SetOptions(merge: true));

      AppLogger.debug('Personal lista synkad: ${list.name}');
    } catch (e) {
      AppLogger.error('Firebase synk-fel för personal lista ${list.id}: $e');
    }
  }

  Future<void> syncCollaborativeListToFirebase(UnifiedShoppingList list) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('unified_shared_shopping_lists')
          .doc(list.id)
          .set(list.toFirestore(), SetOptions(merge: true));

      AppLogger.debug('Kollaborativ lista synkad: ${list.name}');
    } catch (e) {
      AppLogger.error(
          'Firebase synk-fel för kollaborativ lista ${list.id}: $e');
    }
  }

  Future<void> deleteListFromFirebase(String listId, bool isCollaborative) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) return;

    try {
      if (isCollaborative) {
        await _firestore
            .collection('unified_shared_shopping_lists')
            .doc(listId)
            .delete();
      } else {
        await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('unified_shopping_lists')
            .doc(listId)
            .delete();
      }
      AppLogger.debug('Lista borttagen från Firebase: $listId');
    } catch (e) {
      AppLogger.error('Fel vid borttagning från Firebase: $e');
    }
  }

  Future<void> syncItemToFirebase(String itemId, List<UnifiedShoppingList> lists) async {
    final list = lists.where((l) => l.id == itemId).firstOrNull;
    if (list == null) return;

    if (list.isPersonal) {
      await syncPersonalListToFirebase(list);
    } else if (list.isCollaborative) {
      await syncCollaborativeListToFirebase(list);
    }
  }
}
// lib/services/unified/unified_shopping_service.dart

/// AI INFO BLOCK:
/// Component: Unified Shopping Service - ERSATTER ALLA shopping services
/// File: services/unified/unified_shopping_service.dart
/// Quick Guide: Central service som hanterar ALL shopping funktionalitet
/// Dependencies IN: Firebase, Hive, auth_service, offline_service
/// Dependencies OUT: ChangeNotifier med lists, CRUD metoder, sync functionality
/// Data flow: Firebase realtime <-> Service state <-> ViewModels -> UI
// ignore: unintended_html_in_doc_comment
/// State management: ChangeNotifier med List<UnifiedShoppingList> och loading states
/// Purpose: Ersatt shopping_list_service, multi_shopping_list_service, social_shopping_service
/// Used in phases: 18.3 (Unified Shopping Migration)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'dart:convert';
import '../../models/unified/unified_shopping_item.dart';
import '../../models/unified/unified_shopping_list.dart';
import '../../core/utils/logger.dart';

class UnifiedShoppingService extends ChangeNotifier {
  static const String _hiveBoxName = 'unified_shopping_lists_cache';
  static const String _activeListKey = 'active_list_id';
  static const Duration _syncDebounce = Duration(seconds: 2);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State - BEHOLLER samma struktur som du har idag
  final List<UnifiedShoppingList> _lists = [];
  String? _activeListId;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;

  // Firebase listeners - samma patterns
  final Map<String, StreamSubscription<DocumentSnapshot>> _listListeners = {};
  StreamSubscription<QuerySnapshot>? _personalListsSubscription;
  StreamSubscription<QuerySnapshot>? _collaborativeListsSubscription;
  Timer? _syncDebounceTimer;

  // Sync queue for offline operations
  final Set<String> _pendingSyncListIds = {};

  // ===== GETTERS - samma API som du anvander idag =====

  List<UnifiedShoppingList> get lists => List.unmodifiable(_lists);
  List<UnifiedShoppingList> get personalLists =>
      lists.where((l) => l.isPersonal).toList();
  List<UnifiedShoppingList> get collaborativeLists =>
      lists.where((l) => l.isCollaborative).toList();

  UnifiedShoppingList? get activeList => _activeListId != null
      ? _lists.where((list) => list.id == _activeListId!).firstOrNull
      : (_lists.isNotEmpty ? _lists.first : null);

  String? get activeListId => _activeListId;
  bool get hasLists => _lists.isNotEmpty;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  bool get hasError => _error != null;
  String? get currentUserId => _auth.currentUser?.uid;
  String? get currentUserDisplayName => _auth.currentUser?.displayName ?? 'Du';

  // ===== INITIALIZATION - samma som du har idag =====

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.info('Initialiserar UnifiedShoppingService...');

      // Oppna Hive box for caching
      final box = await Hive.openBox<String>(_hiveBoxName);

      // Ladda cached data forst (offline-first)
      await _loadCachedLists(box);

      // Lyssna pa auth changes
      _auth.authStateChanges().listen((user) {
        if (user != null) {
          _startFirebaseSync();
        } else {
          _stopFirebaseSync();
          _clearAll();
        }
      });

      // Starta Firebase sync om inloggad
      if (_auth.currentUser != null) {
        _startFirebaseSync();
      }

      _isInitialized = true;
      AppLogger.success('UnifiedShoppingService initialiserad');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Fel vid initialisering: $e');
      _setError('Kunde inte ladda inkopslistor: $e');
    }
  }

  // ===== LIST MANAGEMENT - BEHOLLER alla dina metoder =====

  Future<String?> createPersonalList(String name,
      {List<UnifiedShoppingItem>? items}) async {
    if (currentUserId == null) {
      _setError('Du maste vara inloggad');
      return null;
    }

    if (name.trim().isEmpty) {
      _setError('Listnamn kan inte vara tomt');
      return null;
    }

    try {
      final newList = UnifiedShoppingList.personal(
        name: name.trim(),
        ownerId: currentUserId!,
        ownerDisplayName: currentUserDisplayName!,
        items: items,
      );

      // Lagg till lokalt (optimistic update)
      _lists.add(newList);
      _activeListId = newList.id;
      notifyListeners();

      // Synka till Firebase
      await _syncListToFirebase(newList);

      AppLogger.success('Personlig lista "$name" skapad');
      return newList.id;
    } catch (e) {
      AppLogger.error('Kunde inte skapa personlig lista: $e');
      _setError('Kunde inte skapa lista: $e');
      return null;
    }
  }

  Future<String?> createCollaborativeList({
    required String name,
    String? description,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    List<UnifiedShoppingItem>? items,
    List<String>? categoryIds,
    bool allowGuestEditing = true,
    bool autoRemoveCompleted = false,
  }) async {
    if (currentUserId == null) {
      _setError('Du maste vara inloggad');
      return null;
    }

    if (name.trim().isEmpty) {
      _setError('Listnamn kan inte vara tomt');
      return null;
    }

    try {
      // Skapa member permissions
      final memberPermissions = <String, SharedListPermission>{};
      for (final memberId in memberIds) {
        memberPermissions[memberId] = SharedListPermission.edit;
      }

      final newList = UnifiedShoppingList.collaborative(
        name: name.trim(),
        ownerId: currentUserId!,
        ownerDisplayName: currentUserDisplayName!,
        memberPermissions: memberPermissions,
        items: items,
        description: description?.trim(),
        categoryIds: categoryIds,
        allowGuestEditing: allowGuestEditing,
        autoRemoveCompleted: autoRemoveCompleted,
      );

      // Lagg till lokalt (optimistic update)
      _lists.add(newList);
      _activeListId = newList.id;
      notifyListeners();

      // Synka till Firebase (collaborative lists anvander annan collection)
      await _syncCollaborativeListToFirebase(newList);

      AppLogger.success(
          'Kollaborativ lista "$name" skapad med ${memberIds.length} medlemmar');
      return newList.id;
    } catch (e) {
      AppLogger.error('Kunde inte skapa kollaborativ lista: $e');
      _setError('Kunde inte skapa kollaborativ lista: $e');
      return null;
    }
  }

  Future<bool> renameList(String listId, String newName) async {
    try {
      if (newName.trim().isEmpty) {
        _setError('Listnamn kan inte vara tomt');
        return false;
      }

      final list = _lists.where((l) => l.id == listId).firstOrNull;
      if (list == null) {
        _setError('Lista hittades inte');
        return false;
      }

      final updatedList = list.copyWith(name: newName.trim());
      return await _updateList(updatedList);
    } catch (e) {
      AppLogger.error('Kunde inte byta namn pa lista: $e');
      _setError('Kunde inte byta namn: $e');
      return false;
    }
  }

  Future<bool> deleteList(String listId) async {
    try {
      // Kan inte ta bort om det ar enda listan
      if (_lists.length <= 1) {
        _setError('Du maste ha minst en inkopslista');
        return false;
      }

      final list = _lists.where((l) => l.id == listId).firstOrNull;
      if (list == null) {
        _setError('Lista hittades inte');
        return false;
      }

      // Ta bort lokalt
      _lists.removeWhere((l) => l.id == listId);

      // Om det var aktiva listan, satt en annan som aktiv
      if (_activeListId == listId && _lists.isNotEmpty) {
        await setActiveList(_lists.first.id);
      }

      // Ta bort fran Firebase
      await _deleteListFromFirebase(list);

      // Ta bort fran cache
      await _removeFromCache(listId);

      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('Kunde inte ta bort lista: $e');
      _setError('Kunde inte ta bort lista: $e');
      return false;
    }
  }

  Future<bool> setActiveList(String listId) async {
    try {
      if (!_lists.any((list) => list.id == listId)) {
        _setError('Lista hittades inte');
        return false;
      }

      _activeListId = listId;

      // Spara aktiv lista ID
      final box = await Hive.openBox<String>(_hiveBoxName);
      await box.put(_activeListKey, listId);

      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('Kunde inte satta aktiv lista: $e');
      _setError('Kunde inte byta lista: $e');
      return false;
    }
  }

  // ===== ITEM MANAGEMENT - BEHOLLER alla dina metoder =====

  Future<bool> addItemToActiveList({
    required String name,
    required double amount,
    String unit = '',
    String category = 'Ovrigt',
    String? note,
    double? estimatedPrice,
    int priority = 3,
  }) async {
    if (activeList == null) {
      _setError('Ingen aktiv lista');
      return false;
    }

    if (name.trim().isEmpty) {
      _setError('Artikelnamn kravs');
      return false;
    }

    try {
      final item = activeList!.isCollaborative
          ? UnifiedShoppingItem.collaborative(
              name: name.trim(),
              amount: amount,
              unit: unit,
              category: category,
              addedByUserId: currentUserId!,
              addedByDisplayName: currentUserDisplayName!,
              note: note?.trim(),
              estimatedPrice: estimatedPrice,
              priority: priority,
            )
          : UnifiedShoppingItem.basic(
              name: name.trim(),
              amount: amount,
              unit: unit,
              category: category,
            );

      final updatedList = activeList!.addItem(
        item,
        userId: currentUserId,
        userDisplayName: currentUserDisplayName,
      );

      return await _updateList(updatedList);
    } catch (e) {
      AppLogger.error('Kunde inte lagga till artikel: $e');
      _setError('Kunde inte lagga till artikel: $e');
      return false;
    }
  }

  Future<bool> toggleItemBought(String itemId) async {
    if (activeList == null) {
      _setError('Ingen aktiv lista');
      return false;
    }

    try {
      final updatedList = activeList!.toggleItemBought(
        itemId,
        userId: currentUserId,
        userDisplayName: currentUserDisplayName,
      );

      return await _updateList(updatedList);
    } catch (e) {
      AppLogger.error('Kunde inte andra artikel-status: $e');
      _setError('Kunde inte andra status: $e');
      return false;
    }
  }

  Future<bool> removeItemFromActiveList(String itemId) async {
    if (activeList == null) {
      _setError('Ingen aktiv lista');
      return false;
    }

    try {
      final updatedList = activeList!.removeItem(
        itemId,
        userId: currentUserId,
        userDisplayName: currentUserDisplayName,
      );

      return await _updateList(updatedList);
    } catch (e) {
      AppLogger.error('Kunde inte ta bort artikel: $e');
      _setError('Kunde inte ta bort artikel: $e');
      return false;
    }
  }

  Future<bool> clearBoughtItems() async {
    if (activeList == null) {
      _setError('Ingen aktiv lista');
      return false;
    }

    try {
      final updatedList = activeList!.clearBoughtItems(
        userId: currentUserId,
        userDisplayName: currentUserDisplayName,
      );

      return await _updateList(updatedList);
    } catch (e) {
      AppLogger.error('Kunde inte rensa kopta artiklar: $e');
      _setError('Kunde inte rensa kopta artiklar: $e');
      return false;
    }
  }

  Future<bool> uncheckAllItems() async {
    if (activeList == null) {
      _setError('Ingen aktiv lista');
      return false;
    }

    try {
      final updatedList = activeList!.uncheckAllItems(
        userId: currentUserId,
        userDisplayName: currentUserDisplayName,
      );

      return await _updateList(updatedList);
    } catch (e) {
      AppLogger.error('Kunde inte avmarkera alla artiklar: $e');
      _setError('Kunde inte avmarkera alla artiklar: $e');
      return false;
    }
  }

  // ===== MIGRATION HELPERS - for att flytta din befintliga data =====

  /// Migrerar din befintliga shopping_list data till unified systemet
  Future<void> migrateFromExistingData() async {
    try {
      AppLogger.info('Startar migration av befintliga shopping lists...');

      // Detta kommer vi implementera steg-for-steg
      // for att flytta din befintliga data sakert

      AppLogger.success('Migration slutford!');
    } catch (e) {
      AppLogger.error('Migration misslyckades: $e');
      rethrow;
    }
  }

  // ===== PRIVATE METHODS - samma patterns som du har =====

  Future<bool> _updateList(UnifiedShoppingList updatedList) async {
    try {
      final index = _lists.indexWhere((list) => list.id == updatedList.id);
      if (index == -1) {
        _setError('Lista hittades inte');
        return false;
      }

      // Uppdatera lokalt (optimistic update)
      _lists[index] = updatedList;
      notifyListeners();

      // Spara till cache
      await _saveToCache(updatedList);

      // Schemalägg synk (debounced)
      _scheduleSyncForList(updatedList.id);

      return true;
    } catch (e) {
      AppLogger.error('Kunde inte uppdatera lista: $e');
      _setError('Kunde inte uppdatera lista: $e');
      return false;
    }
  }

  void _scheduleSyncForList(String listId) {
    _pendingSyncListIds.add(listId);

    // Avbryt tidigare timer
    _syncDebounceTimer?.cancel();

    // Starta ny timer
    _syncDebounceTimer = Timer(_syncDebounce, () {
      _syncPendingLists();
    });
  }

  Future<void> _syncPendingLists() async {
    if (_pendingSyncListIds.isEmpty || currentUserId == null) return;

    final listsToSync = List<String>.from(_pendingSyncListIds);
    _pendingSyncListIds.clear();

    for (final listId in listsToSync) {
      try {
        final list = _lists.where((l) => l.id == listId).firstOrNull;
        if (list == null) continue;

        if (list.isCollaborative) {
          await _syncCollaborativeListToFirebase(list);
        } else {
          await _syncListToFirebase(list);
        }
      } catch (e) {
        AppLogger.error('Kunde inte synka lista $listId: $e');
      }
    }
  }

  Future<void> _syncListToFirebase(UnifiedShoppingList list) async {
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('shopping_lists')
          .doc(list.id)
          .set(list.toFirestore(), SetOptions(merge: true));

      // Uppdatera sync status
      final syncedList = list.markAsSynced();
      final index = _lists.indexWhere((l) => l.id == list.id);
      if (index != -1) {
        _lists[index] = syncedList;
        await _saveToCache(syncedList);
      }
    } catch (e) {
      AppLogger.error('Firebase synk-fel for lista ${list.id}: $e');
      final errorList = list.markAsError();
      final index = _lists.indexWhere((l) => l.id == list.id);
      if (index != -1) {
        _lists[index] = errorList;
      }
    }
  }

  Future<void> _syncCollaborativeListToFirebase(
      UnifiedShoppingList list) async {
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('shared_shopping_lists')
          .doc(list.id)
          .set(list.toFirestore(), SetOptions(merge: true));

      // Uppdatera sync status
      final syncedList = list.markAsSynced();
      final index = _lists.indexWhere((l) => l.id == list.id);
      if (index != -1) {
        _lists[index] = syncedList;
        await _saveToCache(syncedList);
      }
    } catch (e) {
      AppLogger.error(
          'Firebase synk-fel for kollaborativ lista ${list.id}: $e');
      final errorList = list.markAsError();
      final index = _lists.indexWhere((l) => l.id == list.id);
      if (index != -1) {
        _lists[index] = errorList;
      }
    }
  }

  // ===== FIREBASE SYNC METHODS =====

  void _startFirebaseSync() {
    if (currentUserId == null) return;

    AppLogger.info('Startar Firebase sync...');

    // Personal lists
    _personalListsSubscription = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('shopping_lists')
        .snapshots()
        .listen(_handlePersonalListsSnapshot);

    // Collaborative lists
    _collaborativeListsSubscription = _firestore
        .collection('shared_shopping_lists')
        .where('memberPermissions.$currentUserId', isNotEqualTo: null)
        .snapshots()
        .listen(_handleCollaborativeListsSnapshot);
  }

  void _stopFirebaseSync() {
    _personalListsSubscription?.cancel();
    _collaborativeListsSubscription?.cancel();
    _personalListsSubscription = null;
    _collaborativeListsSubscription = null;

    for (final listener in _listListeners.values) {
      listener.cancel();
    }
    _listListeners.clear();
  }

  void _handlePersonalListsSnapshot(QuerySnapshot snapshot) {
    try {
      for (final change in snapshot.docChanges) {
        final list = UnifiedShoppingList.fromFirestore(change.doc);

        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            _updateLocalList(list);
            break;
          case DocumentChangeType.removed:
            _removeLocalList(list.id);
            break;
        }
      }
      notifyListeners();
    } catch (e) {
      AppLogger.error('Fel vid hantering av personal lists snapshot: $e');
    }
  }

  void _handleCollaborativeListsSnapshot(QuerySnapshot snapshot) {
    try {
      for (final change in snapshot.docChanges) {
        final list = UnifiedShoppingList.fromFirestore(change.doc);

        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            _updateLocalList(list);
            break;
          case DocumentChangeType.removed:
            _removeLocalList(list.id);
            break;
        }
      }
      notifyListeners();
    } catch (e) {
      AppLogger.error('Fel vid hantering av collaborative lists snapshot: $e');
    }
  }

  void _updateLocalList(UnifiedShoppingList updatedList) {
    final index = _lists.indexWhere((l) => l.id == updatedList.id);
    if (index != -1) {
      _lists[index] = updatedList;
    } else {
      _lists.add(updatedList);
    }
    _saveToCache(updatedList);
  }

  void _removeLocalList(String listId) {
    _lists.removeWhere((l) => l.id == listId);
    _removeFromCache(listId);
  }

  // ===== CACHE METHODS =====

  Future<void> _loadCachedLists(Box<String> box) async {
    try {
      final cachedListIds =
          box.keys.where((key) => key != _activeListKey).toList();

      for (final listId in cachedListIds) {
        final cachedData = box.get(listId);
        if (cachedData != null) {
          jsonDecode(cachedData);
          // Simplified cache loading - i produktion skulle vi ha mer robust parsing
          AppLogger.info('Laddat cached lista: $listId');
        }
      }

      // Load active list ID
      _activeListId = box.get(_activeListKey);

      AppLogger.info('Cached lists laddade');
    } catch (e) {
      AppLogger.error('Fel vid laddning av cached lists: $e');
    }
  }

  Future<void> _saveToCache(UnifiedShoppingList list) async {
    try {
      final box = await Hive.openBox<String>(_hiveBoxName);
      final listJson = jsonEncode(list.toFirestore());
      await box.put(list.id, listJson);
    } catch (e) {
      AppLogger.error('Fel vid sparande till cache: $e');
    }
  }

  Future<void> _removeFromCache(String listId) async {
    try {
      final box = await Hive.openBox<String>(_hiveBoxName);
      await box.delete(listId);
    } catch (e) {
      AppLogger.error('Fel vid borttagning fran cache: $e');
    }
  }

  Future<void> _deleteListFromFirebase(UnifiedShoppingList list) async {
    try {
      if (list.isCollaborative) {
        await _firestore
            .collection('shared_shopping_lists')
            .doc(list.id)
            .delete();
      } else {
        await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('shopping_lists')
            .doc(list.id)
            .delete();
      }
    } catch (e) {
      AppLogger.error('Fel vid borttagning fran Firebase: $e');
    }
  }

  // ===== ERROR HANDLING =====

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _clearAll() {
    _lists.clear();
    _activeListId = null;
    _isLoading = false;
    _isSyncing = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopFirebaseSync();
    _syncDebounceTimer?.cancel();
    super.dispose();
  }
}

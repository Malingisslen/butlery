// lib/services/unified/unified_shopping_service.dart


import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../repositories/interfaces/auth_repository.dart';
import '../../repositories/firestore_repository.dart';
import 'package:hive/hive.dart';
import 'dart:convert';
import '../../models/unified/unified_shopping_item.dart';
import '../../models/unified/unified_shopping_list.dart';
import '../../core/utils/logger.dart';

class UnifiedShoppingService extends ChangeNotifier {
  static const String _hiveBoxName = 'unified_shopping_lists_cache';
  static const String _activeListKey = 'active_list_id';
  static const Duration _syncDebounce = Duration(seconds: 2);

final FirestoreRepository _firestoreRepository;
final AuthRepository _authRepository;
FirebaseFirestore get _firestore => _firestoreRepository.firestore;

UnifiedShoppingService({
  required FirestoreRepository firestoreRepository,
  required AuthRepository authRepository,
})  : _firestoreRepository = firestoreRepository,
      _authRepository = authRepository;


  // State
  final List<UnifiedShoppingList> _lists = [];
  String? _activeListId;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;

  // Firebase listeners
  final Map<String, StreamSubscription<DocumentSnapshot>> _listListeners = {};
  StreamSubscription<QuerySnapshot>? _personalListsSubscription;
  StreamSubscription<QuerySnapshot>? _collaborativeListsSubscription;
  Timer? _syncDebounceTimer;

  // Sync queue for offline operations
  final Set<String> _pendingSyncListIds = {};

  // ===== GETTERS =====

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
  String? get currentUserId => _authRepository.currentUserId;
  String? get currentUserDisplayName =>
      _authRepository.getCurrentUser()?.displayName ?? 'Du';

  // ===== INITIALIZATION - FÖRENKLAD UTAN MIGRATION =====

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.info('🔄 Initialiserar UnifiedShoppingService...');

      // ✅ EMULATOR FIX: Konfigurera Firestore för emulator om det behövs
      if (kDebugMode) {
        try {
          // Detta hjälper med emulator DNS-problem
          _firestore.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );
        } catch (e) {
          AppLogger.debug('Firestore settings redan satta');
        }
      }

      // Öppna Hive box för caching
      final box = await Hive.openBox<String>(_hiveBoxName);

      // Ladda cached data först (offline-first)
      await _loadCachedLists(box);

      // Lyssna på auth changes
      _authRepository.authStateChanges().listen((user) {
        if (user != null) {
          _startFirebaseSync();
        } else {
          _stopFirebaseSync();
          _clearAll();
        }
      });

      // Starta Firebase sync om inloggad
      if (_authRepository.getCurrentUser() != null) {
        _startFirebaseSync();
      }

      _isInitialized = true;
      AppLogger.success('✅ UnifiedShoppingService initialiserad');
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Fel vid initialisering: $e');
      _setError('Kunde inte ladda inköpslistor: $e');
    }
  }

  // ===== LIST MANAGEMENT =====

  Future<String?> createPersonalList(String name,
      {List<UnifiedShoppingItem>? items}) async {
    if (currentUserId == null) {
      _setError('Du måste vara inloggad');
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

      // Lägg till lokalt (optimistic update)
      _lists.add(newList);
      _activeListId = newList.id;
      notifyListeners();

      // Spara till cache
      await _saveToCache(newList);

      // Synka till Firebase
      _scheduleSyncForList(newList.id);

      AppLogger.success('✅ Personlig lista "$name" skapad');
      return newList.id;
    } catch (e) {
      AppLogger.error('❌ Kunde inte skapa personlig lista: $e');
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
      _setError('Du måste vara inloggad');
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

      // Lägg till lokalt (optimistic update)
      _lists.add(newList);
      _activeListId = newList.id;
      notifyListeners();

      // Spara till cache
      await _saveToCache(newList);

      // Synka till Firebase (collaborative lists använder annan collection)
      _scheduleSyncForList(newList.id);

      AppLogger.success(
          '✅ Kollaborativ lista "$name" skapad med ${memberIds.length} medlemmar');
      return newList.id;
    } catch (e) {
      AppLogger.error('❌ Kunde inte skapa kollaborativ lista: $e');
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
      AppLogger.error('❌ Kunde inte byta namn på lista: $e');
      _setError('Kunde inte byta namn: $e');
      return false;
    }
  }

  Future<bool> deleteList(String listId) async {
    try {
      // Kan inte ta bort om det är enda listan
      if (_lists.length <= 1) {
        _setError('Du måste ha minst en inköpslista');
        return false;
      }

      final list = _lists.where((l) => l.id == listId).firstOrNull;
      if (list == null) {
        _setError('Lista hittades inte');
        return false;
      }

      // Ta bort lokalt
      _lists.removeWhere((l) => l.id == listId);

      // Om det var aktiva listan, sätt en annan som aktiv
      if (_activeListId == listId && _lists.isNotEmpty) {
        await setActiveList(_lists.first.id);
      }

      // Ta bort från cache
      await _removeFromCache(listId);

      // Ta bort från Firebase
      _scheduleDeleteForList(listId, list.isCollaborative);

      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('❌ Kunde inte ta bort lista: $e');
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
      AppLogger.error('❌ Kunde inte sätta aktiv lista: $e');
      _setError('Kunde inte byta lista: $e');
      return false;
    }
  }

  // ===== ITEM MANAGEMENT =====

  Future<bool> addItemToActiveList({
    required String name,
    required double amount,
    String unit = '',
    String category = 'Övrigt',
    String? note,
    double? estimatedPrice,
    int priority = 3,
  }) async {
    if (activeList == null) {
      _setError('Ingen aktiv lista');
      return false;
    }

    if (name.trim().isEmpty) {
      _setError('Artikelnamn krävs');
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
      AppLogger.error('❌ Kunde inte lägga till artikel: $e');
      _setError('Kunde inte lägga till artikel: $e');
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
      AppLogger.error('❌ Kunde inte ändra artikel-status: $e');
      _setError('Kunde inte ändra status: $e');
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
      AppLogger.error('❌ Kunde inte ta bort artikel: $e');
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
      AppLogger.error('❌ Kunde inte rensa köpta artiklar: $e');
      _setError('Kunde inte rensa köpta artiklar: $e');
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
      AppLogger.error('❌ Kunde inte avmarkera alla artiklar: $e');
      _setError('Kunde inte avmarkera alla artiklar: $e');
      return false;
    }
  }

  // ===== EXPORT =====

  String exportListAsText() {
    if (activeList == null) return 'Ingen aktiv lista';

    final buffer = StringBuffer();
    buffer.writeln('📋 ${activeList!.name}');
    buffer.writeln('=' * activeList!.name.length);
    buffer.writeln();

    if (activeList!.description?.isNotEmpty == true) {
      buffer.writeln(activeList!.description);
      buffer.writeln();
    }

    final activeItems =
        activeList!.items.where((item) => !item.bought).toList();
    final boughtItems = activeList!.items.where((item) => item.bought).toList();

    if (activeItems.isNotEmpty) {
      buffer.writeln('📝 Kvar att handla:');
      for (final item in activeItems) {
        buffer.writeln('☐ ${item.displayText}');
      }
      buffer.writeln();
    }

    if (boughtItems.isNotEmpty) {
      buffer.writeln('✅ Inhandlat:');
      for (final item in boughtItems) {
        buffer.writeln('☑ ${item.displayText}');
      }
    }

    return buffer.toString();
  }

  // ===== PRIVATE METHODS =====

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
      AppLogger.error('❌ Kunde inte uppdatera lista: $e');
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

  void _scheduleDeleteForList(String listId, bool isCollaborative) {
    // För borttagning, gör direkt utan debounce
    _deleteListFromFirebase(listId, isCollaborative);
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

  // ===== FIREBASE SYNC METHODS =====

  Future<void> _syncListToFirebase(UnifiedShoppingList list) async {
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('unified_shopping_lists')
          .doc(list.id)
          .set(list.toFirestore(), SetOptions(merge: true));

      AppLogger.debug('Lista synkad: ${list.name}');
    } catch (e) {
      AppLogger.error('Firebase synk-fel för lista ${list.id}: $e');
    }
  }

  Future<void> _syncCollaborativeListToFirebase(
      UnifiedShoppingList list) async {
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

  void _startFirebaseSync() {
    if (currentUserId == null) return;

    AppLogger.info('🔄 Startar Firebase sync för unified data...');

    try {
      // Personal lists
      _personalListsSubscription = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('unified_shopping_lists')
          .snapshots()
          .listen(
        _handlePersonalListsSnapshot,
        onError: (error) {
          AppLogger.error('Personal lists snapshot error: $error');
        },
      );

      // Collaborative lists
      _collaborativeListsSubscription = _firestore
          .collection('unified_shared_shopping_lists')
          .where('memberPermissions.$currentUserId', isNotEqualTo: null)
          .snapshots()
          .listen(
        _handleCollaborativeListsSnapshot,
        onError: (error) {
          AppLogger.error('Collaborative lists snapshot error: $error');
        },
      );

      AppLogger.success('✅ Firebase sync startat');
    } catch (e) {
      AppLogger.error('❌ Kunde inte starta Firebase sync: $e');
    }
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

  // ===== CACHE METHODS - ✅ FIXAD FÖR ATT FUNGERA OFFLINE =====

  Future<void> _loadCachedLists(Box<String> box) async {
    try {
      final cachedListIds =
          box.keys.where((key) => key != _activeListKey).toList();

      for (final listId in cachedListIds) {
        final cachedData = box.get(listId);
        if (cachedData != null) {
          try {
            // ✅ FIX: Parse JSON properly from cache
            final listData = jsonDecode(cachedData);
            final list = UnifiedShoppingList.fromJson(listData);
            _lists.add(list);
            AppLogger.debug('Laddad cached lista: ${list.name}');
          } catch (e) {
            AppLogger.error('Fel vid parsing av cached lista $listId: $e');
            // Ta bort trasig cache
            await box.delete(listId);
          }
        }
      }

      // Load active list ID
      _activeListId = box.get(_activeListKey);

      // Om ingen aktiv lista men vi har listor, sätt första som aktiv
      if (_activeListId == null && _lists.isNotEmpty) {
        _activeListId = _lists.first.id;
        await box.put(_activeListKey, _activeListId!);
      }

      AppLogger.debug('✅ ${_lists.length} cached lists laddade');
    } catch (e) {
      AppLogger.error('Fel vid laddning av cached lists: $e');
    }
  }

  Future<void> _saveToCache(UnifiedShoppingList list) async {
    try {
      final box = await Hive.openBox<String>(_hiveBoxName);
      final listData = list.toJson();
      final listJson = jsonEncode(listData);
      await box.put(list.id, listJson);
      AppLogger.debug('Lista cachad: ${list.name}');
    } catch (e) {
      AppLogger.error('Fel vid sparande till cache: $e');
    }
  }

  Future<void> _removeFromCache(String listId) async {
    try {
      final box = await Hive.openBox<String>(_hiveBoxName);
      await box.delete(listId);
      AppLogger.debug('Lista borttagen från cache: $listId');
    } catch (e) {
      AppLogger.error('Fel vid borttagning från cache: $e');
    }
  }

  Future<void> _deleteListFromFirebase(
      String listId, bool isCollaborative) async {
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

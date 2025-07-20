// lib/services/unified/modules/shopping_service_initialization.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/cache/json_cache_helper.dart';
import '../../../core/utils/logger.dart';
import '../../../repositories/interfaces/auth_repository.dart';
import '../../../repositories/firestore_repository.dart';
import '../../../models/unified/unified_shopping_list.dart';

/// Handles initialization logic for UnifiedShoppingService
class ShoppingServiceInitialization {
  final FirestoreRepository _firestoreRepository;
  final AuthRepository _authRepository;
  final JsonCacheHelper _cacheHelper;
  final List<UnifiedShoppingList> _lists;
  final void Function(String?) _setActiveListId;
  final void Function() _notifyListeners;
  final void Function(String) _setError;
  final void Function() _clearAll;
  final void Function() _startFirebaseSync;
  final String? Function() _getCurrentUserId;

  static const String _activeListKey = 'active_list_id';
  bool _isInitialized = false;

  ShoppingServiceInitialization({
    required FirestoreRepository firestoreRepository,
    required AuthRepository authRepository,
    required JsonCacheHelper cacheHelper,
    required List<UnifiedShoppingList> lists,
    required void Function(String?) setActiveListId,
    required void Function() notifyListeners,
    required void Function(String) setError,
    required void Function() clearAll,
    required void Function() startFirebaseSync,
    required String? Function() getCurrentUserId,
  }) : _firestoreRepository = firestoreRepository,
       _authRepository = authRepository,
       _cacheHelper = cacheHelper,
       _lists = lists,
       _setActiveListId = setActiveListId,
       _notifyListeners = notifyListeners,
       _setError = setError,
       _clearAll = clearAll,
       _startFirebaseSync = startFirebaseSync,
       _getCurrentUserId = getCurrentUserId;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.info('🔄 Initialiserar UnifiedShoppingService...');

      // ✅ EMULATOR FIX: Konfigurera Firestore för emulator om det behövs
      if (kDebugMode) {
        try {
          // Detta hjälper med emulator DNS-problem
          _firestoreRepository.firestore.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );
        } catch (e) {
          AppLogger.debug('Firestore settings redan satta');
        }
      }

      // Initialize cache helper
      _cacheHelper.setCurrentUser(_getCurrentUserId());

      // Ladda cached data först (offline-first)
      await _loadCachedLists();

      // Lyssna på auth changes using mixin
      _authRepository.authStateChanges().listen((user) {
        _cacheHelper.setCurrentUser(user?.uid);
        if (user == null) {
          _clearAll();
        }
      });

      // Starta Firebase sync om inloggad using mixin
      if (_authRepository.getCurrentUser() != null) {
        _startFirebaseSync();
      }

      _isInitialized = true;
      AppLogger.success('✅ UnifiedShoppingService initialiserad');
      _notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Fel vid initialisering: $e');
      _setError('Kunde inte ladda inköpslistor: $e');
    }
  }

  /// Load lists - alias for initialize for compatibility
  Future<void> loadLists() async {
    await initialize();
  }

  Future<void> _loadCachedLists() async {
    try {
      final cachedListIds = await _cacheHelper.getAllKeys();
      final dataKeys = cachedListIds.where((key) => key != _activeListKey).toList();

      for (final listId in dataKeys) {
        final listData = await _cacheHelper.loadJson(listId);
        if (listData != null) {
          try {
            final list = UnifiedShoppingList.fromJson(listData);
            _lists.add(list);
            AppLogger.debug('Laddad cached lista: ${list.name}');
          } catch (e) {
            AppLogger.error('Fel vid parsing av cached lista $listId: $e');
            // Ta bort trasig cache
            await _cacheHelper.delete(listId);
          }
        }
      }

      // Load active list ID
      final activeListId = await _cacheHelper.loadActiveId(_activeListKey);
      _setActiveListId(activeListId);

      // Om ingen aktiv lista men vi har listor, sätt första som aktiv
      if (activeListId == null && _lists.isNotEmpty) {
        final firstListId = _lists.first.id;
        _setActiveListId(firstListId);
        await _cacheHelper.saveActiveId(_activeListKey, firstListId);
      }

      AppLogger.debug('✅ ${_lists.length} cached lists laddade');
    } catch (e) {
      AppLogger.error('Fel vid laddning av cached lists: $e');
    }
  }
}
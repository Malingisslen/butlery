// lib/viewmodels/menu_viewmodel.dart
// ✅ INTEGRERAD med social import support

import 'package:flutter/foundation.dart';
import '../constants/icon_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/recipe_unified.dart';
import '../services/unified/unified_recipe_service.dart';
import '../services/menu_service.dart';
import '../services/permission_service.dart';
import '../services/unified/unified_friends_service.dart';
import '../services/unified/operations/social_menu_operations.dart';
import '../core/injection.dart';
import '../core/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ViewModel för VeckomenyView
/// ✅ INTEGRERAD med social import för seamless menu management
class MenuViewModel extends ChangeNotifier {
  final UnifiedRecipeService _recipeService;
  final MenuService _menuService;
  late final SocialMenuOperations _socialMenuOps;

  // BEFINTLIG State
  Map<String, List<Recipe>> _menu = {};
  bool _isGenerating = false;
  String? _error;
  String _lastPrompt = '';

  // ✅ UPPDATERAD: Kombinerade menyer (egna + importerade)
  List<SavedMenuInfo> _savedMenus = [];

  MenuViewModel({
    UnifiedRecipeService? recipeService,
    MenuService? menuService,
  })  : _recipeService = recipeService ?? sl<UnifiedRecipeService>(),
        _menuService = menuService ?? sl<MenuService>() {
    // ✅ NY INIT
    
    // Initialize social menu operations
    _socialMenuOps = SocialMenuOperations(
      firestore: FirebaseFirestore.instance,
      friendsService: sl<UnifiedFriendsService>(),
    );

    // Lyssna på ändringar från UnifiedRecipeService
    _recipeService.addListener(_onRecipesChanged);

    // Ladda kombinerade menyer vid start
    _loadAllMenus();
  }

  // ===== BEFINTLIGA GETTERS =====
  Map<String, List<Recipe>> get menu => Map.unmodifiable(_menu);
  bool get isGenerating => _isGenerating;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasMenu => _menu.isNotEmpty;
  String get lastPrompt => _lastPrompt;

  int get totalRecipeCount =>
      _menu.values.fold(0, (total, recipes) => total + recipes.length);

  List<Recipe> get availableRecipes {
    // Ensure service is initialized and get unified recipes
    if (!_recipeService.isInitialized) {
      return [];
    }
    return _recipeService.recipes;
  }
  bool get hasAvailableRecipes => availableRecipes.isNotEmpty;

  // ✅ UPPDATERAD: Kombinerade menyer
  List<SavedMenuInfo> get savedMenus => List.unmodifiable(_savedMenus);

  // ===== BEFINTLIGA ACTIONS =====
  Future<void> generateMenu(String prompt) async {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) {
      _setError('Ange vad du vill ha för meny');
      return;
    }

    _setGenerating(true);
    _lastPrompt = trimmedPrompt;

    try {
      // Ensure recipe service is initialized before proceeding
      if (!_recipeService.isInitialized) {
        AppLogger.info('🔄 Initialiserar recept-service för meny-generering...');
        await _recipeService.initialize();
      }
      
      await Future.delayed(const Duration(milliseconds: 300));

      if (availableRecipes.isEmpty) {
        throw Exception('Inga recept tillgängliga. Lägg till recept först.');
      }

      final generatedMenu = _menuService.generateMenuFromPrompt(
        trimmedPrompt,
        availableRecipes,
      );

      if (generatedMenu.isEmpty) {
        throw Exception(
          'Kunde inte generera meny från din begäran. Prova att vara mer specifik.',
        );
      }

      _menu = generatedMenu;
      _error = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setGenerating(false);
    }
  }

  Future<void> regenerateSection(String section) async {
    if (!hasMenu) return;

    _setGenerating(true);

    try {
      await Future.delayed(const Duration(milliseconds: 200));

      final currentCount = _menu[section]?.length ?? 1;

      final newRecipes = _menuService.generateMenuFromPrompt(
        '$currentCount $section',
        availableRecipes,
      );

      if (newRecipes.containsKey(section)) {
        _menu[section] = newRecipes[section]!;
        _error = null;
        notifyListeners();
      }
    } catch (e) {
      _setError('Kunde inte uppdatera $section: ${e.toString()}');
    } finally {
      _setGenerating(false);
    }
  }

  void clearMenu() {
    _menu = {};
    _lastPrompt = '';
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ===== UPPDATERADE METODER =====

  Future<bool> saveMenuWithNameAndComment(
    String menuName,
    String comment, {
    bool shareWithFriends = false,
    List<String>? selectedFriendIds,
    String? shareMessage,
  }) async {
    if (!hasMenu) {
      _setError('Ingen meny att spara');
      return false;
    }

    if (menuName.trim().isEmpty) {
      _setError('Ange ett namn för menyn');
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final menuKey = 'saved_menu_${menuName.replaceAll(' ', '_')}_$timestamp';

      final savedMenu = SavedMenuData(
        name: menuName.trim(),
        savedDate: DateTime.now(),
        recipeCount: totalRecipeCount,
        menu: _menu,
        lastPrompt: _lastPrompt,
        comment: comment.trim(),
      );

      final menuJson = jsonEncode(savedMenu.toJson());
      await prefs.setString(menuKey, menuJson);

      // Social sharing
      if (shareWithFriends &&
          selectedFriendIds != null &&
          selectedFriendIds.isNotEmpty) {
        try {
          final shareSuccess = await _socialMenuOps.shareMenuWithFriends(
            menu: savedMenu.menu,
            friendUserIds: selectedFriendIds,
            message: shareMessage?.trim(),
            customTitle: savedMenu.name,
          );

          if (shareSuccess) {
            AppLogger.success(
                '✅ Meny sparad OCH delad med ${selectedFriendIds.length} vänner: $menuName');
          } else {
            AppLogger.warning(
                '⚠️ Meny sparad lokalt, men social delning misslyckades');
            _setError('Meny sparad, men kunde inte dela med vänner');
          }
        } catch (e) {
          AppLogger.warning(
              '⚠️ Meny sparad lokalt, men social delning misslyckades: $e');
          _setError('Meny sparad, men kunde inte dela med vänner: $e');
        }
      } else {
        AppLogger.success(
            '✅ Meny sparad lokalt: $menuName med $totalRecipeCount recept');
      }

      // ✅ UPPDATERAD: Ladda alla menyer (inklusive importerade)
      await _loadAllMenus();

      return true;
    } catch (e) {
      _setError('Kunde inte spara meny: ${e.toString()}');
      AppLogger.error('Save menu failed', e);
      return false;
    }
  }

  /// ✅ UPPDATERAD: Ladda meny med support för importerade menyer
  Future<bool> loadSavedMenu(String menuKey) async {
    try {
      // Försök ladda från SharedPreferences först
      final prefs = await SharedPreferences.getInstance();
      final menuJson = prefs.getString(menuKey);

      if (menuJson != null) {
        // Lokal sparad meny
        final menuData = SavedMenuData.fromJson(jsonDecode(menuJson));
        _menu = menuData.menu;
        _lastPrompt = menuData.lastPrompt;
        _error = null;
        notifyListeners();

        AppLogger.success('✅ Lokal meny laddad: ${menuData.name}');
        return true;
      }

      // ✅ NY: Försök ladda från importerade menyer
      final importedMenu = await _loadImportedMenu(menuKey);
      if (importedMenu != null) {
        _menu = importedMenu.menu;
        _lastPrompt = importedMenu.lastPrompt;
        _error = null;
        notifyListeners();

        AppLogger.success('✅ Importerad meny laddad: ${importedMenu.name}');
        return true;
      }

      _setError('Menyn kunde inte hittas');
      return false;
    } catch (e) {
      _setError('Kunde inte ladda meny: ${e.toString()}');
      AppLogger.error('Load menu failed', e);
      return false;
    }
  }

  Future<bool> deleteSavedMenu(String menuKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(menuKey);

      // ✅ UPPDATERAD: Ladda alla menyer
      await _loadAllMenus();

      AppLogger.success('✅ Meny borttagen: $menuKey');
      return true;
    } catch (e) {
      _setError('Kunde inte ta bort meny: ${e.toString()}');
      AppLogger.error('Delete menu failed', e);
      return false;
    }
  }

  Future<bool> markMenuAsModified(String menuKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final menuJson = prefs.getString(menuKey);

      if (menuJson == null) {
        _setError('Menyn kunde inte hittas');
        return false;
      }

      final menuData = SavedMenuData.fromJson(jsonDecode(menuJson));

      if (menuData.isOwned) {
        _setError('Kan bara markera importerade menyer som modifierade');
        return false;
      }

      final modifiedMenuData = SavedMenuData(
        name: menuData.name,
        savedDate: menuData.savedDate,
        recipeCount: menuData.recipeCount,
        menu: menuData.menu,
        lastPrompt: menuData.lastPrompt,
        comment: menuData.comment,
        originalAuthor: menuData.originalAuthor,
        originalAuthorId: menuData.originalAuthorId,
        isModified: true,
        firebaseId: menuData.firebaseId,
      );

      await prefs.setString(menuKey, jsonEncode(modifiedMenuData.toJson()));
      await _loadAllMenus();

      AppLogger.success('✅ Meny markerad som modifierad: ${menuData.name}');
      return true;
    } catch (e) {
      _setError('Kunde inte markera meny som modifierad: ${e.toString()}');
      AppLogger.error('Mark menu as modified failed', e);
      return false;
    }
  }

  /// ✅ NY: Manual refresh av alla menyer
  Future<void> refreshSavedMenus() async {
    AppLogger.info('🔄 Tvingar omladning av alla menyer...');
    await _loadAllMenus();
  }

  // ===== SOCIAL MENU METHODS =====

  /// Share current menu with selected friends
  Future<bool> shareCurrentMenuWithFriends({
    required List<String> friendUserIds,
    String? message,
    String? customTitle,
  }) async {
    if (!hasMenu) {
      _setError('Ingen meny att dela');
      return false;
    }

    try {
      return await _socialMenuOps.shareMenuWithFriends(
        menu: _menu,
        friendUserIds: friendUserIds,
        message: message,
        customTitle: customTitle,
      );
    } catch (e) {
      _setError('Kunde inte dela meny: $e');
      return false;
    }
  }

  /// Share current menu with friend group/category
  Future<bool> shareCurrentMenuWithGroup({
    required String categoryId,
    String? message,
    String? customTitle,
  }) async {
    if (!hasMenu) {
      _setError('Ingen meny att dela');
      return false;
    }

    try {
      return await _socialMenuOps.shareMenuWithGroup(
        menu: _menu,
        categoryId: categoryId,
        message: message,
        customTitle: customTitle,
      );
    } catch (e) {
      _setError('Kunde inte dela meny med grupp: $e');
      return false;
    }
  }

  /// Get menus shared with current user (not yet imported)
  Future<List<Map<String, dynamic>>> getAvailableSharedMenus() async {
    try {
      final sharedMenus = await _socialMenuOps.getMenusSharedWithMe();
      // Filter out already imported menus
      return sharedMenus.where((menu) => menu['isImported'] != true).toList();
    } catch (e) {
      AppLogger.error('Failed to get available shared menus', e);
      return [];
    }
  }

  /// Import shared menu
  Future<bool> importSharedMenu(String sharedMenuId) async {
    try {
      final success = await _socialMenuOps.importSharedMenu(sharedMenuId);
      if (success) {
        // Refresh saved menus to show newly imported menu
        await _loadAllMenus();
      }
      return success;
    } catch (e) {
      _setError('Kunde inte importera meny: $e');
      return false;
    }
  }

  /// Mark shared menu as viewed
  Future<void> markSharedMenuAsViewed(String sharedMenuId) async {
    await _socialMenuOps.markMenuAsViewed(sharedMenuId);
  }

  /// Get sharing statistics
  Future<Map<String, dynamic>> getSharingStats() async {
    return await _socialMenuOps.getSharingStats();
  }

  // ===== NYA METODER - Social Integration =====

  /// ✅ NY: Ladda alla menyer (lokala + importerade)
  Future<void> _loadAllMenus() async {
    try {
      final localMenus = await _loadLocalMenus();
      final importedMenus = await _loadImportedMenus();

      // Kombinera listorna
      final allMenus = <SavedMenuInfo>[...localMenus, ...importedMenus];

      // Sortera: egna först, sedan importerade, inom varje typ efter datum
      allMenus.sort((a, b) {
        // Egna menyer först
        if (a.isOwned && !b.isOwned) return -1;
        if (!a.isOwned && b.isOwned) return 1;

        // Inom samma typ, sortera efter datum (nyaste först)
        return b.savedDate.compareTo(a.savedDate);
      });

      _savedMenus = allMenus;
      notifyListeners();

      AppLogger.success(
          '✅ Alla menyer laddade: ${localMenus.length} lokala, ${importedMenus.length} importerade');
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av menyer: $e');
    }
  }

  /// ✅ NY: Ladda lokala sparade menyer (tidigare logik)
  Future<List<SavedMenuInfo>> _loadLocalMenus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final menuKeys =
          keys.where((key) => key.startsWith('saved_menu_')).toList();

      final menuInfos = <SavedMenuInfo>[];

      for (final key in menuKeys) {
        try {
          final menuJson = prefs.getString(key);
          if (menuJson != null) {
            final menuData = SavedMenuData.fromJson(jsonDecode(menuJson));

            // Bara egna menyer (inte importerade som blivit sparade lokalt)
            if (menuData.isOwned) {
              menuInfos.add(SavedMenuInfo(
                key: key,
                name: menuData.name,
                savedDate: menuData.savedDate,
                recipeCount: menuData.recipeCount,
                comment: menuData.comment,
                originalAuthor: menuData.originalAuthor,
                isModified: menuData.isModified,
                isOwned: menuData.isOwned,
              ));
            }
          }
        } catch (e) {
          AppLogger.warning('⚠️ Kunde inte läsa lokal meny $key: $e');
        }
      }

      return menuInfos;
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av lokala menyer: $e');
      return [];
    }
  }

  /// ✅ NY: Ladda importerade menyer från social service
  Future<List<SavedMenuInfo>> _loadImportedMenus() async {
    try {
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return [];

      final importedMenus = <SavedMenuInfo>[];

      // Hämta importerade menyer från social service
      final sharedMenus = await _socialMenuOps.getMenusSharedWithMe();
      
      for (final sharedMenu in sharedMenus) {
        // Only include imported menus
        if (sharedMenu['isImported'] == true) {
          // Handle Firebase Timestamp
          DateTime sharedDate;
          final sharedAtData = sharedMenu['sharedAt'];
          if (sharedAtData is Timestamp) {
            sharedDate = sharedAtData.toDate();
          } else if (sharedAtData is DateTime) {
            sharedDate = sharedAtData;
          } else {
            sharedDate = DateTime.now(); // Fallback
          }

          importedMenus.add(SavedMenuInfo(
            key: 'imported_menu_${sharedMenu['id']}', // Special key för importerade
            name: sharedMenu['title'] ?? 'Namnlös meny',
            savedDate: sharedDate, // Använd delningsdatum
            recipeCount: sharedMenu['totalRecipes'] ?? 0,
            comment: sharedMenu['description'] ?? '',
            originalAuthor: sharedMenu['sharedByDisplayName'] ?? 'Okänd användare',
            isModified: false,
            isOwned: false, // Inte ägd av användaren
          ));
        }
      }

      return importedMenus;
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av importerade menyer: $e');
      return [];
    }
  }

  /// ✅ NY: Ladda en specifik importerad meny
  Future<SavedMenuData?> _loadImportedMenu(String menuKey) async {
    try {
      if (!menuKey.startsWith('imported_menu_')) return null;

      final sharedMenuId = menuKey.replaceFirst('imported_menu_', '');
      final sharedMenuData = await _socialMenuOps.getSharedMenuData(sharedMenuId);

      if (sharedMenuData == null) return null;

      // Handle Firebase Timestamp
      DateTime sharedDate;
      final sharedAtData = sharedMenuData['sharedAt'];
      if (sharedAtData is Timestamp) {
        sharedDate = sharedAtData.toDate();
      } else if (sharedAtData is DateTime) {
        sharedDate = sharedAtData;
      } else {
        sharedDate = DateTime.now(); // Fallback
      }

      // Skapa SavedMenuData från SharedMenu
      return SavedMenuData(
        name: sharedMenuData['title'] ?? 'Namnlös meny',
        savedDate: sharedDate,
        recipeCount: sharedMenuData['totalRecipes'] ?? 0,
        menu: sharedMenuData['menu'] as Map<String, List<Recipe>>? ?? {},
        lastPrompt: 'Importerad från ${sharedMenuData['sharedByDisplayName'] ?? 'Okänd användare'}',
        comment: sharedMenuData['description'] ?? '',
        originalAuthor: sharedMenuData['sharedByDisplayName'],
        originalAuthorId: sharedMenuData['sharedByUserId'],
        isModified: false,
        firebaseId: sharedMenuData['id'],
      );
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av importerad meny: $e');
      return null;
    }
  }

  // TODO: Implement social content listener when social features are ready
  // void _onSocialContentChanged() {
  //   // När social content ändras (t.ex. ny import), uppdatera meny-listan
  //   _loadAllMenus();
  // }

  // ===== BEFINTLIGA PRIVATE METHODS =====
  void _setGenerating(bool value) {
    _isGenerating = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _onRecipesChanged() {
    if (hasMenu) {
      final allRecipeIds = availableRecipes.map((r) => r.id).toSet();
      var menuChanged = false;

      _menu.forEach((category, recipes) {
        final validRecipes =
            recipes.where((r) => allRecipeIds.contains(r.id)).toList();
        if (validRecipes.length != recipes.length) {
          _menu[category] = validRecipes;
          menuChanged = true;
        }
      });

      if (menuChanged) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _recipeService.removeListener(_onRecipesChanged);
    // TODO: Remove social service listener when implemented
    // _socialService.removeListener(_onSocialContentChanged); // ✅ NY CLEANUP
    super.dispose();
  }
}

// ===== BEFINTLIGA HJÄLPKLASSER =====

class SavedMenuInfo {
  final String key;
  final String name;
  final DateTime savedDate;
  final int recipeCount;
  final String comment;
  final String? originalAuthor;
  final bool isModified;
  final bool isOwned;

  SavedMenuInfo({
    required this.key,
    required this.name,
    required this.savedDate,
    required this.recipeCount,
    required this.comment,
    this.originalAuthor,
    this.isModified = false,
    this.isOwned = true,
  });

  String get attribution {
    if (isOwned) return 'Din meny';
    if (isModified) return 'Inspirerad av $originalAuthor';
    return 'Av $originalAuthor';
  }

  IconType get statusIcon {
    if (isOwned) return IconType.restaurantMenu;
    if (isModified) return IconType.autoFixHigh;
    return IconType.person;
  }

  // Color should be handled by UI layer - this is just for data identification
  String get attributionColorType {
    if (isOwned) return 'owned';
    if (isModified) return 'modified';
    return 'shared';
  }
}

class SavedMenuData {
  final String name;
  final DateTime savedDate;
  final int recipeCount;
  final Map<String, List<Recipe>> menu;
  final String lastPrompt;
  final String comment;
  final String? originalAuthor;
  final String? originalAuthorId;
  final bool isModified;
  final String? firebaseId;

  SavedMenuData({
    required this.name,
    required this.savedDate,
    required this.recipeCount,
    required this.menu,
    required this.lastPrompt,
    required this.comment,
    this.originalAuthor,
    this.originalAuthorId,
    this.isModified = false,
    this.firebaseId,
  });

  bool get isOwned => originalAuthor == null;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'savedDate': savedDate.millisecondsSinceEpoch,
      'recipeCount': recipeCount,
      'menu': menu.map((key, recipes) => MapEntry(
            key,
            recipes.map((recipe) => recipe.toJson()).toList(),
          )),
      'lastPrompt': lastPrompt,
      'comment': comment,
      'originalAuthor': originalAuthor,
      'originalAuthorId': originalAuthorId,
      'isModified': isModified,
      'firebaseId': firebaseId,
    };
  }

  static SavedMenuData fromJson(Map<String, dynamic> json) {
    final menuMap = <String, List<Recipe>>{};

    if (json['menu'] != null) {
      final menuJson = json['menu'] as Map<String, dynamic>;
      menuJson.forEach((key, recipeList) {
        if (recipeList is List) {
          menuMap[key] = recipeList
              .map((recipeJson) =>
                  Recipe.fromJson(recipeJson as Map<String, dynamic>))
              .toList();
        }
      });
    }

    return SavedMenuData(
      name: json['name'] ?? '',
      savedDate: DateTime.fromMillisecondsSinceEpoch(json['savedDate'] ?? 0),
      recipeCount: json['recipeCount'] ?? 0,
      menu: menuMap,
      lastPrompt: json['lastPrompt'] ?? '',
      comment: json['comment'] ?? '',
      originalAuthor: json['originalAuthor'],
      originalAuthorId: json['originalAuthorId'],
      isModified: json['isModified'] ?? false,
      firebaseId: json['firebaseId'],
    );
  }
}

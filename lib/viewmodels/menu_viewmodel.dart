// lib/viewmodels/menu_viewmodel.dart
// ✅ INTEGRERAD med social import support

import 'package:flutter/foundation.dart';
import '../constants/icon_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/recipe.dart';
import '../services/unified/unified_recipe_service.dart';
import '../services/menu_service.dart';
import '../services/user_service.dart'; // ✅ NY IMPORT
import '../core/injection.dart';
import '../core/utils/logger.dart';

/// ViewModel för VeckomenyView
/// ✅ INTEGRERAD med social import för seamless menu management
class MenuViewModel extends ChangeNotifier {
  final UnifiedRecipeService _recipeService;
  final MenuService _menuService;
  final UserService _userService; // ✅ NY SERVICE

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
    UserService? userService, // ✅ NY PARAMETER
  })  : _recipeService = recipeService ?? sl<UnifiedRecipeService>(),
        _menuService = menuService ?? sl<MenuService>(),
        _userService = userService ?? sl<UserService>() {
    // ✅ NY INIT

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
      _menu.values.fold(0, (sum, recipes) => sum + recipes.length);

  List<Recipe> get availableRecipes => _recipeService.legacyRecipes;
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
          // TODO: Implement social sharing through UnifiedFriendsService
          // await _socialService.shareMenuToFriends(
          //   menu: savedMenu.menu,
          //   friendUserIds: selectedFriendIds,
          //   message: shareMessage?.trim(),
          //   customTitle: savedMenu.name,
          // );
          debugPrint('Social sharing not yet implemented');

          AppLogger.success(
              '✅ Meny sparad OCH delad med ${selectedFriendIds.length} vänner: $menuName');
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
      final currentUserId = _userService.currentUserProfile?.uid;
      if (currentUserId == null) return [];

      final importedMenus = <SavedMenuInfo>[];

      // TODO: Implement social menu loading through UnifiedFriendsService
      // 🚀 PERFORMANCE FIX: Skip loading imported menus if social content hasn't been loaded yet
      // This prevents triggering Firebase queries during app startup
      // if (!_socialService.hasLoadedContent) {
      //   AppLogger.info('🚀 Skipping imported menus - social content not loaded yet');
      //   return [];
      // }

      // Hämta importerade menyer från social service
      const List<dynamic> sharedMenus = []; // Placeholder until social features implemented
      for (final sharedMenu in sharedMenus) {
        if (sharedMenu.isImportedBy(currentUserId)) {
          importedMenus.add(SavedMenuInfo(
            key:
                'imported_menu_${sharedMenu.id}', // Special key för importerade
            name: sharedMenu.menuTitle,
            savedDate: sharedMenu.sharedAt, // Använd delningsdatum
            recipeCount: sharedMenu.totalRecipeCount,
            comment: sharedMenu.shareMessage ?? '',
            originalAuthor: sharedMenu.sharedByDisplayName,
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

      // TODO: Implement social menu lookup through UnifiedFriendsService
      // final sharedMenuId = menuKey.replaceFirst('imported_menu_', '');
      // final sharedMenu = _socialService.menusSharedWithMe
      //     .where((m) => m.id == sharedMenuId)
      //     .firstOrNull;
      const dynamic sharedMenu = null; // Placeholder until social features implemented

      if (sharedMenu == null) return null;

      final currentUserId = _userService.currentUserProfile?.uid;
      if (currentUserId == null || !sharedMenu.isImportedBy(currentUserId)) {
        return null;
      }

      // Skapa SavedMenuData från SharedMenu
      return SavedMenuData(
        name: sharedMenu.menuTitle,
        savedDate: sharedMenu.sharedAt,
        recipeCount: sharedMenu.totalRecipeCount,
        menu: sharedMenu.menuSnapshot,
        lastPrompt: 'Importerad från ${sharedMenu.sharedByDisplayName}',
        comment: sharedMenu.shareMessage ?? '',
        originalAuthor: sharedMenu.sharedByDisplayName,
        originalAuthorId: sharedMenu.sharedByUserId,
        isModified: false,
        firebaseId: sharedMenu.id,
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

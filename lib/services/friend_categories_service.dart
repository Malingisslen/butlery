// lib/services/friend_categories_service.dart - ✅ KOMPLETT FIXAD VERSION

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/friend_category.dart';
import '../models/user_profile.dart';
import '../services/friends_service.dart';
import '../core/utils/logger.dart';
import '../core/error/error_handler.dart';
import '../repositories/friends_repository.dart';
import '../repositories/user_repository.dart';

class FriendCategoriesService extends ChangeNotifier {
  final FriendsRepository _friendsRepository;
  final UserRepository _userRepository;
  final FriendsService _friendsService;

  // State
  List<FriendCategory> _categories = [];
  final Map<String, List<UserProfile>> _categoryFriends = {}; // categoryId -> friends
  bool _isLoading = false;
  String? _error;

  // Cache timestamps
  final Map<String, DateTime> _categoryFriendsTimestamps = {};
  static const int _cacheDurationMinutes = 15;

  FriendCategoriesService({
    required FriendsService friendsService,
    required FriendsRepository friendsRepository,
    required UserRepository userRepository,
  })  : _friendsService = friendsService,
        _friendsRepository = friendsRepository,
        _userRepository = userRepository;

  // ===== GETTERS =====

  List<FriendCategory> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  String? get currentUserId => _userRepository.currentUserId;

  /// Get categories sorted by sort order
  List<FriendCategory> get sortedCategories {
    final sorted = List<FriendCategory>.from(_categories);
    sorted.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted;
  }

  /// Get categories with friends
  List<FriendCategory> get categoriesWithFriends {
    return _categories.where((category) => category.isNotEmpty).toList();
  }

  /// Get friends for specific category (cached)
  List<UserProfile> getFriendsForCategory(String categoryId) {
    return _categoryFriends[categoryId] ?? [];
  }

  /// Initialize service
  Future<void> initialize() async {
    AppLogger.info('🔄 Initialiserar FriendCategoriesService...');

    _userRepository.authStateChanges().listen((userId) {
      if (userId != null) {
        _loadCategories();
      } else {
        _clearAll();
      }
    });

    if (_userRepository.currentUserId != null) {
      await _loadCategories();
    }
  }

  /// ✅ FÖRBÄTTRAT: Create new category med korrekt Firebase path
  Future<bool> createCategory({
    required String name,
    String? description,
    String? emoji,
    List<String>? friendUserIds,
    int? sortOrder,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      _setError('Du måste vara inloggad för att skapa kategorier');
      return false;
    }

    if (name.trim().isEmpty) {
      _setError('Kategorinamn krävs');
      return false;
    }

    // Check if category name already exists
    if (_categories
        .any((cat) => cat.name.toLowerCase() == name.toLowerCase())) {
      _setError('En kategori med detta namn finns redan');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      // Validate friend IDs
      if (friendUserIds != null && friendUserIds.isNotEmpty) {
        final userFriends = _friendsService.friends.map((f) => f.uid).toSet();
        final invalidFriends =
            friendUserIds.where((id) => !userFriends.contains(id));

        if (invalidFriends.isNotEmpty) {
          _setError('Några valda användare är inte dina vänner');
          return false;
        }
      }

      // Determine sort order
      final effectiveSortOrder = sortOrder ?? _getNextSortOrder();

      // Create category
      final initialFriendIds = friendUserIds ?? [];

      // ✅ FIXAT: Säkerställ att skaparen alltid är medlem i gruppen
      if (!initialFriendIds.contains(userId)) {
        initialFriendIds.add(userId);
      }

      final category = FriendCategory.create(
        ownerId: userId,
        name: name.trim(),
        description: description?.trim(),
        emoji: emoji?.trim(),
        friendUserIds: initialFriendIds,
        sortOrder: effectiveSortOrder,
      );

      AppLogger.info(
          '📁 Sparar kategori till: users/$userId/friendCategories/${category.id}');

      await _friendsRepository.saveCategory(userId, category);
      AppLogger.success(
          '✅ Kategori sparad till Firebase: users/$userId/friendCategories/${category.id}');

      // Add to local cache
      _categories.add(category);
      AppLogger.info(
          '📝 Kategori tillagd i lokal cache. Total: ${_categories.length}');

      // Load friends for this category
      if (category.isNotEmpty) {
        await _loadFriendsForCategory(category.id);
      }

      AppLogger.success('✅ Kategori "${category.name}" skapad framgångsrikt');

      // ✅ VIKTIGT: Trigga notifyListeners för att uppdatera UI
      AppLogger.info('🔔 Triggar notifyListeners för UI-uppdatering...');
      notifyListeners();

      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte skapa kategori', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update existing category
  Future<bool> updateCategory({
    required String categoryId,
    String? name,
    String? description,
    String? emoji,
    List<String>? friendUserIds,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      _setError('Du måste vara inloggad för att uppdatera kategorier');
      return false;
    }

    // Hitta befintlig kategori
    final existingCategory = getCategoryById(categoryId);
    if (existingCategory == null) {
      _setError('Kategorin hittades inte');
      return false;
    }

    // Kontrollera att användaren äger kategorin
    if (existingCategory.ownerId != userId) {
      _setError('Du har inte behörighet att redigera denna kategori');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      // Kontrollera om namnet ändrats och om det nya namnet redan finns
      if (name != null && name.trim() != existingCategory.name) {
        if (_categories.any((cat) =>
            cat.name.toLowerCase() == name.toLowerCase() &&
            cat.id != categoryId)) {
          _setError('En kategori med detta namn finns redan');
          return false;
        }
      }

      // Validera friend IDs om de ändrats
      if (friendUserIds != null) {
        final userFriends = _friendsService.friends.map((f) => f.uid).toSet();
        final invalidFriends =
            friendUserIds.where((id) => !userFriends.contains(id));

        if (invalidFriends.isNotEmpty) {
          _setError('Några valda användare är inte dina vänner');
          return false;
        }
      }

      // Skapa uppdaterad kategori
      final updatedCategory = existingCategory.copyWith(
        name: name?.trim(),
        description: description?.trim(),
        emoji: emoji?.trim(),
        friendUserIds: friendUserIds,
        updatedAt: DateTime.now(),
      );

      await _friendsRepository.updateCategory(
        userId,
        categoryId,
        updatedCategory.toFirestore(),
      );

      // Uppdatera lokal cache
      final index = _categories.indexWhere((cat) => cat.id == categoryId);
      if (index != -1) {
        _categories[index] = updatedCategory;
      }

      // Ladda vänner för kategorin om den har medlemmar
      if (updatedCategory.isNotEmpty) {
        await _loadFriendsForCategory(categoryId);
      } else {
        // Rensa cache om kategorin nu är tom
        _categoryFriends[categoryId] = [];
      }

      AppLogger.success(
          '✅ Kategori "${updatedCategory.name}" uppdaterad framgångsrikt');

      // Trigga notifyListeners för att uppdatera UI
      notifyListeners();

      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte uppdatera kategori', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete existing category
  Future<bool> deleteCategory(String categoryId) async {
    final userId = currentUserId;
    if (userId == null) {
      _setError('Du måste vara inloggad för att ta bort kategorier');
      return false;
    }

    // Hitta befintlig kategori
    final existingCategory = getCategoryById(categoryId);
    if (existingCategory == null) {
      _setError('Kategorin hittades inte');
      return false;
    }

    // Kontrollera att användaren äger kategorin
    if (existingCategory.ownerId != userId) {
      _setError('Du har inte behörighet att ta bort denna kategori');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      await _friendsRepository.deleteCategory(userId, categoryId);
      AppLogger.success(
          '✅ Kategori borttagen från Firebase: users/$userId/friendCategories/$categoryId');

      // Ta bort från lokal cache
      _categories.removeWhere((cat) => cat.id == categoryId);
      _categoryFriends.remove(categoryId);
      _categoryFriendsTimestamps.remove(categoryId);

      AppLogger.info(
          '📝 Kategori borttagen från lokal cache. Kvar: ${_categories.length}');
      AppLogger.success(
          '✅ Kategori "${existingCategory.name}" borttagen framgångsrikt');

      // Trigga notifyListeners för att uppdatera UI
      notifyListeners();

      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte ta bort kategori', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get category by ID
  FriendCategory? getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((cat) => cat.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  /// Get categories containing specific friend
  List<FriendCategory> getCategoriesForFriend(String friendUserId) {
    return _categories
        .where((cat) => cat.containsFriend(friendUserId))
        .toList();
  }

  /// Search categories by name
  List<FriendCategory> searchCategories(String query) {
    if (query.trim().isEmpty) return sortedCategories;

    final lowerQuery = query.toLowerCase();
    return _categories.where((category) {
      return category.name.toLowerCase().contains(lowerQuery) ||
          (category.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Get category statistics
  CategoryStats getCategoryStats(String categoryId) {
    final category = getCategoryById(categoryId);
    if (category == null) {
      throw Exception('Kategorin hittades inte');
    }

    return CategoryStats.fromCategory(category);
  }

  /// Get all category statistics
  List<CategoryStats> getAllCategoryStats() {
    return _categories
        .map((category) => CategoryStats.fromCategory(category))
        .toList();
  }

  /// Check if category name is available
  bool isCategoryNameAvailable(String name, {String? excludeCategoryId}) {
    return !_categories.any((cat) =>
        cat.name.toLowerCase() == name.toLowerCase() &&
        cat.id != excludeCategoryId);
  }

  /// ===== PRIVATE METHODS =====

  /// ✅ FIXAT: Load categories från user-specific subcollection
  Future<void> _loadCategories() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      AppLogger.info('🔄 Laddar kategorier för användare: $userId');
      AppLogger.info('📁 Path: users/$userId/friendCategories');

      final categories = await _friendsRepository.fetchCategories(userId);

      _categories = categories;

      AppLogger.success(
          '✅ ${_categories.length} kategorier laddade från users/$userId/friendCategories');

      // Load friends for categories with friends
      final categoriesWithFriends = _categories.where((cat) => cat.isNotEmpty);
      for (final category in categoriesWithFriends) {
        await _loadFriendsForCategory(category.id);
      }

      if (_categories.isEmpty) {
        AppLogger.info('📝 Inga kategorier finns - användaren skapar egna');
      }

      notifyListeners();
    } catch (e) {
      AppLogger.error(
          'Kunde inte ladda kategorier från users/$userId/friendCategories', e);
      _setError('Kunde inte ladda kategorier: $e');
      notifyListeners();
    }
  }

  /// Load friends for specific category (with caching)
  Future<void> _loadFriendsForCategory(String categoryId) async {
    final category = getCategoryById(categoryId);
    if (category == null || category.isEmpty) {
      _categoryFriends[categoryId] = [];
      return;
    }

    // Check cache first
    final cacheTime = _categoryFriendsTimestamps[categoryId];
    if (cacheTime != null) {
      final isExpired = DateTime.now().difference(cacheTime).inMinutes >
          _cacheDurationMinutes;
      if (!isExpired && _categoryFriends.containsKey(categoryId)) {
        return; // Use cached data
      }
    }

    try {
      // Get friend profiles from UserService via FriendsService
      final allFriends = _friendsService.friends;
      final categoryFriends = allFriends
          .where((friend) => category.friendUserIds.contains(friend.uid))
          .toList();

      _categoryFriends[categoryId] = categoryFriends;
      _categoryFriendsTimestamps[categoryId] = DateTime.now();

      AppLogger.info(
          '✅ ${categoryFriends.length} vänner laddade för kategori "${category.name}"');
    } catch (e) {
      AppLogger.error('Kunde inte ladda vänner för kategori $categoryId', e);
      _categoryFriends[categoryId] = [];
    }
  }

  /// Get next sort order for new category
  int _getNextSortOrder() {
    if (_categories.isEmpty) return 0;
    return _categories
            .map((cat) => cat.sortOrder)
            .reduce((a, b) => a > b ? a : b) +
        1;
  }

  /// Clear all data
  void _clearAll() {
    _categories.clear();
    _categoryFriends.clear();
    _categoryFriendsTimestamps.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error state
  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  /// Clear error
  void _clearError() {
    _error = null;
  }

  /// Public error clearing
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Refresh all data
  Future<void> refresh() async {
    AppLogger.info('🔄 Refreshing FriendCategoriesService...');
    await _loadCategories();
  }

  /// Clear friends cache (useful when friends list updates)
  void clearFriendsCache() {
    _categoryFriends.clear();
    _categoryFriendsTimestamps.clear();
    AppLogger.info('🗑️ Category friends cache rensad');
  }

  // ===== MEDLEMSHANTERING =====

  /// Ta bort en vän från en kategori/grupp
  Future<bool> removeFriendFromCategory(
      String categoryId, String friendUserId) async {
    try {
      _setLoading(true);
      _clearError();

      AppLogger.info('🔄 Tar bort vän $friendUserId från kategori $categoryId');

      // Hitta kategorin
      final categoryIndex =
          _categories.indexWhere((cat) => cat.id == categoryId);
      if (categoryIndex == -1) {
        _setError('Kategorien hittades inte');
        return false;
      }

      final category = _categories[categoryIndex];

      // Kontrollera att vännen finns i kategorin
      if (!category.friendUserIds.contains(friendUserId)) {
        _setError('Användaren är inte medlem i denna grupp');
        return false;
      }

      // Skapa uppdaterad kategori utan den borttagna vännen
      final updatedFriendIds = List<String>.from(category.friendUserIds)
        ..remove(friendUserId);

      final updatedCategory = category.copyWith(
        friendUserIds: updatedFriendIds,
        friendCount: updatedFriendIds.length,
        updatedAt: DateTime.now(),
      );

      await _friendsRepository.updateCategory(
        userId,
        categoryId,
        updatedCategory.toFirestore(),
      );

      // Uppdatera lokal cache
      _categories[categoryIndex] = updatedCategory;

      // Uppdatera friend cache för kategorin
      if (updatedCategory.isNotEmpty) {
        await _loadFriendsForCategory(categoryId);
      } else {
        _categoryFriends[categoryId] = [];
      }

      AppLogger.success('✅ Vän borttagen från kategori framgångsrikt');
      notifyListeners();
      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('❌ Kunde inte ta bort vän från kategori', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Lägg till en vän till en kategori/grupp
  Future<bool> addFriendToCategory(
      String categoryId, String friendUserId) async {
    try {
      _setLoading(true);
      _clearError();

      AppLogger.info(
          '🔄 Lägger till vän $friendUserId till kategori $categoryId');

      // Hitta kategorin
      final categoryIndex =
          _categories.indexWhere((cat) => cat.id == categoryId);
      if (categoryIndex == -1) {
        _setError('Kategorien hittades inte');
        return false;
      }

      final category = _categories[categoryIndex];

      // Kontrollera att vännen inte redan finns i kategorin
      if (category.friendUserIds.contains(friendUserId)) {
        _setError('Användaren är redan medlem i denna grupp');
        return false;
      }

      // Skapa uppdaterad kategori med den nya vännen
      final updatedFriendIds = List<String>.from(category.friendUserIds)
        ..add(friendUserId);

      final updatedCategory = category.copyWith(
        friendUserIds: updatedFriendIds,
        friendCount: updatedFriendIds.length,
        updatedAt: DateTime.now(),
      );

      // ✅ FIXAT: Uppdatera i user-specific subcollection
      await _friendsRepository.updateCategory(
        userId,
        categoryId,
        updatedCategory.toFirestore(),
      );

      // Uppdatera lokal cache
      _categories[categoryIndex] = updatedCategory;

      // Uppdatera friend cache för kategorin
      await _loadFriendsForCategory(categoryId);

      AppLogger.success('✅ Vän tillagd till kategori framgångsrikt');
      notifyListeners();
      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('❌ Kunde inte lägga till vän till kategori', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Kontrollera om användaren är admin för en kategori
  bool isUserAdminOfCategory(String categoryId, String userId) {
    final category = getCategoryById(categoryId);
    return category?.createdBy == userId;
  }

  /// Kontrollera om användaren är medlem i en kategori
  bool isUserMemberOfCategory(String categoryId, String userId) {
    final category = getCategoryById(categoryId);
    return category?.friendUserIds.contains(userId) ?? false;
  }

  /// Hämta alla kategorier där användaren är admin
  List<FriendCategory> getCategoriesWhereUserIsAdmin(String userId) {
    return _categories.where((cat) => cat.createdBy == userId).toList();
  }

  /// Hämta alla kategorier där användaren är medlem (men inte admin)
  List<FriendCategory> getCategoriesWhereUserIsMember(String userId) {
    return _categories
        .where((cat) =>
            cat.friendUserIds.contains(userId) && cat.createdBy != userId)
        .toList();
  }

  @override
  void dispose() {
    AppLogger.info('🗑️ FriendCategoriesService disposing...');
    _clearAll();
    super.dispose();
  }
}

/// Helper class för kategori-statistik
class CategoryStats {
  final String categoryId;
  final String name;
  final int friendCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? emoji;

  CategoryStats({
    required this.categoryId,
    required this.name,
    required this.friendCount,
    required this.createdAt,
    required this.updatedAt,
    this.emoji,
  });

  factory CategoryStats.fromCategory(FriendCategory category) {
    return CategoryStats(
      categoryId: category.id,
      name: category.name,
      friendCount: category.friendCount,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
      emoji: category.emoji,
    );
  }

  /// Formaterad visning av statistik
  String get formattedSummary {
    return '$name: $friendCount ${friendCount == 1 ? 'vän' : 'vänner'}';
  }

  /// Hur länge sedan kategorin uppdaterades
  String get timeSinceUpdate {
    final now = DateTime.now();
    final difference = now.difference(updatedAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} dagar sedan';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} timmar sedan';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minuter sedan';
    } else {
      return 'Just nu';
    }
  }
}

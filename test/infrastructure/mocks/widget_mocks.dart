import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/viewmodels/social/activity_feed_viewmodel.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import '../factories/recipe_factory.dart';

/// Base mock for ViewModels with ChangeNotifier support
class MockBaseViewModel extends Mock implements BaseViewModel {
  final List<VoidCallback> _listeners = [];
  bool _isDisposed = false;
  bool _isBusy = false;
  String? _errorMessage;

  bool get isBusy => _isBusy;

  String? get errorMessage => _errorMessage;

  @override
  bool get hasError => _errorMessage != null;

  @override
  bool get isDisposed => _isDisposed;

  @override
  void addListener(VoidCallback listener) {
    if (!_isDisposed) {
      _listeners.add(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      for (final listener in List.from(_listeners)) {
        listener();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _listeners.clear();
  }

  @override
  bool get hasListeners => _listeners.isNotEmpty;

  // Helper methods for testing
  void setLoadingState(bool loading) {
    _isBusy = loading;
    notifyListeners();
  }

  void setErrorState(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  @override
  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }
}

/// Mock for AuthViewModel
class MockAuthViewModel extends MockBaseViewModel implements AuthViewModel {
  bool _isAuthenticated = false;
  String? _currentUserId;
  String? _userEmail;

  @override
  bool get isAuthenticated => _isAuthenticated;

  String? get currentUserId => _currentUserId;

  String? get userEmail => _userEmail;

  void setAuthState({
    bool isAuthenticated = false,
    String? userId,
    String? email,
  }) {
    _isAuthenticated = isAuthenticated;
    _currentUserId = userId;
    _userEmail = email;
    notifyListeners();
  }
}

/// Mock for RecipeListViewModel
class MockRecipeListViewModel extends MockBaseViewModel
    implements RecipeListViewModel {
  List<Recipe> _recipes = [];
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  List<Recipe> get recipes => _recipes;

  @override
  String get searchQuery => _searchQuery;

  @override
  bool get isLoading => _isLoading;

  void setRecipeListState({
    List<Recipe>? recipes,
    String? searchQuery,
    bool? isLoading,
  }) {
    if (recipes != null) _recipes = recipes;
    if (searchQuery != null) _searchQuery = searchQuery;
    if (isLoading != null) _isLoading = isLoading;
    notifyListeners();
  }
}

/// Mock for RecipeDetailViewModel
class MockRecipeDetailViewModel extends MockBaseViewModel
    implements RecipeDetailViewModel {
  Recipe? _recipe;
  bool _isLoading = false;

  @override
  Recipe get recipe => _recipe ?? RecipeFactory.build();

  @override
  bool get isLoading => _isLoading;

  void setRecipeDetailState({
    Recipe? recipe,
    bool? isLoading,
  }) {
    if (recipe != null) _recipe = recipe;
    if (isLoading != null) _isLoading = isLoading;
    notifyListeners();
  }
}

/// Mock for RecipeFormViewModel
class MockRecipeFormViewModel extends MockBaseViewModel
    implements RecipeFormViewModel {
  Recipe? _recipe;
  bool _isLoading = false;
  String? _editMode;
  EditMode? _editModeEnum;

  @override
  Recipe? get recipe => _recipe;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get editMode => _editMode;

  @override
  EditMode? get editModeEnum => _editModeEnum;

  void setRecipeFormState({
    Recipe? recipe,
    bool? isLoading,
    String? editMode,
    EditMode? editModeEnum,
  }) {
    if (recipe != null) _recipe = recipe;
    if (isLoading != null) _isLoading = isLoading;
    if (editMode != null) _editMode = editMode;
    if (editModeEnum != null) _editModeEnum = editModeEnum;
    notifyListeners();
  }
}

/// Mock for UnifiedShoppingViewModel
class MockUnifiedShoppingViewModel extends MockBaseViewModel
    implements UnifiedShoppingViewModel {
  List<UnifiedShoppingList> _shoppingLists = [];
  bool _isLoading = false;

  List<UnifiedShoppingList> get shoppingLists => _shoppingLists;

  @override
  bool get isLoading => _isLoading;

  void setShoppingState({
    List<UnifiedShoppingList>? lists,
    bool? isLoading,
  }) {
    if (lists != null) _shoppingLists = lists;
    if (isLoading != null) _isLoading = isLoading;
    notifyListeners();
  }
}

/// Mock for MenuViewModel
class MockMenuViewModel extends MockBaseViewModel implements MenuViewModel {
  bool _isLoading = false;

  @override
  bool get isLoading => _isLoading;

  void setMenuState({
    bool? isLoading,
  }) {
    if (isLoading != null) _isLoading = isLoading;
    notifyListeners();
  }
}

/// Mock for UserProfileViewModel
class MockUserProfileViewModel extends MockBaseViewModel
    implements UserProfileViewModel {
  UserProfile? _userProfile;
  bool _isLoading = false;
  String _displayName = 'Test Användare';
  String? _avatarUrl;
  bool _isSearchable = true;
  bool _allowEmailSearch = false;
  bool _hasUnsavedChanges = false;
  bool _isUploadingAvatar = false;
  String? _displayNameError;
  String? _error;
  bool _hasProfile = true;
  bool _isFormValid = true;
  CookingSkillLevel? _cookingSkillLevel;
  List<String> _cuisineAffinities = [];
  String _bio = '';

  // UserProfileViewModel interface implementation

  @override
  String get displayName => _displayName;

  @override
  String? get avatarUrl => _avatarUrl;

  @override
  bool get isSearchable => _isSearchable;

  @override
  bool get allowEmailSearch => _allowEmailSearch;

  @override
  CookingSkillLevel? get cookingSkillLevel => _cookingSkillLevel;

  @override
  List<String> get cuisineAffinities => List.unmodifiable(_cuisineAffinities);

  @override
  String get bio => _bio;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get isUploadingAvatar => _isUploadingAvatar;

  @override
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  @override
  String? get displayNameError => _displayNameError;

  @override
  String? get error => _error ?? _displayNameError;

  @override
  bool get hasError => _error != null || _displayNameError != null;

  @override
  UserProfile? get currentProfile => _userProfile;

  @override
  bool get hasProfile => _hasProfile;

  @override
  bool get isFormValid => _isFormValid;

  // Mock methods for UserProfileViewModel interface

  @override
  void updateDisplayName(String value) {
    _displayName = value.trim();
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  @override
  void updateIsSearchable(bool value) {
    _isSearchable = value;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  @override
  void updateAllowEmailSearch(bool value) {
    _allowEmailSearch = value;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  @override
  void updateCookingSkillLevel(CookingSkillLevel? value) {
    _cookingSkillLevel = value;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  @override
  bool toggleCuisineAffinity(String cuisine) {
    if (_cuisineAffinities.contains(cuisine)) {
      _cuisineAffinities.remove(cuisine);
    } else {
      if (_cuisineAffinities.length >= 5) return false;
      _cuisineAffinities.add(cuisine);
    }
    _hasUnsavedChanges = true;
    notifyListeners();
    return true;
  }

  @override
  void updateBio(String value) {
    _bio = value.trim();
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  @override
  Future<bool> uploadAvatar() async {
    _isUploadingAvatar = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 100));

    _isUploadingAvatar = false;
    _avatarUrl = 'https://example.com/test-avatar.jpg';
    _hasUnsavedChanges = true;
    notifyListeners();

    return true;
  }

  @override
  void removeAvatar() {
    _avatarUrl = null;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  @override
  Future<bool> saveProfile() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 100));

    _isLoading = false;
    _hasUnsavedChanges = false;
    notifyListeners();

    return true;
  }

  @override
  void resetForm() {
    _displayName = 'Test Användare';
    _isSearchable = true;
    _allowEmailSearch = false;
    _hasUnsavedChanges = false;
    _displayNameError = null;
    _error = null;
    _cookingSkillLevel = null;
    _cuisineAffinities = [];
    _bio = '';
    notifyListeners();
  }

  @override
  Future<bool> checkDisplayNameAvailability() async {
    await Future.delayed(const Duration(milliseconds: 100));

    if (_displayName.toLowerCase().contains('taken')) {
      _displayNameError = 'Detta namn är redan taget';
      notifyListeners();
      return false;
    }

    _displayNameError = null;
    notifyListeners();
    return true;
  }

  @override
  void clearError() {
    _error = null;
    _displayNameError = null;
    notifyListeners();
  }

  // Test helper methods

  void setUserProfileState({
    UserProfile? profile,
    bool? isLoading,
    String? error,
    String? displayName,
    String? avatarUrl,
    bool? isSearchable,
    bool? allowEmailSearch,
    bool? hasUnsavedChanges,
    bool? isUploadingAvatar,
    String? displayNameError,
    bool? hasProfile,
    bool? isFormValid,
    CookingSkillLevel? cookingSkillLevel,
    List<String>? cuisineAffinities,
    String? bio,
  }) {
    if (profile != null) _userProfile = profile;
    if (isLoading != null) _isLoading = isLoading;
    if (error != null) _error = error;
    if (displayName != null) _displayName = displayName;
    if (avatarUrl != null) _avatarUrl = avatarUrl;
    if (isSearchable != null) _isSearchable = isSearchable;
    if (allowEmailSearch != null) _allowEmailSearch = allowEmailSearch;
    if (hasUnsavedChanges != null) _hasUnsavedChanges = hasUnsavedChanges;
    if (isUploadingAvatar != null) _isUploadingAvatar = isUploadingAvatar;
    if (displayNameError != null) _displayNameError = displayNameError;
    if (hasProfile != null) _hasProfile = hasProfile;
    if (isFormValid != null) _isFormValid = isFormValid;
    if (cookingSkillLevel != null) _cookingSkillLevel = cookingSkillLevel;
    if (cuisineAffinities != null) _cuisineAffinities = cuisineAffinities;
    if (bio != null) _bio = bio;
    notifyListeners();
  }
}

/// Mock for FriendsViewModel
class MockFriendsViewModel extends MockBaseViewModel
    implements FriendsViewModel {
  List<UserProfile> _friends = [];
  bool _isLoading = false;

  @override
  List<UserProfile> get friends => _friends;

  @override
  bool get isLoading => _isLoading;

  void setFriendsState({
    List<UserProfile>? friends,
    bool? isLoading,
    String? error,
  }) {
    if (friends != null) _friends = friends;
    if (isLoading != null) _isLoading = isLoading;
    if (error != null) _errorMessage = error;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {
    // Mock implementation - just return completed future
    return Future.value();
  }
}

/// Mock for ActivityFeedViewModel
class MockActivityFeedViewModel extends MockBaseViewModel
    implements ActivityFeedViewModel {
  List<ActivityEvent> _events = const [];
  bool _hasMore = false;
  ActivityEventType? _filter;

  @override
  List<ActivityEvent> get events => _events;

  @override
  List<ActivityEvent> get filteredEvents => _filter == null
      ? _events
      : _events.where((e) => e.type == _filter).toList();

  @override
  bool get hasMore => _hasMore;

  @override
  ActivityEventType? get filter => _filter;

  @override
  Future<void> loadFeed() async => Future.value();

  @override
  Future<void> loadMore() async => Future.value();

  @override
  Future<void> refresh() async => Future.value();

  @override
  void setFilter(ActivityEventType? type) {
    _filter = type;
    notifyListeners();
  }

  void setFeedState({
    List<ActivityEvent>? events,
    bool? hasMore,
    ActivityEventType? filter,
  }) {
    if (events != null) _events = events;
    if (hasMore != null) _hasMore = hasMore;
    if (filter != null) _filter = filter;
    notifyListeners();
  }
}

/// Mock for SocialRecipeViewModel
class MockSocialRecipeViewModel extends Mock implements SocialRecipeViewModel {
  final List<VoidCallback> _listeners = [];
  bool _isDisposed = false;
  bool _isLoading = false;
  bool _isLoadingComments = false;
  int _commentCount = 0;

  bool get isLoading => _isLoading;

  @override
  bool get isLoadingComments => _isLoadingComments;

  @override
  int get commentCount => _commentCount;

  bool get isDisposed => _isDisposed;

  @override
  void addListener(VoidCallback listener) {
    if (!_isDisposed) {
      _listeners.add(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      for (final listener in List.from(_listeners)) {
        listener();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _listeners.clear();
  }

  @override
  bool get hasListeners => _listeners.isNotEmpty;

  void setSocialRecipeState({
    bool? isLoading,
    bool? isLoadingComments,
    int? commentCount,
  }) {
    if (isLoading != null) _isLoading = isLoading;
    if (isLoadingComments != null) _isLoadingComments = isLoadingComments;
    if (commentCount != null) _commentCount = commentCount;
    notifyListeners();
  }
}

/// Helper class to create pre-configured mock ViewModels
class WidgetMockFactory {
  /// Create a mock auth view model with default logged-in state
  static MockAuthViewModel createMockAuthViewModel({
    bool isAuthenticated = true,
    String? userId = 'test-user-123',
    String? email = 'test@example.com',
  }) {
    final mock = MockAuthViewModel();
    mock.setAuthState(
      isAuthenticated: isAuthenticated,
      userId: userId,
      email: email,
    );
    return mock;
  }

  /// Create a mock recipe list view model with sample recipes
  static MockRecipeListViewModel createMockRecipeListViewModel({
    List<Recipe>? recipes,
    bool isLoading = false,
    String? searchQuery,
  }) {
    final mock = MockRecipeListViewModel();
    mock.setRecipeListState(
      recipes: recipes ?? [],
      isLoading: isLoading,
      searchQuery: searchQuery ?? '',
    );
    return mock;
  }

  /// Create a mock recipe detail view model
  static MockRecipeDetailViewModel createMockRecipeDetailViewModel({
    Recipe? recipe,
    bool isLoading = false,
  }) {
    final mock = MockRecipeDetailViewModel();
    mock.setRecipeDetailState(
      recipe: recipe ?? RecipeFactory.build(),
      isLoading: isLoading,
    );
    return mock;
  }

  /// Create a mock shopping view model with sample lists
  static MockUnifiedShoppingViewModel createMockShoppingViewModel({
    List<UnifiedShoppingList>? lists,
    bool isLoading = false,
  }) {
    final mock = MockUnifiedShoppingViewModel();
    mock.setShoppingState(
      lists: lists ?? [],
      isLoading: isLoading,
    );
    return mock;
  }

  /// Create test recipes with various configurations
  static List<Recipe> createTestRecipes({int count = 3}) {
    return List.generate(
      count,
      (index) => RecipeFactory.build(
        id: 'recipe_$index',
        title: 'Testrätt ${index + 1}',
        description: 'En läcker svensk maträtt nummer ${index + 1}',
        ingredients: [
          'Ingrediens ${index * 2 + 1}',
          'Ingrediens ${index * 2 + 2}'
        ],
        instructions: [
          'Steg 1 för recept ${index + 1}',
          'Steg 2 för recept ${index + 1}'
        ],
        mealType: index % 2 == 0 ? 'Lunch' : 'Middag',
        portions: 4 + index,
        timeMinutes: 30 + (index * 10),
        rating: 3.5 + (index * 0.5),
        personalTagIds: ['svensk', 'vardagsmat'],
        imageUrls: index == 0 ? [] : ['https://example.com/image_$index.jpg'],
      ),
    );
  }

  /// Create test shopping lists with various configurations
  static List<UnifiedShoppingList> createTestShoppingLists({int count = 2}) {
    return List.generate(
      count,
      (index) => UnifiedShoppingList(
        id: 'list_$index',
        name: 'Inköpslista ${index + 1}',
        ownerId: 'test_user_123',
        ownerDisplayName: 'Test Användare',
        items: List.generate(
          3 + index,
          (itemIndex) => UnifiedShoppingItem(
            id: 'item_${index}_$itemIndex',
            name: 'Vara ${itemIndex + 1}',
            amount: 1.0 + itemIndex,
            unit: itemIndex % 2 == 0 ? 'st' : 'kg',
            bought: itemIndex == 0,
            category: itemIndex % 3 == 0
                ? 'Mejeri'
                : itemIndex % 3 == 1
                    ? 'Frukt & Grönt'
                    : 'Skafferi',
          ),
        ),
        createdAt: DateTime.now().subtract(Duration(days: index)),
        updatedAt: DateTime.now(),
        type: index == 1 ? ListType.collaborative : ListType.personal,
        memberPermissions: index == 1
            ? {
                'user_2': SharedListPermission.edit,
                'user_3': SharedListPermission.view
              }
            : {},
      ),
    );
  }

  /// Create a test user profile
  static UserProfile createTestUserProfile({
    String? id,
    String? displayName,
    String? email,
    String? avatarUrl,
  }) {
    return UserProfile(
      uid: id ?? 'test_user_123',
      displayName: displayName ?? 'Test Användare',
      email: email ?? 'test@example.com',
      avatarUrl: avatarUrl,
      joinedAt: DateTime.now().subtract(const Duration(days: 30)),
      lastActiveAt: DateTime.now(),
      fcmToken: 'token_1',
      notificationsEnabled: true,
    );
  }
}

/// Comprehensive realtime menu model providing advanced collaborative meal planning and recipe organization.
/// This model implements sophisticated collaborative menu management following Single Responsibility Principle,
/// handling all aspects of realtime menu collaboration including category-based recipe organization, participant
/// management, menu analytics, and comprehensive UI integration. It provides complete collaborative menu
/// infrastructure while maintaining clean separation from UI concerns and business logic implementation.

// lib/models/realtime/realtime_menu.dart

// ✅ Firebase DocumentSnapshot dependency abstracted to repository layer
// Note: Use fromData() constructor - repositories handle Firebase specifics
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/models/realtime/realtime_menu_operations.dart';
import 'package:butlery/models/realtime/realtime_menu_analytics.dart';
import 'package:butlery/models/realtime/realtime_menu_factory.dart';

/// Comprehensive realtime menu model with collaborative meal planning and recipe organization delegation.
/// Represents a complete collaborative menu with category-based recipe organization, participant management,
/// and comprehensive analytics through focused component delegation. This class serves as the orchestration
/// layer for all collaborative menu features while maintaining clean separation of concerns.
class RealtimeMenu extends RealtimeResource {
  /// Core menu data component providing pure data representation without business logic contamination.
  /// Contains the fundamental menu structure including categories, recipes, metadata, and temporal information
  /// while delegating to specialized data handling for clean separation of concerns and focused responsibility.
  /// Used internally for data operations and serialization through delegation pattern.
  final RealtimeMenuData _data;

  /// Creates a new realtime menu with comprehensive collaborative configuration and component delegation.
  /// This constructor provides complete menu initialization with delegation to specialized components
  /// for data management, operations, and analytics while maintaining clean separation of concerns
  /// and focused responsibility distribution throughout the collaborative menu architecture.
  RealtimeMenu({
    required super.id,
    required super.ownerId,
    required super.ownerDisplayName,
    required super.participants,
    super.createdAt,
    super.lastEditedAt,
    required super.lastEditedBy,
    required super.lastEditedByDisplayName,
    super.editCount,
    super.isActive,
    super.metadata,
    required RealtimeMenuData data,
  })  : _data = data,
        super(
          type: RealtimeResourceType.menu,
        );

  /// Factory constructors for simplified menu creation with specialized initialization patterns.

  /// Creates a new realtime menu from existing menu categories structure with collaborative setup.
  factory RealtimeMenu.fromMenuCategories({
    required String menuTitle,
    required Map<String, List<Recipe>> menuSnapshot,
    required String ownerId,
    required String ownerDisplayName,
    List<String>? editorUserIds,
    List<String>? viewerUserIds,
    String? menuNotes,
    List<String>? favoriteRecipeIds,
    String? originalPrompt,
    DateTime? createdForDate,
  }) {
    final params = RealtimeMenuFactory.createFromMenuCategories(
      menuTitle: menuTitle,
      menuSnapshot: menuSnapshot,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      editorUserIds: editorUserIds,
      viewerUserIds: viewerUserIds,
      menuNotes: menuNotes,
      favoriteRecipeIds: favoriteRecipeIds,
      originalPrompt: originalPrompt,
      createdForDate: createdForDate,
    );

    return RealtimeMenu(
      id: params['id'] as String,
      ownerId: params['ownerId'] as String,
      ownerDisplayName: params['ownerDisplayName'] as String,
      participants: params['participants'] as Map<String, ResourcePermission>,
      lastEditedBy: params['lastEditedBy'] as String,
      lastEditedByDisplayName: params['lastEditedByDisplayName'] as String,
      data: params['data'] as RealtimeMenuData,
    );
  }

  /// Creates a realtime menu instance from repository data with complete parsing and validation.
  /// @deprecated Firebase-specific constructor. Repositories should use fromData() instead.
  /// This maintains backward compatibility while repositories are updated.
  factory RealtimeMenu.fromRepositoryData(String id, Map<String, dynamic> data) {
    final params = RealtimeMenuFactory.parseRepositoryData(id, data);

    return RealtimeMenu(
      id: params['id'] as String,
      ownerId: params['ownerId'] as String,
      ownerDisplayName: params['ownerDisplayName'] as String,
      participants: params['participants'] as Map<String, ResourcePermission>,
      createdAt: params['createdAt'] as DateTime,
      lastEditedAt: params['lastEditedAt'] as DateTime,
      lastEditedBy: params['lastEditedBy'] as String,
      lastEditedByDisplayName: params['lastEditedByDisplayName'] as String,
      editCount: params['editCount'] as int,
      isActive: params['isActive'] as bool,
      metadata: params['metadata'] as Map<String, dynamic>,
      data: params['data'] as RealtimeMenuData,
    );
  }
  
  /// Preferred factory constructor from clean data
  /// Repositories should provide DateTime objects and clean Map data,
  /// eliminating Firebase-specific types from the model layer.
  factory RealtimeMenu.fromData({
    required String id,
    required String ownerId,
    required String ownerDisplayName,
    required Map<String, ResourcePermission> participants,
    required DateTime createdAt,
    required DateTime lastEditedAt,
    required String lastEditedBy,
    required String lastEditedByDisplayName,
    required RealtimeMenuData data,
    int editCount = 0,
    bool isActive = true,
    Map<String, dynamic> metadata = const {},
  }) {
    return RealtimeMenu(
      id: id,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      participants: participants,
      createdAt: createdAt,
      lastEditedAt: lastEditedAt,
      lastEditedBy: lastEditedBy,
      lastEditedByDisplayName: lastEditedByDisplayName,
      editCount: editCount,
      isActive: isActive,
      metadata: metadata,
      data: data,
    );
  }

  /// Creates a realtime menu instance from JSON data for caching and client-side deserialization.
  factory RealtimeMenu.fromJson(Map<String, dynamic> json) {
    final params = RealtimeMenuFactory.parseJsonData(json);

    return RealtimeMenu(
      id: params['id'] as String,
      ownerId: params['ownerId'] as String,
      ownerDisplayName: params['ownerDisplayName'] as String,
      participants: params['participants'] as Map<String, ResourcePermission>,
      createdAt: params['createdAt'] as DateTime,
      lastEditedAt: params['lastEditedAt'] as DateTime,
      lastEditedBy: params['lastEditedBy'] as String,
      lastEditedByDisplayName: params['lastEditedByDisplayName'] as String,
      editCount: params['editCount'] as int,
      isActive: params['isActive'] as bool,
      metadata: params['metadata'] as Map<String, dynamic>,
      data: params['data'] as RealtimeMenuData,
    );
  }

  /// Data access properties for menu content through delegation to specialized data component.

  /// Gets the menu title through delegation to data component for clean separation.
  String get menuTitle => _data.menuTitle;

  /// Gets the menu creation target date through delegation to data component.
  DateTime get createdForDate => _data.createdForDate;

  /// Gets the complete category-recipe mapping through delegation to data component.
  Map<String, List<Recipe>> get menuSnapshot => _data.menuSnapshot;

  /// Gets optional menu notes through delegation to data component.
  String? get menuNotes => _data.menuNotes;

  /// Gets optional favorite recipe IDs through delegation to data component.
  List<String>? get favoriteRecipeIds => _data.favoriteRecipeIds;

  /// Gets optional original generation prompt through delegation to data component.
  String? get originalPrompt => _data.originalPrompt;

  /// Gets all menu categories through delegation to data component.
  List<String> get categories => _data.categories;

  /// Gets all unique recipes across categories through delegation to data component.
  List<Recipe> get allUniqueRecipes => _data.allUniqueRecipes;

  // ===== MENU OPERATIONS (DELEGATE TO OPERATIONS) =====

  /// Update basic menu information
  RealtimeMenu updateBasicInfo({
    String? menuTitle,
    DateTime? createdForDate,
    String? menuNotes,
    List<String>? favoriteRecipeIds,
    String? originalPrompt,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedData = _data.copyWith(
      menuTitle: menuTitle,
      createdForDate: createdForDate,
      menuNotes: menuNotes,
      favoriteRecipeIds: favoriteRecipeIds,
      originalPrompt: originalPrompt,
    );

    return _copyWithUpdatedData(
      data: updatedData,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Add recipe to specific category
  RealtimeMenu addRecipeToCategory({
    required String categoryName,
    required Recipe recipe,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedData = RealtimeMenuOperations.addRecipeToCategory(
      _data,
      categoryName: categoryName,
      recipe: recipe,
    );

    return _copyWithUpdatedData(
      data: updatedData,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Remove recipe from specific category
  RealtimeMenu removeRecipeFromCategory({
    required String categoryName,
    required int recipeIndex,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedData = RealtimeMenuOperations.removeRecipeFromCategory(
      _data,
      categoryName: categoryName,
      recipeIndex: recipeIndex,
    );

    return _copyWithUpdatedData(
      data: updatedData,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Move recipe between categories
  RealtimeMenu moveRecipeBetweenCategories({
    required String fromCategory,
    required int fromIndex,
    required String toCategory,
    int? toIndex,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedData = RealtimeMenuOperations.moveRecipeBetweenCategories(
      _data,
      fromCategory: fromCategory,
      fromIndex: fromIndex,
      toCategory: toCategory,
      toIndex: toIndex,
    );

    return _copyWithUpdatedData(
      data: updatedData,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Replace recipe in category
  RealtimeMenu replaceRecipeInCategory({
    required String categoryName,
    required int recipeIndex,
    required Recipe newRecipe,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedData = RealtimeMenuOperations.replaceRecipeInCategory(
      _data,
      categoryName: categoryName,
      recipeIndex: recipeIndex,
      newRecipe: newRecipe,
    );

    return _copyWithUpdatedData(
      data: updatedData,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Clear all recipes from category
  RealtimeMenu clearCategory({
    required String categoryName,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedData = RealtimeMenuOperations.clearCategory(
      _data,
      categoryName: categoryName,
    );

    return _copyWithUpdatedData(
      data: updatedData,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Update whole category with new recipes
  RealtimeMenu updateWholeCategory({
    required String categoryName,
    required List<Recipe> recipes,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedData = RealtimeMenuOperations.updateWholeCategory(
      _data,
      categoryName: categoryName,
      recipes: recipes,
    );

    return _copyWithUpdatedData(
      data: updatedData,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Regenerate category with new recipes
  RealtimeMenu regenerateCategory({
    required String categoryName,
    required List<Recipe> newRecipes,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedData = RealtimeMenuOperations.regenerateCategory(
      _data,
      categoryName: categoryName,
      newRecipes: newRecipes,
    );

    return _copyWithUpdatedData(
      data: updatedData,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  // ===== STATISTICS (DELEGATE TO OPERATIONS) =====

  /// Common menu categories
  static List<String> get commonCategories => RealtimeMenuOperations.commonCategories;

  /// Categories sorted in logical order
  List<String> get categoriesSorted => RealtimeMenuOperations.getCategoriesSorted(_data);

  /// Total number of recipes in entire menu
  int get totalRecipeCount => RealtimeMenuOperations.getTotalRecipeCount(_data);

  /// Number of categories that have recipes
  int get categoriesWithRecipes => RealtimeMenuOperations.getCategoriesWithRecipes(_data);

  /// Number of empty categories
  int get emptyCategoriesCount => RealtimeMenuOperations.getEmptyCategoriesCount(_data);

  /// Is menu complete? (has recipes in at least 2 categories)
  bool get isComplete => RealtimeMenuOperations.isComplete(_data);

  /// Is menu well balanced? (has recipes in at least 3 categories)
  bool get isWellBalanced => RealtimeMenuOperations.isWellBalanced(_data);

  /// Get average number of recipes per category
  double get averageRecipesPerCategory => RealtimeMenuOperations.getAverageRecipesPerCategory(_data);

  /// Check if menu has favorites defined
  bool get hasFavorites => RealtimeMenuOperations.hasFavorites(_data);

  /// Number of favorite recipes
  int get favoritesCount => RealtimeMenuOperations.getFavoritesCount(_data);

  /// Check if menu has notes
  bool get hasNotes => RealtimeMenuOperations.hasNotes(_data);

  /// Check if menu was generated from prompt
  bool get wasGenerated => RealtimeMenuOperations.wasGenerated(_data);

  /// Menu summary for UI
  String get menuSummary => RealtimeMenuOperations.getMenuSummary(_data);

  /// Get menu completion percentage
  double get completionPercentage => RealtimeMenuOperations.getCompletionPercentage(_data);

  /// Get completion status text
  String get completionStatus => RealtimeMenuOperations.getCompletionStatus(_data);

  // ===== DATA ACCESS METHODS (DELEGATE TO DATA) =====

  /// Get recipes for specific category
  List<Recipe> getRecipesForCategory(String categoryName) => _data.getRecipesForCategory(categoryName);

  /// Check if category has recipes
  bool categoryHasRecipes(String categoryName) => _data.categoryHasRecipes(categoryName);

  /// Convert to MenuViewModel format
  Map<String, List<Recipe>> toMenuViewModelFormat() => _data.toMenuViewModelFormat();

  /// Check if menu contains a specific recipe
  bool containsRecipe(String recipeId) => _data.containsRecipe(recipeId);

  /// Find which category a recipe belongs to
  String? findRecipeCategory(String recipeId) => _data.findRecipeCategory(recipeId);

  /// Create a personal copy of the menu
  Map<String, List<Recipe>> createPersonalMenuCopy() {
    return RealtimeMenuOperations.createPersonalMenuCopy(_data, ownerDisplayName);
  }

  // ===== SEARCH AND ANALYTICS (DELEGATE TO ANALYTICS) =====

  /// Search recipes in menu
  List<Recipe> searchRecipes(String query) => RealtimeMenuAnalytics.searchRecipes(_data, query);

  /// Advanced recipe search
  List<Recipe> searchRecipesAdvanced({
    String? query,
    String? mealType,
    List<String>? tags,
    int? maxTimeMinutes,
    int? minPortions,
    int? maxPortions,
    double? minRating,
  }) => RealtimeMenuAnalytics.searchRecipesAdvanced(
    _data,
    query: query,
    mealType: mealType,
    tags: tags,
    maxTimeMinutes: maxTimeMinutes,
    minPortions: minPortions,
    maxPortions: maxPortions,
    minRating: minRating,
  );

  /// Filter menu by specific meal type
  Map<String, List<Recipe>> filterByMealType(String mealType) => 
      RealtimeMenuAnalytics.filterByMealType(_data, mealType);

  /// Filter menu by max cooking time
  Map<String, List<Recipe>> filterByMaxTime(int maxMinutes) => 
      RealtimeMenuAnalytics.filterByMaxTime(_data, maxMinutes);

  /// Filter menu by minimum rating
  Map<String, List<Recipe>> filterByMinRating(double minRating) => 
      RealtimeMenuAnalytics.filterByMinRating(_data, minRating);

  /// Filter menu by tags
  Map<String, List<Recipe>> filterByTags(List<String> requiredTags) => 
      RealtimeMenuAnalytics.filterByTags(_data, requiredTags);

  /// Get healthiness score
  double get healthinessScore => RealtimeMenuAnalytics.getHealthinessScore(_data);

  // ===== PARTICIPANT MANAGEMENT (OVERRIDE FROM REALTIMERESOURCE) =====

  @override
  RealtimeMenu addParticipant(
    String userId,
    String userDisplayName,
    ResourcePermission permission,
  ) {
    final updatedParticipants = Map<String, ResourcePermission>.from(participants);
    updatedParticipants[userId] = permission;

    return copyWithMetadata(
      participants: updatedParticipants,
      lastEditedAt: DateTime.now(),
      lastEditedBy: ownerId,
      lastEditedByDisplayName: ownerDisplayName,
      editCount: editCount + 1,
    );
  }

  @override
  RealtimeMenu removeParticipant(String userId) {
    if (userId == ownerId) {
      throw ArgumentError('Cannot remove owner from menu');
    }

    final updatedParticipants = Map<String, ResourcePermission>.from(participants);
    updatedParticipants.remove(userId);

    return copyWithMetadata(
      participants: updatedParticipants,
      lastEditedAt: DateTime.now(),
      lastEditedBy: ownerId,
      lastEditedByDisplayName: ownerDisplayName,
      editCount: editCount + 1,
    );
  }

  @override
  RealtimeMenu updateParticipantPermission(
    String userId,
    ResourcePermission newPermission,
  ) {
    if (userId == ownerId && newPermission != ResourcePermission.owner) {
      throw ArgumentError('Owner must maintain owner permission');
    }

    final updatedParticipants = Map<String, ResourcePermission>.from(participants);
    updatedParticipants[userId] = newPermission;

    return copyWithMetadata(
      participants: updatedParticipants,
      lastEditedAt: DateTime.now(),
      lastEditedBy: ownerId,
      lastEditedByDisplayName: ownerDisplayName,
      editCount: editCount + 1,
    );
  }

  // ===== COPY METHODS =====

  @override
  RealtimeMenu copyWithMetadata({
    Map<String, ResourcePermission>? participants,
    DateTime? lastEditedAt,
    String? lastEditedBy,
    String? lastEditedByDisplayName,
    int? editCount,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return RealtimeMenu(
      id: id,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      participants: participants ?? this.participants,
      createdAt: createdAt,
      lastEditedAt: lastEditedAt ?? DateTime.now(),
      lastEditedBy: lastEditedBy ?? this.lastEditedBy,
      lastEditedByDisplayName: lastEditedByDisplayName ?? this.lastEditedByDisplayName,
      editCount: editCount ?? (this.editCount + 1),
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      data: _data,
    );
  }

  /// Create copy with updated menu data and metadata
  RealtimeMenu copyWith({
    String? menuTitle,
    DateTime? createdForDate,
    Map<String, List<Recipe>>? menuSnapshot,
    String? menuNotes,
    List<String>? favoriteRecipeIds,
    String? originalPrompt,
    Map<String, ResourcePermission>? participants,
    DateTime? lastEditedAt,
    String? lastEditedBy,
    String? lastEditedByDisplayName,
    int? editCount,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    final updatedData = _data.copyWith(
      menuTitle: menuTitle,
      createdForDate: createdForDate,
      menuSnapshot: menuSnapshot,
      menuNotes: menuNotes,
      favoriteRecipeIds: favoriteRecipeIds,
      originalPrompt: originalPrompt,
    );

    return RealtimeMenu(
      id: id,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      participants: participants ?? this.participants,
      createdAt: createdAt,
      lastEditedAt: lastEditedAt ?? DateTime.now(),
      lastEditedBy: lastEditedBy ?? this.lastEditedBy,
      lastEditedByDisplayName: lastEditedByDisplayName ?? this.lastEditedByDisplayName,
      editCount: editCount ?? (this.editCount + 1),
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      data: updatedData,
    );
  }

  /// Helper method for copying with updated data
  RealtimeMenu _copyWithUpdatedData({
    required RealtimeMenuData data,
    required String lastEditedBy,
    required String lastEditedByDisplayName,
  }) {
    final params = RealtimeMenuFactory.createCopyParameters(
      id: id,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      participants: participants,
      createdAt: createdAt,
      lastEditedAt: super.lastEditedAt,
      lastEditedBy: super.lastEditedBy,
      lastEditedByDisplayName: super.lastEditedByDisplayName,
      editCount: editCount,
      isActive: isActive,
      metadata: metadata,
      data: data,
      newLastEditedBy: lastEditedBy,
      newLastEditedByDisplayName: lastEditedByDisplayName,
    );

    return RealtimeMenu(
      id: params['id'] as String,
      ownerId: params['ownerId'] as String,
      ownerDisplayName: params['ownerDisplayName'] as String,
      participants: params['participants'] as Map<String, ResourcePermission>,
      createdAt: params['createdAt'] as DateTime,
      lastEditedAt: params['lastEditedAt'] as DateTime,
      lastEditedBy: params['lastEditedBy'] as String,
      lastEditedByDisplayName: params['lastEditedByDisplayName'] as String,
      editCount: params['editCount'] as int,
      isActive: params['isActive'] as bool,
      metadata: params['metadata'] as Map<String, dynamic>,
      data: params['data'] as RealtimeMenuData,
    );
  }

  // ===== SERIALIZATION (DELEGATE TO DATA) =====

  @override
  Map<String, dynamic> serializeContent() => _data.serializeContent();

  /// JSON serialization for caching
  Map<String, dynamic> toJson() {
    final json = toJsonMetadata();
    json.addAll(_data.toJson());
    return json;
  }

  /// Create from repository data map (removes Firebase dependency)
  static RealtimeMenu fromMap(String id, Map<String, dynamic> data) {
    // Parse directly without mock DocumentSnapshot
    final params = RealtimeMenuFactory.parseJsonData({
      'id': id,
      ...data,
    });

    return RealtimeMenu(
      id: params['id'] as String,
      ownerId: params['ownerId'] as String,
      ownerDisplayName: params['ownerDisplayName'] as String,
      participants: params['participants'] as Map<String, ResourcePermission>,
      createdAt: params['createdAt'] as DateTime,
      lastEditedAt: params['lastEditedAt'] as DateTime,
      lastEditedBy: params['lastEditedBy'] as String,
      lastEditedByDisplayName: params['lastEditedByDisplayName'] as String,
      editCount: params['editCount'] as int,
      isActive: params['isActive'] as bool,
      metadata: params['metadata'] as Map<String, dynamic>,
      data: params['data'] as RealtimeMenuData,
    );
  }

  @override
  String toString() {
    return 'RealtimeMenu('
        'id: $id, '
        'title: $menuTitle, '
        'recipes: $totalRecipeCount, '
        'categories: ${categories.length}, '
        'participants: $participantCount, '
        'completion: ${(completionPercentage * 100).toInt()}%, '
        'lastEdit: $lastEditedTimeAgo'
        ')';
  }
}
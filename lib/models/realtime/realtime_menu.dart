// lib/models/realtime/realtime_menu.dart

// TODO: Abstract Firebase DocumentSnapshot dependency to repository layer
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/models/realtime/realtime_menu_operations.dart';
import 'package:butlery/models/realtime/realtime_menu_analytics.dart';
import 'package:butlery/models/realtime/realtime_menu_factory.dart';

/// Realtime resource for collaborative category-based menu planning
///
/// This class provides a clean API that delegates to focused components:
/// - RealtimeMenuData: Pure data representation and serialization
/// - RealtimeMenuOperations: Business logic and menu operations
/// - RealtimeMenuAnalytics: Search, filtering, and analytics
///
/// ❌ DOES NOT CONTAIN: Business logic implementation, search algorithms, UI concerns
class RealtimeMenu extends RealtimeResource {
  /// The core menu data
  final RealtimeMenuData _data;

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

  // ===== FACTORY CONSTRUCTORS =====

  /// Factory to create new realtime menu from existing MenuViewModel structure
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

  /// Create from Firestore document
  factory RealtimeMenu.fromFirestore(DocumentSnapshot doc) {
    final params = RealtimeMenuFactory.parseFirestoreData(doc);

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

  /// Create from JSON
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

  // ===== DATA ACCESS PROPERTIES =====

  /// Menu title (delegates to data)
  String get menuTitle => _data.menuTitle;

  /// Created for date (delegates to data)
  DateTime get createdForDate => _data.createdForDate;

  /// Menu snapshot (delegates to data)
  Map<String, List<Recipe>> get menuSnapshot => _data.menuSnapshot;

  /// Menu notes (delegates to data)
  String? get menuNotes => _data.menuNotes;

  /// Favorite recipe IDs (delegates to data)
  List<String>? get favoriteRecipeIds => _data.favoriteRecipeIds;

  /// Original prompt (delegates to data)
  String? get originalPrompt => _data.originalPrompt;

  /// All categories (delegates to data)
  List<String> get categories => _data.categories;

  /// All unique recipes (delegates to data)
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

  /// Replace recipe in specific category and position
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

  /// Clear entire category (remove all recipes)
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

  /// Update entire category with new recipes
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

  /// Regenerate specific category (for AI generation)
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

  /// Detailed menu summary with statistics
  String get detailedMenuSummary => RealtimeMenuOperations.getDetailedMenuSummary(_data);

  /// Get meal type distribution
  Map<String, int> get mealTypeDistribution => RealtimeMenuOperations.getMealTypeDistribution(_data);

  /// Get most active category
  String? get mostActiveCategory => RealtimeMenuOperations.getMostActiveCategory(_data);

  /// Get least active category
  String? get leastActiveCategory => RealtimeMenuOperations.getLeastActiveCategory(_data);

  /// Get menu completion percentage
  double get completionPercentage => RealtimeMenuOperations.getCompletionPercentage(_data);

  /// Get completion status text
  String get completionStatus => RealtimeMenuOperations.getCompletionStatus(_data);

  /// Get progress color name
  String get progressColorName => RealtimeMenuOperations.getProgressColorName(_data);

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

  /// Get recipes that need attention
  List<Recipe> get recipesNeedingAttention => RealtimeMenuOperations.getRecipesNeedingAttention(_data);

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

  /// Get cooking time distribution
  Map<String, int> get cookingTimeDistribution => RealtimeMenuAnalytics.getCookingTimeDistribution(_data);

  /// Get difficulty distribution
  Map<String, int> get difficultyDistribution => RealtimeMenuAnalytics.getDifficultyDistribution(_data);

  /// Get rating distribution
  Map<String, int> get ratingDistribution => RealtimeMenuAnalytics.getRatingDistribution(_data);

  /// Get all unique tags in menu
  List<String> get allTags => RealtimeMenuAnalytics.getAllTags(_data);

  /// Get tag frequency distribution
  Map<String, int> get tagFrequency => RealtimeMenuAnalytics.getTagFrequency(_data);

  /// Get most popular tags
  List<String> getMostPopularTags({int limit = 10}) => 
      RealtimeMenuAnalytics.getMostPopularTags(_data, limit: limit);

  /// Get healthiness score
  double get healthinessScore => RealtimeMenuAnalytics.getHealthinessScore(_data);

  /// Get balance insights
  MenuBalanceInsights get balanceInsights => RealtimeMenuAnalytics.getBalanceInsights(_data);

  /// Get recipe recommendations
  List<String> get recipeRecommendations => RealtimeMenuAnalytics.getRecipeRecommendations(_data);

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
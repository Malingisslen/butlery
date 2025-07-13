// lib/models/realtime/realtime_menu.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../recipe.dart';
import '../permissions/resource_permission.dart';
import 'realtime_resource.dart';


/// Realtidsresurs för gemensam kategori-baserad menyplanering
///
/// Denna klass innehåller BARA:
/// - Menu data representation
/// - Business logic för menu operations
/// - Serialization methods
/// - Utility methods för menu manipulation
///
/// ❌ INNEHÅLLER INTE: UI widgets, styling, theme methods, Flutter UI imports
class RealtimeMenu extends RealtimeResource {
  /// Titel för menyn (t.ex. "Familj Anderssons veckomeny")
  final String menuTitle;

  /// När menyn skapades/planerades för
  final DateTime createdForDate;

  /// Kategori-baserad meny-struktur: Kategori -> Lista av recept
  /// Key: 'Middag', 'Lunch', 'Frukost', etc. (samma som befintlig menystruktur)
  /// Value: Lista av Recipe objekt för den kategorin
  final Map<String, List<Recipe>> menuSnapshot;

  /// Extra anteckningar för hela menyn
  final String? menuNotes;

  /// Favoritrecept som ofta används (för quick-add)
  final List<String>? favoriteRecipeIds;

  /// Ursprunglig prompt som användes för att generera menyn (om tillämpligt)
  final String? originalPrompt;

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
    required this.menuTitle,
    DateTime? createdForDate,
    required this.menuSnapshot,
    this.menuNotes,
    this.favoriteRecipeIds,
    this.originalPrompt,
  })  : createdForDate = createdForDate ?? DateTime.now(),
        super(
          type: RealtimeResourceType.menu,
        );

  /// Factory för att skapa ny realtidsmeny från befintlig MenuViewModel-struktur
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
    // Skapa participants map
    final participants = <String, ResourcePermission>{};

    // Ägaren får owner-behörighet
    participants[ownerId] = ResourcePermission.owner;

    // Lägg till redigerare
    if (editorUserIds != null) {
      for (final userId in editorUserIds) {
        if (userId != ownerId) {
          participants[userId] = ResourcePermission.editor;
        }
      }
    }

    // Lägg till betraktare
    if (viewerUserIds != null) {
      for (final userId in viewerUserIds) {
        if (userId != ownerId && !participants.containsKey(userId)) {
          participants[userId] = ResourcePermission.viewer;
        }
      }
    }

    return RealtimeMenu(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      participants: participants,
      lastEditedBy: ownerId,
      lastEditedByDisplayName: ownerDisplayName,
      menuTitle: menuTitle,
      createdForDate: createdForDate ?? DateTime.now(),
      menuSnapshot: menuSnapshot,
      menuNotes: menuNotes,
      favoriteRecipeIds: favoriteRecipeIds,
      originalPrompt: originalPrompt,
    );
  }

  // ===== MENU CONTENT OPERATIONS =====

  /// Uppdatera grundläggande menyinformation
  RealtimeMenu updateBasicInfo({
    String? menuTitle,
    DateTime? createdForDate,
    String? menuNotes,
    List<String>? favoriteRecipeIds,
    String? originalPrompt,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    return copyWith(
      menuTitle: menuTitle,
      createdForDate: createdForDate,
      menuNotes: menuNotes,
      favoriteRecipeIds: favoriteRecipeIds,
      originalPrompt: originalPrompt,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Lägg till recept till specifik kategori
  RealtimeMenu addRecipeToCategory({
    required String categoryName,
    required Recipe recipe,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedMenu = Map<String, List<Recipe>>.from(menuSnapshot);

    // Initiera kategori om den inte finns
    if (!updatedMenu.containsKey(categoryName)) {
      updatedMenu[categoryName] = [];
    }

    // Lägg till recept till kategorin
    updatedMenu[categoryName] = [...updatedMenu[categoryName]!, recipe];

    return copyWith(
      menuSnapshot: updatedMenu,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Ta bort recept från specifik kategori
  RealtimeMenu removeRecipeFromCategory({
    required String categoryName,
    required int recipeIndex,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedMenu = Map<String, List<Recipe>>.from(menuSnapshot);

    if (!updatedMenu.containsKey(categoryName) ||
        recipeIndex < 0 ||
        recipeIndex >= updatedMenu[categoryName]!.length) {
      throw ArgumentError(
          'Ogiltigt recept-index för kategori $categoryName: $recipeIndex');
    }

    // Ta bort recept från kategorin
    final updatedCategoryRecipes =
        List<Recipe>.from(updatedMenu[categoryName]!);
    updatedCategoryRecipes.removeAt(recipeIndex);
    updatedMenu[categoryName] = updatedCategoryRecipes;

    return copyWith(
      menuSnapshot: updatedMenu,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Flytta recept mellan kategorier
  RealtimeMenu moveRecipeBetweenCategories({
    required String fromCategory,
    required int fromIndex,
    required String toCategory,
    int? toIndex,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedMenu = Map<String, List<Recipe>>.from(menuSnapshot);

    // Validera from-kategori
    if (!updatedMenu.containsKey(fromCategory) ||
        fromIndex < 0 ||
        fromIndex >= updatedMenu[fromCategory]!.length) {
      throw ArgumentError(
          'Ogiltigt från-index för kategori $fromCategory: $fromIndex');
    }

    // Initiera to-kategori om den inte finns
    if (!updatedMenu.containsKey(toCategory)) {
      updatedMenu[toCategory] = [];
    }

    // Hämta receptet som ska flyttas
    final recipe = updatedMenu[fromCategory]![fromIndex];

    // Ta bort från ursprunglig kategori
    final updatedFromCategory = List<Recipe>.from(updatedMenu[fromCategory]!);
    updatedFromCategory.removeAt(fromIndex);
    updatedMenu[fromCategory] = updatedFromCategory;

    // Lägg till på ny kategori
    final updatedToCategory = List<Recipe>.from(updatedMenu[toCategory]!);
    final insertIndex = toIndex ?? updatedToCategory.length;
    updatedToCategory.insert(
        insertIndex.clamp(0, updatedToCategory.length), recipe);
    updatedMenu[toCategory] = updatedToCategory;

    return copyWith(
      menuSnapshot: updatedMenu,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Ersätt recept i specifik kategori och position
  RealtimeMenu replaceRecipeInCategory({
    required String categoryName,
    required int recipeIndex,
    required Recipe newRecipe,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedMenu = Map<String, List<Recipe>>.from(menuSnapshot);

    if (!updatedMenu.containsKey(categoryName) ||
        recipeIndex < 0 ||
        recipeIndex >= updatedMenu[categoryName]!.length) {
      throw ArgumentError(
          'Ogiltigt recept-index för kategori $categoryName: $recipeIndex');
    }

    // Ersätt receptet
    final updatedCategoryRecipes =
        List<Recipe>.from(updatedMenu[categoryName]!);
    updatedCategoryRecipes[recipeIndex] = newRecipe;
    updatedMenu[categoryName] = updatedCategoryRecipes;

    return copyWith(
      menuSnapshot: updatedMenu,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Rensa hela kategorin (ta bort alla recept)
  RealtimeMenu clearCategory({
    required String categoryName,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedMenu = Map<String, List<Recipe>>.from(menuSnapshot);
    updatedMenu[categoryName] = [];

    return copyWith(
      menuSnapshot: updatedMenu,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Uppdatera hela kategorin med nya recept
  RealtimeMenu updateWholeCategory({
    required String categoryName,
    required List<Recipe> recipes,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    final updatedMenu = Map<String, List<Recipe>>.from(menuSnapshot);
    updatedMenu[categoryName] = List<Recipe>.from(recipes);

    return copyWith(
      menuSnapshot: updatedMenu,
      lastEditedBy: editedBy,
      lastEditedByDisplayName: editedByDisplayName,
    );
  }

  /// Regenerera specifik kategori (för AI-generering)
  RealtimeMenu regenerateCategory({
    required String categoryName,
    required List<Recipe> newRecipes,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    return updateWholeCategory(
      categoryName: categoryName,
      recipes: newRecipes,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  // ===== BUSINESS LOGIC GETTERS =====

  /// Vanliga meny-kategorier (kan utökas)
  static const List<String> commonCategories = [
    'Middag',
    'Lunch',
    'Frukost',
    'Mellanmål',
    'Dessert',
    'Bakningar',
  ];

  /// Alla kategorier i denna meny
  List<String> get categories => menuSnapshot.keys.toList();

  /// Kategorier sorterade i logisk ordning
  List<String> get categoriesSorted {
    final sorted = List<String>.from(categories);
    sorted.sort((a, b) {
      // Prioritera vanliga kategorier i ordning
      final aIndex = commonCategories.indexOf(a);
      final bIndex = commonCategories.indexOf(b);

      if (aIndex != -1 && bIndex != -1) {
        return aIndex.compareTo(bIndex);
      } else if (aIndex != -1) {
        return -1;
      } else if (bIndex != -1) {
        return 1;
      } else {
        return a.compareTo(b);
      }
    });
    return sorted;
  }

  /// Totalt antal recept i hela menyn
  int get totalRecipeCount {
    return menuSnapshot.values
        .fold(0, (total, categoryRecipes) => total + categoryRecipes.length);
  }

  /// Antal kategorier som har recept
  int get categoriesWithRecipes {
    return menuSnapshot.values
        .where((categoryRecipes) => categoryRecipes.isNotEmpty)
        .length;
  }

  /// Antal tomma kategorier
  int get emptyCategoriesCount {
    return menuSnapshot.values
        .where((categoryRecipes) => categoryRecipes.isEmpty)
        .length;
  }

  /// Är menyn komplett? (har recept i minst 2 kategorier)
  bool get isComplete => categoriesWithRecipes >= 2;

  /// Är menyn väl balanserad? (har recept i minst 3 kategorier)
  bool get isWellBalanced => categoriesWithRecipes >= 3;

  /// Hämta recept för specifik kategori
  List<Recipe> getRecipesForCategory(String categoryName) {
    return menuSnapshot[categoryName] ?? [];
  }

  /// Kontrollera om kategori har recept
  bool categoryHasRecipes(String categoryName) {
    return getRecipesForCategory(categoryName).isNotEmpty;
  }

  /// Hämta alla unika recept i menyn (för ingredienslista)
  List<Recipe> get allUniqueRecipes {
    final allRecipes = <Recipe>[];
    final seenIds = <String>{};

    for (final categoryRecipes in menuSnapshot.values) {
      for (final recipe in categoryRecipes) {
        if (!seenIds.contains(recipe.id)) {
          allRecipes.add(recipe);
          seenIds.add(recipe.id);
        }
      }
    }

    return allRecipes;
  }

  /// Meny-sammanfattning för UI (kompatibel med befintlig SharedMenu)
  String get menuSummary {
    if (totalRecipeCount == 0) {
      return 'Tom meny';
    }

    final parts = <String>[];
    for (final entry in menuSnapshot.entries) {
      final categoryName = entry.key;
      final count = entry.value.length;
      if (count > 0) {
        parts.add('$count $categoryName');
      }
    }
    return parts.join(', ');
  }

  /// Detaljerad meny-sammanfattning med statistik
  String get detailedMenuSummary {
    if (totalRecipeCount == 0) {
      return 'Tom meny - inga recept tillagda än';
    }

    final parts = <String>[];
    parts.add('$totalRecipeCount recept');
    parts.add('$categoriesWithRecipes kategorier');

    if (isWellBalanced) {
      parts.add('väl balanserad');
    } else if (isComplete) {
      parts.add('komplett');
    } else {
      parts.add('pågående');
    }

    return parts.join(' • ');
  }

  /// Konvertera till format som är kompatibelt med MenuViewModel
  Map<String, List<Recipe>> toMenuViewModelFormat() {
    return Map<String, List<Recipe>>.from(menuSnapshot);
  }

  /// Få mest populära måltidstyper i menyn
  Map<String, int> get mealTypeDistribution {
    final distribution = <String, int>{};

    for (final recipes in menuSnapshot.values) {
      for (final recipe in recipes) {
        distribution[recipe.mealType] =
            (distribution[recipe.mealType] ?? 0) + 1;
      }
    }

    return distribution;
  }

  /// Få mest aktiva kategorin (med flest recept)
  String? get mostActiveCategory {
    if (menuSnapshot.isEmpty) return null;

    String? maxCategory;
    int maxCount = 0;

    for (final entry in menuSnapshot.entries) {
      if (entry.value.length > maxCount) {
        maxCount = entry.value.length;
        maxCategory = entry.key;
      }
    }

    return maxCategory;
  }

  /// Få minst aktiva kategorin (med minst recept, men inte tom)
  String? get leastActiveCategory {
    if (menuSnapshot.isEmpty) return null;

    String? minCategory;
    int minCount = double.maxFinite.toInt();

    for (final entry in menuSnapshot.entries) {
      if (entry.value.isNotEmpty && entry.value.length < minCount) {
        minCount = entry.value.length;
        minCategory = entry.key;
      }
    }

    return minCategory;
  }

  /// Kontrollera om menyn innehåller ett specifikt recept
  bool containsRecipe(String recipeId) {
    for (final recipes in menuSnapshot.values) {
      if (recipes.any((recipe) => recipe.id == recipeId)) {
        return true;
      }
    }
    return false;
  }

  /// Hitta vilken kategori ett recept tillhör
  String? findRecipeCategory(String recipeId) {
    for (final entry in menuSnapshot.entries) {
      if (entry.value.any((recipe) => recipe.id == recipeId)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Få genomsnittligt antal recept per kategori
  double get averageRecipesPerCategory {
    if (categories.isEmpty) return 0.0;
    return totalRecipeCount / categories.length;
  }

  /// Kontrollera om menyn har favoritrecept definierade
  bool get hasFavorites => favoriteRecipeIds?.isNotEmpty == true;

  /// Antal favoritrecept
  int get favoritesCount => favoriteRecipeIds?.length ?? 0;

  /// Kontrollera om menyn har anteckningar
  bool get hasNotes => menuNotes?.isNotEmpty == true;

  /// Kontrollera om menyn genererades från prompt
  bool get wasGenerated => originalPrompt?.isNotEmpty == true;

  /// Få menu completion percentage (för progress indicators)
  double get completionPercentage {
    if (commonCategories.isEmpty) return 0.0;

    int completedCategories = 0;
    for (final category in commonCategories) {
      if (categoryHasRecipes(category)) {
        completedCategories++;
      }
    }

    return completedCategories / commonCategories.length;
  }

  /// Få completion status text
  String get completionStatus {
    if (completionPercentage >= 1.0) {
      return 'Komplett meny';
    } else if (completionPercentage >= 0.8) {
      return 'Nästan klar';
    } else if (completionPercentage >= 0.5) {
      return 'Halvfärdig';
    } else if (completionPercentage >= 0.2) {
      return 'Påbörjad';
    } else {
      return 'Tom meny';
    }
  }

  /// Få progress color name (för UI widgets att använda med AppTheme)
  String get progressColorName {
    if (completionPercentage >= 0.8) {
      return 'success';
    } else if (completionPercentage >= 0.5) {
      return 'primary';
    } else if (completionPercentage >= 0.2) {
      return 'warning';
    } else {
      return 'error';
    }
  }

  // ===== MENU SEARCH AND FILTERING =====

  /// Sök recept i menyn baserat på query
  List<Recipe> searchRecipes(String query) {
    if (query.isEmpty) return allUniqueRecipes;

    final lowerQuery = query.toLowerCase();
    final results = <Recipe>[];

    for (final recipes in menuSnapshot.values) {
      for (final recipe in recipes) {
        if (recipe.title.toLowerCase().contains(lowerQuery) ||
            recipe.description.toLowerCase().contains(lowerQuery) ||
            recipe.ingredients.any((ingredient) =>
                ingredient.toLowerCase().contains(lowerQuery)) ||
            recipe.mealType.toLowerCase().contains(lowerQuery)) {
          results.add(recipe);
        }
      }
    }

    return results;
  }

  /// Filtrera menyn efter specifik måltidstyp
  Map<String, List<Recipe>> filterByMealType(String mealType) {
    final filtered = <String, List<Recipe>>{};

    for (final entry in menuSnapshot.entries) {
      final filteredRecipes =
          entry.value.where((recipe) => recipe.mealType == mealType).toList();

      if (filteredRecipes.isNotEmpty) {
        filtered[entry.key] = filteredRecipes;
      }
    }

    return filtered;
  }

  /// Få recept som behöver uppmärksamhet (ofullständiga)
  List<Recipe> get recipesNeedingAttention {
    final needingAttention = <Recipe>[];

    for (final recipes in menuSnapshot.values) {
      for (final recipe in recipes) {
        if (recipe.title.isEmpty ||
            recipe.ingredients.isEmpty ||
            recipe.instructions.isEmpty) {
          needingAttention.add(recipe);
        }
      }
    }

    return needingAttention;
  }

  // ===== PARTICIPANT MANAGEMENT (OVERRIDE från RealtimeResource) =====

  @override
  RealtimeMenu addParticipant(
    String userId,
    String userDisplayName,
    ResourcePermission permission,
  ) {
    final updatedParticipants =
        Map<String, ResourcePermission>.from(participants);
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
      throw ArgumentError('Kan inte ta bort ägaren från menyn');
    }

    final updatedParticipants =
        Map<String, ResourcePermission>.from(participants);
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
      throw ArgumentError('Ägaren måste behålla owner-behörighet');
    }

    final updatedParticipants =
        Map<String, ResourcePermission>.from(participants);
    updatedParticipants[userId] = newPermission;

    return copyWithMetadata(
      participants: updatedParticipants,
      lastEditedAt: DateTime.now(),
      lastEditedBy: ownerId,
      lastEditedByDisplayName: ownerDisplayName,
      editCount: editCount + 1,
    );
  }

  // ===== OVERRIDE ABSTRACT METHODS =====

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
      lastEditedByDisplayName:
          lastEditedByDisplayName ?? this.lastEditedByDisplayName,
      editCount: editCount ?? (this.editCount + 1),
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      menuTitle: menuTitle,
      createdForDate: createdForDate,
      menuSnapshot: menuSnapshot,
      menuNotes: menuNotes,
      favoriteRecipeIds: favoriteRecipeIds,
      originalPrompt: originalPrompt,
    );
  }

  /// Skapa kopia med uppdaterat meny-innehåll och metadata
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
    return RealtimeMenu(
      id: id,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      participants: participants ?? this.participants,
      createdAt: createdAt,
      lastEditedAt: lastEditedAt ?? DateTime.now(),
      lastEditedBy: lastEditedBy ?? this.lastEditedBy,
      lastEditedByDisplayName:
          lastEditedByDisplayName ?? this.lastEditedByDisplayName,
      editCount: editCount ?? (this.editCount + 1),
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      menuTitle: menuTitle ?? this.menuTitle,
      createdForDate: createdForDate ?? this.createdForDate,
      menuSnapshot: menuSnapshot ?? this.menuSnapshot,
      menuNotes: menuNotes ?? this.menuNotes,
      favoriteRecipeIds: favoriteRecipeIds ?? this.favoriteRecipeIds,
      originalPrompt: originalPrompt ?? this.originalPrompt,
    );
  }

  @override
  Map<String, dynamic> serializeContent() {
    // Serialisera menuSnapshot till Firestore-format (samma som SharedMenu)
    final menuData = <String, List<Map<String, dynamic>>>{};
    for (final entry in menuSnapshot.entries) {
      final categoryName = entry.key;
      final recipes = entry.value;
      menuData[categoryName] =
          recipes.map((recipe) => recipe.toFirestore(isNested: true)).toList();
    }

    return {
      'menuTitle': menuTitle,
      'createdForDate': Timestamp.fromDate(createdForDate),
      'menuSnapshot': menuData,
      'menuNotes': menuNotes,
      'favoriteRecipeIds': favoriteRecipeIds,
      'originalPrompt': originalPrompt,
    };
  }

  /// Skapa från Firestore dokument
  factory RealtimeMenu.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final metadataMap = RealtimeResource.parseFirestoreMetadata(data, doc.id);

    // Parse menu-specifik data (samma struktur som SharedMenu)
    final menuData = data['menuSnapshot'] as Map<String, dynamic>? ?? {};
    final menuSnapshot = <String, List<Recipe>>{};

    // Konvertera menu data tillbaka till Recipe objekt
    for (final entry in menuData.entries) {
      final categoryName = entry.key;
      final recipesData = entry.value as List<dynamic>? ?? [];

      final recipes = recipesData
          .map((recipeData) => Recipe(
                title: recipeData['title'] as String? ?? '',
                description: recipeData['description'] as String? ?? '',
                portions: recipeData['portions'] as int?,
                timeMinutes: recipeData['timeMinutes'] as int?,
                ingredients: List<String>.from(recipeData['ingredients'] ?? []),
                instructions:
                    List<String>.from(recipeData['instructions'] ?? []),
                tags: recipeData['tags'] != null
                    ? List<String>.from(recipeData['tags'])
                    : null,
                rating: (recipeData['rating'] as num?)?.toDouble(),
                imageUrls: List<String>.from(recipeData['imageUrls'] ?? []),
                mealType: recipeData['mealType'] as String? ?? 'Middag',
                sourceUrl: recipeData['sourceUrl'] as String?,
              ))
          .toList();

      menuSnapshot[categoryName] = recipes;
    }

    return RealtimeMenu(
      id: metadataMap['id'] as String,
      ownerId: metadataMap['ownerId'] as String,
      ownerDisplayName: metadataMap['ownerDisplayName'] as String,
      participants:
          metadataMap['participants'] as Map<String, ResourcePermission>,
      createdAt: metadataMap['createdAt'] as DateTime,
      lastEditedAt: metadataMap['lastEditedAt'] as DateTime,
      lastEditedBy: metadataMap['lastEditedBy'] as String,
      lastEditedByDisplayName: metadataMap['lastEditedByDisplayName'] as String,
      editCount: metadataMap['editCount'] as int,
      isActive: metadataMap['isActive'] as bool,
      metadata: metadataMap['metadata'] as Map<String, dynamic>,
      menuTitle: data['menuTitle'] as String? ?? '',
      createdForDate:
          (data['createdForDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      menuSnapshot: menuSnapshot,
      menuNotes: data['menuNotes'] as String?,
      favoriteRecipeIds: data['favoriteRecipeIds'] != null
          ? List<String>.from(data['favoriteRecipeIds'])
          : null,
      originalPrompt: data['originalPrompt'] as String?,
    );
  }

  // ===== UTILITY METHODS =====

  /// Skapa en personlig kopia av menyn (kompatibel med MenuViewModel)
  Map<String, List<Recipe>> createPersonalMenuCopy() {
    final personalMenu = <String, List<Recipe>>{};

    for (final entry in menuSnapshot.entries) {
      final categoryName = entry.key;
      final recipes = entry.value;

      // Skapa kopior av recepten med ny attribution
      final personalRecipes = recipes
          .map((recipe) => recipe.copyWith(
                id: '', // Nytt ID genereras
                sourceUrl: 'Delad meny från $ownerDisplayName',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                lastCookedAt: null,
              ))
          .toList();

      personalMenu[categoryName] = personalRecipes;
    }

    return personalMenu;
  }

  /// JSON serialization för caching
  Map<String, dynamic> toJson() {
    final json = toJsonMetadata();

    // Serialisera menuSnapshot för JSON
    final menuData = <String, List<Map<String, dynamic>>>{};
    for (final entry in menuSnapshot.entries) {
      menuData[entry.key] =
          entry.value.map((recipe) => recipe.toJson()).toList();
    }

    json['menuTitle'] = menuTitle;
    json['createdForDate'] = createdForDate.toIso8601String();
    json['menuSnapshot'] = menuData;
    json['menuNotes'] = menuNotes;
    json['favoriteRecipeIds'] = favoriteRecipeIds;
    json['originalPrompt'] = originalPrompt;

    return json;
  }

  factory RealtimeMenu.fromJson(Map<String, dynamic> json) {
    // Parse participants
    final participantsData =
        json['participants'] as Map<String, dynamic>? ?? {};
    final participants = <String, ResourcePermission>{};

    for (final entry in participantsData.entries) {
      try {
        participants[entry.key] = ResourcePermissionHelper.fromString(
          entry.value as String,
        );
      } catch (e) {
        continue;
      }
    }

    // Parse menuSnapshot från JSON
    final menuData = json['menuSnapshot'] as Map<String, dynamic>? ?? {};
    final menuSnapshot = <String, List<Recipe>>{};

    for (final entry in menuData.entries) {
      final recipesData = entry.value as List<dynamic>? ?? [];
      final recipes = recipesData
          .map((recipeData) =>
              Recipe.fromJson(recipeData as Map<String, dynamic>))
          .toList();
      menuSnapshot[entry.key] = recipes;
    }

    return RealtimeMenu(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      ownerDisplayName: json['ownerDisplayName'] as String,
      participants: participants,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastEditedAt: DateTime.parse(json['lastEditedAt'] as String),
      lastEditedBy: json['lastEditedBy'] as String,
      lastEditedByDisplayName: json['lastEditedByDisplayName'] as String,
      editCount: json['editCount'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      menuTitle: json['menuTitle'] as String? ?? '',
      createdForDate: DateTime.parse(json['createdForDate'] as String),
      menuSnapshot: menuSnapshot,
      menuNotes: json['menuNotes'] as String?,
      favoriteRecipeIds: json['favoriteRecipeIds'] != null
          ? List<String>.from(json['favoriteRecipeIds'])
          : null,
      originalPrompt: json['originalPrompt'] as String?,
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

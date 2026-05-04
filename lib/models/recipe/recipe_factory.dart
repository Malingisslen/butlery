import 'package:clock/clock.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

/// Factory methods for recipe construction and conversion.
class RecipeFactory {
  /// Create a basic personal recipe
  static Recipe createPersonal({
    required String title,
    required String description,
    required List<String> ingredients,
    required List<String> instructions,
    required String mealType,
    String? createdBy,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
    List<String>? imageUrls,
    bool isPublic = false,
  }) {
    return Recipe(
      core: RecipeCore(
        title: title,
        description: description,
        ingredients: ingredients,
        instructions: instructions,
        mealType: mealType,
        createdBy: createdBy,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        personalTagIds: personalTagIds,
        sourceUrl: sourceUrl,
        imageUrls: imageUrls,
        isPublic: isPublic,
      ),
      type: RecipeType.personal,
    );
  }

  /// Create a quick personal recipe with minimal data
  static Recipe createQuickPersonal({
    required String title,
    required List<String> ingredients,
    required List<String> instructions,
    String mealType = 'Middag',
    String? createdBy,
  }) {
    return Recipe(
      core: RecipeCore(
        title: title,
        description: '', // Can be filled later
        ingredients: ingredients,
        instructions: instructions,
        mealType: mealType,
        createdBy: createdBy,
      ),
      type: RecipeType.personal,
    );
  }

  /// Create a shared recipe (read-only for others)
  static Recipe createShared({
    required String title,
    required String description,
    required List<String> ingredients,
    required List<String> instructions,
    required String mealType,
    required String ownerId,
    required String ownerDisplayName,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
    List<String>? imageUrls,
    bool allowGuestViewing = true,
  }) {
    return Recipe(
      core: RecipeCore(
        title: title,
        description: description,
        ingredients: ingredients,
        instructions: instructions,
        mealType: mealType,
        createdBy: ownerId,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        personalTagIds: personalTagIds,
        sourceUrl: sourceUrl,
        imageUrls: imageUrls,
        isPublic: true,
      ),
      type: RecipeType.shared,
      socialData: RecipeSocialData(
        ownerId: ownerId,
        ownerDisplayName: ownerDisplayName,
        allowGuestViewing: allowGuestViewing,
        allowMemberInvites: false, // Shared recipes don't allow invites
      ),
    );
  }

  /// Create a collaborative recipe (can be co-edited)
  static Recipe createCollaborative({
    required String title,
    required String description,
    required List<String> ingredients,
    required List<String> instructions,
    required String mealType,
    required String ownerId,
    required String ownerDisplayName,
    Map<String, ResourcePermission>? memberPermissions,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    String? descriptionCollaborative,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
    List<String>? imageUrls,
  }) {
    return Recipe(
      core: RecipeCore(
        title: title,
        description: description,
        ingredients: ingredients,
        instructions: instructions,
        mealType: mealType,
        createdBy: ownerId,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        personalTagIds: personalTagIds,
        sourceUrl: sourceUrl,
        imageUrls: imageUrls,
        isPublic: true, // Collaborative recipes are typically public to members
      ),
      type: RecipeType.collaborative,
      socialData: RecipeSocialData(
        ownerId: ownerId,
        ownerDisplayName: ownerDisplayName,
        memberPermissions: memberPermissions ?? {},
        allowGuestViewing: allowGuestViewing,
        allowMemberInvites: allowMemberInvites,
        descriptionCollaborative: descriptionCollaborative,
      ),
    );
  }

  /// Create a realtime recipe (live editing)
  static Recipe createRealtime({
    required String title,
    required String description,
    required List<String> ingredients,
    required List<String> instructions,
    required String mealType,
    required String ownerId,
    required String ownerDisplayName,
    Map<String, ResourcePermission>? memberPermissions,
    List<String>? activeEditorIds,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
    List<String>? imageUrls,
  }) {
    return Recipe(
      core: RecipeCore(
        title: title,
        description: description,
        ingredients: ingredients,
        instructions: instructions,
        mealType: mealType,
        createdBy: ownerId,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        personalTagIds: personalTagIds,
        sourceUrl: sourceUrl,
        imageUrls: imageUrls,
        isPublic: true,
      ),
      type: RecipeType.realtime,
      socialData: RecipeSocialData(
        ownerId: ownerId,
        ownerDisplayName: ownerDisplayName,
        memberPermissions: memberPermissions ?? {},
        allowGuestViewing: true,
        allowMemberInvites: true,
      ),
      realtimeData: RecipeRealtimeData(
        activeEditorIds: activeEditorIds,
        lastEditedByUserId: ownerId,
        lastEditedByDisplayName: ownerDisplayName,
        lastEditedAt: clock.now(),
        editCount: 0,
        isActive: true,
      ),
    );
  }

  /// Convert personal recipe to shared
  static Recipe convertToShared(
    Recipe personalRecipe, {
    required String ownerId,
    required String ownerDisplayName,
    bool allowGuestViewing = true,
  }) {
    if (personalRecipe.type != RecipeType.personal) {
      throw ArgumentError('Only personal recipes can be converted to shared');
    }

    return Recipe(
      core: personalRecipe.core.copyWith(
        isPublic: true,
        createdBy: ownerId,
      ),
      type: RecipeType.shared,
      socialData: RecipeSocialData(
        ownerId: ownerId,
        ownerDisplayName: ownerDisplayName,
        allowGuestViewing: allowGuestViewing,
        allowMemberInvites: false,
      ),
      offlineData: personalRecipe.offlineData,
    );
  }

  /// Convert personal recipe to collaborative
  static Recipe convertToCollaborative(
    Recipe personalRecipe, {
    required String ownerId,
    required String ownerDisplayName,
    Map<String, ResourcePermission>? initialMembers,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    String? descriptionCollaborative,
  }) {
    if (personalRecipe.type != RecipeType.personal) {
      throw ArgumentError(
          'Only personal recipes can be converted to collaborative');
    }

    return Recipe(
      core: personalRecipe.core.copyWith(
        isPublic: true,
        createdBy: ownerId,
      ),
      type: RecipeType.collaborative,
      socialData: RecipeSocialData(
        ownerId: ownerId,
        ownerDisplayName: ownerDisplayName,
        memberPermissions: initialMembers ?? {},
        allowGuestViewing: allowGuestViewing,
        allowMemberInvites: allowMemberInvites,
        descriptionCollaborative: descriptionCollaborative,
      ),
      offlineData: personalRecipe.offlineData,
    );
  }

  /// Convert collaborative recipe to realtime
  static Recipe convertToRealtime(
    Recipe collaborativeRecipe, {
    List<String>? activeEditorIds,
  }) {
    if (collaborativeRecipe.type != RecipeType.collaborative) {
      throw ArgumentError(
          'Only collaborative recipes can be converted to realtime');
    }

    return Recipe(
      core: collaborativeRecipe.core,
      type: RecipeType.realtime,
      socialData: collaborativeRecipe.socialData,
      realtimeData: RecipeRealtimeData(
        activeEditorIds: activeEditorIds,
        lastEditedByUserId: collaborativeRecipe.socialData?.ownerId,
        lastEditedByDisplayName:
            collaborativeRecipe.socialData?.ownerDisplayName,
        lastEditedAt: clock.now(),
        editCount: 0,
        isActive: true,
      ),
      offlineData: collaborativeRecipe.offlineData,
    );
  }

  /// Create personal copy from any recipe type
  static Recipe createPersonalCopy(
    Recipe sourceRecipe, {
    required String newOwnerId,
    String? customTitle,
  }) {
    final titleSuffix = sourceRecipe.socialData?.ownerDisplayName != null
        ? ' (från ${sourceRecipe.socialData!.ownerDisplayName})'
        : ' (kopia)';

    return Recipe(
      core: RecipeCore(
        title: customTitle ?? '${sourceRecipe.core.title}$titleSuffix',
        description: sourceRecipe.core.description,
        ingredients: [...sourceRecipe.core.ingredients],
        instructions: [...sourceRecipe.core.instructions],
        mealType: sourceRecipe.core.mealType,
        createdBy: newOwnerId,
        portions: sourceRecipe.core.portions,
        timeMinutes: sourceRecipe.core.timeMinutes,
        rating: sourceRecipe.core.rating,
        personalTagIds: sourceRecipe.core.personalTagIds != null
            ? [...sourceRecipe.core.personalTagIds!]
            : null,
        personalTags: sourceRecipe.core.personalTags != null
            ? [...sourceRecipe.core.personalTags!]
            : null,
        sourceUrl: AppLocale.current.recipeCopiedFrom(sourceRecipe.core.title),
        imageUrls: [...sourceRecipe.core.imageUrls],
        isPublic: false, // Personal copies are private by default
        tagResult: sourceRecipe.core.tagResult,
        tagOverrides: sourceRecipe.core.tagOverrides,
        ingredientsNormalized: sourceRecipe.core.ingredientsNormalized != null
            ? [...sourceRecipe.core.ingredientsNormalized!]
            : null,
      ),
      type: RecipeType.personal,
    );
  }

  /// Create an empty recipe template
  static Recipe createEmptyTemplate({
    String title = 'Nytt recept',
    String mealType = 'Middag',
    String? createdBy,
  }) {
    return Recipe(
      core: RecipeCore(
        title: title,
        description: '',
        ingredients: [''],
        instructions: [''],
        mealType: mealType,
        createdBy: createdBy,
      ),
      type: RecipeType.personal,
    );
  }

  /// Create recipe from URL/import data
  static Recipe createFromImport({
    required String title,
    required String description,
    required List<String> ingredients,
    required List<String> instructions,
    required String sourceUrl,
    String mealType = 'Middag',
    String? createdBy,
    int? portions,
    int? timeMinutes,
    List<String>? imageUrls,
  }) {
    return Recipe(
      core: RecipeCore(
        title: title,
        description: description,
        ingredients: ingredients,
        instructions: instructions,
        mealType: mealType,
        createdBy: createdBy,
        portions: portions,
        timeMinutes: timeMinutes,
        sourceUrl: sourceUrl,
        imageUrls: imageUrls ?? [],
      ),
      type: RecipeType.personal,
    );
  }

  /// Validate factory parameters
  static bool validateBasicRecipeData({
    required String title,
    required List<String> ingredients,
    required List<String> instructions,
    required String mealType,
  }) {
    if (title.trim().isEmpty) return false;
    if (ingredients.isEmpty) return false;
    if (instructions.isEmpty) return false;
    if (mealType.trim().isEmpty) return false;

    // Check that ingredients and instructions are not empty
    if (ingredients.every((ingredient) => ingredient.trim().isEmpty)) {
      return false;
    }
    if (instructions.every((instruction) => instruction.trim().isEmpty)) {
      return false;
    }

    return true;
  }

  /// Get default meal types
  static List<String> getDefaultMealTypes() {
    return [
      'Frukost',
      'Lunch',
      'Middag',
      'Mellanmål',
      'Efterrätt',
      'Dryck',
      'Bakning',
    ];
  }

  /// Get default recipe tags
  static List<String> getCommonTags() {
    return [
      'Snabbt',
      'Vegetariskt',
      'Veganskt',
      'Glutenfritt',
      'Laktosfritt',
      'Barnvänligt',
      'Festmat',
      'Vardagsmat',
      'Hälsosamt',
      'Billigt',
    ];
  }
}

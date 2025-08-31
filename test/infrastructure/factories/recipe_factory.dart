/// Recipe Factory for generating test recipes
/// 
/// Provides factory methods for creating Recipe instances
/// with configurable properties for testing.
library;

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

/// Factory for creating test Recipe instances
class RecipeFactory {
  /// Private constructor to prevent instantiation
  RecipeFactory._();
  
  /// Build a Recipe with configurable properties
  static Recipe build({
    String? id,
    String title = 'Test Recipe',
    String description = 'Test recipe description',
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? imageUrls,
    String mealType = 'Lunch',
    int? portions = 4,
    int? timeMinutes = 30,
    double? rating = 4.5,
    List<String>? tags,
    String? sourceUrl,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isPublic = false,
    DateTime? lastCookedAt,
    RecipeType type = RecipeType.personal,
    RecipeSocialData? socialData,
    RecipeRealtimeData? realtimeData,
    RecipeOfflineData? offlineData,
  }) {
    final core = RecipeCore(
      id: id ?? 'recipe_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      ingredients: ingredients ?? ['Ingredient 1', 'Ingredient 2'],
      instructions: instructions ?? ['Step 1', 'Step 2'],
      imageUrls: imageUrls ?? [],
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      tags: tags ?? ['test', 'recipe'],
      sourceUrl: sourceUrl,
      createdBy: createdBy ?? 'test_user',
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      isPublic: isPublic,
      lastCookedAt: lastCookedAt,
    );
    
    return Recipe(
      core: core,
      type: type,
      socialData: socialData,
      realtimeData: realtimeData,
      offlineData: offlineData,
    );
  }
  
  /// Build a list of recipes
  static List<Recipe> buildList({
    int count = 3,
    String titlePrefix = 'Recipe',
  }) {
    return List.generate(
      count,
      (index) => build(
        id: 'recipe_$index',
        title: '$titlePrefix ${index + 1}',
        description: 'Description for $titlePrefix ${index + 1}',
      ),
    );
  }
  
  /// Build a personal recipe
  static Recipe buildPersonal({
    String? id,
    String title = 'Personal Recipe',
    String? createdBy,
  }) {
    return build(
      id: id,
      title: title,
      createdBy: createdBy,
      type: RecipeType.personal,
    );
  }
  
  /// Build a collaborative recipe
  static Recipe buildCollaborative({
    String? id,
    String title = 'Collaborative Recipe',
    List<String>? sharedWith,
    Map<String, ResourcePermission>? permissions,
  }) {
    return build(
      id: id,
      title: title,
      type: RecipeType.collaborative,
      socialData: RecipeSocialData(
        ownerId: 'test_user',
        ownerDisplayName: 'Test User',
        memberPermissions: permissions ?? {
          'user1': ResourcePermission.editor,
          'user2': ResourcePermission.viewer,
        },
        allowGuestViewing: false,
        allowMemberInvites: true,
      ),
    );
  }
  
  /// Build a shared recipe
  static Recipe buildShared({
    String? id,
    String title = 'Shared Recipe',
    bool isPublic = true,
  }) {
    return build(
      id: id,
      title: title,
      type: RecipeType.shared,
      isPublic: isPublic,
      socialData: RecipeSocialData(
        ownerId: 'test_user',
        ownerDisplayName: 'Test User',
        allowGuestViewing: isPublic,
      ),
    );
  }
  
  /// Build a realtime recipe
  static Recipe buildRealtime({
    String? id,
    String title = 'Realtime Recipe',
    List<String>? activeUsers,
  }) {
    return build(
      id: id,
      title: title,
      type: RecipeType.realtime,
      realtimeData: RecipeRealtimeData(
        activeEditorIds: activeUsers ?? ['user1'],
        lastEditedAt: DateTime.now(),
        lastEditedByUserId: 'test_user',
        lastEditedByDisplayName: 'Test User',
        editCount: 0,
        isActive: true,
      ),
    );
  }
  
  /// Build a recipe with cooking history
  static Recipe buildWithCookingHistory({
    String? id,
    String title = 'Frequently Cooked Recipe',
    DateTime? lastCookedAt,
  }) {
    return build(
      id: id,
      title: title,
      lastCookedAt: lastCookedAt ?? DateTime.now().subtract(const Duration(days: 1)),
    );
  }
}
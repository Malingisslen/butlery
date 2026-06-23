/// Test data builder for RealtimeMenu objects
///
/// Provides fluent API for creating test realtime menus with Swedish-themed defaults
/// and various preset configurations for different test scenarios.
library;

import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:uuid/uuid.dart';
import 'recipe_builder.dart';

/// Builder pattern for creating test RealtimeMenu instances
class RealtimeMenuBuilder {
  String id = const Uuid().v4();
  String ownerId = 'owner_123';
  String ownerDisplayName = 'Test Owner';
  Map<String, ResourcePermission> participants = {};
  DateTime createdAt = DateTime.now();
  DateTime lastEditedAt = DateTime.now();
  String lastEditedBy = 'owner_123';
  String lastEditedByDisplayName = 'Test Owner';
  int editCount = 0;
  bool isActive = true;
  Map<String, dynamic>? metadata;

  // RealtimeMenuData fields
  String menuTitle = 'Test Menu';
  DateTime createdForDate = DateTime.now();
  Map<String, List<Recipe>> menuSnapshot = {};
  String? menuNotes;
  List<String>? favoriteRecipeIds;
  String? originalPrompt;

  RealtimeMenuBuilder() {
    // Owner is NOT in participants map - tracked separately via ownerId field
  }

  /// Creates a Swedish weekly menu preset
  RealtimeMenuBuilder asSwedishWeeklyMenu() {
    menuTitle = 'Veckans meny';
    menuNotes = 'Planering för hela veckan med svenska favoriter';
    createdForDate = DateTime.now().add(const Duration(days: 7));

    // Create Swedish recipe presets
    final meatballs = RecipeBuilder().asSwedishDinner().build();
    final pasta = RecipeBuilder().asItalianPasta().build();
    final porridge = RecipeBuilder().asSwedishBreakfast().build();
    final kladdkaka = RecipeBuilder().asSwedishDessert().build();

    menuSnapshot = {
      'Måndag': [meatballs, kladdkaka],
      'Tisdag': [pasta],
      'Onsdag': [meatballs],
      'Torsdag': [pasta, kladdkaka],
      'Fredag': [meatballs],
      'Helg': [porridge, meatballs, kladdkaka],
    };

    favoriteRecipeIds = [meatballs.id, kladdkaka.id];
    originalPrompt = 'Skapa en veckomeny med svenska klassiker';

    return this;
  }

  /// Creates a collaborative menu with multiple participants
  RealtimeMenuBuilder asCollaborativeMenu() {
    menuTitle = 'Familjens meny';
    menuNotes = 'Gemensam planering för hela familjen';

    // Add multiple participants
    participants['editor_456'] = ResourcePermission.editor;
    participants['viewer_789'] = ResourcePermission.viewer;
    participants['editor_012'] = ResourcePermission.editor;

    lastEditedBy = 'editor_456';
    lastEditedByDisplayName = 'Anna Andersson';
    editCount = 15;

    return this;
  }

  /// Creates a minimal menu for edge case testing
  RealtimeMenuBuilder asMinimalMenu() {
    menuTitle = 'Min';
    menuSnapshot = {'Dag': []};
    menuNotes = null;
    favoriteRecipeIds = null;
    originalPrompt = null;
    editCount = 0;

    return this;
  }

  /// Set custom ID
  RealtimeMenuBuilder withId(String id) {
    this.id = id;
    return this;
  }

  /// Set custom title
  RealtimeMenuBuilder withTitle(String title) {
    menuTitle = title;
    return this;
  }

  /// Set custom owner
  RealtimeMenuBuilder withOwner(String ownerId, String displayName) {
    this.ownerId = ownerId;
    ownerDisplayName = displayName;

    // Update last edited if owner was last editor
    if (lastEditedBy == this.ownerId) {
      lastEditedBy = ownerId;
      lastEditedByDisplayName = displayName;
    }

    return this;
  }

  /// Add a participant with specific permission
  RealtimeMenuBuilder withParticipant(
    String userId,
    ResourcePermission permission,
  ) {
    participants[userId] = permission;
    return this;
  }

  /// Set menu categories with recipes
  RealtimeMenuBuilder withCategories(Map<String, List<Recipe>> categories) {
    menuSnapshot = categories;
    return this;
  }

  /// Add a single category with recipes
  RealtimeMenuBuilder withCategory(String categoryName, List<Recipe> recipes) {
    menuSnapshot[categoryName] = recipes;
    return this;
  }

  /// Set menu notes
  RealtimeMenuBuilder withNotes(String notes) {
    menuNotes = notes;
    return this;
  }

  /// Set favorite recipe IDs
  RealtimeMenuBuilder withFavorites(List<String> recipeIds) {
    favoriteRecipeIds = recipeIds;
    return this;
  }

  /// Set created for date
  RealtimeMenuBuilder withCreatedForDate(DateTime date) {
    createdForDate = date;
    return this;
  }

  /// Set edit count
  RealtimeMenuBuilder withEditCount(int count) {
    editCount = count;
    return this;
  }

  /// Set last edited by
  RealtimeMenuBuilder withLastEditedBy(String userId, String displayName) {
    lastEditedBy = userId;
    lastEditedByDisplayName = displayName;
    lastEditedAt = DateTime.now();
    return this;
  }

  /// Set active status
  RealtimeMenuBuilder withActiveStatus(bool active) {
    isActive = active;
    return this;
  }

  /// Set metadata
  RealtimeMenuBuilder withMetadata(Map<String, dynamic> metadata) {
    this.metadata = metadata;
    return this;
  }

  /// Build the RealtimeMenu instance
  RealtimeMenu build() {
    final menuData = RealtimeMenuData(
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
      participants: participants,
      createdAt: createdAt,
      lastEditedAt: lastEditedAt,
      lastEditedBy: lastEditedBy,
      lastEditedByDisplayName: lastEditedByDisplayName,
      editCount: editCount,
      isActive: isActive,
      metadata: metadata,
      data: menuData,
    );
  }
}

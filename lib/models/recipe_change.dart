/// Comprehensive recipe change tracking model providing detailed change history and audit trail functionality.
/// This model implements sophisticated recipe change management following Single Responsibility Principle,
/// handling all aspects of recipe modification tracking including change type classification, state transitions,
/// and comprehensive audit trail capabilities. It provides essential functionality for real-time collaboration,
/// version control, and change synchronization while maintaining clean separation from recipe data concerns.
/// **Single Responsibility Focus:**
/// This model exclusively handles recipe change tracking and audit operations:
/// - **Change Type Classification**: Comprehensive change categorization with added, modified, and removed states
/// - **Recipe State Tracking**: Complete recipe snapshot management with before/after state preservation
/// - **Audit Trail Support**: Essential data for change history, collaboration tracking, and version management
/// - **Synchronization Integration**: Core data structure for real-time change broadcasting and conflict resolution
/// **What This Model Does NOT Handle:**
/// - Recipe data management and business logic (handled by Recipe models and services)
/// - Change persistence and storage operations (handled by repositories and services)
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Real-time synchronization and broadcasting (handled by synchronization services)
/// **Recipe Change Features:**
/// - **Comprehensive Change Classification**: Complete change type system with granular modification tracking and state transitions
/// - **Recipe Snapshot Management**: Full recipe state preservation for accurate change detection and audit trail maintenance
/// - **Collaboration Support**: Essential infrastructure for real-time collaboration with change conflict resolution and merge capabilities
/// - **Version Control Integration**: Core functionality for recipe versioning, rollback operations, and change history tracking
/// - **Synchronization Optimization**: Efficient change representation for network transmission and real-time updates
/// **Usage Examples:**
/// ```dart
/// // Track recipe addition
/// final addedChange = RecipeChange(
///   type: RecipeChangeType.added,
///   recipe: newRecipe,
/// );
/// // Track recipe modification
/// final modifiedChange = RecipeChange(
///   type: RecipeChangeType.modified,
///   recipe: updatedRecipe,
/// );
/// // Track recipe removal
/// final removedChange = RecipeChange(
///   type: RecipeChangeType.removed,
///   recipe: deletedRecipe,
/// );
/// // Use in change tracking systems
/// final changes = <RecipeChange>[
///   RecipeChange(type: RecipeChangeType.added, recipe: recipe1),
///   RecipeChange(type: RecipeChangeType.modified, recipe: recipe2),
///   RecipeChange(type: RecipeChangeType.removed, recipe: recipe3),
/// ];
/// // Apply changes to collaborative systems
/// await collaborationService.broadcastChanges(changes);
/// await versionControlService.recordChanges(changes);
/// ```

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Enumeration defining the different types of recipe changes for comprehensive change tracking.
/// Recipe change types categorize modifications for accurate tracking and synchronization:
/// - [added] - New recipe creation with complete recipe data initialization
/// - [modified] - Existing recipe update with partial or complete data changes
/// - [removed] - Recipe deletion with final state preservation for audit trails
enum RecipeChangeType {
  /// Recipe creation with new data initialization
  added,

  /// Recipe modification with existing data updates
  modified,

  /// Recipe deletion with state preservation for audit
  removed
}

/// Comprehensive recipe change tracking model with audit trail and collaboration support.
/// Represents a complete recipe change with classification, state data, and metadata
/// for accurate change tracking, version control, and real-time collaboration systems.
class RecipeChange {
  /// Type of change performed on the recipe.
  /// Categorizes the modification for proper handling in synchronization,
  /// audit trails, and collaboration systems with accurate state management.
  final RecipeChangeType type;

  /// Complete recipe state at the time of change.
  /// Preserves the full recipe data for accurate change tracking, version control,
  /// and audit trail maintenance with complete state information.
  final Recipe recipe;

  /// Creates a new recipe change tracking instance with type classification and recipe state.
  /// [type] The category of change performed (added, modified, removed)
  /// [recipe] Complete recipe state at the time of change for audit trail preservation
  RecipeChange({
    required this.type,
    required this.recipe,
  });

  /// Utility methods for change analysis and processing.

  /// Checks if this change represents a recipe addition operation.
  /// Returns true when the change type indicates new recipe creation,
  /// useful for filtering and processing addition-specific operations.
  bool get isAddition => type == RecipeChangeType.added;

  /// Checks if this change represents a recipe modification operation.
  /// Returns true when the change type indicates existing recipe updates,
  /// useful for filtering and processing modification-specific operations.
  bool get isModification => type == RecipeChangeType.modified;

  /// Checks if this change represents a recipe removal operation.
  /// Returns true when the change type indicates recipe deletion,
  /// useful for filtering and processing removal-specific operations.
  bool get isRemoval => type == RecipeChangeType.removed;

  /// Gets the unique identifier of the affected recipe.
  /// Provides convenient access to the recipe ID for indexing, lookup,
  /// and correlation operations in change tracking systems.
  String get recipeId => recipe.id;

  /// Gets a descriptive Swedish text representation of the change type.
  /// Provides localized change descriptions for Swedish users with natural
  /// language formatting for user interface display and notifications.
  /// Returns Swedish change descriptions: 'Tillagd', 'Ändrad', 'Borttagen'.
  String get changeTypeText {
    final l = AppLocale.current;
    switch (type) {
      case RecipeChangeType.added:
        return l.changeTypeAdded;
      case RecipeChangeType.modified:
        return l.changeTypeModified;
      case RecipeChangeType.removed:
        return l.changeTypeRemoved;
    }
  }

  /// Standard object methods for comparison, debugging, and collection operations.

  /// Returns a string representation of the recipe change for debugging and logging.
  /// Provides essential change information in a readable format for development
  /// and debugging purposes with change type and recipe identification.
  @override
  String toString() {
    return 'RecipeChange(type: $type, recipe: ${recipe.id})';
  }

  /// Compares two recipe changes for equality based on type and recipe identity.
  /// Uses change type and recipe ID for equality comparison ensuring consistent
  /// change identity across different instances of the same change data.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecipeChange &&
        other.type == type &&
        other.recipe.id == recipe.id;
  }

  /// Generates hash code based on change type and recipe identifier.
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and change identification.
  @override
  int get hashCode => Object.hash(type, recipe.id);
}

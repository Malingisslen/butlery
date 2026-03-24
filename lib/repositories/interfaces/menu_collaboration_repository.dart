import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Repository interface for collaborative menu operations.
/// Handles shared menu CRUD, collaboration setup, and real-time listeners.
abstract class MenuCollaborationRepository extends Repository<SharedMenu> {
  /// Enable real-time collaboration for a menu with atomic updates
  Future<bool> enableCollaboration({
    required String menuId,
    required List<String> collaboratorIds,
    Map<String, String>? collaboratorDisplayNames,
  });

  /// Check if user can collaborate on menu based on permissions
  Future<bool> canCollaborate(String menuId, String userId);

  /// Add recipe to collaborative menu using FieldValue operations
  Future<bool> addRecipeToMenu({
    required String menuId,
    required String category,
    required Recipe recipe,
    String? suggestedBy,
    String? suggestion,
  });

  /// Remove recipe from collaborative menu using FieldValue operations
  Future<bool> removeRecipeFromMenu({
    required String menuId,
    required String category,
    required String recipeId,
    String? reason,
  });

  /// Start real-time listener for menu collaboration updates
  void startCollaborationListener(String menuId, Function(SharedMenu) onUpdate);

  /// Stop real-time listener for menu collaboration
  void stopCollaborationListener(String menuId);

  /// Dispose of all active listeners and resources
  void disposeAllListeners();
}

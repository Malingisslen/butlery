import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Repository interface for collaborative menu operations.
/// This interface provides comprehensive menu collaboration functionality including
/// real-time menu sharing, rating systems, commenting, and template management.
/// It serves as the abstraction layer for all collaborative menu data operations,
/// isolating Firebase-specific implementations from business logic.
/// **Core Collaboration Features:**
/// - **Real-time Collaboration**: Enable/disable collaborative editing on menus
/// - **Recipe Management**: Add/remove recipes from collaborative menus with FieldValue operations
/// - **Rating System**: Menu rating and review functionality with statistical tracking
/// - **Comment System**: Threaded menu discussions with likes and real-time streaming
/// - **Template Management**: Menu template creation and usage with increment operations
/// - **Activity Logging**: Collaboration activity tracking and audit trails
/// **Repository Pattern Benefits:**
/// - Abstracts Firebase FieldValue operations (serverTimestamp, arrayUnion, arrayRemove, increment)
/// - Enables clean unit testing without Firebase mocking violations
/// - Supports integration testing with Firebase emulator for FieldValue operations
/// - Maintains clean separation between business logic and data persistence
/// - Enables future data source migration and technology flexibility
/// **Testing Strategy:**
/// - Unit tests mock at repository level using production_mocks.dart
/// - Integration tests use Firebase emulator for FieldValue operations
/// - Follows HYBRID_TESTING_STRATEGY.md guidelines: "Mock at repository level, never mock Firebase directly"
/// **Usage Examples:**
/// ```dart
/// final repo = ServiceLocator.get<MenuCollaborationRepository>();
/// // Enable collaboration
/// final success = await repo.enableCollaboration(
///   menuId: menuId,
///   collaboratorIds: ['user1', 'user2'],
///   collaboratorDisplayNames: {'user1': 'Anna', 'user2': 'Erik'},
/// );
/// // Add recipe collaboratively
/// await repo.addRecipeToMenu(
///   menuId: menuId,
///   category: 'Huvudrätt',
///   recipe: recipe,
///   suggestion: 'Perfekt för söndagsmiddag!',
/// );
/// // Rate menu
/// await repo.rateMenu(menuId: menuId, rating: 5.0, comment: 'Fantastisk!');
/// ```
abstract class MenuCollaborationRepository extends Repository<SharedMenu> {
  /// Enable real-time collaboration for a menu with atomic updates
  /// Abstracts Firebase update operations with collaboration metadata
  /// including serverTimestamp and collaboration settings.
  Future<bool> enableCollaboration({
    required String menuId,
    required List<String> collaboratorIds,
    Map<String, String>? collaboratorDisplayNames,
  });

  /// Check if user can collaborate on menu based on permissions
  /// Validates collaboration permissions by checking menu ownership,
  /// sharing status, and explicit collaborator lists.
  Future<bool> canCollaborate(String menuId, String userId);

  /// Add recipe to collaborative menu using FieldValue operations
  /// Abstracts Firebase arrayUnion and serverTimestamp operations
  /// for adding recipes to categorized menu snapshots.
  Future<bool> addRecipeToMenu({
    required String menuId,
    required String category,
    required Recipe recipe,
    String? suggestedBy,
    String? suggestion,
  });

  /// Remove recipe from collaborative menu using FieldValue operations
  /// Abstracts Firebase arrayRemove and serverTimestamp operations
  /// for removing recipes from categorized menu snapshots.
  Future<bool> removeRecipeFromMenu({
    required String menuId,
    required String category,
    required String recipeId,
    String? reason,
  });

  /// Rate a menu with timestamp and user tracking
  /// Abstracts Firebase collection operations for menu ratings
  /// with serverTimestamp and user identification.
  Future<bool> rateMenu({
    required String menuId,
    required double rating,
    String? comment,
  });

  /// Get all ratings for a menu ordered by timestamp
  /// Retrieves rating collection data with user information
  /// and chronological ordering for analytics.
  Future<List<Map<String, dynamic>>> getMenuRatings(String menuId);

  /// Calculate and return average rating for a menu
  /// Computes statistical average from rating collection
  /// with proper handling of empty data sets.
  Future<double> getMenuAverageRating(String menuId);

  /// Update menu's cached average rating and count
  /// Abstracts Firebase update operations for denormalized
  /// rating statistics on menu documents.
  Future<void> updateMenuRatingStatistics(String menuId);

  /// Add comment to menu with threading support
  /// Abstracts Firebase collection operations for comments
  /// with serverTimestamp and reply thread management.
  Future<bool> addMenuComment({
    required String menuId,
    required String comment,
    String? replyToCommentId,
  });

  /// Get real-time comments stream for a menu
  /// Provides Firebase snapshots stream for live comment updates
  /// with chronological ordering and metadata inclusion.
  Stream<List<Map<String, dynamic>>> getMenuCommentsStream(String menuId);

  /// Toggle like/unlike status on a comment
  /// Abstracts Firebase atomic operations for like counting
  /// and user tracking with concurrent modification safety.
  Future<bool> toggleCommentLike({
    required String menuId,
    required String commentId,
  });

  /// Create menu template with metadata and usage tracking
  /// Abstracts Firebase document creation with template metadata,
  /// serverTimestamp, and initialization of usage statistics.
  Future<String?> createMenuTemplate({
    required String templateName,
    required Map<String, List<Recipe>> menuSnapshot,
    String? description,
    List<String>? tags,
  });

  /// Get user's menu templates
  /// Returns templates owned by the current user from Firestore.
  Future<List<Map<String, dynamic>>> getUserMenuTemplates();

  /// Delete a menu template by ID
  /// Only the owner can delete their template.
  Future<bool> deleteMenuTemplate(String templateId);

  /// Create menu from template with usage increment
  /// Abstracts template retrieval, menu creation, and Firebase
  /// increment operations for template usage statistics.
  Future<String?> createMenuFromTemplate({
    required String templateId,
    required String menuTitle,
    List<String>? sharedToUserIds,
    String? shareMessage,
    bool enableCollaboration = false,
  });

  /// Log collaboration activity for audit and analytics
  /// Abstracts Firebase subcollection operations for activity
  /// tracking with serverTimestamp and structured metadata.
  Future<void> logMenuActivity({
    required String menuId,
    required Map<String, dynamic> activity,
    required String userId,
    required String userDisplayName,
  });

  /// Start real-time listener for menu collaboration updates
  /// Abstracts Firebase snapshot listeners for live collaboration
  /// features with proper subscription management.
  void startCollaborationListener(String menuId, Function(SharedMenu) onUpdate);

  /// Stop real-time listener for menu collaboration
  /// Manages Firebase subscription lifecycle and resource cleanup
  /// for collaboration listeners.
  void stopCollaborationListener(String menuId);

  /// Dispose of all active listeners and resources
  /// Comprehensive cleanup of Firebase subscriptions and
  /// collaboration state for proper resource management.
  void disposeAllListeners();
}

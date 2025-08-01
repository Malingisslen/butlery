import 'dart:async';
import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_change.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

/// Repository interface for recipe data operations and management.
///
/// This interface extends the base Repository pattern to provide specialized
/// recipe data operations including real-time synchronization, user-specific
/// querying, and archive access. It manages recipe data persistence, retrieval,
/// and real-time updates for the Butlery recipe management system.
///
/// **Key Recipe Operations:**
/// - **Personal Recipes**: CRUD operations for user-owned recipes
/// - **Recipe Streaming**: Real-time updates for recipe collections
/// - **Search Functionality**: Text-based recipe search capabilities
/// - **Batch Operations**: Efficient bulk recipe operations
/// - **Archive Access**: Public recipe repository integration
/// - **Change Tracking**: Real-time change notifications for collaborative features
///
/// **Real-time Features:**
/// The repository supports real-time recipe synchronization through Firebase
/// streams, enabling collaborative editing, live updates, and instant
/// synchronization across multiple devices and users.
///
/// **Archive Integration:**
/// Provides access to the public recipe archive, allowing users to discover
/// and import community-shared recipes while maintaining separation between
/// personal and public recipe collections.
///
/// **Performance Considerations:**
/// - Implements efficient querying with user-specific filters
/// - Supports real-time streaming with memory management
/// - Optimizes batch operations for bulk recipe imports
/// - Provides search functionality with appropriate indexing
///
/// **Usage Examples:**
/// ```dart
/// final recipeRepo = ServiceLocator.get<RecipeRepository>();
/// 
/// // Watch user's recipes in real-time
/// recipeRepo.watchRecipes(userId).listen((recipes) {
///   updateRecipeList(recipes);
/// });
/// 
/// // Subscribe to recipe changes for collaboration
/// recipeRepo.subscribeToUserRecipes(userId, (changes) {
///   for (final change in changes) {
///     handleRecipeChange(change);
///   }
/// });
/// 
/// // Search and import from archive
/// final archiveRecipes = await recipeRepo.fetchArchiveRecipes();
/// final selectedRecipe = await recipeRepo.fetchArchiveRecipe(recipeId);
/// await recipeRepo.create(selectedRecipe.copyWith(ownerId: currentUserId));
/// ```
abstract class RecipeRepository extends Repository<Recipe> with StreamManagementMixin {
  /// Provides a real-time stream of all recipes belonging to the specified user.
  ///
  /// Returns a [Stream] that emits updated recipe lists whenever recipes are
  /// added, modified, or removed for the given user. This enables reactive UI
  /// updates and real-time synchronization across multiple app instances.
  ///
  /// [userId] The unique identifier of the user whose recipes to watch
  ///
  /// Returns [Stream<List<Recipe>>] that emits recipe list updates
  ///
  /// **Stream Characteristics:**
  /// - Emits immediately with current recipes when subscribed
  /// - Continues emitting updates throughout the subscription lifecycle
  /// - Automatically handles Firestore connection management
  /// - Filters recipes to only include those owned by the specified user
  ///
  /// **Memory Management:**
  /// Remember to cancel stream subscriptions when no longer needed to prevent
  /// memory leaks and unnecessary network traffic.
  ///
  /// Example:
  /// ```dart
  /// late StreamSubscription subscription;
  /// subscription = recipeRepo.watchRecipes(currentUserId).listen(
  ///   (recipes) {
  ///     if (mounted) setState(() {
  ///       userRecipes = recipes;
  ///     });
  ///   },
  ///   onError: (error) => handleRecipeStreamError(error),
  /// );
  /// 
  /// // Don't forget to cancel
  /// @override
  /// void dispose() {
  ///   subscription.cancel();
  ///   super.dispose();
  /// }
  /// ```
  Stream<List<Recipe>> watchRecipes(String userId);

  /// Subscribes to real-time recipe change notifications for collaborative features.
  ///
  /// Establishes a subscription to recipe change events for the specified user,
  /// providing detailed information about what changed, when, and by whom. This
  /// is essential for collaborative editing features and conflict resolution.
  ///
  /// [userId] The unique identifier of the user whose recipe changes to monitor
  /// [onData] Callback function that receives lists of [RecipeChange] objects
  /// [onError] Optional error handler for subscription failures
  ///
  /// Returns [StreamSubscription] that can be cancelled to stop receiving updates
  ///
  /// **Change Tracking Details:**
  /// Each [RecipeChange] contains:
  /// - Change type (added, modified, removed)
  /// - Recipe ID and affected data
  /// - Timestamp of the change
  /// - User who made the change (for collaborative contexts)
  ///
  /// **Collaborative Use Cases:**
  /// - Real-time editing notifications
  /// - Conflict detection and resolution
  /// - Activity feeds and change history
  /// - Synchronization status indicators
  ///
  /// Example:
  /// ```dart
  /// final subscription = recipeRepo.subscribeToUserRecipes(
  ///   userId,
  ///   (changes) {
  ///     for (final change in changes) {
  ///       switch (change.type) {
  ///         case ChangeType.added:
  ///           showNotification('New recipe: ${change.recipe.title}');
  ///           break;
  ///         case ChangeType.modified:
  ///           handleRecipeUpdate(change);
  ///           break;
  ///         case ChangeType.removed:
  ///           removeRecipeFromUI(change.recipeId);
  ///           break;
  ///       }
  ///     }
  ///   },
  ///   onError: (error) => handleSubscriptionError(error),
  /// );
  /// ```
  StreamSubscription subscribeToUserRecipes(
    String userId,
    void Function(List<RecipeChange>) onData, {
    Function? onError,
  });

  /// Searches through the current user's recipes using the provided query.
  ///
  /// Performs a text-based search across recipe titles, descriptions, ingredients,
  /// and other searchable fields within the current user's recipe collection.
  /// The search is case-insensitive and supports partial matches.
  ///
  /// [query] The search text to match against recipe content
  ///
  /// Returns [List<Recipe>] containing recipes that match the search criteria
  ///
  /// **Search Scope:**
  /// - Recipe titles and descriptions
  /// - Ingredient names and quantities
  /// - Recipe tags and categories
  /// - Cooking instructions (optional, based on implementation)
  ///
  /// **Search Behavior:**
  /// - Case-insensitive matching
  /// - Partial word matching
  /// - Results ordered by relevance
  /// - Empty query returns empty results
  ///
  /// **Performance Note:**
  /// Search performance depends on collection size and indexing strategy.
  /// Consider implementing client-side caching for frequently accessed recipes.
  ///
  /// Example:
  /// ```dart
  /// final searchResults = await recipeRepo.searchRecipes('chicken pasta');
  /// if (searchResults.isNotEmpty) {
  ///   displaySearchResults(searchResults);
  /// } else {
  ///   showNoResultsMessage();
  /// }
  /// 
  /// // Search with user feedback
  /// final query = searchController.text.trim();
  /// if (query.length >= 2) {
  ///   final results = await recipeRepo.searchRecipes(query);
  ///   updateSearchResultsUI(results);
  /// }
  /// ```
  Future<List<Recipe>> searchRecipes(String query);

  /// Adds multiple recipes to the repository in a single batch operation.
  ///
  /// Efficiently creates multiple recipes simultaneously, which is useful for
  /// bulk imports, recipe sharing, or migrating recipe collections. This method
  /// should use batch operations to minimize network requests and ensure
  /// atomicity where possible.
  ///
  /// [recipes] List of recipe objects to create in the repository
  ///
  /// Throws [ValidationException] if any recipe data is invalid
  /// Throws [StorageException] if the batch operation fails
  ///
  /// **Batch Operation Benefits:**
  /// - Reduced network overhead compared to individual creates
  /// - Better performance for large recipe collections
  /// - Atomic operations where supported by the backend
  /// - Consistent error handling for the entire batch
  ///
  /// **Use Cases:**
  /// - Importing recipes from external sources
  /// - Sharing recipe collections between users
  /// - Migrating data during app updates
  /// - Restoring recipes from backups
  ///
  /// Example:
  /// ```dart
  /// final importedRecipes = await parseRecipeFile(file);
  /// try {
  ///   await recipeRepo.addRecipes(importedRecipes);
  ///   showSuccess('${importedRecipes.length} recipes imported successfully');
  /// } catch (e) {
  ///   showError('Failed to import recipes: $e');
  /// }
  /// 
  /// // Progress tracking for large batches
  /// final batches = chunk(recipes, 10); // Process in batches of 10
  /// for (int i = 0; i < batches.length; i++) {
  ///   await recipeRepo.addRecipes(batches[i]);
  ///   updateProgress((i + 1) / batches.length);
  /// }
  /// ```
  Future<void> addRecipes(List<Recipe> recipes);

  /// Retrieves all recipes from the public recipe archive.
  ///
  /// Accesses the community-shared recipe collection that contains publicly
  /// available recipes contributed by users. These recipes can be viewed,
  /// imported, and adapted by any user of the application.
  ///
  /// Returns [List<Recipe>] containing all publicly available archive recipes
  ///
  /// Throws [StorageException] if archive access fails
  /// Throws [NetworkException] if network connectivity issues occur
  ///
  /// **Archive Characteristics:**
  /// - Curated collection of community-shared recipes
  /// - Read-only access for browsing and importing
  /// - Regularly updated with new community contributions
  /// - Separate from personal recipe collections
  ///
  /// **Performance Considerations:**
  /// Archive collections can be large. Consider implementing:
  /// - Pagination for large datasets
  /// - Caching strategies for offline access
  /// - Progressive loading for better user experience
  ///
  /// **Import Workflow:**
  /// Recipes from the archive should be copied to the user's personal
  /// collection rather than referenced directly to allow customization.
  ///
  /// Example:
  /// ```dart
  /// // Load archive recipes with loading state
  /// if (mounted) setState(() { isLoadingArchive = true; });
  /// try {
  ///   final archiveRecipes = await recipeRepo.fetchArchiveRecipes();
  ///   if (mounted) setState(() {
  ///     availableRecipes = archiveRecipes;
  ///     isLoadingArchive = false;
  ///   });
  /// } catch (e) {
  ///   handleArchiveError(e);
  ///   if (mounted) setState(() { isLoadingArchive = false; });
  /// }
  /// 
  /// // Import selected recipe
  /// final selectedRecipe = archiveRecipes[index];
  /// final personalRecipe = selectedRecipe.copyWith(
  ///   id: null, // Generate new ID
  ///   ownerId: currentUserId,
  ///   createdAt: DateTime.now(),
  /// );
  /// await recipeRepo.create(personalRecipe);
  /// ```
  Future<List<Recipe>> fetchArchiveRecipes();

  /// Retrieves a specific recipe from the public archive by its identifier.
  ///
  /// Fetches a single recipe from the community archive using its unique ID.
  /// This is useful for direct recipe access via links, sharing, or when
  /// displaying detailed recipe information from the archive.
  ///
  /// [id] The unique identifier of the archive recipe to retrieve
  ///
  /// Returns [Recipe] object from the archive
  ///
  /// Throws [RecipeNotFoundException] if the recipe doesn't exist in the archive
  /// Throws [StorageException] if archive access fails
  ///
  /// **Direct Access Use Cases:**
  /// - Deep linking to specific archive recipes
  /// - Recipe sharing via archive IDs
  /// - Detailed recipe preview before importing
  /// - Recipe recommendation systems
  ///
  /// **Security Note:**
  /// Archive recipes are publicly accessible and don't require authentication.
  /// However, validate the recipe ID format to prevent injection attacks.
  ///
  /// Example:
  /// ```dart
  /// // Handle deep link to archive recipe
  /// try {
  ///   final recipe = await recipeRepo.fetchArchiveRecipe(recipeId);
  ///   showRecipePreview(recipe);
  /// } on RecipeNotFoundException {
  ///   showError('Recipe not found in archive');
  /// } catch (e) {
  ///   showError('Failed to load recipe: $e');
  /// }
  /// 
  /// // Preview before import
  /// final archiveRecipe = await recipeRepo.fetchArchiveRecipe(id);
  /// final shouldImport = await showImportDialog(archiveRecipe);
  /// if (shouldImport) {
  ///   final personalRecipe = archiveRecipe.copyWith(
  ///     ownerId: currentUserId,
  ///     importedFrom: id,
  ///   );
  ///   await recipeRepo.create(personalRecipe);
  /// }
  /// ```
  Future<Recipe> fetchArchiveRecipe(String id);

  /// Retrieves all recipes owned by the specified user.
  ///
  /// Fetches a complete list of recipes belonging to the given user ID. This
  /// is a one-time fetch operation (as opposed to the streaming [watchRecipes]
  /// method) useful for data export, migration, or when real-time updates
  /// are not required.
  ///
  /// [userId] The unique identifier of the user whose recipes to fetch
  ///
  /// Returns [List<Recipe>] containing all recipes owned by the user
  ///
  /// Throws [StorageException] if the fetch operation fails
  ///
  /// **Use Cases:**
  /// - Data export and backup operations
  /// - Recipe migration between accounts
  /// - Analytics and reporting
  /// - One-time recipe loading for caching
  ///
  /// **Performance Considerations:**
  /// This method loads all recipes at once, which may impact performance
  /// for users with large recipe collections. Consider:
  /// - Implementing pagination for large datasets
  /// - Using [watchRecipes] for real-time UI updates
  /// - Caching results for frequently accessed users
  ///
  /// **Comparison with watchRecipes:**
  /// - [fetchUserRecipes]: One-time fetch, no ongoing updates
  /// - [watchRecipes]: Real-time stream, continuous updates
  ///
  /// Example:
  /// ```dart
  /// // Export user's recipes
  /// final allRecipes = await recipeRepo.fetchUserRecipes(userId);
  /// final exportData = RecipeExporter.exportToJson(allRecipes);
  /// await saveToFile(exportData);
  /// 
  /// // Cache user recipes for offline access
  /// final recipes = await recipeRepo.fetchUserRecipes(currentUserId);
  /// await cacheManager.storeRecipes(recipes);
  /// 
  /// // Migration scenario
  /// final oldUserRecipes = await recipeRepo.fetchUserRecipes(oldUserId);
  /// final migratedRecipes = oldUserRecipes.map(
  ///   (recipe) => recipe.copyWith(ownerId: newUserId),
  /// ).toList();
  /// await recipeRepo.addRecipes(migratedRecipes);
  /// ```
  Future<List<Recipe>> fetchUserRecipes(String userId);
}

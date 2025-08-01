/// Comprehensive shared recipe model providing advanced recipe sharing and collaboration capabilities.
///
/// This model implements sophisticated individual recipe sharing functionality following Single Responsibility Principle,
/// handling all aspects of recipe distribution including complete recipe snapshots, permission management,
/// collaboration features, and comprehensive user interaction analytics. It provides complete recipe sharing
/// capabilities while maintaining clean separation from recipe creation and menu management concerns.
///
/// **Single Responsibility Focus:**
/// This model exclusively handles shared recipe management and tracking:
/// - **Complete Recipe Snapshots**: Full recipe preservation with all data for independent sharing and offline access
/// - **Collaboration Features**: Advanced collaboration settings with granular permission management and edit modes
/// - **Engagement Analytics**: Comprehensive tracking of views, imports, and user interactions with detailed metrics
/// - **Attribution Management**: Proper recipe attribution and import handling with source acknowledgment
///
/// **What This Model Does NOT Handle:**
/// - Recipe creation and editing operations (handled by recipe services and builders)
/// - Menu composition and management (handled by menu models and services)
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Recipe persistence and storage operations (handled by repositories and services)
///
/// **Shared Recipe Features:**
/// - **Complete Recipe Snapshots**: Full recipe preservation with all ingredients, instructions, and metadata for independent sharing
/// - **Advanced Collaboration**: Team-based recipe sharing with collaborative editing and permission-based access control
/// - **Flexible Sharing Scopes**: Individual, multiple recipient, and friends-based sharing with automatic scope detection
/// - **Attribution Management**: Proper source attribution for imported recipes with creator acknowledgment
/// - **Comprehensive Analytics**: Complete engagement tracking with view counts, import statistics, and user interaction metrics
///
/// **Usage Examples:**
/// ```dart
/// // Create new shared recipe with collaboration
/// final sharedRecipe = SharedRecipe.create(
///   originalRecipeId: recipeId,
///   sharedByUserId: currentUserId,
///   sharedByDisplayName: 'Anna Andersson',
///   sharedToUserIds: [friend1Id, friend2Id],
///   shareMessage: 'Hoppas ni gillar det här familjerecept!',
///   allowImport: true,
///   allowCollaboration: true,
///   recipeSnapshot: originalRecipe,
/// );
/// 
/// // Track user engagement
/// final viewedRecipe = sharedRecipe.markViewedBy(userId);
/// final importedRecipe = viewedRecipe.markImportedBy(userId);
/// 
/// // Handle user dismissal
/// final dismissedRecipe = sharedRecipe.markDismissedBy(userId);
/// final restoredRecipe = dismissedRecipe.undismissBy(userId);
/// 
/// // Check permissions and edit modes
/// final canView = sharedRecipe.canBeViewedBy(userId);
/// final editMode = sharedRecipe.getEditModeFor(userId);
/// final permission = sharedRecipe.permission;
/// 
/// // Create attributed import
/// final importedRecipe = sharedRecipe.createImportRecipe(
///   newOwnerId: currentUserId,
/// );
/// ```

// lib/models/shared_recipe.dart

import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart'; // För debugPrint
import 'package:butlery/models/recipe_unified.dart'; // Import unified Recipe model
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

/// Enumeration defining the scope of recipe sharing for distribution categorization.
///
/// Share scopes determine the distribution pattern and recipient management:
/// - [individual] - Recipe shared with a specific person for direct personal sharing
/// - [multiple] - Recipe shared with multiple specific recipients for group distribution
/// - [friends] - Recipe shared with all friends (future feature for broad social sharing)
enum ShareScope {
  individual, // Delad till specifik person
  multiple, // Delad till flera personer
  friends, // Delad till alla vänner (framtida feature)
}

/// Comprehensive shared recipe model with complete recipe snapshots and collaboration features.
///
/// Represents a complete shared recipe with all associated metadata including recipe snapshots,
/// engagement analytics, collaboration settings, and comprehensive user interaction tracking.
class SharedRecipe {
  /// Unique identifier for this shared recipe instance.
  final String id;
  
  /// Reference identifier to the original recipe for tracking and linking.
  ///
  /// Maintains connection to the source recipe for updates and attribution.
  final String originalRecipeId; // Reference to original recipe
  
  /// User identifier of the recipe owner who initiated sharing.
  ///
  /// References the user who created and is sharing the recipe.
  final String sharedByUserId; // Who shared it
  
  /// Cached display name of the recipe owner for UI performance.
  ///
  /// Stored locally to avoid additional user profile lookups during recipe display.
  final String sharedByDisplayName; // Cache for performance
  
  /// List of user IDs that the recipe is shared with.
  ///
  /// Enables direct user-to-user recipe sharing with individual targeting.
  final List<String> sharedToUserIds; // Who received it
  
  /// Timestamp when the recipe was originally shared.
  ///
  /// Used for chronological tracking and time-based analytics.
  final DateTime sharedAt;
  
  /// Optional personal message included with the recipe share.
  ///
  /// Allows for custom communication and context for the recipe sharing.
  final String? shareMessage; // Optional message with share
  
  /// Scope of the recipe sharing for distribution categorization.
  ///
  /// Controls the sharing pattern and recipient management approach.
  final ShareScope scope;
  
  /// Flag indicating whether recipients can import or copy the recipe.
  ///
  /// Controls recipe duplication permissions for recipient usage.
  final bool allowImport; // Can recipients import/copy
  
  /// Flag indicating whether collaborative editing is allowed.
  ///
  /// Controls whether recipients can participate in collaborative recipe editing.
  final bool allowCollaboration; // 🆕 Can recipients edit collaboratively
  
  /// Total number of times the recipe has been viewed.
  ///
  /// Engagement metric for tracking recipe popularity and reach.
  final int viewCount; // How many times viewed
  
  /// Total number of times the recipe has been imported by users.
  ///
  /// Conversion metric for tracking recipe adoption and usefulness.
  final int importCount; // How many times imported
  
  /// List of user IDs who have viewed the shared recipe.
  ///
  /// Detailed engagement tracking for user-specific analytics and permissions.
  final List<String> viewedByUserIds; // Who has viewed
  
  /// List of user IDs who have imported the shared recipe.
  ///
  /// Conversion tracking for measuring recipe adoption and user engagement.
  final List<String> importedByUserIds; // Who has imported
  
  /// List of user IDs who have dismissed the recipe from their list.
  ///
  /// User preference tracking for managing recipe visibility and reducing noise.
  final List<String> dismissedByUserIds; // 🆕 Who has dismissed it from their list

  /// Complete snapshot of the recipe at the time of sharing.
  ///
  /// Preserves the entire recipe state including all data for independent sharing
  /// and offline access without dependencies on the original recipe.
  final Recipe recipeSnapshot; // Copy of recipe at time of sharing

  /// Creates a new shared recipe with all required metadata and calculated statistics.
  ///
  /// This constructor provides comprehensive shared recipe initialization with proper defaults
  /// and validation for all sharing aspects including engagement tracking, permission management,
  /// and complete recipe snapshot preservation with Swedish localization support.
  ///
  /// [id] Unique identifier for the shared recipe instance
  /// [originalRecipeId] Reference to the source recipe for tracking and linking
  /// [sharedByUserId] User identifier of the recipe owner who initiated sharing
  /// [sharedByDisplayName] Cached display name for UI performance optimization
  /// [sharedToUserIds] List of users to share the recipe with for direct targeting
  /// [sharedAt] Sharing timestamp, defaults to current time for chronological tracking
  /// [shareMessage] Optional personal message for sharing context and communication
  /// [scope] Distribution scope, defaults to individual for single recipient sharing
  /// [allowImport] Import permission flag, defaults to true for maximum utility
  /// [allowCollaboration] Collaboration permission flag, defaults to false for security
  /// [viewCount] Initial view count, defaults to 0 for new recipe sharing
  /// [importCount] Initial import count, defaults to 0 for new recipe sharing
  /// [viewedByUserIds] Initial list of viewers, defaults to empty for new sharing
  /// [importedByUserIds] Initial list of importers, defaults to empty for new sharing
  /// [dismissedByUserIds] Initial list of users who dismissed the recipe, defaults to empty
  /// [recipeSnapshot] Complete recipe data preserved at time of sharing for independence
  SharedRecipe({
    required this.id,
    required this.originalRecipeId,
    required this.sharedByUserId,
    required this.sharedByDisplayName,
    required this.sharedToUserIds,
    DateTime? sharedAt,
    this.shareMessage,
    this.scope = ShareScope.individual,
    this.allowImport = true,
    this.allowCollaboration = false, // Default: ej kollaborativ
    this.viewCount = 0,
    this.importCount = 0,
    this.viewedByUserIds = const [],
    this.importedByUserIds = const [],
    this.dismissedByUserIds = const [], // Default tom lista
    required this.recipeSnapshot,
  }) : sharedAt = sharedAt ?? DateTime.now();

  /// Factory constructor for creating new shared recipes with auto-generated ID and intelligent defaults.
  ///
  /// Creates a new shared recipe with automatic ID generation, intelligent scope determination,
  /// and current timestamp initialization. This factory provides convenient recipe sharing
  /// creation with automatic configuration based on recipient count and sharing patterns.
  ///
  /// [originalRecipeId] Reference identifier to the source recipe for tracking
  /// [sharedByUserId] User identifier of the recipe owner initiating sharing
  /// [sharedByDisplayName] Display name for caching and UI performance optimization
  /// [sharedToUserIds] List of users to share the recipe with for distribution
  /// [shareMessage] Optional personal message for sharing context and communication
  /// [scope] Optional sharing scope, auto-determined based on recipient count if not provided
  /// [allowImport] Import permission flag, defaults to true for maximum recipe utility
  /// [allowCollaboration] Collaboration permission flag, defaults to false for content security
  /// [recipeSnapshot] Complete recipe data to preserve at time of sharing for independence
  ///
  /// Returns a new [SharedRecipe] instance with generated ID, current timestamp, and determined scope.
  ///
  /// **Scope Determination Logic:**
  /// - Single recipient (length = 1): [ShareScope.individual] for direct personal sharing
  /// - Multiple recipients (length > 1): [ShareScope.multiple] for group distribution
  /// - Custom scope: Uses provided scope parameter when explicitly specified
  factory SharedRecipe.create({
    required String originalRecipeId,
    required String sharedByUserId,
    required String sharedByDisplayName,
    required List<String> sharedToUserIds,
    String? shareMessage,
    ShareScope? scope,
    bool allowImport = true,
    bool allowCollaboration = false, // NY: Kollaborationsinställning
    required Recipe recipeSnapshot,
  }) {
    // Determine scope based on number of recipients
    final determinedScope = scope ??
        (sharedToUserIds.length == 1
            ? ShareScope.individual
            : ShareScope.multiple);

    return SharedRecipe(
      id: const Uuid().v4(),
      originalRecipeId: originalRecipeId,
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedToUserIds: sharedToUserIds,
      sharedAt: DateTime.now(),
      shareMessage: shareMessage,
      scope: determinedScope,
      allowImport: allowImport,
      allowCollaboration: allowCollaboration, // Skicka vidare parametern
      recipeSnapshot: recipeSnapshot,
    );
  }

  /// Creates a copy of this shared recipe with updated engagement statistics and settings.
  ///
  /// Used for all recipe modifications while maintaining immutable data patterns and ensuring
  /// consistent state management for engagement tracking, user interaction analytics, and
  /// collaboration settings. This method preserves original sharing metadata while allowing
  /// selective updates to dynamic engagement and permission data.
  ///
  /// [viewCount] Updated total view count for engagement metrics tracking  
  /// [importCount] Updated total import count for conversion metrics analysis
  /// [viewedByUserIds] Updated list of users who have viewed the recipe for engagement tracking
  /// [importedByUserIds] Updated list of users who have imported the recipe for conversion analytics
  /// [dismissedByUserIds] Updated list of users who have dismissed the recipe for preference management
  /// [allowCollaboration] Updated collaboration permission flag for access control modification
  ///
  /// Returns a new [SharedRecipe] instance with updated values while preserving original metadata.
  SharedRecipe copyWith({
    int? viewCount,
    int? importCount,
    List<String>? viewedByUserIds,
    List<String>? importedByUserIds,
    List<String>? dismissedByUserIds, // Lägg till dismiss tracking
    bool? allowCollaboration,
  }) {
    return SharedRecipe(
      id: id,
      originalRecipeId: originalRecipeId,
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedToUserIds: sharedToUserIds,
      sharedAt: sharedAt,
      shareMessage: shareMessage,
      scope: scope,
      allowImport: allowImport,
      allowCollaboration: allowCollaboration ?? this.allowCollaboration,
      viewCount: viewCount ?? this.viewCount,
      importCount: importCount ?? this.importCount,
      viewedByUserIds: viewedByUserIds ?? List.from(this.viewedByUserIds),
      importedByUserIds: importedByUserIds ?? List.from(this.importedByUserIds),
      dismissedByUserIds:
          dismissedByUserIds ?? List.from(this.dismissedByUserIds),
      recipeSnapshot: recipeSnapshot,
    );
  }

  /// Engagement tracking methods for user interaction analytics and recipe sharing insights.

  /// Marks the recipe as viewed by the specified user with engagement tracking and analytics.
  ///
  /// Implements view tracking functionality with duplicate prevention and engagement metrics updates.
  /// If the user has already viewed the recipe, returns the existing recipe unchanged to prevent
  /// duplicate view counting while maintaining consistent engagement analytics.
  ///
  /// [userId] The user identifier who viewed the shared recipe
  ///
  /// Returns a new [SharedRecipe] instance with updated view tracking, or unchanged if already viewed.
  SharedRecipe markViewedBy(String userId) {
    if (viewedByUserIds.contains(userId)) return this;

    return copyWith(
      viewCount: viewCount + 1,
      viewedByUserIds: [...viewedByUserIds, userId],
    );
  }

  /// Marks the recipe as imported by the specified user with conversion tracking and analytics.
  ///
  /// Implements import tracking functionality with duplicate prevention and conversion metrics updates.
  /// If the user has already imported the recipe, returns the existing recipe unchanged to prevent
  /// duplicate import counting while maintaining accurate conversion analytics.
  ///
  /// [userId] The user identifier who imported the shared recipe
  ///
  /// Returns a new [SharedRecipe] instance with updated import tracking, or unchanged if already imported.
  SharedRecipe markImportedBy(String userId) {
    if (importedByUserIds.contains(userId)) return this;

    return copyWith(
      importCount: importCount + 1,
      importedByUserIds: [...importedByUserIds, userId],
    );
  }

  /// Marks the recipe as dismissed by the specified user for personalized recipe filtering.
  ///
  /// Implements dismissal tracking functionality allowing users to hide recipes from their list
  /// without affecting the recipe sharing for other users. Provides duplicate prevention for
  /// clean dismissal state management and user preference tracking.
  ///
  /// [userId] The user identifier who dismissed the shared recipe
  ///
  /// Returns a new [SharedRecipe] instance with updated dismissal tracking, or unchanged if already dismissed.
  SharedRecipe markDismissedBy(String userId) {
    if (dismissedByUserIds.contains(userId)) return this;

    return copyWith(
      dismissedByUserIds: [...dismissedByUserIds, userId],
    );
  }

  /// Restores the recipe to the specified user's list by removing dismissal status.
  ///
  /// Implements dismissal reversal functionality allowing users to restore previously dismissed
  /// recipes to their active sharing list with clean state management and preference restoration.
  ///
  /// [userId] The user identifier who wants to restore the shared recipe
  ///
  /// Returns a new [SharedRecipe] instance with dismissal removed, or unchanged if not dismissed.
  SharedRecipe undismissBy(String userId) {
    if (!dismissedByUserIds.contains(userId)) return this;

    final updatedDismissed = List<String>.from(dismissedByUserIds);
    updatedDismissed.remove(userId);

    return copyWith(
      dismissedByUserIds: updatedDismissed,
    );
  }

  /// Permission validation and user interaction checking methods for recipe sharing control.

  /// Checks if the specified user is a recipient of this shared recipe.
  ///
  /// Provides convenient access to recipient status for permission validation
  /// and UI state management in recipe sharing interfaces.
  ///
  /// [userId] The user identifier to check for recipient status
  ///
  /// Returns true if the user is included in the shared recipe recipients list.
  bool isSharedTo(String userId) => sharedToUserIds.contains(userId);

  /// Checks if the specified user has viewed this shared recipe.
  ///
  /// Provides convenient access to user-specific view status for engagement analytics
  /// and UI state management showing viewed/unviewed recipe states.
  ///
  /// [userId] The user identifier to check for view status
  ///
  /// Returns true if the user has previously viewed the shared recipe.
  bool isViewedBy(String userId) => viewedByUserIds.contains(userId);

  /// Checks if the specified user has imported this shared recipe.
  ///
  /// Provides convenient access to user-specific import status for conversion tracking
  /// and UI state management showing imported/not imported recipe states.
  ///
  /// [userId] The user identifier to check for import status
  ///
  /// Returns true if the user has previously imported the shared recipe.
  bool isImportedBy(String userId) => importedByUserIds.contains(userId);

  /// Checks if the specified user has dismissed this recipe from their list.
  ///
  /// Provides access to user-specific dismissal status for personalized recipe filtering
  /// and user preference management in recipe sharing interfaces.
  ///
  /// [userId] The user identifier to check for dismissal status
  ///
  /// Returns true if the user has dismissed the recipe from their active list.
  bool isDismissedBy(String userId) => dismissedByUserIds.contains(userId);

  /// Checks if the current authenticated user has dismissed this recipe.
  ///
  /// Provides convenient access to current user's dismissal status for UI state management
  /// without requiring explicit user ID parameter for authenticated user interactions.
  ///
  /// Returns true if the current user has dismissed the recipe, false if no authenticated user.
  bool get isDismissed {
    final currentUserId = FirebaseAuthRepository().currentUserId;
    if (currentUserId == null) return false;
    return isDismissedBy(currentUserId);
  }

  /// Alias getter for the recipe snapshot to match SharedContentViewModel expectations.
  ///
  /// Provides backward compatibility with existing code that expects a `recipe` property
  /// for accessing the complete recipe data.
  Recipe get recipe => recipeSnapshot;

  /// Checks if the current authenticated user has read/viewed this recipe.
  ///
  /// Provides convenient access to current user's read status for UI state management
  /// determining if the recipe should be marked as read or unread.
  ///
  /// Returns true if the current user has viewed the recipe, false if no authenticated user.
  bool get read {
    final currentUserId = FirebaseAuthRepository().currentUserId;
    if (currentUserId == null) return false;
    return isViewedBy(currentUserId);
  }

  /// Checks if the specified user has permission to view this shared recipe.
  ///
  /// Implements access control by verifying if the user is either the recipe owner
  /// or included in the list of users the recipe was shared with for permission validation.
  ///
  /// [userId] The user identifier to check for view permissions
  ///
  /// Returns true if the user can view the recipe (is owner or recipient).
  bool canBeViewedBy(String userId) {
    return sharedByUserId == userId || isSharedTo(userId);
  }


  /// Recipe attribution and permission management methods for import and collaboration control.

  /// Creates a new recipe with proper attribution for importing shared recipes.
  ///
  /// Implements recipe import functionality with proper source attribution and Swedish localization
  /// for maintaining recipe provenance and giving credit to original recipe owners while creating
  /// independent copies for the importing user.
  ///
  /// [newOwnerId] The user identifier who will own the imported recipe copy
  ///
  /// Returns a new [Recipe] instance with attribution text and reset sharing metadata.
  ///
  /// **Attribution Format:** 'Inspirerat av recept från [SharedByDisplayName]'
  Recipe createImportRecipe({required String newOwnerId}) {
    // Create new recipe with attribution
    final attributionText = 'Inspirerat av recept från $sharedByDisplayName';

    return recipeSnapshot.copyWith(
      // Generate new ID för imported copy
      sourceUrl: attributionText,
      // Reset sharing-specific metadata
    );
  }

  /// Gets the permission level for this shared recipe based on collaboration settings.
  ///
  /// Implements permission mapping from collaboration settings to resource permissions
  /// for access control integration and UI permission validation.
  ///
  /// Returns [ResourcePermission.editor] if collaboration is allowed, [ResourcePermission.viewer] otherwise.
  ResourcePermission get permission {
    if (allowCollaboration) {
      return ResourcePermission.editor;
    } else {
      return ResourcePermission.viewer;
    }
  }

  /// Determines the appropriate edit mode for the specified user based on ownership and permissions.
  ///
  /// Implements comprehensive edit mode determination logic considering user ownership status,
  /// collaboration permissions, and recipient status for appropriate UI and interaction control.
  ///
  /// [userId] The user identifier to determine edit mode for
  ///
  /// Returns appropriate [EditMode] based on user relationship to the shared recipe:
  /// - [EditMode.owner]: Recipe owner can edit original recipe directly
  /// - [EditMode.collaborative]: Recipients with collaboration permission can edit collaboratively  
  /// - [EditMode.readOnlyWithFork]: Recipients without collaboration can view and fork only
  /// - [EditMode.noAccess]: Non-recipients have no access to the recipe
  EditMode getEditModeFor(String userId) {
    if (sharedByUserId == userId) {
      return EditMode.owner; // Ägaren redigerar alltid original
    }

    if (allowCollaboration && sharedToUserIds.contains(userId)) {
      return EditMode.collaborative; // Kollaborativ redigering
    }

    if (sharedToUserIds.contains(userId)) {
      return EditMode.readOnlyWithFork; // Bara läsning + fork
    }

    return EditMode.noAccess;
  }

  /// UI helper methods for Swedish-localized display and recipe sharing analytics.

  /// Gets user-friendly Swedish text for how long ago the recipe was shared.
  ///
  /// Provides localized time-ago display optimized for Swedish users with natural
  /// language formatting for improved user experience and temporal context in recipe sharing.
  ///
  /// Returns Swedish time format: 'Nu', '5 min sedan', '2 tim sedan', '3 dagar sedan', '2 veckor sedan'.
  String get timeAgoText {
    final now = DateTime.now();
    final difference = now.difference(sharedAt);

    if (difference.inMinutes < 1) {
      return 'Nu';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min sedan';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} tim sedan';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dagar sedan';
    } else {
      return '${(difference.inDays / 7).floor()} veckor sedan';
    }
  }

  /// Data persistence and serialization methods for Firestore and caching integration.

  /// Converts the shared recipe to Firestore-compatible format for persistence.
  ///
  /// Transforms all recipe sharing data including complete recipe snapshots into Firestore format
  /// with proper timestamp handling, engagement tracking serialization, and nested object management
  /// for efficient database storage and retrieval.
  ///
  /// Returns a map containing all shared recipe data formatted for Firestore persistence.
  Map<String, dynamic> toFirestore() {
    return {
      'originalRecipeId': originalRecipeId,
      'sharedByUserId': sharedByUserId,
      'sharedByDisplayName': sharedByDisplayName,
      'sharedToUserIds': sharedToUserIds,
      'sharedAt': AppTimestamp.fromDateTime(sharedAt).toFirestore(),
      'shareMessage': shareMessage,
      'scope': scope.name,
      'allowImport': allowImport,
      'allowCollaboration': allowCollaboration,
      'viewCount': viewCount,
      'importCount': importCount,
      'viewedByUserIds': viewedByUserIds,
      'importedByUserIds': importedByUserIds,
      'dismissedByUserIds': dismissedByUserIds, // Spara dismiss data
      'recipeSnapshot': recipeSnapshot.toFirestore(), // Complete recipe snapshot
    };
  }

  /// Creates a shared recipe instance from Firestore repository data with robust error handling.
  ///
  /// Transforms Firestore document data into a complete [SharedRecipe] instance with proper
  /// type conversion, recipe reconstruction, comprehensive error handling, and engagement tracking
  /// deserialization for robust data recovery from database storage.
  ///
  /// [id] Document identifier from Firestore for shared recipe identification
  /// [data] Raw document data from Firestore containing all shared recipe fields
  ///
  /// Returns a new [SharedRecipe] instance with all data properly parsed and validated.
  ///
  /// Throws parsing errors if critical data is malformed or missing required fields.
  factory SharedRecipe.fromMap(String id, Map<String, dynamic> data) {
    try {
      debugPrint('🔍 Parsing SharedRecipe från doc ID: $id');

      // Hantera recipe snapshot reconstruction utan type cast errors
      final recipeData = data['recipeSnapshot'] as Map<String, dynamic>;

      // Skapa Recipe direkt från data istället för att använda mock DocumentSnapshot
      final recipe = Recipe(
        core: RecipeCore(
          id: recipeData['id'] as String? ?? '',
          title: recipeData['title'] as String? ?? 'Untitled Recipe',
          description: recipeData['description'] as String? ?? '',
          ingredients: List<String>.from(recipeData['ingredients'] ?? []),
          instructions: List<String>.from(recipeData['instructions'] ?? []),
          imageUrls: List<String>.from(recipeData['imageUrls'] ?? []),
          mealType: recipeData['mealType'] as String? ?? 'Middag',
          portions: recipeData['portions'] as int?,
          timeMinutes: recipeData['timeMinutes'] as int?,
          rating: (recipeData['rating'] as num?)?.toDouble(),
          tags: List<String>.from(recipeData['tags'] ?? []),
          sourceUrl: recipeData['sourceUrl'] as String?,
          createdAt: _parseTimestamp(recipeData['createdAt']) ?? DateTime.now(),
          updatedAt: _parseTimestamp(recipeData['updatedAt']) ?? DateTime.now(),
          lastCookedAt: _parseTimestamp(recipeData['lastCookedAt']),
        ),
        type: RecipeType.shared, // Mark as shared recipe
      );

      return SharedRecipe(
        id: id,
        originalRecipeId: data['originalRecipeId'] as String? ?? '',
        sharedByUserId: data['sharedByUserId'] as String? ?? '',
        sharedByDisplayName: data['sharedByDisplayName'] as String? ?? '',
        sharedToUserIds: List<String>.from(data['sharedToUserIds'] ?? []),
        sharedAt: _parseTimestamp(data['sharedAt']) ?? DateTime.now(),
        shareMessage: data['shareMessage'] as String?,
        scope: ShareScope.values.firstWhere(
          (s) => s.name == data['scope'],
          orElse: () => ShareScope.individual,
        ),
        allowImport: data['allowImport'] as bool? ?? true,
        allowCollaboration: data['allowCollaboration'] as bool? ?? false,
        viewCount: data['viewCount'] as int? ?? 0,
        importCount: data['importCount'] as int? ?? 0,
        viewedByUserIds: List<String>.from(data['viewedByUserIds'] ?? []),
        importedByUserIds: List<String>.from(data['importedByUserIds'] ?? []),
        dismissedByUserIds: List<String>.from(
            data['dismissedByUserIds'] ?? []), // Läs dismiss data
        recipeSnapshot: recipe,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing SharedRecipe från doc $id: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Helper method for robust timestamp parsing with comprehensive format support.
  ///
  /// Provides universal timestamp parsing capability handling multiple Firestore timestamp formats,
  /// raw epoch data, ISO strings, and native DateTime objects with graceful fallback for
  /// robust data recovery and timestamp normalization.
  ///
  /// [timestamp] Dynamic timestamp data from various sources and formats
  ///
  /// Returns parsed [DateTime] object or null if timestamp is null, with current time fallback for errors.
  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    try {
      if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp is Map) {
        // Handle raw timestamp data from Firestore
        final seconds = timestamp['seconds'] as int?;
        final nanoseconds = timestamp['nanoseconds'] as int? ?? 0;
        if (seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(
              seconds * 1000 + nanoseconds ~/ 1000000);
        }
      } else if (timestamp is int) {
        // Handle milliseconds since epoch
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        // Handle ISO string format
        return DateTime.parse(timestamp);
      }

      debugPrint('⚠️ Unknown timestamp format: ${timestamp.runtimeType}');
      return DateTime.now();
    } catch (e) {
      debugPrint('❌ Error parsing timestamp: $e');
      return DateTime.now();
    }
  }

  /// Converts the shared recipe to JSON format for caching and client-side storage.
  ///
  /// Provides JSON serialization for client-side caching, local storage, and data transfer
  /// with ISO timestamp formatting and complete recipe snapshot serialization for
  /// offline functionality and performance optimization.
  ///
  /// Returns a JSON-compatible map with all shared recipe data properly formatted.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalRecipeId': originalRecipeId,
      'sharedByUserId': sharedByUserId,
      'sharedByDisplayName': sharedByDisplayName,
      'sharedToUserIds': sharedToUserIds,
      'sharedAt': sharedAt.toIso8601String(),
      'shareMessage': shareMessage,
      'scope': scope.name,
      'allowImport': allowImport,
      'allowCollaboration': allowCollaboration,
      'viewCount': viewCount,
      'importCount': importCount,
      'viewedByUserIds': viewedByUserIds,
      'importedByUserIds': importedByUserIds,
      'dismissedByUserIds': dismissedByUserIds, // JSON support för dismiss
      'recipeSnapshot': recipeSnapshot.toJson(),
    };
  }

  /// Creates a shared recipe instance from JSON data for caching and deserialization.
  ///
  /// Transforms JSON cache data into a complete [SharedRecipe] instance with proper
  /// type conversion, engagement tracking deserialization, and recipe reconstruction
  /// for client-side caching and offline functionality support.
  ///
  /// [json] JSON data containing all shared recipe fields and recipe snapshot
  ///
  /// Returns a new [SharedRecipe] instance with all data properly parsed from JSON.
  factory SharedRecipe.fromJson(Map<String, dynamic> json) {
    return SharedRecipe(
      id: json['id'] as String,
      originalRecipeId: json['originalRecipeId'] as String? ?? '',
      sharedByUserId: json['sharedByUserId'] as String? ?? '',
      sharedByDisplayName: json['sharedByDisplayName'] as String? ?? '',
      sharedToUserIds: List<String>.from(json['sharedToUserIds'] ?? []),
      sharedAt: DateTime.parse(json['sharedAt'] as String),
      shareMessage: json['shareMessage'] as String?,
      scope: ShareScope.values.firstWhere(
        (s) => s.name == json['scope'],
        orElse: () => ShareScope.individual,
      ),
      allowImport: json['allowImport'] as bool? ?? true,
      allowCollaboration: json['allowCollaboration'] as bool? ?? false,
      viewCount: json['viewCount'] as int? ?? 0,
      importCount: json['importCount'] as int? ?? 0,
      viewedByUserIds: List<String>.from(json['viewedByUserIds'] ?? []),
      importedByUserIds: List<String>.from(json['importedByUserIds'] ?? []),
      dismissedByUserIds: List<String>.from(
          json['dismissedByUserIds'] ?? []), // JSON parse för dismiss
      recipeSnapshot: Recipe.fromJson(
        json['recipeSnapshot'] as Map<String, dynamic>,
      ),
    );
  }

  /// Standard object methods for debugging, comparison, and identity management.

  /// Returns a string representation of the shared recipe for debugging and logging.
  ///
  /// Provides essential recipe sharing information in a readable format for development
  /// and debugging purposes with recipe title, owner name, and recipient count.
  @override
  String toString() {
    return 'SharedRecipe(id: $id, recipe: ${recipeSnapshot.title}, sharedBy: $sharedByDisplayName, recipients: ${sharedToUserIds.length})';
  }

  /// Compares two shared recipes for equality based on unique identifier.
  ///
  /// Uses recipe sharing ID for equality comparison ensuring consistent object
  /// identity across different instances of the same shared recipe data.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SharedRecipe && other.id == id;
  }

  /// Generates hash code based on unique shared recipe identifier.
  ///
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and recipe identification.
  @override
  int get hashCode => id.hashCode;
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}

/// Comprehensive shared menu model providing advanced menu sharing and collaboration capabilities.
///
/// This model implements sophisticated menu sharing functionality following Single Responsibility Principle,
/// handling all aspects of menu distribution including complete recipe snapshots, engagement tracking,
/// collaboration features, and comprehensive user interaction analytics. It provides complete menu sharing
/// capabilities while maintaining clean separation from menu creation and individual recipe management concerns.
///
/// **Single Responsibility Focus:**
/// This model exclusively handles shared menu management and tracking:
/// - **Complete Menu Snapshots**: Full recipe collection preservation with categorized organization and metadata
/// - **Engagement Analytics**: Comprehensive tracking of views, imports, and user interactions with detailed metrics
/// - **Collaboration Features**: Advanced collaboration settings with permission management and shared editing capabilities
/// - **User Interaction Management**: Complete user state tracking including dismissal and import status management
///
/// **What This Model Does NOT Handle:**
/// - Menu creation and editing operations (handled by menu services and builders)
/// - Individual recipe management and CRUD operations (handled by recipe services)
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Menu persistence and storage operations (handled by repositories and services)
///
/// **Shared Menu Features:**
/// - **Complete Recipe Snapshots**: Full menu preservation with all recipes, categories, and metadata for independent sharing
/// - **Advanced Analytics**: Comprehensive engagement tracking with view counts, import statistics, and user interaction metrics
/// - **Collaboration Support**: Team-based menu sharing with collaboration permissions and shared editing capabilities
/// - **User State Management**: Complete tracking of user interactions including views, imports, and dismissal status
/// - **Swedish Localization**: Complete Swedish language support for menu titles, categories, and user interface elements
///
/// **Usage Examples:**
/// ```dart
/// // Create new shared menu with collaboration
/// final sharedMenu = SharedMenu.create(
///   sharedByUserId: currentUserId,
///   sharedByDisplayName: 'Anna Andersson',
///   sharedToUserIds: [friend1Id, friend2Id],
///   shareMessage: 'Min veckomeny för nästa vecka - hoppas ni gillar den!',
///   menuTitle: 'Annas veckomeny v.45',
///   menuSnapshot: {
///     'Middag': [recipe1, recipe2, recipe3],
///     'Lunch': [recipe4, recipe5],
///     'Frukost': [recipe6],
///   },
///   allowCollaboration: true,
/// );
/// 
/// // Track user engagement
/// final viewedMenu = sharedMenu.markViewedBy(userId);
/// final importedMenu = viewedMenu.markImportedBy(userId);
/// 
/// // Handle user dismissal
/// final dismissedMenu = sharedMenu.markDismissedBy(userId);
/// final restoredMenu = dismissedMenu.undismissBy(userId);
/// 
/// // Check permissions and status
/// final canView = sharedMenu.canBeViewedBy(userId);
/// final shouldShow = sharedMenu.shouldBeShownTo(userId);
/// final canImport = sharedMenu.allowImport;
/// 
/// // Get menu analytics
/// final summary = sharedMenu.menuSummary; // '3 middag, 2 lunch, 1 frukost'
/// final timeAgo = sharedMenu.timeAgoText; // '2 dagar sedan'
/// ```

// lib/models/shared_menu.dart

import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart'; // För debugPrint
import 'package:butlery/models/recipe_unified.dart'; // Import unified Recipe model

/// Comprehensive shared menu model with complete recipe snapshots and collaboration features.
///
/// Represents a complete shared menu with all associated metadata including recipe collections,
/// engagement analytics, collaboration settings, and comprehensive user interaction tracking.
class SharedMenu {
  /// Unique identifier for this shared menu instance.
  final String id;
  
  /// User identifier of the menu owner who initiated sharing.
  ///
  /// References the user who created and is sharing the menu.
  final String sharedByUserId;
  
  /// Cached display name of the menu owner for UI performance.
  ///
  /// Stored locally to avoid additional user profile lookups during menu display.
  final String sharedByDisplayName;
  
  /// List of user IDs that the menu is shared with.
  ///
  /// Enables direct user-to-user menu sharing with individual targeting.
  final List<String> sharedToUserIds;
  
  /// Timestamp when the menu was originally shared.
  ///
  /// Used for chronological tracking and time-based analytics.
  final DateTime sharedAt;
  
  /// Optional personal message included with the menu share.
  ///
  /// Allows for custom communication and context for the menu sharing.
  final String? shareMessage;
  
  /// Title of the shared menu for identification and display.
  ///
  /// User-friendly menu name for organization and UI display purposes.
  final String menuTitle; // e.g., "Marias veckomeny"
  
  /// Complete snapshot of the menu with all recipes organized by category.
  ///
  /// Preserves the entire menu state including all recipes and their categorization
  /// for independent sharing without dependencies on original menu data.
  final Map<String, List<Recipe>> menuSnapshot; // Complete menu copy
  
  /// Cached total recipe count for quick statistics and UI display.
  ///
  /// Pre-calculated count for performance optimization in analytics and displays.
  final int totalRecipeCount; // For quick stats
  
  /// List of category names present in the menu snapshot.
  ///
  /// Extracted category names for quick access and menu organization display.
  final List<String> categories; // ["Middag", "Lunch", etc.]
  
  /// Total number of times the menu has been viewed.
  ///
  /// Engagement metric for tracking menu popularity and reach.
  final int viewCount;
  
  /// Total number of times the menu has been imported by users.
  ///
  /// Conversion metric for tracking menu adoption and usefulness.
  final int importCount;
  
  /// List of user IDs who have viewed the shared menu.
  ///
  /// Detailed engagement tracking for user-specific analytics and permissions.
  final List<String> viewedByUserIds;
  
  /// List of user IDs who have imported the shared menu.
  ///
  /// Conversion tracking for measuring menu adoption and user engagement.
  final List<String> importedByUserIds;
  
  /// List of user IDs who have dismissed the menu from their list.
  ///
  /// User preference tracking for managing menu visibility and reducing noise.
  final List<String> dismissedByUserIds; // 🆕 Who has dismissed it from their list
  
  /// Flag indicating whether collaborative editing is allowed.
  ///
  /// Controls whether recipients can participate in collaborative menu editing.
  final bool allowCollaboration; // 🆕 Kollaborationsinställning för menyer

  /// Creates a new shared menu with all required metadata and calculated statistics.
  ///
  /// [id] Unique identifier for the shared menu instance
  /// [sharedByUserId] User identifier of the menu owner
  /// [sharedByDisplayName] Cached display name for UI performance
  /// [sharedToUserIds] List of users to share the menu with
  /// [sharedAt] Sharing timestamp, defaults to current time
  /// [shareMessage] Optional personal message for context
  /// [menuTitle] Menu title for identification and display
  /// [menuSnapshot] Complete menu with recipes organized by category
  /// [viewedByUserIds] Optional list of users who have viewed the menu
  /// [importedByUserIds] Optional list of users who have imported the menu
  /// [dismissedByUserIds] Optional list of users who have dismissed the menu
  /// [allowCollaboration] Flag for collaborative editing permissions
  SharedMenu({
    required this.id,
    required this.sharedByUserId,
    required this.sharedByDisplayName,
    required this.sharedToUserIds,
    DateTime? sharedAt,
    this.shareMessage,
    required this.menuTitle,
    required this.menuSnapshot,
    List<String>? viewedByUserIds,
    List<String>? importedByUserIds,
    List<String>? dismissedByUserIds, // 🆕 Optional parameter
    this.allowCollaboration = false, // 🆕 Default: ej kollaborativ
  })  : sharedAt = sharedAt ?? DateTime.now(),
        totalRecipeCount = menuSnapshot.values.fold(
          0,
          (totalCount, recipes) => totalCount + recipes.length,
        ),
        categories = menuSnapshot.keys.toList(),
        viewCount = 0,
        importCount = 0,
        viewedByUserIds = viewedByUserIds ?? [],
        importedByUserIds = importedByUserIds ?? [],
        dismissedByUserIds = dismissedByUserIds ?? []; // 🆕 Default tom lista

  /// Factory constructor for creating new shared menus with auto-generated ID.
  ///
  /// Creates a new shared menu with automatic ID generation and default settings.
  /// Automatically generates user-friendly menu title if not provided and initializes
  /// all engagement tracking with empty states for new menu sharing.
  ///
  /// [sharedByUserId] User identifier of the menu owner
  /// [sharedByDisplayName] Display name for caching and UI performance
  /// [sharedToUserIds] List of users to share the menu with
  /// [shareMessage] Optional personal message for sharing context
  /// [menuTitle] Optional custom menu title, auto-generated if not provided
  /// [menuSnapshot] Complete menu with recipes organized by category
  /// [allowCollaboration] Flag for enabling collaborative editing features
  ///
  /// Returns a new [SharedMenu] instance with generated ID and current timestamp.
  factory SharedMenu.create({
    required String sharedByUserId,
    required String sharedByDisplayName,
    required List<String> sharedToUserIds,
    String? shareMessage,
    String? menuTitle,
    required Map<String, List<Recipe>> menuSnapshot,
    bool allowCollaboration = false, // 🆕 Kollaborationsinställning för menyer
  }) {
    final title = menuTitle ?? '${sharedByDisplayName}s veckomeny';

    return SharedMenu(
      id: const Uuid().v4(),
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedToUserIds: sharedToUserIds,
      sharedAt: DateTime.now(),
      shareMessage: shareMessage,
      menuTitle: title,
      menuSnapshot: menuSnapshot,
      allowCollaboration: allowCollaboration, // 🆕 Skicka vidare parametern
    );
  }

  /// Menu modification and engagement tracking methods.

  /// Creates a copy of this shared menu with updated engagement statistics.
  ///
  /// Used for all menu modifications while maintaining immutable data patterns
  /// and ensuring consistent state management for engagement tracking and collaboration settings.
  ///
  /// [viewCount] Updated total view count for engagement metrics
  /// [importCount] Updated total import count for conversion metrics
  /// [viewedByUserIds] Updated list of users who have viewed the menu
  /// [importedByUserIds] Updated list of users who have imported the menu
  /// [dismissedByUserIds] Updated list of users who have dismissed the menu
  /// [allowCollaboration] Updated collaboration permission flag
  ///
  /// Returns a new [SharedMenu] instance with updated values.
  SharedMenu copyWith({
    int? viewCount,
    int? importCount,
    List<String>? viewedByUserIds,
    List<String>? importedByUserIds,
    List<String>? dismissedByUserIds, // 🆕 Lägg till dismiss tracking
    bool? allowCollaboration, // 🆕 Kollaborativ uppdatering
  }) {
    return SharedMenu._internal(
      id: id,
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedToUserIds: sharedToUserIds,
      sharedAt: sharedAt,
      shareMessage: shareMessage,
      menuTitle: menuTitle,
      menuSnapshot: menuSnapshot,
      totalRecipeCount: totalRecipeCount,
      categories: categories,
      viewCount: viewCount ?? this.viewCount,
      importCount: importCount ?? this.importCount,
      viewedByUserIds: viewedByUserIds ?? List.from(this.viewedByUserIds),
      importedByUserIds: importedByUserIds ?? List.from(this.importedByUserIds),
      dismissedByUserIds:
          dismissedByUserIds ?? List.from(this.dismissedByUserIds), // 🆕
      allowCollaboration: allowCollaboration ?? this.allowCollaboration, // 🆕
    );
  }

  /// Private constructor för copyWith
  SharedMenu._internal({
    required this.id,
    required this.sharedByUserId,
    required this.sharedByDisplayName,
    required this.sharedToUserIds,
    required this.sharedAt,
    this.shareMessage,
    required this.menuTitle,
    required this.menuSnapshot,
    required this.totalRecipeCount,
    required this.categories,
    required this.viewCount,
    required this.importCount,
    required this.viewedByUserIds,
    required this.importedByUserIds,
    required this.dismissedByUserIds, // 🆕
    required this.allowCollaboration, // 🆕 LÄGG TILL DENNA RAD
  });

  /// Engagement tracking methods for user interaction analytics.

  /// Marks the menu as viewed by the specified user with engagement tracking.
  ///
  /// Implements view tracking functionality with duplicate prevention and analytics updates.
  /// If the user has already viewed the menu, returns the existing menu unchanged.
  ///
  /// [userId] The user identifier who viewed the menu
  ///
  /// Returns a new [SharedMenu] instance with updated view tracking, or unchanged if already viewed.
  SharedMenu markViewedBy(String userId) {
    if (viewedByUserIds.contains(userId)) return this;

    return copyWith(
      viewCount: viewCount + 1,
      viewedByUserIds: [...viewedByUserIds, userId],
    );
  }

  /// Marks the menu as imported by the specified user with conversion tracking.
  ///
  /// Implements import tracking functionality with duplicate prevention and conversion analytics.
  /// If the user has already imported the menu, returns the existing menu unchanged.
  ///
  /// [userId] The user identifier who imported the menu
  ///
  /// Returns a new [SharedMenu] instance with updated import tracking, or unchanged if already imported.
  SharedMenu markImportedBy(String userId) {
    if (importedByUserIds.contains(userId)) return this;

    return copyWith(
      importCount: importCount + 1,
      importedByUserIds: [...importedByUserIds, userId],
    );
  }

  /// Marks the menu as dismissed by the specified user for personalized filtering.
  ///
  /// Implements dismissal tracking functionality allowing users to hide menus from their list
  /// without affecting the menu for other users. Provides duplicate prevention for clean tracking.
  ///
  /// [userId] The user identifier who dismissed the menu
  ///
  /// Returns a new [SharedMenu] instance with updated dismissal tracking, or unchanged if already dismissed.
  SharedMenu markDismissedBy(String userId) {
    if (dismissedByUserIds.contains(userId)) return this;

    return copyWith(
      dismissedByUserIds: [...dismissedByUserIds, userId],
    );
  }

  /// Restores the menu to the specified user's list by removing dismissal status.
  ///
  /// Implements dismissal reversal functionality allowing users to restore previously
  /// dismissed menus to their active list with clean state management.
  ///
  /// [userId] The user identifier who wants to restore the menu
  ///
  /// Returns a new [SharedMenu] instance with dismissal removed, or unchanged if not dismissed.
  SharedMenu undismissBy(String userId) {
    if (!dismissedByUserIds.contains(userId)) return this;

    final updatedDismissed = List<String>.from(dismissedByUserIds);
    updatedDismissed.remove(userId);

    return copyWith(
      dismissedByUserIds: updatedDismissed,
    );
  }

  /// Permission validation and user interaction checking methods.

  /// Checks if the specified user has permission to view this shared menu.
  ///
  /// Implements access control by verifying if the user is either the menu owner
  /// or included in the list of users the menu was shared with.
  ///
  /// [userId] The user identifier to check for view permissions
  ///
  /// Returns true if the user can view the menu (is owner or recipient).
  bool canBeViewedBy(String userId) {
    return sharedByUserId == userId || sharedToUserIds.contains(userId);
  }

  /// Checks if the specified user has viewed this shared menu.
  ///
  /// Provides convenient access to user-specific view status for UI state
  /// management and engagement analytics tracking.
  ///
  /// [userId] The user identifier to check for view status
  ///
  /// Returns true if the user has viewed the shared menu.
  bool isViewedBy(String userId) => viewedByUserIds.contains(userId);
  
  /// Checks if the specified user has imported this shared menu.
  ///
  /// Provides convenient access to user-specific import status for conversion
  /// tracking and user experience optimization.
  ///
  /// [userId] The user identifier to check for import status
  ///
  /// Returns true if the user has imported the shared menu.
  bool isImportedBy(String userId) => importedByUserIds.contains(userId);

  /// Checks if the specified user has dismissed this menu from their list.
  ///
  /// Provides access to user-specific dismissal status for personalized
  /// menu filtering and user preference management.
  ///
  /// [userId] The user identifier to check for dismissal status
  ///
  /// Returns true if the user has dismissed the menu from their list.
  bool isDismissedBy(String userId) => dismissedByUserIds.contains(userId);

  /// Checks if the current authenticated user has dismissed this menu.
  ///
  /// Provides convenient access to current user's dismissal status for UI
  /// state management without requiring explicit user ID parameter.
  ///
  /// Returns true if the current user has dismissed the menu, false if no authenticated user.
  bool get isDismissed {
    final currentUserId = FirebaseAuthRepository().currentUserId;
    if (currentUserId == null) return false;
    return isDismissedBy(currentUserId);
  }

  /// Checks if the current authenticated user has read/viewed this menu.
  ///
  /// Provides convenient access to current user's read status for UI state management
  /// determining if the menu should be marked as read or unread.
  ///
  /// Returns true if the current user has viewed the menu, false if no authenticated user.
  bool get read {
    final currentUserId = FirebaseAuthRepository().currentUserId;
    if (currentUserId == null) return false;
    return isViewedBy(currentUserId);
  }

  /// Checks if the menu should be displayed to the specified user.
  ///
  /// Implements comprehensive visibility logic combining view permissions
  /// with user dismissal preferences for personalized menu filtering.
  ///
  /// [userId] The user identifier to check for display eligibility
  ///
  /// Returns true if the menu should be shown (has permission and not dismissed).
  bool shouldBeShownTo(String userId) {
    return canBeViewedBy(userId) && !isDismissedBy(userId);
  }

  /// Checks if the menu can be imported by users.
  ///
  /// Implements import permission logic with validation for menu content
  /// and extensible business rules for import restrictions.
  ///
  /// Returns true if the menu contains recipes and meets import criteria.
  bool get allowImport {
    // Basic logic: alla menyer kan importeras om de har recept
    if (totalRecipeCount == 0) return false;

    // Du kan lägga till mer komplex logik här senare, som:
    // - Kontrollera om sharedByUserId har tillåtit import
    // - Kontrollera om menyn är för gammal
    // - Kontrollera premium features, etc.

    return true; // Som standard tillåter vi import av alla menyer med recept
  }

  /// UI helper methods for Swedish-localized display and menu analytics.

  /// Gets a localized Swedish summary of the menu contents for preview display.
  ///
  /// Provides user-friendly menu overview with recipe counts by category
  /// formatted in Swedish for natural language menu description.
  ///
  /// Returns Swedish menu summary like '3 middag, 2 lunch, 1 frukost'.
  String get menuSummary {
    final parts = <String>[];
    for (final entry in menuSnapshot.entries) {
      final categoryName = entry.key.toLowerCase();
      final count = entry.value.length;
      if (count > 0) {
        parts.add('$count $categoryName');
      }
    }
    return parts.join(', ');
  }

  /// Gets user-friendly Swedish text for how long ago the menu was shared.
  ///
  /// Provides localized time-ago display optimized for Swedish users with natural
  /// language formatting for improved user experience and temporal context.
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

  /// Analytics and statistics methods for menu engagement insights.

  /// Gets the conversion rate from views to imports as a percentage.
  ///
  /// Provides menu effectiveness metrics by calculating the percentage of
  /// viewers who imported the menu for performance analysis.
  ///
  /// Returns conversion rate as a percentage (0.0 to 100.0).
  double get conversionRate {
    if (viewCount == 0) return 0.0;
    return (importCount / viewCount) * 100.0;
  }
  
  /// Gets the total number of unique users who have interacted with the menu.
  ///
  /// Provides engagement reach metrics by counting all users who have viewed,
  /// imported, or dismissed the menu for comprehensive interaction analysis.
  int get totalInteractions {
    final allInteractors = <String>{
      ...viewedByUserIds,
      ...importedByUserIds,
      ...dismissedByUserIds,
    };
    return allInteractors.length;
  }
  
  /// Checks if the menu has any recipe content available for sharing.
  ///
  /// Provides validation for menu sharing eligibility based on content availability.
  ///
  /// Returns true if the menu contains at least one recipe in any category.
  bool get hasContent => totalRecipeCount > 0;
  
  /// Gets the most popular category based on recipe count.
  ///
  /// Provides menu analysis by identifying the category with the most recipes
  /// for content optimization and user preference insights.
  ///
  /// Returns the category name with the highest recipe count, or null if empty.
  String? get mostPopularCategory {
    if (menuSnapshot.isEmpty) return null;
    
    String? topCategory;
    int maxCount = 0;
    
    for (final entry in menuSnapshot.entries) {
      if (entry.value.length > maxCount) {
        maxCount = entry.value.length;
        topCategory = entry.key;
      }
    }
    
    return topCategory;
  }

  /// Data persistence and serialization methods for Firestore and caching integration.

  /// Converts the shared menu to Firestore-compatible format for persistence.
  ///
  /// Transforms all menu data including complete recipe snapshots into Firestore format
  /// with proper timestamp handling and nested object serialization for database efficiency.
  ///
  /// Returns a map containing all shared menu data formatted for Firestore persistence.
  Map<String, dynamic> toFirestore() {
    // Convert menu snapshot to Firestore format - UTAN serverTimestamp i nested data
    final menuData = <String, dynamic>{};
    for (final entry in menuSnapshot.entries) {
      menuData[entry.key] = entry.value.map((recipe) {
        // Få recipe data och säkerställ att inga FieldValue.serverTimestamp() finns i nested objects
        final recipeData = recipe.toFirestore();

        // Ersätt eventuella serverTimestamp med DateTime.now() för nested objects
        if (recipeData['createdAt'] is DateTime) {
          recipeData['createdAt'] = AppTimestamp.fromDateTime(recipe.createdAt).toFirestore();
        }
        if (recipeData['updatedAt'] is DateTime) {
          recipeData['updatedAt'] = AppTimestamp.fromDateTime(recipe.updatedAt).toFirestore();
        }
        if (recipeData['lastCookedAt'] is DateTime && recipe.lastCookedAt != null) {
          recipeData['lastCookedAt'] = AppTimestamp.fromDateTime(recipe.lastCookedAt!).toFirestore();
        }

        return recipeData;
      }).toList();
    }

    return {
      'sharedByUserId': sharedByUserId,
      'sharedByDisplayName': sharedByDisplayName,
      'sharedToUserIds': sharedToUserIds,
      'sharedAt': AppTimestamp.fromDateTime(sharedAt).toFirestore(),
      'shareMessage': shareMessage,
      'menuTitle': menuTitle,
      'menuSnapshot': menuData,
      'totalRecipeCount': totalRecipeCount,
      'categories': categories,
      'viewCount': viewCount,
      'importCount': importCount,
      'viewedByUserIds': viewedByUserIds,
      'importedByUserIds': importedByUserIds,
      'dismissedByUserIds': dismissedByUserIds, // 🆕 Spara dismiss data
      'allowCollaboration': allowCollaboration, // 🆕 LÄGG TILL DENNA RAD
    };
  }

  /// Creates a shared menu instance from Firestore repository data with robust error handling.
  ///
  /// Transforms Firestore document data into a complete [SharedMenu] instance with proper
  /// type conversion, recipe reconstruction, and comprehensive error handling for robust data recovery.
  ///
  /// [id] Document identifier from Firestore
  /// [data] Raw document data from Firestore with all menu fields
  ///
  /// Returns a new [SharedMenu] instance with all data properly parsed and validated.
  /// Factory constructor to create SharedMenu from Firestore document.
  ///
  /// This is a convenience method that delegates to fromMap for compatibility
  /// with services expecting a fromFirestore method.
  factory SharedMenu.fromFirestore(Map<String, dynamic> data, String id) {
    return SharedMenu.fromMap(id, data);
  }
  
  factory SharedMenu.fromMap(String id, Map<String, dynamic> data) {
    try {
      debugPrint('🔍 Parsing SharedMenu från doc ID: $id');

      // 🔧 FIXED: Reconstruct menu snapshot utan MockDocumentSnapshot type cast
      final menuData = data['menuSnapshot'] as Map<String, dynamic>? ?? {};
      final reconstructedMenu = <String, List<Recipe>>{};

      for (final entry in menuData.entries) {
        final recipeList = <Recipe>[];
        final recipes = entry.value as List<dynamic>? ?? [];

        for (final recipeData in recipes) {
          try {
            // 🔧 FIXED: Skapa Recipe direkt från data istället för via mock DocumentSnapshot
            final recipeMap = recipeData as Map<String, dynamic>;
            final recipe = Recipe(
              core: RecipeCore(
                id: recipeMap['id'] as String? ?? '',
                title: recipeMap['title'] as String? ?? 'Untitled Recipe',
                description: recipeMap['description'] as String? ?? '',
                ingredients: List<String>.from(recipeMap['ingredients'] ?? []),
                instructions: List<String>.from(recipeMap['instructions'] ?? []),
                imageUrls: List<String>.from(recipeMap['imageUrls'] ?? []),
                mealType: recipeMap['mealType'] as String? ?? 'Middag',
                portions: recipeMap['portions'] as int?,
                timeMinutes: recipeMap['timeMinutes'] as int?,
                rating: (recipeMap['rating'] as num?)?.toDouble(),
                tags: List<String>.from(recipeMap['tags'] ?? []),
                sourceUrl: recipeMap['sourceUrl'] as String?,
                createdAt:
                    _parseTimestamp(recipeMap['createdAt']) ?? DateTime.now(),
                updatedAt:
                    _parseTimestamp(recipeMap['updatedAt']) ?? DateTime.now(),
                lastCookedAt: _parseTimestamp(recipeMap['lastCookedAt']),
              ),
              type: RecipeType.shared, // Mark as shared menu recipe
            );
            recipeList.add(recipe);
          } catch (e) {
            debugPrint('⚠️ Skippar ogiltigt recept i meny: $e');
            // Skip invalid recipes rather than failing entirely
            continue;
          }
        }
        reconstructedMenu[entry.key] = recipeList;
      }

      return SharedMenu._internal(
        id: id,
        sharedByUserId: data['sharedByUserId'] as String? ?? '',
        sharedByDisplayName: data['sharedByDisplayName'] as String? ?? '',
        sharedToUserIds: List<String>.from(data['sharedToUserIds'] ?? []),
        sharedAt: _parseTimestamp(data['sharedAt']) ?? DateTime.now(),
        shareMessage: data['shareMessage'] as String?,
        menuTitle: data['menuTitle'] as String? ?? 'Delad meny',
        menuSnapshot: reconstructedMenu,
        totalRecipeCount: data['totalRecipeCount'] as int? ?? 0,
        categories: List<String>.from(data['categories'] ?? []),
        viewCount: data['viewCount'] as int? ?? 0,
        importCount: data['importCount'] as int? ?? 0,
        viewedByUserIds: List<String>.from(data['viewedByUserIds'] ?? []),
        importedByUserIds: List<String>.from(data['importedByUserIds'] ?? []),
        dismissedByUserIds: List<String>.from(
            data['dismissedByUserIds'] ?? []), // 🆕 Läs dismiss data
        allowCollaboration: data['allowCollaboration'] as bool? ??
            false, // 🆕 LÄGG TILL DENNA RAD
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing SharedMenu från doc $id: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 🔧 ADDED: Helper method för robust timestamp parsing
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

  /// JSON serialization för caching
  Map<String, dynamic> toJson() {
    // Convert menu snapshot to JSON format
    final menuData = <String, dynamic>{};
    for (final entry in menuSnapshot.entries) {
      menuData[entry.key] =
          entry.value.map((recipe) => recipe.toJson()).toList();
    }

    return {
      'id': id,
      'sharedByUserId': sharedByUserId,
      'sharedByDisplayName': sharedByDisplayName,
      'sharedToUserIds': sharedToUserIds,
      'sharedAt': sharedAt.toIso8601String(),
      'shareMessage': shareMessage,
      'menuTitle': menuTitle,
      'menuSnapshot': menuData,
      'totalRecipeCount': totalRecipeCount,
      'categories': categories,
      'viewCount': viewCount,
      'importCount': importCount,
      'viewedByUserIds': viewedByUserIds,
      'importedByUserIds': importedByUserIds,
      'dismissedByUserIds': dismissedByUserIds, // 🆕 JSON support för dismiss
      'allowCollaboration':
          allowCollaboration, // 🆕 JSON support för collaboration
    };
  }

  factory SharedMenu.fromJson(Map<String, dynamic> json) {
    // Reconstruct menu snapshot from JSON
    final menuData = json['menuSnapshot'] as Map<String, dynamic>? ?? {};
    final reconstructedMenu = <String, List<Recipe>>{};

    for (final entry in menuData.entries) {
      final recipeList = <Recipe>[];
      final recipes = entry.value as List<dynamic>? ?? [];

      for (final recipeData in recipes) {
        try {
          recipeList.add(Recipe.fromJson(recipeData as Map<String, dynamic>));
        } catch (e) {
          // Skip invalid recipes
          continue;
        }
      }
      reconstructedMenu[entry.key] = recipeList;
    }

    return SharedMenu._internal(
      id: json['id'] as String,
      sharedByUserId: json['sharedByUserId'] as String? ?? '',
      sharedByDisplayName: json['sharedByDisplayName'] as String? ?? '',
      sharedToUserIds: List<String>.from(json['sharedToUserIds'] ?? []),
      sharedAt: DateTime.parse(json['sharedAt'] as String),
      shareMessage: json['shareMessage'] as String?,
      menuTitle: json['menuTitle'] as String? ?? 'Delad meny',
      menuSnapshot: reconstructedMenu,
      totalRecipeCount: json['totalRecipeCount'] as int? ?? 0,
      categories: List<String>.from(json['categories'] ?? []),
      viewCount: json['viewCount'] as int? ?? 0,
      importCount: json['importCount'] as int? ?? 0,
      viewedByUserIds: List<String>.from(json['viewedByUserIds'] ?? []),
      importedByUserIds: List<String>.from(json['importedByUserIds'] ?? []),
      dismissedByUserIds: List<String>.from(
          json['dismissedByUserIds'] ?? []), // 🆕 JSON parse för dismiss
      allowCollaboration: json['allowCollaboration'] as bool? ??
          false, // 🆕 JSON parse för collaboration
    );
  }

  /// Standard object methods for debugging, comparison, and identity management.

  /// Returns a string representation of the shared menu for debugging and logging.
  ///
  /// Provides essential menu information in a readable format for development
  /// and debugging purposes with menu title, owner, and recipe count.
  @override
  String toString() {
    return 'SharedMenu(id: $id, title: $menuTitle, sharedBy: $sharedByDisplayName, recipes: $totalRecipeCount)';
  }

  /// Compares two shared menus for equality based on unique identifier.
  ///
  /// Uses menu ID for equality comparison ensuring consistent object
  /// identity across different instances of the same menu data.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SharedMenu && other.id == id;
  }

  /// Generates hash code based on unique menu identifier.
  ///
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and menu identification.
  @override
  int get hashCode => id.hashCode;
}

/// Centralized test constants to eliminate hardcoded values across test files
///
/// This file contains all commonly used test values, ensuring consistency
/// and making it easier to update test data across the entire test suite.
library;

// Note: These enums are defined in the models. Import them from the actual model files
// that use them when you need to use the constants that reference them.

/// Test constants for consistent test data across all test files
class TestConstants {
  // Prevent instantiation
  TestConstants._();

  // ============================================================================
  // User IDs and Authentication
  // ============================================================================

  /// Primary test user ID
  static const String testUserId = 'test-user-123';

  /// Secondary test user ID for multi-user scenarios
  static const String secondaryUserId = 'test-user-456';

  /// Third test user ID for collaboration tests
  static const String thirdUserId = 'test-user-789';

  /// Admin user ID for permission tests
  static const String adminUserId = 'admin-user-001';

  /// Guest user ID for anonymous tests
  static const String guestUserId = 'guest-user-999';

  /// Friend user ID for social features
  static const String friendUserId = 'friend-user-111';

  /// Blocked user ID for blocking tests
  static const String blockedUserId = 'blocked-user-666';

  // ============================================================================
  // User Emails
  // ============================================================================

  /// Primary test email
  static const String testEmail = 'test@example.com';

  /// Secondary test email
  static const String secondaryEmail = 'user2@example.com';

  /// Admin email
  static const String adminEmail = 'admin@example.com';

  /// Invalid email for validation tests
  static const String invalidEmail = 'invalid-email';

  /// Swedish test email
  static const String swedishEmail = 'sven@example.se';

  /// New user email for registration tests
  static const String newUserEmail = 'newuser@example.com';

  // ============================================================================
  // User Names and Display Names
  // ============================================================================

  /// Primary test display name
  static const String testDisplayName = 'Test User';

  /// Secondary display name
  static const String secondaryDisplayName = 'User Two';

  /// Swedish test user name
  static const String swedishUserName = 'Sven Svensson';

  /// Admin display name
  static const String adminDisplayName = 'Admin User';

  // ============================================================================
  // Passwords
  // ============================================================================

  /// Valid test password
  static const String testPassword = 'Test123!@#';

  /// Invalid password (too short)
  static const String invalidPassword = '123';

  /// Weak password for validation tests
  static const String weakPassword = 'password';

  // ============================================================================
  // Recipe IDs
  // ============================================================================

  /// Primary test recipe ID
  static const String testRecipeId = 'recipe-123';

  /// Secondary recipe ID
  static const String secondaryRecipeId = 'recipe-456';

  /// Shared recipe ID for social features
  static const String sharedRecipeId = 'shared-recipe-789';

  /// Collaborative recipe ID
  static const String collaborativeRecipeId = 'collab-recipe-001';

  /// Archived recipe ID
  static const String archivedRecipeId = 'archived-recipe-999';

  /// Non-existent recipe ID for error tests
  static const String nonExistentRecipeId = 'non-existent-recipe';

  // ============================================================================
  // Recipe Titles and Content
  // ============================================================================

  /// Swedish meatballs recipe title
  static const String swedishMeatballsTitle = 'Köttbullar';

  /// Swedish pancakes recipe title
  static const String swedishPancakesTitle = 'Pannkakor';

  /// Swedish cinnamon buns recipe title
  static const String swedishCinnamonBunsTitle = 'Kanelbullar';

  /// Test recipe title
  static const String testRecipeTitle = 'Test Recipe';

  /// Updated recipe title
  static const String updatedRecipeTitle = 'Updated Recipe';

  /// Test recipe description
  static const String testRecipeDescription = 'A delicious test recipe';

  /// Swedish recipe description
  static const String swedishRecipeDescription = 'Traditional Swedish recipe';

  // ============================================================================
  // Menu IDs
  // ============================================================================

  /// Test menu ID
  static const String testMenuId = 'menu-123';

  /// Weekly menu ID
  static const String weeklyMenuId = 'weekly-menu-456';

  /// Shared menu ID
  static const String sharedMenuId = 'shared-menu-789';

  // ============================================================================
  // Shopping List IDs
  // ============================================================================

  /// Personal shopping list ID
  static const String personalListId = 'personal-list-123';

  /// Collaborative shopping list ID
  static const String collaborativeListId = 'collab-list-456';

  /// Shared shopping list ID
  static const String sharedListId = 'shared-list-789';

  // ============================================================================
  // URLs and Paths
  // ============================================================================

  /// Test image URL
  static const String testImageUrl = 'https://example.com/image.jpg';

  /// Test avatar URL
  static const String testAvatarUrl = 'https://example.com/avatar.png';

  /// Test recipe image URL
  static const String recipeImageUrl = 'https://example.com/recipe.jpg';

  /// Test file path
  static const String testFilePath = '/path/to/test/file.jpg';

  /// Test deep link
  static const String testDeepLink = 'butlery://recipe/123';

  // ============================================================================
  // Timestamps and Durations
  // ============================================================================

  /// Test cooking time in minutes
  static const int testCookingTime = 30;

  /// Test prep time in minutes
  static const int testPrepTime = 15;

  /// Test total time in minutes
  static const int testTotalTime = 45;

  /// Test servings
  static const int testServings = 4;

  /// Test rating
  static const double testRating = 4.5;

  // ============================================================================
  // Collections and Paths
  // ============================================================================

  /// Recipes collection name
  static const String recipesCollection = 'recipes';

  /// Users collection name
  static const String usersCollection = 'users';

  /// Shopping lists collection name
  static const String shoppingListsCollection = 'shoppingLists';

  /// Menus collection name
  static const String menusCollection = 'menus';

  /// Comments collection name
  static const String commentsCollection = 'comments';

  // ============================================================================
  // Error Messages
  // ============================================================================

  /// Generic test error message
  static const String testErrorMessage = 'Test error occurred';

  /// Network error message
  static const String networkErrorMessage = 'Network error';

  /// Permission denied message
  static const String permissionDeniedMessage = 'Permission denied';

  /// Not found error message
  static const String notFoundMessage = 'Resource not found';

  /// Validation error message
  static const String validationErrorMessage = 'Validation failed';

  // ============================================================================
  // Test Data Arrays
  // ============================================================================

  /// Test ingredients list
  static const List<String> testIngredients = [
    '2 cups flour',
    '1 cup milk',
    '2 eggs',
    '1 tsp salt',
  ];

  /// Test instructions list
  static const List<String> testInstructions = [
    'Mix dry ingredients',
    'Add wet ingredients',
    'Stir until combined',
    'Cook for 20 minutes',
  ];

  /// Test tags
  static const List<String> testTags = [
    'vegetarian',
    'quick',
    'easy',
    'healthy',
  ];

  /// Swedish cuisine tags
  static const List<String> swedishTags = [
    'svensk',
    'traditionell',
    'husmanskost',
  ];

  // ============================================================================
  // Permission Strings (use actual enum values in your tests)
  // ============================================================================

  /// Default meal type string for tests
  static const String defaultMealType = 'dinner';

  /// Default resource permission string
  static const String defaultPermission = 'viewer';

  /// Editor permission string
  static const String editorPermission = 'editor';

  /// Owner permission string
  static const String ownerPermission = 'owner';

  // ============================================================================
  // Friend Request Messages
  // ============================================================================

  /// Test friend request message
  static const String friendRequestMessage = "Hi! Let's connect on Butlery!";

  /// Friend request rejection reason
  static const String rejectionReason = "Sorry, I don't know you";

  // ============================================================================
  // Category Names
  // ============================================================================

  /// Test category name
  static const String testCategoryName = 'Test Category';

  /// Family category name
  static const String familyCategoryName = 'Family';

  /// Friends category name
  static const String friendsCategoryName = 'Friends';

  /// Work category name
  static const String workCategoryName = 'Work';

  // ============================================================================
  // Test Timeouts
  // ============================================================================

  /// Short timeout for quick operations (milliseconds)
  static const int shortTimeout = 100;

  /// Medium timeout for standard operations (milliseconds)
  static const int mediumTimeout = 500;

  /// Long timeout for slow operations (milliseconds)
  static const int longTimeout = 2000;

  // ============================================================================
  // Mock Data Helpers
  // ============================================================================

  /// Get a test timestamp
  static DateTime get testTimestamp => DateTime(2024, 1, 1, 12, 0, 0);

  /// Get an updated timestamp
  static DateTime get updatedTimestamp => DateTime(2024, 1, 2, 12, 0, 0);

  /// Get a future timestamp
  static DateTime get futureTimestamp => DateTime(2025, 1, 1, 12, 0, 0);

  /// Get a past timestamp
  static DateTime get pastTimestamp => DateTime(2023, 1, 1, 12, 0, 0);
}

/// Test error codes for consistent error testing
class TestErrorCodes {
  TestErrorCodes._();

  /// Firebase auth error codes
  static const String userNotFound = 'user-not-found';
  static const String wrongPassword = 'wrong-password';
  static const String emailAlreadyInUse = 'email-already-in-use';
  static const String weakPassword = 'weak-password';
  static const String invalidEmail = 'invalid-email';
  static const String requiresRecentLogin = 'requires-recent-login';

  /// Firestore error codes
  static const String permissionDenied = 'permission-denied';
  static const String notFound = 'not-found';
  static const String alreadyExists = 'already-exists';
  static const String unavailable = 'unavailable';
  static const String deadlineExceeded = 'deadline-exceeded';

  /// Custom error codes
  static const String networkError = 'network-error';
  static const String invalidData = 'invalid-data';
  static const String operationFailed = 'operation-failed';
  static const String unauthorized = 'unauthorized';
}

/// Test platform constants
class TestPlatforms {
  TestPlatforms._();

  /// Platform channel names
  static const String imagePickerChannel = 'plugins.flutter.io/image_picker';
  static const String shareChannel = 'plugins.flutter.io/share';
  static const String urlLauncherChannel = 'plugins.flutter.io/url_launcher';

  /// Platform method names
  static const String pickImage = 'pickImage';
  static const String share = 'share';
  static const String launch = 'launch';
  static const String canLaunch = 'canLaunch';
}

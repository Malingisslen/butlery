/// Validation test helper for model tests
///
/// Provides utilities for testing model validation rules
/// and business logic constraints.
library;

/// Helper class for validation testing
class ValidationHelper {
  /// Validate recipe model constraints
  static bool isValidRecipe({
    required String? id,
    required String? title,
    required String? description,
    required List<String>? ingredients,
    required List<String>? instructions,
    required String? mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
  }) {
    // ID must be non-empty
    if (id == null || id.isEmpty) return false;

    // Title must be non-empty
    if (title == null || title.isEmpty) return false;

    // Description must be non-empty
    if (description == null || description.isEmpty) return false;

    // Must have at least one ingredient
    if (ingredients == null || ingredients.isEmpty) return false;

    // Must have at least one instruction
    if (instructions == null || instructions.isEmpty) return false;

    // Meal type must be valid
    if (mealType == null || mealType.isEmpty) return false;

    // Portions must be positive if specified
    if (portions != null && portions <= 0) return false;

    // Time must be positive if specified
    if (timeMinutes != null && timeMinutes <= 0) return false;

    // Rating must be between 0 and 5 if specified
    if (rating != null && (rating < 0 || rating > 5)) return false;

    return true;
  }

  /// Validate user profile constraints
  static bool isValidUserProfile({
    required String? uid,
    required String? displayName,
    required String? email,
    String? bio,
    int? friendsCount,
    int? publicRecipeCount,
  }) {
    // UID must be non-empty
    if (uid == null || uid.isEmpty) return false;

    // Display name must be non-empty
    if (displayName == null || displayName.isEmpty) return false;

    // Email must be valid format
    if (email == null || !isValidEmail(email)) return false;

    // Bio length constraint (if specified)
    if (bio != null && bio.length > 500) return false;

    // Counts must be non-negative
    if (friendsCount != null && friendsCount < 0) return false;
    if (publicRecipeCount != null && publicRecipeCount < 0) return false;

    return true;
  }

  /// Validate shopping list constraints
  static bool isValidShoppingList({
    required String? id,
    required String? name,
    required String? ownerId,
    required List<dynamic>? items,
  }) {
    // ID must be non-empty
    if (id == null || id.isEmpty) return false;

    // Name must be non-empty
    if (name == null || name.isEmpty) return false;

    // Owner ID must be non-empty
    if (ownerId == null || ownerId.isEmpty) return false;

    // Items can be empty but not null
    if (items == null) return false;

    return true;
  }

  /// Validate shopping item constraints
  static bool isValidShoppingItem({
    required String? id,
    required String? name,
    double? quantity,
    String? unit,
    required bool? isBought,
  }) {
    // ID must be non-empty
    if (id == null || id.isEmpty) return false;

    // Name must be non-empty
    if (name == null || name.isEmpty) return false;

    // Quantity must be positive if specified
    if (quantity != null && quantity <= 0) return false;

    // Unit must be valid if specified
    if (unit != null && !isValidUnit(unit)) return false;

    // isBought must be specified
    if (isBought == null) return false;

    return true;
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validate Swedish unit
  static bool isValidUnit(String unit) {
    const validUnits = [
      'styck',
      'st',
      'liter',
      'l',
      'dl',
      'cl',
      'ml',
      'kilogram',
      'kg',
      'hg',
      'g',
      'matsked',
      'msk',
      'tesked',
      'tsk',
      'kryddmått',
      'krm',
      'knippe',
      'påse',
      'burk',
      'paket',
    ];
    return validUnits.contains(unit.toLowerCase());
  }

  /// Validate Swedish meal type
  static bool isValidMealType(String mealType) {
    const validMealTypes = [
      'Frukost',
      'Lunch',
      'Middag',
      'Mellanmål',
      'Fika',
      'Dessert',
      'Förrätt',
      'Huvudrätt',
      'Efterrätt',
      'Bakverk',
      'Dryck',
      'Tillbehör',
    ];
    return validMealTypes.contains(mealType);
  }

  /// Create invalid test cases for validation testing
  static List<Map<String, dynamic>> getInvalidTestCases() {
    return [
      // Empty required fields
      {'case': 'empty_id', 'id': '', 'title': 'Test', 'description': 'Test'},
      {'case': 'empty_title', 'id': 'test', 'title': '', 'description': 'Test'},
      {
        'case': 'empty_description',
        'id': 'test',
        'title': 'Test',
        'description': '',
      },

      // Null required fields
      {'case': 'null_id', 'id': null, 'title': 'Test', 'description': 'Test'},
      {
        'case': 'null_title',
        'id': 'test',
        'title': null,
        'description': 'Test',
      },

      // Invalid numeric values
      {'case': 'negative_portions', 'portions': -1},
      {'case': 'zero_portions', 'portions': 0},
      {'case': 'negative_time', 'timeMinutes': -30},
      {'case': 'invalid_rating_low', 'rating': -1.0},
      {'case': 'invalid_rating_high', 'rating': 6.0},

      // Invalid email formats
      {'case': 'invalid_email_no_at', 'email': 'invalid.email.com'},
      {'case': 'invalid_email_no_domain', 'email': 'invalid@'},
      {'case': 'invalid_email_no_user', 'email': '@example.com'},

      // Empty collections
      {'case': 'empty_ingredients', 'ingredients': []},
      {'case': 'empty_instructions', 'instructions': []},

      // Invalid units
      {'case': 'invalid_unit', 'unit': 'invalid_unit'},

      // Invalid meal types
      {'case': 'invalid_meal_type', 'mealType': 'InvalidMealType'},

      // String length violations
      {'case': 'bio_too_long', 'bio': 'A' * 501},
      {'case': 'title_too_long', 'title': 'A' * 201},
    ];
  }

  /// Test boundary values
  static List<Map<String, dynamic>> getBoundaryTestCases() {
    return [
      // Minimum valid values
      {'case': 'min_portions', 'portions': 1},
      {'case': 'min_time', 'timeMinutes': 1},
      {'case': 'min_rating', 'rating': 0.0},

      // Maximum valid values
      {'case': 'max_portions', 'portions': 999},
      {'case': 'max_time', 'timeMinutes': 9999},
      {'case': 'max_rating', 'rating': 5.0},

      // Edge of validity
      {'case': 'bio_at_limit', 'bio': 'A' * 500},
      {'case': 'title_at_limit', 'title': 'A' * 200},

      // Single item collections
      {
        'case': 'single_ingredient',
        'ingredients': ['One ingredient'],
      },
      {
        'case': 'single_instruction',
        'instructions': ['One step'],
      },

      // Large collections
      {
        'case': 'many_ingredients',
        'ingredients': List.generate(100, (i) => 'Ingredient $i'),
      },
      {
        'case': 'many_instructions',
        'instructions': List.generate(50, (i) => 'Step $i'),
      },
    ];
  }

  /// Validate permission levels
  static bool hasValidPermission({
    required String? userId,
    required String? resourceOwnerId,
    required String permissionLevel,
  }) {
    // User must be identified
    if (userId == null || userId.isEmpty) return false;

    // Resource must have owner
    if (resourceOwnerId == null || resourceOwnerId.isEmpty) return false;

    // Permission level must be valid
    const validLevels = ['viewer', 'editor', 'admin', 'owner'];
    if (!validLevels.contains(permissionLevel)) return false;

    // Owner always has full permissions
    if (userId == resourceOwnerId) return true;

    // Check permission level hierarchy
    switch (permissionLevel) {
      case 'viewer':
        return true; // Can only view
      case 'editor':
        return true; // Can view and edit
      case 'admin':
        return true; // Can view, edit, and manage
      case 'owner':
        return userId == resourceOwnerId; // Only owner
      default:
        return false;
    }
  }

  /// Generate test cases for all validation scenarios
  static Map<String, List<Map<String, dynamic>>> getAllValidationTestCases() {
    return {
      'invalid': getInvalidTestCases(),
      'boundary': getBoundaryTestCases(),
      'edgeCase': [
        {'case': 'unicode_in_title', 'title': '🍔 Burger 汉堡'},
        {
          'case': 'swedish_chars',
          'title': 'Räksmörgås',
          'description': 'Öppna smörgåsar',
        },
        {
          'case': 'special_chars',
          'title': 'Recipe & More!',
          'description': 'Test @ 100%',
        },
        {'case': 'whitespace_only', 'title': '   ', 'description': '\t\n'},
      ],
    };
  }
}

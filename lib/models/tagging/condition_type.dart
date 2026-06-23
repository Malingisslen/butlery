import 'package:butlery/core/l10n/app_locale.dart';

/// Type of condition to evaluate.
enum ConditionType {
  /// Match against recipe ingredient text.
  ingredient,

  /// Match against ingredient database properties (requires lookup).
  property,

  /// Match against recipe title or description.
  keyword,

  /// Match against recipe source URL (contains substring).
  sourceUrl,

  /// Match against auto-generated cuisine tags.
  cuisine,

  /// Match against dietary status (vegetarian, vegan, etc.).
  dietary,

  /// Match against cooking time in minutes.
  time,

  /// Match against user rating (1-5).
  rating,

  /// Match against recipe age (days since added).
  recency,

  /// Match against days since last cooked (null = never cooked = max days).
  cookedRecency,

  /// Match against recipe ownership/collaboration status.
  /// Values: 'mine', 'shared', 'collaborative', 'public'
  ownership,

  /// Match against whether recipe has an image.
  /// Boolean condition: true = has image, false = no image.
  hasImage,

  /// Match against recipe completeness.
  /// Values: 'missing_image', 'missing_description', 'incomplete'
  completeness,
}

/// Extension methods for ConditionType serialization.
extension ConditionTypeExtension on ConditionType {
  String toFirestore() => name;

  static ConditionType fromFirestore(String? value) {
    switch (value?.toLowerCase()) {
      case 'ingredient':
        return ConditionType.ingredient;
      case 'property':
        return ConditionType.property;
      case 'keyword':
        return ConditionType.keyword;
      case 'sourceurl':
      case 'source_url':
        return ConditionType.sourceUrl;
      case 'cuisine':
        return ConditionType.cuisine;
      case 'dietary':
        return ConditionType.dietary;
      case 'time':
        return ConditionType.time;
      case 'rating':
        return ConditionType.rating;
      case 'recency':
        return ConditionType.recency;
      case 'cookedrecency':
      case 'cooked_recency':
        return ConditionType.cookedRecency;
      case 'ownership':
        return ConditionType.ownership;
      case 'hasimage':
      case 'has_image':
        return ConditionType.hasImage;
      case 'completeness':
        return ConditionType.completeness;
      default:
        return ConditionType.keyword; // Safe default
    }
  }

  /// Human-readable localized label for UI.
  String get label {
    final l = AppLocale.current;
    return switch (this) {
      ConditionType.ingredient => l.conditionTypeIngredient,
      ConditionType.property => l.conditionTypeProperty,
      ConditionType.keyword => l.conditionTypeKeyword,
      ConditionType.sourceUrl => l.conditionTypeSource,
      ConditionType.cuisine => l.conditionTypeCuisine,
      ConditionType.dietary => l.conditionTypeDiet,
      ConditionType.time => l.conditionTypeTime,
      ConditionType.rating => l.conditionTypeRating,
      ConditionType.recency => l.conditionTypeRecent,
      ConditionType.cookedRecency => l.conditionTypeCookedRecency,
      ConditionType.ownership => l.conditionTypeOwnership,
      ConditionType.hasImage => l.conditionTypeHasImage,
      ConditionType.completeness => l.conditionTypeCompleteness,
    };
  }

  /// Returns true if this condition type uses numeric values.
  bool get isNumeric => switch (this) {
    ConditionType.time ||
    ConditionType.rating ||
    ConditionType.recency ||
    ConditionType.cookedRecency => true,
    _ => false,
  };

  /// Returns true if this condition type uses boolean values.
  bool get isBoolean => switch (this) {
    ConditionType.hasImage => true,
    _ => false,
  };
}

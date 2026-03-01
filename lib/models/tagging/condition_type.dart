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
    switch (this) {
      case ConditionType.ingredient:
        return l.conditionTypeIngredient;
      case ConditionType.property:
        return l.conditionTypeProperty;
      case ConditionType.keyword:
        return l.conditionTypeKeyword;
      case ConditionType.sourceUrl:
        return l.conditionTypeSource;
      case ConditionType.cuisine:
        return l.conditionTypeCuisine;
      case ConditionType.dietary:
        return l.conditionTypeDiet;
      case ConditionType.time:
        return l.conditionTypeTime;
      case ConditionType.rating:
        return l.conditionTypeRating;
      case ConditionType.recency:
        return l.conditionTypeRecent;
      case ConditionType.ownership:
        return l.conditionTypeOwnership;
      case ConditionType.hasImage:
        return l.conditionTypeHasImage;
      case ConditionType.completeness:
        return l.conditionTypeCompleteness;
    }
  }

  /// Returns true if this condition type uses numeric values.
  bool get isNumeric {
    switch (this) {
      case ConditionType.time:
      case ConditionType.rating:
      case ConditionType.recency:
        return true;
      default:
        return false;
    }
  }

  /// Returns true if this condition type uses boolean values.
  bool get isBoolean {
    switch (this) {
      case ConditionType.hasImage:
        return true;
      default:
        return false;
    }
  }
}

import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';

/// Reserved system tag names that cannot be used for personal tags.
/// Prevents confusion between auto-generated tags and user-created tags.
class ReservedTags {
  ReservedTags._();

  /// All reserved tag names (lowercase for comparison).
  static final Set<String> all = _buildReservedSet();

  static Set<String> _buildReservedSet() {
    final reserved = <String>{};

    // Dietary tags
    for (final entry in DietaryConfig.all) {
      reserved.add(entry.tagSv.toLowerCase());
    }

    // Allergen tags
    for (final entry in AllergenConfig.all) {
      reserved.add(entry.containsTag.toLowerCase());
      if (entry.freeTag != null) {
        reserved.add(entry.freeTag!.toLowerCase());
      }
    }

    return reserved;
  }

  /// Check if a tag name conflicts with system tags.
  /// Comparison is case-insensitive.
  static bool isReserved(String tagName) {
    return all.contains(tagName.toLowerCase());
  }

  /// Validates a tag name, returning error message if invalid.
  /// Returns null if valid.
  static String? validateTagName(String tagName) {
    final trimmed = tagName.trim();
    if (trimmed.isEmpty) {
      return 'Taggnamn kan inte vara tomt';
    }
    if (trimmed.length < 2) {
      return 'Taggnamn måste vara minst 2 tecken';
    }
    if (trimmed.length > 50) {
      return 'Taggnamn får vara max 50 tecken';
    }
    if (isReserved(trimmed)) {
      return 'Detta namn är reserverat för systemtaggar';
    }
    return null;
  }
}

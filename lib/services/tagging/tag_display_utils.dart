/// Utilities for displaying tags with smart prioritization.
///
/// Provides methods to select and order the most relevant tags
/// for display, prioritizing user-added tags first, then
/// categorizing by searchability (protein, dish type, cuisine, etc.).
class TagDisplayUtils {
  TagDisplayUtils._();

  /// Priority categories for auto-generated tags.
  /// Tags in earlier categories are shown before later ones.
  static const List<Set<String>> _priorityCategories = [
    // Priority 1: Protein tags (most searchable)
    {
      'kyckling',
      'anka',
      'kalkon',
      'nötkött',
      'fläskkött',
      'lamm',
      'vilt',
      'fisk',
      'lax',
      'torsk',
      'sill',
      'skaldjur',
      'räkor',
      'tofu',
      'baljväxter',
      'ägg',
    },
    // Priority 2: Dish type
    {
      'soppa',
      'sallad',
      'gryta',
      'gratäng',
      'curry',
      'pizza',
      'taco',
      'bowl',
      'paj',
      'kaka',
      'köttbullar',
      'pannkaka',
      'smoothie',
      'pasta-dish',
      'rice-dish',
      'noodle-dish',
      'potato-dish',
      'bread-dish',
      'hamburgare',
      'smörgås',
      'omelett',
      'våffla',
      'dipp',
      'sås',
    },
    // Priority 3: Cuisine
    {
      'svensk',
      'italiensk',
      'asiatisk',
      'japansk',
      'kinesisk',
      'thailändsk',
      'vietnamesisk',
      'indisk',
      'mexikansk',
      'mellanöstern',
      'grekisk',
      'fransk',
      'spansk',
      'amerikansk',
      'koreansk',
      'nordafrikansk',
      'karibisk',
      'etiopisk',
      'marockansk',
      'brasiliansk',
      'peruansk',
      'argentinsk',
    },
    // Priority 4: Time/difficulty
    {
      'under-15-min',
      'under-30-min',
      'under-45-min',
      'under-60-min',
      'över-60-min',
      'enkel',
      'medel',
      'avancerad',
      'snabblagat',
    },
    // Priority 5: Practical/mood
    {
      'vardagsmiddag',
      'helgmat',
      'fredagsmys',
      'comfort-food',
      'barnvänlig',
      'frysbar',
      'meal-prep',
      'klimatsmart',
      'budgetvänlig',
      'få-ingredienser',
    },
  ];

  /// Display names for tags (Swedish-friendly names).
  /// Tags not in this map are displayed as-is with first letter capitalized.
  static const Map<String, String> _displayNames = {
    // Time tags
    'under-15-min': 'Under 15 min',
    'under-30-min': 'Under 30 min',
    'under-45-min': 'Under 45 min',
    'under-60-min': 'Under 60 min',
    'över-60-min': 'Över 60 min',
    // Difficulty
    'enkel': 'Enkel',
    'medel': 'Medel',
    'avancerad': 'Avancerad',
    // Dish types
    'pasta-dish': 'Pasta',
    'rice-dish': 'Ris',
    'noodle-dish': 'Nudlar',
    'potato-dish': 'Potatis',
    'bread-dish': 'Bröd',
    // Cuisine
    'svensk': 'Svenskt',
    'italiensk': 'Italienskt',
    'asiatisk': 'Asiatiskt',
    'japansk': 'Japanskt',
    'kinesisk': 'Kinesiskt',
    'thailändsk': 'Thailändskt',
    'vietnamesisk': 'Vietnamesiskt',
    'indisk': 'Indiskt',
    'mexikansk': 'Mexikanskt',
    'mellanöstern': 'Mellanöstern',
    'grekisk': 'Grekiskt',
    'fransk': 'Franskt',
    'spansk': 'Spanskt',
    'amerikansk': 'Amerikanskt',
    'koreansk': 'Koreanskt',
    // Practical
    'vardagsmiddag': 'Vardagsmiddag',
    'helgmat': 'Helgmat',
    'fredagsmys': 'Fredagsmys',
    'comfort-food': 'Comfort food',
    'barnvänlig': 'Barnvänlig',
    'frysbar': 'Frysbar',
    'meal-prep': 'Meal prep',
    'klimatsmart': 'Klimatsmart',
    'budgetvänlig': 'Budgetvänlig',
    'få-ingredienser': 'Få ingredienser',
    'snabblagat': 'Snabblagat',
    // Proteins
    'kyckling': 'Kyckling',
    'nötkött': 'Nötkött',
    'fläskkött': 'Fläsk',
    'fisk': 'Fisk',
    'skaldjur': 'Skaldjur',
    'vegetarisk': 'Vegetarisk',
    'vegansk': 'Vegansk',
  };

  /// Time buckets in tightest-first order. Used for display dedup — a 15-min
  /// recipe is stored with all of `under-15/30/45/60-min` (for filter matching)
  /// but should only show the tightest bucket on the recipe card.
  static const List<String> _timeBucketsTightestFirst = [
    'under-15-min',
    'under-30-min',
    'under-45-min',
    'under-60-min',
    'över-60-min',
  ];

  /// Returns the top N tags with smart prioritization.
  ///
  /// Priority order:
  /// 1. User-added tags (from [userAddedTags])
  /// 2. Auto-generated tags by category (protein → dish → cuisine → time → practical)
  /// 3. Remaining tags alphabetically
  ///
  /// [effectiveTags] All tags to choose from (auto-generated + user additions - removals)
  /// [userAddedTags] Tags manually added by user (shown first)
  /// [limit] Maximum number of tags to return (default: 5)
  static List<String> getTopTags(
    Set<String> effectiveTags,
    Set<String> userAddedTags, {
    int limit = 5,
  }) {
    if (effectiveTags.isEmpty) return [];

    final displayTags = _collapseTimeBuckets(effectiveTags);
    final result = <String>[];

    // 1. User-added tags first (in order they were added)
    for (final tag in userAddedTags) {
      if (displayTags.contains(tag) && result.length < limit) {
        result.add(tag);
      }
    }

    if (result.length >= limit) return result;

    // 2. Smart priority for auto-generated tags
    final remaining = displayTags.difference(userAddedTags);
    for (final category in _priorityCategories) {
      for (final tag in category) {
        if (remaining.contains(tag) &&
            !result.contains(tag) &&
            result.length < limit) {
          result.add(tag);
        }
      }
      if (result.length >= limit) return result;
    }

    // 3. Fill with remaining tags alphabetically
    final sorted = remaining.toList()..sort();
    for (final tag in sorted) {
      if (!result.contains(tag) && result.length < limit) {
        result.add(tag);
      }
    }

    return result;
  }

  /// Drops all time buckets except the tightest one present. A 15-min recipe
  /// stores all of `under-15/30/45/60-min` for filter matching, but for
  /// display we only want to show "Under 15 min".
  static Set<String> _collapseTimeBuckets(Set<String> tags) {
    final present =
        _timeBucketsTightestFirst.where(tags.contains).toList(growable: false);
    if (present.length <= 1) return tags;
    final collapsed = Set<String>.from(tags);
    for (var i = 1; i < present.length; i++) {
      collapsed.remove(present[i]);
    }
    return collapsed;
  }

  /// Returns a display-friendly name for a tag.
  ///
  /// Uses [_displayNames] for known tags, otherwise capitalizes first letter.
  static String getDisplayName(String tag) {
    if (_displayNames.containsKey(tag)) {
      return _displayNames[tag]!;
    }
    // Capitalize first letter, replace hyphens with spaces
    final formatted = tag.replaceAll('-', ' ');
    if (formatted.isEmpty) return formatted;
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  /// Returns display names for a list of tags.
  static List<String> getDisplayNames(List<String> tags) {
    return tags.map(getDisplayName).toList();
  }

  /// Checks if a tag is user-added (vs auto-generated).
  static bool isUserAddedTag(String tag, Set<String> userAddedTags) {
    return userAddedTags.contains(tag);
  }
}

import 'package:butlery/core/utils/serialization_utils.dart';

/// User preferences for allergen and dietary tracking in recipes.
///
/// Controls which allergens and dietary restrictions are displayed
/// on recipe cards and detail views.
class UserAllergenPreferences {
  /// Allergen keys the user wants to track and filter.
  final Set<String> trackedAllergens;

  /// Dietary preferences to display.
  final Set<String> trackedDietary;

  /// Show allergen badges on recipe cards.
  final bool showOnCards;

  /// Show allergen badges on detail view.
  final bool showOnDetail;

  /// Show coverage percentage.
  final bool showCoverage;

  /// Whether to include recipes with UNKNOWN allergen status in menu generation.
  /// When false, only recipes with FREE status pass allergen filtering.
  final bool includeUnknownInMenu;

  const UserAllergenPreferences({
    required this.trackedAllergens,
    required this.trackedDietary,
    this.showOnCards = true,
    this.showOnDetail = true,
    this.showCoverage = true,
    this.includeUnknownInMenu = true,
  });

  /// Default preferences with common allergens.
  static const defaults = UserAllergenPreferences(
    trackedAllergens: {
      'gluten',
      'mjölk',
      'nötter',
      'jordnötter',
    },
    trackedDietary: {
      'vegetarisk',
      'vegansk',
    },
    showOnCards: true,
    showOnDetail: true,
    showCoverage: true,
    includeUnknownInMenu: true,
  );

  /// Creates from Firestore map.
  factory UserAllergenPreferences.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return defaults;

    return UserAllergenPreferences(
      trackedAllergens:
          _parseStringSet(data['trackedAllergens']) ??
          defaults.trackedAllergens,
      trackedDietary:
          _parseStringSet(data['trackedDietary']) ?? defaults.trackedDietary,
      showOnCards: SerializationUtils.safeBool(
        data,
        'showOnCards',
        defaultValue: true,
      ),
      showOnDetail: SerializationUtils.safeBool(
        data,
        'showOnDetail',
        defaultValue: true,
      ),
      showCoverage: SerializationUtils.safeBool(
        data,
        'showCoverage',
        defaultValue: true,
      ),
      includeUnknownInMenu: SerializationUtils.safeBool(
        data,
        'includeUnknownInMenu',
        defaultValue: true,
      ),
    );
  }

  /// Converts to Firestore map.
  Map<String, dynamic> toFirestore() {
    return {
      'trackedAllergens': trackedAllergens.toList(),
      'trackedDietary': trackedDietary.toList(),
      'showOnCards': showOnCards,
      'showOnDetail': showOnDetail,
      'showCoverage': showCoverage,
      'includeUnknownInMenu': includeUnknownInMenu,
    };
  }

  /// Creates a copy with updated values.
  UserAllergenPreferences copyWith({
    Set<String>? trackedAllergens,
    Set<String>? trackedDietary,
    bool? showOnCards,
    bool? showOnDetail,
    bool? showCoverage,
    bool? includeUnknownInMenu,
  }) {
    return UserAllergenPreferences(
      trackedAllergens: trackedAllergens ?? this.trackedAllergens,
      trackedDietary: trackedDietary ?? this.trackedDietary,
      showOnCards: showOnCards ?? this.showOnCards,
      showOnDetail: showOnDetail ?? this.showOnDetail,
      showCoverage: showCoverage ?? this.showCoverage,
      includeUnknownInMenu: includeUnknownInMenu ?? this.includeUnknownInMenu,
    );
  }

  /// Adds an allergen to tracked list.
  UserAllergenPreferences trackAllergen(String allergen) {
    return copyWith(
      trackedAllergens: {...trackedAllergens, allergen},
    );
  }

  /// Removes an allergen from tracked list.
  UserAllergenPreferences untrackAllergen(String allergen) {
    return copyWith(
      trackedAllergens: trackedAllergens.where((a) => a != allergen).toSet(),
    );
  }

  /// Adds a dietary preference.
  UserAllergenPreferences trackDietary(String diet) {
    return copyWith(
      trackedDietary: {...trackedDietary, diet},
    );
  }

  /// Removes a dietary preference.
  UserAllergenPreferences untrackDietary(String diet) {
    return copyWith(
      trackedDietary: trackedDietary.where((d) => d != diet).toSet(),
    );
  }

  /// Whether user is tracking any allergens.
  bool get hasTrackedAllergens => trackedAllergens.isNotEmpty;

  /// Whether user is tracking any dietary preferences.
  bool get hasTrackedDietary => trackedDietary.isNotEmpty;

  /// Whether any preferences are active.
  bool get hasAnyPreferences => hasTrackedAllergens || hasTrackedDietary;

  static Set<String>? _parseStringSet(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => _normalizeAllergenKey(e.toString())).toSet();
    }
    return null;
  }

  /// Normalizes ASCII allergen keys to proper Swedish characters.
  /// Firestore data may contain ASCII-only keys from older clients or imports.
  static const _asciiToSwedish = {
    'mjolk': 'mjölk',
    'notter': 'nötter',
    'agg': 'ägg',
    'tradnotter': 'trädnötter',
    'kraftdjur': 'kräftdjur',
    'blotdjur': 'blötdjur',
    'kott': 'kött',
    'flask': 'fläsk',
    'notkott': 'nötkött',
  };

  static String _normalizeAllergenKey(String key) {
    return _asciiToSwedish[key] ?? key;
  }

  /// The same ASCII→Swedish mapping, for models that parse allergen keys
  /// without going through [fromFirestore] — `HouseholdAllergenShare` (BUT-1693)
  /// cannot use that factory, because it returns [defaults] for an absent map
  /// and would turn "no allergies" into four. Every allergen key that reaches a
  /// comparison must pass through here, or a legacy `mjolk` silently
  /// contributes nothing to the household union.
  static String normalizeAllergenKey(String key) => _normalizeAllergenKey(key);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAllergenPreferences &&
          runtimeType == other.runtimeType &&
          _setEquals(trackedAllergens, other.trackedAllergens) &&
          _setEquals(trackedDietary, other.trackedDietary) &&
          showOnCards == other.showOnCards &&
          showOnDetail == other.showOnDetail &&
          showCoverage == other.showCoverage &&
          includeUnknownInMenu == other.includeUnknownInMenu;

  static bool _setEquals<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  int get hashCode => Object.hash(
    trackedAllergens,
    trackedDietary,
    showOnCards,
    showOnDetail,
    showCoverage,
    includeUnknownInMenu,
  );

  @override
  String toString() =>
      'UserAllergenPreferences(${trackedAllergens.length} allergens, ${trackedDietary.length} dietary)';
}

/// Available allergens for user preferences UI.
class AllergenPreferenceOptions {
  AllergenPreferenceOptions._();

  /// All allergens users can track.
  static const Map<String, String> allergens = {
    'gluten': 'Gluten',
    'mjölk': 'Mjölk',
    'laktos': 'Laktos',
    'ägg': 'Ägg',
    'nötter': 'Nötter',
    'jordnötter': 'Jordnötter',
    'trädnötter': 'Trädnötter',
    'fisk': 'Fisk',
    'skaldjur': 'Skaldjur',
    'soja': 'Soja',
    'sesam': 'Sesam',
    'selleri': 'Selleri',
    'senap': 'Senap',
    'lupin': 'Lupin',
    'sulfiter': 'Sulfiter',
    'kött': 'Kött',
    'fläsk': 'Fläsk',
    'nötkött': 'Nötkött',
    'alkohol': 'Alkohol',
  };

  /// All dietary preferences users can track.
  static const Map<String, String> dietary = {
    'vegetarisk': 'Vegetarisk',
    'vegansk': 'Vegansk',
    'pescetarian': 'Pescetarian',
    'halalanpassad': 'Halalanpassad',
    'kosheranpassad': 'Kosheranpassad',
    'graviditetssäker': 'Graviditetssäker',
    'barnvänlig': 'Barnvänlig',
    'nötkötsfri': 'Nötkötsfri',
    'aip-vänlig': 'AIP-vänlig',
  };

  /// Gets Swedish label for an allergen key.
  static String getAllergenLabel(String key) => allergens[key] ?? key;

  /// Gets Swedish label for a dietary key.
  static String getDietaryLabel(String key) => dietary[key] ?? key;
}

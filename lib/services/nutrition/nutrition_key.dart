/// Turns an ingredient name into the keys nutrition matching uses.
///
/// A household's stored food choices are keyed by [storageKey], so changing
/// what it returns for a name orphans every choice already saved for it.
class NutritionKey {
  NutritionKey._();

  static const int maxStorageKeyLength = 60;

  static const Map<String, String> _decomposed = {
    'å': 'å',
    'ä': 'ä',
    'ö': 'ö',
    'é': 'é',
    'è': 'è',
    'ü': 'ü',
  };

  static const Map<String, String> _accents = {
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ü': 'u',
    'ú': 'u',
    'ï': 'i',
    'í': 'i',
    'ñ': 'n',
    'ç': 'c',
    'ô': 'o',
    'ó': 'o',
    'ò': 'o',
    'ø': 'ö',
    'æ': 'ä',
    'î': 'i',
    'ì': 'i',
    'û': 'u',
    'ù': 'u',
    'ë': 'e',
    'ã': 'a',
    'œ': 'oe',
    'ß': 'ss',
  };

  /// Lowercase, accents folded except å/ä/ö, punctuation as spaces, single
  /// spaces: "Crème fraiche," and "creme  fraiche" give the same key.
  static String lookupKey(String name) {
    var s = name.toLowerCase();
    _decomposed.forEach((from, to) => s = s.replaceAll(from, to));
    _accents.forEach((from, to) => s = s.replaceAll(from, to));
    s = s.replaceAll(RegExp(r'[^a-zåäö0-9%\- ]'), ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// The key a household choice is stored under; matches the shape
  /// `firestore.rules` accepts (`^[a-zåäö0-9_]{1,60}$`). Null when nothing
  /// usable is left.
  static String? storageKey(String name) {
    var s = lookupKey(name).replaceAll(RegExp(r'[%\- ]'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    if (s.length > maxStorageKeyLength) {
      s = s.substring(0, maxStorageKeyLength).replaceAll(RegExp(r'_$'), '');
    }
    return s.isEmpty ? null : s;
  }
}

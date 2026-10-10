import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';

/// The recipes of one cookbook in the order the book shows them (BUT-1325).
///
/// [recipes] may be the whole library; only those carrying [tagId] are in
/// the book. Without an own order the book is A–Ö. With one, the listed
/// recipes come first in that order and the rest (tagged from the recipe
/// screen or by a rule after the last reorder) follow A–Ö. Listed ids whose
/// recipe no longer carries the tag are skipped.
List<Recipe> orderCookbookRecipes({
  required String tagId,
  required Iterable<Recipe> recipes,
  required CookbookDetails cookbook,
}) {
  final inBook = recipes
      .where((r) => r.core.personalTagIds?.contains(tagId) ?? false)
      .toList();
  final order = cookbook.recipeOrder;
  if (order == null) return inBook..sort(compareRecipeTitles);

  final byId = {for (final r in inBook) r.id: r};
  final listed = <Recipe>[];
  for (final id in order) {
    final recipe = byId.remove(id);
    if (recipe != null) listed.add(recipe);
  }
  return [...listed, ...byId.values.toList()..sort(compareRecipeTitles)];
}

/// Swedish A–Ö: å, ä and ö sort after z, and case is ignored.
int compareRecipeTitles(Recipe a, Recipe b) =>
    compareSwedish(a.title.trim(), b.title.trim());

// The three code points right after 'z', so å < ä < ö all sort after z;
// é and ü sort with e and y as in Swedish dictionaries.
const _swedishTail = {
  'å': '{',
  'ä': '|',
  'ö': '}',
  'é': 'e',
  'è': 'e',
  'ü': 'y',
};

int compareSwedish(String a, String b) {
  String key(String s) {
    final lower = s.toLowerCase();
    final buffer = StringBuffer();
    for (final ch in lower.split('')) {
      buffer.write(_swedishTail[ch] ?? ch);
    }
    return buffer.toString();
  }

  return key(a).compareTo(key(b));
}

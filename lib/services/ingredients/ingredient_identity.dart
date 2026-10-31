import 'package:butlery/constants/grocery_brands.dart';
import 'package:butlery/constants/preparation_words.dart';
import 'package:butlery/utils/text/swedish_character_normalizer.dart';
import 'package:butlery/utils/text/swedish_pluralization.dart';

/// The one answer to "is this the same ingredient?" for the pantry, the
/// shopping list and check-off, so they cannot drift apart.
class IngredientIdentity {
  const IngredientIdentity._();

  // Descriptors that name a different product on the shelf: smoked salmon
  // at home does not cover fresh salmon, and dried tomatoes do not cover
  // tomatoes. Cutting and size words are dropped; these are kept.
  static const _productStates = {
    'rökt',
    'rökta',
    'rökte',
    'torkad',
    'torkat',
    'torkade',
    'frystorkad',
    'frystorkat',
    'frystorkade',
    'krossad',
    'krossat',
    'krossade',
    'passerad',
    'passerat',
    'passerade',
    'rimmad',
    'rimmat',
    'rimmade',
    'saltad',
    'saltat',
    'saltade',
    'sötad',
    'sötat',
    'sötade',
    'osötad',
    'osötat',
    'osötade',
    'marinerad',
    'marinerat',
    'marinerade',
    'kokt',
    'kokta',
    'stekt',
    'stekta',
    'grillad',
    'grillat',
    'grillade',
    'rostad',
    'rostat',
    'rostade',
    'bakad',
    'bakat',
    'bakade',
    'malen',
    'malet',
    'malda',
  };

  // A colour names a different product too: "röd lök" is the rödlök on
  // the shelf, not lök, and black beans do not cover white ones. The colour
  // joins the next word, so "röd lök" and "rödlök" read the same.
  static const _colourStems = {
    'gul': 'gul',
    'gula': 'gul',
    'gult': 'gul',
    'röd': 'röd',
    'röda': 'röd',
    'rött': 'röd',
    'vit': 'vit',
    'vita': 'vit',
    'vitt': 'vit',
    'grön': 'grön',
    'gröna': 'grön',
    'grönt': 'grön',
    'svart': 'svart',
    'svarta': 'svart',
    'brun': 'brun',
    'bruna': 'brun',
    'brunt': 'brun',
    'orange': 'orange',
    'orangea': 'orange',
    'rosa': 'rosa',
    'ljus': 'ljus',
    'ljusa': 'ljus',
    'ljust': 'ljus',
    'mörk': 'mörk',
    'mörka': 'mörk',
    'mörkt': 'mörk',
  };

  // In a recipe "lök" means the yellow onion (Malin 2026-10-31), and
  // "peppar" the black pepper, so their other names are the same product.
  static const _sameProduct = {
    'gullok': 'lok',
    'matlok': 'lok',
    'svartpeppar': 'peppar',
  };

  // Joining would turn these into another product: white onion is not the
  // vitlök (garlic) on the shelf.
  static const _notJoined = {'vitlök'};

  static final _whitespace = RegExp(r'\s+');
  static final _parenthetical = RegExp(r'\([^)]*\)');

  static String nameKey(String name) {
    final cleaned = name
        .toLowerCase()
        .replaceAll(_parenthetical, ' ')
        .replaceAll(_whitespace, ' ')
        .trim();
    final words = cleaned.isEmpty ? <String>[] : cleaned.split(' ');
    final kept = words
        .where(
          (w) =>
              _productStates.contains(w) ||
              _colourStems.containsKey(w) ||
              !PreparationWords.shouldRemove(w),
        )
        .toList();
    // A name made only of descriptors ("stor") is still a name.
    var base = kept.isEmpty ? words : kept;
    if (base.isEmpty) return '';
    // "Arla mellanmjölk" on the list is the mellanmjölk the pantry holds,
    // as the registry lookup already treats it.
    final folded = SwedishCharacterNormalizer.normalize(base.join(' '));
    final unbranded = GroceryBrands.strip(folded);
    if (unbranded != null) {
      final brandWords = base.length - unbranded.split(' ').length;
      base = folded.endsWith(unbranded)
          ? base.sublist(brandWords)
          : base.sublist(0, base.length - brandWords);
    }
    // Only the head noun of a compound phrase carries the plural.
    base[base.length - 1] = SwedishPluralization.normalizeToSingular(
      base.last,
    );
    // Joined after the plural is read, which does not see into a compound.
    base = _joinColours(base);
    // Folded last so "lok" keeps matching "lök", as the pantry deduction does.
    final key = SwedishCharacterNormalizer.normalize(base.join(' '));
    return _sameProduct[key] ?? key;
  }

  // A colour joins the word after it. Where there is none, or the join
  // would name another product, the colour is dropped as before.
  static List<String> _joinColours(List<String> words) {
    final joined = <String>[];
    for (var i = 0; i < words.length; i++) {
      final stem = _colourStems[words[i]];
      if (stem == null) {
        joined.add(words[i]);
      } else if (i + 1 < words.length &&
          !_notJoined.contains('$stem${words[i + 1]}')) {
        joined.add('$stem${words[++i]}');
      }
    }
    return joined.isEmpty ? words : joined;
  }

  /// Whether two rows are one product: the same registry id
  /// (`RecipeIngredient.ingredientId`, `PantryItem.ingredientId`), or the
  /// same name as [same] reads it. Different ids do not keep two rows of one
  /// name apart, since the name match is what the list relied on before rows
  /// carried an id.
  static bool sameItem(
    String name,
    String? id,
    String otherName,
    String? otherId,
  ) => (id != null && id == otherId) || same(name, otherName);

  static bool same(String a, String b) => nameKey(a) == nameKey(b);
}

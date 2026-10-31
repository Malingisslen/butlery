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
              _productStates.contains(w) || !PreparationWords.shouldRemove(w),
        )
        .toList();
    // A name made only of descriptors ("stor") is still a name.
    final base = kept.isEmpty ? words : kept;
    if (base.isEmpty) return '';
    // Only the head noun of a compound phrase carries the plural.
    base[base.length - 1] = SwedishPluralization.normalizeToSingular(
      base.last,
    );
    // Folded last so "lok" keeps matching "lök", as the pantry deduction does.
    return SwedishCharacterNormalizer.normalize(base.join(' '));
  }

  static bool same(String a, String b) => nameKey(a) == nameKey(b);
}

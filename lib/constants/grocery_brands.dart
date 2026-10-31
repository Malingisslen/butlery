import 'package:butlery/utils/text/swedish_character_normalizer.dart';

/// Swedish grocery brand names that recipes and pantry rows put in front of
/// (or after) a generic product: "Arla mellanmjölk", "krossade tomater
/// Mutti". The registry holds the product, not the brand, so the lookup
/// tries the name again without the brand when the whole name has no entry.
///
/// A brand that IS the product name in Swedish kitchens ("Bregott", "Keso",
/// "Philadelphia", "Oatly") is a registry alias instead and does not belong
/// here. Neither does a brand that is also an ordinary word ("Druvan").
class GroceryBrands {
  GroceryBrands._();

  static const List<String> _brands = [
    'abba',
    'alpro',
    'arla',
    'barilla',
    'blå band',
    'bonne',
    'carlshamn',
    'coop',
    'dan sukker',
    'eldorado',
    'felix',
    'findus',
    'garant',
    'gevalia',
    'heinz',
    'ica basic',
    'ica',
    'idun',
    'ingelsta',
    'kavli',
    'knorr',
    'kockens',
    'kronfågel',
    'kungsörnen',
    'lantmännen',
    'lindahls',
    'marabou',
    'mutti',
    'norrmejerier',
    'pågen',
    'risenta',
    'saltå kvarn',
    'santa maria',
    'scan',
    'skånemejerier',
    'uncle bens',
    'valio',
    'zeta',
    'zoégas',
    'änglamark',
  ];

  // Longest first, so "ica basic" is taken whole before "ica".
  static final List<String> _normalized =
      _brands.map(SwedishCharacterNormalizer.normalize).toList()
        ..sort((a, b) => b.length.compareTo(a.length));

  /// [name] (lowercase, å/ä/ö already folded as the lookup does) without a
  /// leading or trailing brand, or null when it carries none or is nothing
  /// but the brand.
  static String? strip(String name) {
    for (final brand in _normalized) {
      if (name.startsWith('$brand ')) {
        final rest = name.substring(brand.length + 1).trim();
        return rest.isEmpty ? null : rest;
      }
      if (name.endsWith(' $brand')) {
        final rest = name.substring(0, name.length - brand.length - 1).trim();
        return rest.isEmpty ? null : rest;
      }
    }
    return null;
  }
}

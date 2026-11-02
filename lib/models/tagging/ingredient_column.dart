import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';

enum IngredientColumnKind { text, list, number }

/// The CSV columns an admin may propose changes to. The wire name is the CSV
/// column because the proposal is later applied to the CSV, not to Firestore.
///
/// This enum is the single column <-> [IngredientData] field table: the old
/// value of a proposal is read through [oldValueOf], and the comparison that
/// decides "changed?" is [valuesEqual].
enum IngredientColumn {
  swedish('swedish', IngredientColumnKind.text),
  english('english', IngredientColumnKind.text),
  group('group', IngredientColumnKind.text),
  properties('properties', IngredientColumnKind.list),
  aliasesSv('aliases_sv', IngredientColumnKind.list),
  aliasesEn('aliases_en', IngredientColumnKind.list),
  searchTerms('search_terms', IngredientColumnKind.list),
  notesSv('notes_sv', IngredientColumnKind.text),
  notesEn('notes_en', IngredientColumnKind.text),
  seasonAvailability('season_availability', IngredientColumnKind.list),
  typicalStorage('typical_storage', IngredientColumnKind.text),
  typicalUnit('typical_unit', IngredientColumnKind.text),
  priceCategory('price_category', IngredientColumnKind.text),
  avgPriceSek('avg_price_sek', IngredientColumnKind.number),
  carbonFootprintCategory(
    'carbon_footprint_category',
    IngredientColumnKind.text,
  ),
  status('status', IngredientColumnKind.text)
  ;

  const IngredientColumn(this.csvName, this.kind);

  final String csvName;
  final IngredientColumnKind kind;

  static IngredientColumn? fromCsvName(String name) {
    for (final c in values) {
      if (c.csvName == name) return c;
    }
    return null;
  }

  /// The value as the ingredient document holds it: text is `''` when absent,
  /// lists are lists (properties sorted, as a set has no order) and the price
  /// is a number or null. List elements are kept verbatim, including any that
  /// contain a separator, because the old value must match what Firestore holds.
  Object? oldValueOf(IngredientData i) => switch (this) {
    swedish => i.swedish,
    english => i.english,
    group => i.group,
    properties => (i.properties.toList()..sort()),
    aliasesSv => List<String>.of(i.aliasesSv),
    aliasesEn => List<String>.of(i.aliasesEn),
    searchTerms => List<String>.of(i.searchTerms),
    notesSv => i.notesSv.orEmpty(),
    notesEn => i.notesEn.orEmpty(),
    seasonAvailability => List<String>.of(i.seasonAvailability),
    typicalStorage => i.typicalStorage.orEmpty(),
    typicalUnit => i.typicalUnit.orEmpty(),
    priceCategory => i.priceCategory.orEmpty(),
    avgPriceSek => i.avgPriceSek,
    carbonFootprintCategory => i.carbonFootprintCategory.orEmpty(),
    status => i.status,
  };

  /// Lists compare without regard to order, the price numerically, text
  /// exactly (after trimming, which is what the sync does to every cell).
  bool valuesEqual(Object? a, Object? b) {
    switch (kind) {
      case IngredientColumnKind.list:
        final x = _asList(a)..sort();
        final y = _asList(b)..sort();
        if (x.length != y.length) return false;
        for (var n = 0; n < x.length; n++) {
          if (x[n] != y[n]) return false;
        }
        return true;
      case IngredientColumnKind.number:
        final x = a is num ? a.toDouble() : null;
        final y = b is num ? b.toDouble() : null;
        return x == y;
      case IngredientColumnKind.text:
        return _asText(a).trim() == _asText(b).trim();
    }
  }

  static List<String> _asList(Object? v) =>
      v is Iterable ? [for (final e in v) e.toString()] : <String>[];

  static String _asText(Object? v) => v == null ? '' : v.toString();
}

import 'package:butlery/models/recipe/meal_types.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Turns one spreadsheet row (header → cell) into a recipe.
///
/// Column names are matched in Swedish and English, because the people who
/// import a file wrote the header row themselves. Nothing is invented: a row
/// without a title is skipped, and an empty description or ingredient list
/// stays empty rather than getting placeholder text the user then sees.
class SpreadsheetRecipeMapper {
  const SpreadsheetRecipeMapper._();

  /// Lower-cased, trimmed, `_` and `-` read as spaces and inner whitespace
  /// collapsed, so "Gör  så här " and "gör_så_här" find the same column.
  static String normalizeHeader(Object? header) => (header?.toString())
      .orEmpty()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_-]+'), ' ')
      .trim();

  static const _titleKeys = [
    'title',
    'titel',
    'namn',
    'name',
    'recipe',
    'recipe name',
    'recept',
    'receptnamn',
    'rätt',
  ];
  static const _descriptionKeys = ['description', 'beskrivning'];
  static const _ingredientKeys = [
    'ingredients',
    'ingredienser',
    'ingredient',
    'ingrediens',
    'ingredient list',
  ];
  static const _instructionKeys = [
    'instructions',
    'instruktioner',
    'steps',
    'steg',
    'cooking steps',
    'gör så här',
    'tillagning',
    'directions',
    'method',
  ];
  static const _mealTypeKeys = [
    'mealtype',
    'meal type',
    'måltidstyp',
    'måltid',
  ];
  static const _categoryKeys = ['kategori', 'category', 'categories'];
  static const _timeKeys = [
    'cookingtime',
    'prep time',
    'cooking time',
    'tid',
    'tillagningstid',
    'time',
    'minuter',
  ];
  static const _servingKeys = [
    'servings',
    'serving size',
    'portions',
    'portioner',
    'serves',
  ];
  static const _tagKeys = ['tags', 'taggar', 'keywords', 'nyckelord'];
  static const _ratingKeys = ['rating', 'betyg', 'score'];
  static const _sourceKeys = ['source', 'källa', 'url', 'länk'];
  static const _imageKeys = [
    'image',
    'bild',
    'imageurl',
    'image url',
    'bild url',
  ];

  /// The recipe in [data], keyed by [normalizeHeader]ed column names; null
  /// when the row has no title.
  static Recipe? fromRow(Map<String, String> data) {
    final title = _first(data, _titleKeys);
    if (title == null) return null;

    final category = _first(data, _categoryKeys);
    final categoryMealType = category == null ? null : mealTypeFor([category]);
    final explicitMealType = _first(data, _mealTypeKeys);
    final tags = [
      ..._split(_first(data, _tagKeys), RegExp(r'[,;|]')),
      // A category that names no meal type is the user's own label.
      if (category != null && categoryMealType == null) category,
    ];

    return Recipe(
      core: RecipeCore(
        id: const Uuid().v4(),
        title: title,
        description: _first(data, _descriptionKeys).orEmpty(),
        ingredients: _ingredients(data),
        instructions: _instructions(data),
        mealType:
            (explicitMealType == null
                ? null
                : mealTypeFor([explicitMealType])) ??
            categoryMealType ??
            'Middag',
        portions: _firstInt(_first(data, _servingKeys)) ?? 4,
        timeMinutes: _firstInt(_first(data, _timeKeys)) ?? 30,
        // Still NAMES here; FileImportViewModel turns them into tag ids before
        // the recipe is saved.
        personalTagIds: tags.toSet().toList(),
        rating: double.tryParse(
          _first(data, _ratingKeys).orEmpty().replaceAll(',', '.'),
        ),
        // BUT-1819: absent provenance is `null`, and the row then draws
        // nothing; a fallback token would appear verbatim under the title.
        sourceUrl: _first(data, _sourceKeys),
        imageUrls: [?_first(data, _imageKeys)],
        createdBy: null,
        isPublic: false,
      ),
      type: RecipeType.personal,
    );
  }

  /// The first of [labels] that names a meal type, as the app spells it.
  static String? mealTypeFor(Iterable<String> labels) => labels
      .map(MealTypes.match)
      .nonNulls
      .firstOrNull;

  static List<String> _ingredients(Map<String, String> data) {
    final cell = _first(data, _ingredientKeys);
    if (cell != null) return _split(cell, RegExp(r'[;\n|]'));
    return _numberedColumns(data, const ['ingredient', 'ingrediens'], 50);
  }

  static List<String> _instructions(Map<String, String> data) {
    final cell = _first(data, _instructionKeys);
    if (cell == null) {
      return _numberedColumns(data, const [
        'step',
        'steg',
        'instruction',
      ], 20).map(_stripLeadingNumber).toList();
    }
    return _split(cell, RegExp(r'[;\n|]'))
        .expand(splitNumberedSteps)
        .map(_stripLeadingNumber)
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// "1. Sätt ugnen på 175. 2. Blanda" → two steps. Only a run that starts
  /// at 1 and counts up in order is numbering, so a temperature or amount
  /// followed by a full stop stays in its step.
  static List<String> splitNumberedSteps(String text) {
    final trimmed = text.trim();
    if (!RegExp(r'^1[.)]\s').hasMatch(trimmed)) return [trimmed];
    final starts = <int>[0];
    for (var n = 2; ; n++) {
      final next = RegExp(
        '\\s$n[.)]\\s',
      ).firstMatch(trimmed.substring(starts.last + 1));
      if (next == null) break;
      starts.add(starts.last + 1 + next.start + 1);
    }
    return [
      for (var i = 0; i < starts.length; i++)
        trimmed
            .substring(
              starts[i],
              i + 1 < starts.length ? starts[i + 1] : trimmed.length,
            )
            .trim(),
    ];
  }

  static String _stripLeadingNumber(String step) =>
      step.replaceFirst(RegExp(r'^\d{1,2}[.)]\s+'), '').trim();

  static List<String> _numberedColumns(
    Map<String, String> data,
    List<String> prefixes,
    int max,
  ) => [
    for (var i = 1; i <= max; i++)
      ?_first(data, [
        for (final p in prefixes) ...['$p$i', '$p $i'],
      ]),
  ];

  static List<String> _split(String? cell, Pattern on) => cell
      .orEmpty()
      .split(on)
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  static String? _first(Map<String, String> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static int? _firstInt(String? text) {
    final match = RegExp(r'\d+').firstMatch(text.orEmpty());
    return match == null ? null : int.tryParse(match.group(0)!);
  }
}

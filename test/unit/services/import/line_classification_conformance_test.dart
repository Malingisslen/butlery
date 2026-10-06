// BUT-2242 / BUT-1776: the text import path (TextImportStrategy) and the
// rule-based URL path (SwedishLineClassifier, what RuleBasedTier runs) must
// classify the same recipe line the same way. Each case runs ONE line through
// both real paths inside the same surrounding text and compares the outcome:
// kept as an ingredient (with the exact text kept), taken as the heading of
// the row below it, or left out. Where the paths deliberately differ, the row
// names the recorded deviation and asserts both sides.
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/parsing/parsers/swedish_line_classifier.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

/// Where the line sits: inside a marked ingredient block (A), inside an
/// unmarked run of rows (B), or opening a paragraph above a quantity row (C).
const _contexts = <String, String Function(String)>{
  'A': _inMarkedBlock,
  'B': _inUnmarkedRun,
  'C': _openingParagraph,
};

String _inMarkedBlock(String line) =>
    'Kaka\nIngredienser:\n2 dl socker\n$line\n1 tsk bakpulver\n\n'
    'Gör så här:\nBlanda allt och grädda i ugnen i 30 minuter.';

String _inUnmarkedRun(String line) =>
    'Kaka\n\n2 dl socker\n$line\n1 tsk bakpulver\n\n'
    'Blanda allt och grädda i ugnen i 30 minuter.';

String _openingParagraph(String line) =>
    'Kaka\n\n2 dl socker\n1 tsk bakpulver\n\n$line\n2 dl grädde\n1 msk smör\n\n'
    'Gör så här:\nBlanda allt och grädda i ugnen i 30 minuter.';

/// The row below the fixture line in each context, used to read its group.
const _nextRow = {'A': 'bakpulver', 'B': 'bakpulver', 'C': 'grädde'};

/// Expected outcome per line. A plain string applies to both paths in every
/// context. A map gives per-context or per-path values: keys are a context
/// ('A', 'B', 'C') and/or a path ('text', 'url'), or 'C.text' for both.
const _expected = <String, Object>{
  // BUT-1714/BUT-1727: a lone gluten word with a colon stays an ingredient,
  // colon removed so lookup can resolve it.
  'Mjöl:': 'ING(mjöl)',
  'Råg:': 'ING(råg)',
  'Öl:': 'ING(öl)',
  'Havregryn:': 'ING(havregryn)',
  'Vetemjöl:': 'ING(vetemjöl)',
  'Rågmjöl:': 'ING(rågmjöl)',
  // D1 (Malin, 2026-10-06): one word that `looksLikeIngredient` accepts,
  // with a colon, is an ingredient, colon removed.
  'Mjölk:': 'ING(mjölk)',
  'Ägg:': 'ING(ägg)',
  'Soja:': 'HEAD(soja)',
  // D5: a multi-word colon label `looksLikeIngredient` accepts is a heading on
  // the URL path; the text path keeps the raw line as an ingredient.
  'Till kyckling:': {
    'text': 'ING(till kyckling:)',
    'url': 'HEAD(till kyckling)',
  },
  'ägg': 'ING(ägg)',
  'parmesanost': 'ING(parmesanost)',
  'salt': 'ING(salt)',
  'Ägg': 'ING(ägg)',
  'Salt': 'ING(salt)',
  // D2 (Malin, 2026-10-06): a capitalised bare word opening a paragraph is
  // an ingredient.
  'Parmesanost': 'ING(parmesanost)',
  'Gräddsås': 'ING(gräddsås)',
  'Gräddsås:': 'HEAD(gräddsås)',
  'Deg:': 'HEAD(deg)',
  'Till servering:': 'HEAD(till servering)',
  // D3: a colon-less vocabulary heading groups the rows below it on the URL
  // path only; neither path keeps it as an ingredient.
  'Till servering': {'text': 'ABSENT', 'url': 'HEAD(till servering)'},
  'Ingredienser': 'ABSENT',
  'Ingredienser:': 'ABSENT',
};

String _expectedFor(String line, String context, String path) {
  final e = _expected[line]!;
  if (e is String) return e;
  final m = e as Map<String, String>;
  return m['$context.$path'] ?? m[path] ?? m[context] ?? m['default']!;
}

String _verdict({
  required String line,
  required List<String> flat,
  required String? sectionOfNextRow,
}) {
  final raw = line.trim().toLowerCase();
  final label = raw.endsWith(':') ? raw.substring(0, raw.length - 1) : raw;
  final lower = flat.map((e) => e.trim().toLowerCase()).toList();
  if (lower.contains(label)) return 'ING($label)';
  if (lower.contains(raw)) return 'ING($raw)';
  if (sectionOfNextRow?.toLowerCase() == label) return 'HEAD($label)';
  return 'ABSENT';
}

Future<String> _textPath(String text, String line, String next) async {
  final recipe = (await TextImportStrategy().import(text)).recipe;
  expect(recipe, isNotNull, reason: 'the text path found no recipe');
  final row = recipe!.structuredIngredients
      .where((i) => i.raw.toLowerCase().contains(next))
      .firstOrNull;
  return _verdict(
    line: line,
    flat: recipe.ingredients,
    sectionOfNextRow: row?.section,
  );
}

String _urlPath(String text, String line, String next) {
  final s = SwedishLineClassifier.instance.parseStructure(
    text,
    captureSubHeadings: true,
  );
  final i = s.ingredients.indexWhere((r) => r.toLowerCase().contains(next));
  return _verdict(
    line: line,
    flat: s.ingredients,
    sectionOfNextRow: i < 0 ? null : s.ingredientSections[i],
  );
}

void main() {
  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  for (final line in _expected.keys) {
    for (final context in _contexts.keys) {
      final text = _contexts[context]!(line);
      final next = _nextRow[context]!;
      test('text path: "$line" in context $context', () async {
        expect(
          await _textPath(text, line, next),
          _expectedFor(line, context, 'text'),
        );
      });
      test('url path: "$line" in context $context', () {
        expect(
          _urlPath(text, line, next),
          _expectedFor(line, context, 'url'),
        );
      });
    }
  }

  // D4: on its own the URL classifier takes a bare first line as the recipe
  // title, so the fixtures above never put the line first.
  test('url path: a lone first-line word is the title', () {
    final s = SwedishLineClassifier.instance.parseStructure(
      'ägg\n2 dl socker\n1 tsk bakpulver',
      captureSubHeadings: true,
    );
    expect(s.title?.toLowerCase(), 'ägg');
  });
}

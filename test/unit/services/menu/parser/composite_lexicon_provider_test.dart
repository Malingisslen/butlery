/// Unit tests for [CompositeLexiconProvider].
///
/// Verifies merge semantics: Firestore overlay overrides code defaults,
/// missing categories fall through, empty Firestore returns pure code lexicon.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/menu/parser/composite_lexicon_provider.dart';
import 'package:butlery/services/menu/parser/lexicon_provider.dart';

/// Stub provider that returns a fixed lexicon.
class _StubLexiconProvider implements LexiconProvider {
  final Lexicon _lexicon;
  int loadCount = 0;

  _StubLexiconProvider(this._lexicon);

  @override
  Future<Lexicon> load() async {
    loadCount++;
    return _lexicon;
  }
}

void main() {
  group('CompositeLexiconProvider', () {
    test('merges code and firestore — firestore wins on conflict', () async {
      final code = _StubLexiconProvider(Lexicon({
        LexiconCategory.dietaryStems: {'vegansk': 'vegan', 'lchf': 'lchf'},
        LexiconCategory.cuisineStems: {'japanskt': 'japanese'},
      }));

      final firestore = _StubLexiconProvider(Lexicon({
        LexiconCategory.dietaryStems: {'vegansk': 'vegan_override'},
      }));

      final composite = CompositeLexiconProvider(
        code: code,
        firestore: firestore,
      );

      final result = await composite.load();

      // Firestore override wins
      expect(
          result.of(LexiconCategory.dietaryStems)['vegansk'], 'vegan_override');
      // Code-only entry passes through
      expect(result.of(LexiconCategory.dietaryStems)['lchf'], 'lchf');
      // Code-only category passes through
      expect(result.of(LexiconCategory.cuisineStems)['japanskt'], 'japanese');
    });

    test('empty firestore returns pure code lexicon', () async {
      final code = _StubLexiconProvider(Lexicon({
        LexiconCategory.mealStems: {'middag': 'middag'},
      }));
      final firestore = _StubLexiconProvider(const Lexicon.empty());

      final composite = CompositeLexiconProvider(
        code: code,
        firestore: firestore,
      );

      final result = await composite.load();

      expect(result.of(LexiconCategory.mealStems)['middag'], 'middag');
    });

    test('firestore adds new category not in code', () async {
      final code = _StubLexiconProvider(Lexicon({
        LexiconCategory.mealStems: {'lunch': 'lunch'},
      }));
      final firestore = _StubLexiconProvider(Lexicon({
        LexiconCategory.themeStems: {'festmat': 'festive'},
      }));

      final composite = CompositeLexiconProvider(
        code: code,
        firestore: firestore,
      );

      final result = await composite.load();

      expect(result.of(LexiconCategory.mealStems)['lunch'], 'lunch');
      expect(result.of(LexiconCategory.themeStems)['festmat'], 'festive');
    });

    test('both providers are called exactly once', () async {
      final code = _StubLexiconProvider(const Lexicon.empty());
      final firestore = _StubLexiconProvider(const Lexicon.empty());

      final composite = CompositeLexiconProvider(
        code: code,
        firestore: firestore,
      );

      await composite.load();

      expect(code.loadCount, 1);
      expect(firestore.loadCount, 1);
    });
  });
}

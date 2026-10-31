/// A failed Firestore lexicon read must not stick for the session: the
/// generation still runs on the code lexicon, and the next one asks again.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_menu_lexicon_repository.dart';
import 'package:butlery/services/menu/parser/code_lexicon_provider.dart';
import 'package:butlery/services/menu/parser/composite_lexicon_provider.dart';
import 'package:butlery/services/menu/parser/firestore_lexicon_provider.dart';
import 'package:butlery/services/menu/parser/lexicon_provider.dart';
import 'package:butlery/services/menu_service.dart';

import '../../infrastructure/factories/recipe_factory.dart';

class _ThrowingFirestore extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      throw StateError('offline');
}

/// Hands out the queued lexicons in order and counts the loads.
class _ScriptedProvider implements LexiconProvider {
  _ScriptedProvider(this._script);

  final List<Lexicon> _script;
  int loads = 0;

  @override
  Future<Lexicon> load() async =>
      _script[loads++ < _script.length ? loads - 1 : _script.length - 1];
}

void main() {
  const code = CodeLexiconProvider();

  Future<Lexicon> incompleteCode() async {
    final base = await code.load();
    return base.mergedWith(const Lexicon({}, isComplete: false));
  }

  List<Recipe> dinners() => [
    RecipeFactory.build(id: 'd1', title: 'd1', mealType: 'middag'),
    RecipeFactory.build(id: 'd2', title: 'd2', mealType: 'middag'),
  ];

  group('Lexicon.isComplete', () {
    test('a merge is complete only when both parts are', () {
      const complete = Lexicon({});
      const incomplete = Lexicon({}, isComplete: false);

      expect(complete.mergedWith(complete).isComplete, isTrue);
      expect(complete.mergedWith(incomplete).isComplete, isFalse);
      expect(incomplete.mergedWith(complete).isComplete, isFalse);
    });
  });

  group('Firestore lexicon provider chain', () {
    test(
      'an unreadable collection yields a usable but incomplete lexicon',
      () async {
        final provider = CompositeLexiconProvider(
          code: code,
          firestore: FirestoreLexiconProvider(
            repository: FirebaseMenuLexiconRepository(
              firestore: _ThrowingFirestore(),
            ),
          ),
        );

        final lexicon = await provider.load();

        expect(lexicon.isComplete, isFalse);
        expect(lexicon.of(LexiconCategory.mealStems), isNotEmpty);
      },
    );

    test('an empty but readable collection is complete', () async {
      final provider = CompositeLexiconProvider(
        code: code,
        firestore: FirestoreLexiconProvider(
          repository: FirebaseMenuLexiconRepository(
            firestore: FakeFirebaseFirestore(),
          ),
        ),
      );

      expect((await provider.load()).isComplete, isTrue);
    });

    test('the repository reports failure only when the fetch threw', () async {
      final failing = FirebaseMenuLexiconRepository(
        firestore: _ThrowingFirestore(),
      );
      final healthy = FirebaseMenuLexiconRepository(
        firestore: FakeFirebaseFirestore(),
      );

      expect((await failing.loadOverridesWithStatus()).failed, isTrue);
      expect((await healthy.loadOverridesWithStatus()).failed, isFalse);
    });
  });

  group('MenuService lexicon cache', () {
    test('generation still works on an incomplete lexicon', () async {
      final provider = _ScriptedProvider([await incompleteCode()]);
      final service = MenuService(lexiconProvider: provider);

      final menu = await service.generateMenuFromPrompt('en middag', dinners());

      expect(menu, isNotEmpty);
    });

    test(
      'an incomplete lexicon is loaded again by the next call, once per call',
      () async {
        final provider = _ScriptedProvider([await incompleteCode()]);
        final service = MenuService(lexiconProvider: provider);

        await service.generateMenuFromPrompt('en middag', dinners());
        expect(provider.loads, 1);
        await service.generateMenuFromPrompt('en middag', dinners());
        expect(provider.loads, 2);
      },
    );

    test('once a complete lexicon loads, it is kept', () async {
      final provider = _ScriptedProvider([
        await incompleteCode(),
        await code.load(),
      ]);
      final service = MenuService(lexiconProvider: provider);

      await service.generateMenuFromPrompt('en middag', dinners());
      await service.generateMenuFromPrompt('en middag', dinners());
      expect(provider.loads, 2);
      await service.generateMenuFromPrompt('en middag', dinners());
      await service.parsePrompt('en middag');

      expect(provider.loads, 2, reason: 'a complete lexicon is cached');
    });
  });
}

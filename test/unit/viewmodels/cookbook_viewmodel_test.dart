import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/services/tagging/cookbook_service.dart';
import 'package:butlery/viewmodels/cookbook_viewmodel.dart';

import '../../test_support/base_unit_test.dart';
import '../../test_support/cookbook_fixtures.dart';

class _MockCookbookService extends Mock implements CookbookService {}

void main() {
  late _MockCookbookService service;
  late StreamController<List<PersonalTag>> tagStream;
  late List<Recipe> library;
  late CookbookViewModel vm;

  setUpAll(() {
    registerFallbackValue(cookbookTag());
    registerFallbackValue(const CookbookDetails());
    registerFallbackValue(<Recipe>[]);
  });

  setUp(() async {
    await BaseUnitTest.setupUnit();
    service = _MockCookbookService();
    tagStream = StreamController<List<PersonalTag>>.broadcast();
    library = [];
    when(() => service.watchTags()).thenAnswer((_) => tagStream.stream);
    when(() => service.libraryChanges).thenAnswer((_) => const Stream.empty());
    when(() => service.libraryRecipes).thenAnswer((_) => library);
    when(() => service.save(any(), any())).thenAnswer((_) async => true);
    when(() => service.addRecipes(any(), any())).thenAnswer((_) async => 1);
    vm = CookbookViewModel(service: service);
  });

  tearDown(() async {
    vm.dispose();
    await tagStream.close();
    await BaseUnitTest.teardownUnit();
  });

  Future<void> emitTags(List<PersonalTag> tags) async {
    vm.start();
    tagStream.add(tags);
    await pumpEventQueue();
  }

  CookbookDetails savedDetails() =>
      verify(() => service.save(any(), captureAny())).captured.single
          as CookbookDetails;

  group('shelf', () {
    test(
      'cookbooks lists only tags with a cookbook, otherTags the rest',
      () async {
        await emitTags([
          cookbookTag(id: 'plain', name: 'Vanlig'),
          cookbookTag(
            id: 'book',
            name: 'Bok',
            cookbook: const CookbookDetails(),
          ),
        ]);

        expect(vm.cookbooks.map((t) => t.id), ['book']);
        expect(vm.otherTags.map((t) => t.id), ['plain']);
        expect(vm.tagsLoaded, isTrue);
      },
    );
  });

  group('move', () {
    late PersonalTag tag;

    setUp(() {
      library = [
        cookbookRecipe('r1', 'Apelsinkaka', tagIds: ['book']),
        cookbookRecipe('r2', 'Bullar', tagIds: ['book']),
        cookbookRecipe('r3', 'Citronpaj', tagIds: ['book']),
      ];
      tag = cookbookTag(cookbook: const CookbookDetails());
    });

    test('writes the whole visible order, which starts an own order', () async {
      final ok = await vm.move(tag, 0, 1);

      expect(ok, isTrue);
      expect(savedDetails().recipeOrder, ['r2', 'r1', 'r3']);
    });

    test(
      'drops ids of recipes that left the book and keeps the notes',
      () async {
        tag = cookbookTag(
          cookbook: const CookbookDetails(
            recipeOrder: ['gone', 'r3', 'r1', 'r2'],
            recipeNotes: {'r1': 'Mormors tips'},
          ),
        );

        await vm.move(tag, 2, -1);

        final saved = savedDetails();
        expect(saved.recipeOrder, ['r3', 'r2', 'r1']);
        expect(saved.recipeNotes, {'r1': 'Mormors tips'});
      },
    );

    test('out of range returns false and writes nothing', () async {
      expect(await vm.move(tag, 0, -1), isFalse);
      expect(await vm.move(tag, 2, 1), isFalse);
      expect(await vm.move(tag, 7, -1), isFalse);
      expect(await vm.move(tag, -1, 1), isFalse);

      verifyNever(() => service.save(any(), any()));
      // Control: the same call one step inside the range does write.
      expect(await vm.move(tag, 1, 1), isTrue);
      verify(() => service.save(any(), any())).called(1);
    });

    test('a tag that is not a cookbook is not written', () async {
      expect(await vm.move(cookbookTag(), 0, 1), isFalse);

      verifyNever(() => service.save(any(), any()));
    });
  });

  group('sortAlphabetically', () {
    test('clears the own order and keeps the rest of the book', () async {
      final tag = cookbookTag(
        cookbook: const CookbookDetails(
          description: 'Text',
          recipeOrder: ['r2', 'r1'],
        ),
      );

      await vm.sortAlphabetically(tag);

      final saved = savedDetails();
      expect(saved.recipeOrder, isNull);
      expect(saved.hasCustomOrder, isFalse);
      expect(saved.description, 'Text');
    });
  });

  group('setNote', () {
    final tag = cookbookTag(
      cookbook: const CookbookDetails(
        recipeNotes: {'r1': 'Gammal text', 'r2': 'Behåll'},
      ),
    );

    test('trims the text before saving it', () async {
      await vm.setNote(tag, 'r1', '  Ny text \n');

      expect(savedDetails().recipeNotes, {'r1': 'Ny text', 'r2': 'Behåll'});
    });

    test('an empty text removes only that recipe\'s note', () async {
      await vm.setNote(tag, 'r1', '   ');

      expect(savedDetails().recipeNotes, {'r2': 'Behåll'});
    });
  });

  group('addRecipes', () {
    PersonalTag bookWithRecipes(int count) {
      library = [
        for (var i = 0; i < count; i++)
          cookbookRecipe('in$i', 'Recept $i', tagIds: ['book']),
        cookbookRecipe('x1', 'Ny ett'),
        cookbookRecipe('x2', 'Ny två'),
      ];
      return cookbookTag(cookbook: const CookbookDetails());
    }

    test('past the 1000 cap sets the error and writes nothing', () async {
      final tag = bookWithRecipes(999);

      final added = await vm.addRecipes(tag, [library[999], library[1000]]);

      expect(added, isNull);
      expect(vm.error, 'En kokbok kan ha högst 1000 recept.');
      verifyNever(() => service.addRecipes(any(), any()));
    });

    test('exactly at the cap is allowed', () async {
      final tag = bookWithRecipes(999);

      final added = await vm.addRecipes(tag, [library[999]]);

      expect(added, 1);
      expect(vm.error, isNull);
      verify(() => service.addRecipes(tag, [library[999]])).called(1);
    });

    test('a partial add reports the failure', () async {
      final tag = bookWithRecipes(1);
      when(() => service.addRecipes(any(), any())).thenAnswer((_) async => 1);

      final added = await vm.addRecipes(tag, [library[1], library[2]]);

      expect(added, 1);
      expect(vm.error, isNotNull);
    });
  });

  group('cover photo', () {
    test(
      'a recipe cover whose recipe left the book falls back to the colour',
      () {
        library = [
          cookbookRecipe(
            'r1',
            'Kvar',
            tagIds: ['book'],
            thumbnailUrl: 'https://img/kvar.jpg',
          ),
          // Still in the library with a photo, but no longer carries the tag.
          cookbookRecipe(
            'left',
            'Lämnade',
            tagIds: ['other'],
            thumbnailUrl: 'https://img/left.jpg',
          ),
        ];
        const gone = CookbookDetails(
          cover: CookbookCover(
            kind: CookbookCoverKind.recipe,
            recipeId: 'left',
          ),
        );
        const present = CookbookDetails(
          cover: CookbookCover(kind: CookbookCoverKind.recipe, recipeId: 'r1'),
        );

        expect(vm.coverImageUrl(cookbookTag(cookbook: gone)), isNull);
        expect(
          vm.coverImageUrl(cookbookTag(cookbook: present)),
          'https://img/kvar.jpg',
        );
      },
    );
  });

  group('order of the book', () {
    test('a rule-tagged recipe lands after the ordered ones', () {
      library = [
        cookbookRecipe('a', 'Apelsinkaka', ruleTagIds: ['book']),
        cookbookRecipe('b', 'Bullar', tagIds: ['book']),
        cookbookRecipe('c', 'Citronpaj', tagIds: ['book']),
      ];
      final tag = cookbookTag(
        cookbook: const CookbookDetails(recipeOrder: ['c', 'b']),
      );

      expect(vm.recipesIn(tag).map((r) => r.id), ['c', 'b', 'a']);
      expect(vm.recipeCount(tag), 3);
    });
  });
}

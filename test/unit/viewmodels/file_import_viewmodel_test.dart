/// Tests for the FileImportViewModel extracted from FileImportView (WS10 MVVM).
/// Covers the parse path, which is the cleanly-injectable core of the flow.
/// The importSelected loop+count mirrors the (separately tested)
/// PhotoImportViewModel.saveSelectedRecipes partial-failure logic.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/file_import_viewmodel.dart';

import '../../infrastructure/factories/recipe_factory.dart';

class _FakeImportManager extends Fake implements ImportManager {
  _FakeImportManager({
    this.result = const FileImportResult([]),
    this.throws = false,
  });
  final FileImportResult result;
  final bool throws;

  @override
  Future<FileImportResult> importFile() async {
    if (throws) throw Exception('boom');
    return result;
  }
}

class _FakeRecipeService extends Fake implements UnifiedRecipeService {
  _FakeRecipeService({this.held = const [], this.initialized = true});
  final List<Recipe> held;
  final bool initialized;
  final created = <Map<String, Object?>>[];

  @override
  bool get isInitialized => initialized;

  @override
  List<Recipe> get recipes => held;

  @override
  Future<String?> createPersonalRecipe({
    required String title,
    String description = '',
    List<String> ingredients = const [],
    List<String> instructions = const [],
    List<String> imageUrls = const [],
    String mealType = 'Middag',
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
  }) async {
    created.add({'title': title, 'personalTagIds': personalTagIds});
    return 'id${created.length}';
  }
}

class _FakeTagService extends Fake implements PersonalTagService {
  _FakeTagService(this.existing);
  final List<PersonalTag> existing;
  int getAllTagsCalls = 0;
  final createdTags = <PersonalTag>[];

  @override
  Future<List<PersonalTag>> getAllTags() async {
    getAllTagsCalls++;
    return existing;
  }

  @override
  Future<PersonalTag?> createTag(PersonalTag tag) async {
    createdTags.add(tag);
    return tag;
  }
}

const _denied = RateLimitDenied(
  message: 'nej',
  retryAfter: Duration(minutes: 1),
  limitType: LimitType.perMinute,
  suggestedAction: FallbackAction.retryLater,
);

Recipe _recipe(String id) => RecipeFactory.build(id: id, title: 'R$id');

void main() {
  group('FileImportViewModel.parseFile', () {
    test('returns parsed recipes and clears loading on success', () async {
      final vm = FileImportViewModel(
        importManager: _FakeImportManager(
          result: FileImportResult([_recipe('1'), _recipe('2')]),
        ),
      );
      addTearDown(vm.dispose);

      final parsed = await vm.parseFile();

      expect(parsed, hasLength(2));
      expect(vm.isLoading, isFalse);
    });

    test(
      'returns empty and sets the no-recipes status when none found',
      () async {
        final vm = FileImportViewModel(importManager: _FakeImportManager());
        addTearDown(vm.dispose);

        final parsed = await vm.parseFile();

        expect(parsed, isEmpty);
        expect(vm.isLoading, isFalse);
        expect(
          vm.statusMessage,
          equals(AppLocale.current.importNoFileOrNoRecipes),
        );
      },
    );

    test(
      'returns empty and surfaces a generic error when the import manager throws',
      () async {
        final vm = FileImportViewModel(
          importManager: _FakeImportManager(throws: true),
        );
        addTearDown(vm.dispose);

        final parsed = await vm.parseFile();

        expect(parsed, isEmpty);
        expect(vm.isLoading, isFalse);
        expect(vm.statusMessage, equals(AppLocale.current.errorGeneric));
      },
    );
  });

  test('a refused import says why and returns nothing', () async {
    final vm = FileImportViewModel(
      importManager: _FakeImportManager(
        result: const FileImportResult.rateLimit(_denied),
      ),
    );
    addTearDown(vm.dispose);

    final parsed = await vm.parseFile();

    expect(parsed, isEmpty);
    expect(vm.isLoading, isFalse);
    expect(vm.statusMessage, equals(_denied.swedishMessage));
  });

  group('FileImportViewModel.importSelected', () {
    test('resets when nothing was selected', () async {
      final vm = FileImportViewModel(importManager: _FakeImportManager());
      addTearDown(vm.dispose);

      await vm.importSelected(const []);

      expect(vm.isLoading, isFalse);
      expect(vm.importedCount, 0);
      expect(vm.failedCount, 0);
      expect(vm.allSucceeded, isTrue);
    });
  });

  group('FileImportViewModel duplicates and cap', () {
    Recipe pancakes({String title = 'Pannkakor', List<String>? ingredients}) =>
        RecipeFactory.build(
          id: title + (ingredients ?? const ['a']).join(),
          title: title,
          ingredients: ingredients ?? ['2 ägg', '3 dl mjölk'],
        );

    FileImportViewModel vmFor(
      List<Recipe> parsed, {
      _FakeRecipeService? service,
    }) {
      final vm = FileImportViewModel(
        importManager: _FakeImportManager(result: FileImportResult(parsed)),
        recipeService: service ?? _FakeRecipeService(),
        tagService: _FakeTagService(const []),
      );
      addTearDown(vm.dispose);
      return vm;
    }

    test('proves a recipe the user already holds, under another casing and '
        'spacing of its title, is left out of the preview', () async {
      final vm = vmFor(
        [pancakes(), pancakes(title: 'Våfflor')],
        service: _FakeRecipeService(held: [pancakes(title: '  PANNKAKOR ')]),
      );

      final parsed = await vm.parseFile();

      expect(parsed.map((r) => r.title), ['Våfflor']);
    });

    test('proves two identical rows in one file become one', () async {
      final vm = vmFor([pancakes(), pancakes()]);

      expect(await vm.parseFile(), hasLength(1));
    });

    test('proves the same title with different ingredients is not a '
        'duplicate', () async {
      final vm = vmFor(
        [
          pancakes(ingredients: ['1 ägg']),
        ],
        service: _FakeRecipeService(held: [pancakes()]),
      );

      expect(await vm.parseFile(), hasLength(1));
    });

    test(
      'proves nothing is removed before the recipe list has loaded',
      () async {
        final vm = vmFor(
          [pancakes()],
          service: _FakeRecipeService(held: [pancakes()], initialized: false),
        );

        expect(await vm.parseFile(), hasLength(1));
      },
    );

    test('proves a file whose recipes are all held says so', () async {
      final vm = vmFor(
        [pancakes()],
        service: _FakeRecipeService(held: [pancakes()]),
      );

      expect(await vm.parseFile(), isEmpty);
      expect(vm.statusMessage, AppLocale.current.importAllAlreadyHeld);
    });

    test(
      'proves a file with more than the cap yields exactly the cap',
      () async {
        final vm = vmFor([
          for (var i = 0; i <= FileImportViewModel.maxRecipesPerFile; i++)
            _recipe('$i'),
        ]);

        expect(
          await vm.parseFile(),
          hasLength(FileImportViewModel.maxRecipesPerFile),
        );
      },
    );

    test('proves the final message reports skipped duplicates and the rows '
        'over the cap', () async {
      final vm = vmFor(
        [
          pancakes(),
          for (var i = 0; i <= FileImportViewModel.maxRecipesPerFile; i++)
            _recipe('$i'),
        ],
        service: _FakeRecipeService(held: [pancakes()]),
      );

      final parsed = await vm.parseFile();
      await vm.importSelected([parsed.first]);

      final l = AppLocale.current;
      expect(vm.statusMessage, contains(l.importSkippedDuplicates(1)));
      expect(
        vm.statusMessage,
        contains(
          l.importSkippedOverLimit(2, FileImportViewModel.maxRecipesPerFile),
        ),
      );
    });
  });

  group('FileImportViewModel tag resolution', () {
    test('proves tag names become the user\'s tag ids, new names are created '
        'once, and a name too long to be a tag is dropped', () async {
      final longName = 'x' * 51;
      final tagService = _FakeTagService([
        PersonalTag.create(name: 'Vegetariskt').copyWith(id: 't1'),
      ]);
      final recipeService = _FakeRecipeService();
      final vm = FileImportViewModel(
        importManager: _FakeImportManager(),
        recipeService: recipeService,
        tagService: tagService,
      );
      addTearDown(vm.dispose);

      await vm.importSelected([
        RecipeFactory.build(
          id: 'a',
          title: 'A',
          personalTagIds: ['vegetariskt', 'Snabbt', longName],
        ),
        RecipeFactory.build(
          id: 'b',
          title: 'B',
          personalTagIds: ['SNABBT'],
        ),
      ]);

      expect(tagService.getAllTagsCalls, 1);
      expect(tagService.createdTags, hasLength(1));
      expect(tagService.createdTags.single.name.toLowerCase(), 'snabbt');
      final snabbtId = tagService.createdTags.single.id;
      expect(recipeService.created.map((c) => c['personalTagIds']), [
        unorderedEquals(['t1', snabbtId]),
        [snabbtId],
      ]);
      expect(vm.importedCount, 2);
    });
  });
}

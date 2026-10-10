import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/services/tagging/cookbook_service.dart';
import 'package:butlery/viewmodels/cookbook_viewmodel.dart';
import 'package:butlery/views/cookbooks/cookbook_detail_view.dart';
import 'package:butlery/views/cookbooks/cookbook_edit_sheet.dart';
import 'package:butlery/views/cookbooks/cookbook_recipe_sheets.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';
import '../../test_support/cookbook_fixtures.dart';

class _MockCookbookService extends Mock implements CookbookService {}

void main() {
  final l10n = AppLocalizationsSv();
  late _MockCookbookService service;
  late StreamController<List<PersonalTag>> tagStream;
  late CookbookViewModel vm;
  late List<Recipe> library;
  late List<RouteSettings> pushed;

  setUpAll(() {
    registerFallbackValue(cookbookTag());
    registerFallbackValue(const CookbookDetails());
    registerFallbackValue(<Recipe>[]);
  });

  setUp(() async {
    await BaseUnitTest.setupUnit();
    service = _MockCookbookService();
    tagStream = StreamController<List<PersonalTag>>.broadcast();
    pushed = [];
    library = [];
    when(() => service.watchTags()).thenAnswer((_) => tagStream.stream);
    when(() => service.libraryChanges).thenAnswer((_) => const Stream.empty());
    when(() => service.libraryRecipes).thenAnswer((_) => library);
    when(() => service.save(any(), any())).thenAnswer((_) async => true);
    when(() => service.remove(any())).thenAnswer((_) async => true);
    when(() => service.addRecipes(any(), any())).thenAnswer(
      (inv) async => (inv.positionalArguments[1] as List<Recipe>).length,
    );
    vm = CookbookViewModel(service: service)..start();
  });

  tearDown(() async {
    vm.dispose();
    await tagStream.close();
    await BaseUnitTest.teardownUnit();
  });

  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Route<dynamic>? spyRoutes(RouteSettings settings) {
    pushed.add(settings);
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const Scaffold(body: Text('recipe-detail-page')),
    );
  }

  Future<void> openEditSheet(WidgetTester tester, PersonalTag tag) async {
    tallView(tester);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCookbookEditSheet(context, vm: vm, tag: tag),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    tagStream.add([tag]);
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> openPicker(WidgetTester tester, PersonalTag tag) async {
    tallView(tester);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAddRecipesSheet(context, vm: vm, tag: tag),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    tagStream.add([tag]);
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> openBook(
    WidgetTester tester, {
    CookbookDetails details = const CookbookDetails(),
  }) async {
    tallView(tester);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        onGenerateRoute: spyRoutes,
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ChangeNotifierProvider<CookbookViewModel>.value(
                        value: vm,
                        child: const CookbookDetailView(tagId: 'book'),
                      ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    tagStream.add([cookbookTag(cookbook: details)]);
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  ({PersonalTag tag, CookbookDetails details}) capturedSave() {
    final c = verify(
      () => service.save(captureAny(), captureAny()),
    ).captured;
    expect(c, hasLength(2), reason: 'save called exactly once');
    return (tag: c[0] as PersonalTag, details: c[1] as CookbookDetails);
  }

  Finder descriptionField() => find.byType(EditableText);

  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<ButtonStyleButton>(button).onPressed != null;

  group('edit sheet', () {
    testWidgets('"Skapa kokbok" turns a plain tag into a cookbook', (
      tester,
    ) async {
      final plain = cookbookTag();
      await openEditSheet(tester, plain);

      expect(find.text(l10n.cookbookMakeTitle), findsOneWidget);
      expect(find.text(l10n.cookbookSave), findsNothing);
      expect(find.text(l10n.cookbookRemove), findsNothing);

      await tester.tap(find.text(l10n.cookbookCreate));
      await tester.pumpAndSettle();

      final saved = capturedSave();
      expect(saved.tag.id, plain.id);
      expect(saved.details, const CookbookDetails());
      expect(find.text(l10n.cookbookMakeTitle), findsNothing);
    });

    testWidgets('edits description (trimmed) and colour of an existing book', (
      tester,
    ) async {
      await openEditSheet(
        tester,
        cookbookTag(
          cookbook: const CookbookDetails(
            description: 'Gammal text',
            recipeOrder: ['r2', 'r1'],
            recipeNotes: {'r1': 'Mer kanel'},
          ),
        ),
      );
      expect(find.text(l10n.cookbookEditTitle), findsOneWidget);
      expect(find.text('Gammal text'), findsOneWidget);

      await tester.enterText(descriptionField(), '  Söndagsmat hos mormor  ');
      await tester.tap(find.byKey(const ValueKey('cookbook-swatch-brick')));
      await tester.pump();
      await tester.tap(find.text(l10n.cookbookSave));
      await tester.pumpAndSettle();

      final saved = capturedSave();
      expect(saved.details.description, 'Söndagsmat hos mormor');
      expect(saved.details.cover.colorKey, 'brick');
      expect(saved.details.cover.kind, CookbookCoverKind.color);
      // The sheet edits only description and cover.
      expect(saved.details.recipeOrder, ['r2', 'r1']);
      expect(saved.details.recipeNotes, {'r1': 'Mer kanel'});
      expect(find.text(l10n.cookbookEditTitle), findsNothing);
    });

    testWidgets(
      'saves on the LATEST tag, so order and notes changed while the sheet '
      'was open are not overwritten',
      (tester) async {
        final snapshot = cookbookTag(
          cookbook: const CookbookDetails(description: 'Start'),
        );
        await openEditSheet(tester, snapshot);

        tagStream.add([
          cookbookTag(
            cookbook: const CookbookDetails(
              description: 'Start',
              recipeOrder: ['r3', 'r1', 'r2'],
              recipeNotes: {'r2': 'Lägg i ugnen först'},
            ),
          ),
        ]);
        await tester.pump();

        await tester.enterText(descriptionField(), 'Ny beskrivning');
        await tester.tap(find.text(l10n.cookbookSave));
        await tester.pumpAndSettle();

        final saved = capturedSave();
        expect(saved.details.description, 'Ny beskrivning');
        expect(saved.details.recipeOrder, ['r3', 'r1', 'r2']);
        expect(saved.details.recipeNotes, {'r2': 'Lägg i ugnen först'});
        expect(saved.tag.cookbook?.recipeOrder, ['r3', 'r1', 'r2']);
      },
    );

    testWidgets('"Sluta vara kokbok" asks first; cancel removes nothing', (
      tester,
    ) async {
      await openEditSheet(
        tester,
        cookbookTag(cookbook: const CookbookDetails()),
      );

      await tester.tap(find.text(l10n.cookbookRemove));
      await tester.pumpAndSettle();
      expect(find.text(l10n.cookbookRemoveBody), findsOneWidget);
      verifyNever(() => service.remove(any()));

      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.cookbookRemoveBody), findsNothing);
      expect(find.text(l10n.cookbookEditTitle), findsOneWidget);
      verifyNever(() => service.remove(any()));
    });

    testWidgets('confirming "Sluta vara kokbok" removes the book', (
      tester,
    ) async {
      await openEditSheet(
        tester,
        cookbookTag(cookbook: const CookbookDetails()),
      );

      await tester.tap(find.text(l10n.cookbookRemove));
      await tester.pumpAndSettle();
      final confirm = find.descendant(
        of: find.byType(Dialog),
        matching: find.ancestor(
          of: find.text(l10n.cookbookRemove),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      final removed =
          verify(() => service.remove(captureAny())).captured.single
              as PersonalTag;
      expect(removed.id, 'book');
      expect(find.text(l10n.cookbookEditTitle), findsNothing);
    });

    testWidgets(
      'switching cover kind shows that kind\'s controls and saves it',
      (
        tester,
      ) async {
        await openEditSheet(
          tester,
          cookbookTag(cookbook: const CookbookDetails()),
        );
        expect(find.text(l10n.cookbookChoosePhoto), findsNothing);

        await tester.tap(find.text(l10n.cookbookCoverOwnPhoto));
        await tester.pump();
        expect(find.text(l10n.cookbookChoosePhoto), findsOneWidget);

        await tester.tap(find.text(l10n.cookbookCoverRecipePhoto));
        await tester.pump();
        expect(find.text(l10n.cookbookChoosePhoto), findsNothing);

        await tester.tap(find.text(l10n.cookbookSave));
        await tester.pumpAndSettle();
        final saved = capturedSave();
        expect(saved.details.cover.kind, CookbookCoverKind.recipe);
        expect(saved.details.cover.imageUrl, isNull);
      },
    );

    testWidgets(
      'recipe cover with no recipe photos says so instead of an empty picker',
      (tester) async {
        library = [
          cookbookRecipe('r1', 'Kanelbullar', tagIds: ['book']),
        ];
        await openEditSheet(
          tester,
          cookbookTag(cookbook: const CookbookDetails()),
        );

        await tester.tap(find.text(l10n.cookbookCoverRecipePhoto));
        await tester.pump();

        expect(find.text(l10n.cookbookNoRecipePhotos), findsOneWidget);
        expect(find.text(l10n.cookbookChooseRecipePhoto), findsNothing);
      },
    );
  });

  group('add-recipes picker', () {
    setUp(() {
      library = [
        cookbookRecipe('orts', 'Örtsoppa'),
        cookbookRecipe('appel', 'Äppelpaj'),
        cookbookRecipe('apri', 'Aprikoskaka'),
        cookbookRecipe('in', 'Redan med', tagIds: ['book']),
      ];
    });

    final confirmButton = find.descendant(
      of: find.byKey(CookbookRecipePickerSheet.confirmKey),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );

    testWidgets('lists only recipes that are not in the book yet', (
      tester,
    ) async {
      await openPicker(tester, cookbookTag(cookbook: const CookbookDetails()));

      expect(find.text('Örtsoppa'), findsOneWidget);
      expect(find.text('Äppelpaj'), findsOneWidget);
      expect(find.text('Aprikoskaka'), findsOneWidget);
      expect(find.text('Redan med'), findsNothing);
    });

    testWidgets('confirm is disabled at zero ticks and counts the ticks', (
      tester,
    ) async {
      await openPicker(tester, cookbookTag(cookbook: const CookbookDetails()));

      expect(find.text(l10n.cookbookPickerAdd(0)), findsOneWidget);
      expect(enabled(tester, confirmButton), isFalse);

      await tester.tap(find.text('Äppelpaj'));
      await tester.pump();
      await tester.tap(find.text('Aprikoskaka'));
      await tester.pump();
      expect(find.text(l10n.cookbookPickerAdd(2)), findsOneWidget);
      expect(enabled(tester, confirmButton), isTrue);

      await tester.tap(find.text('Äppelpaj'));
      await tester.pump();
      await tester.tap(find.text('Aprikoskaka'));
      await tester.pump();
      expect(enabled(tester, confirmButton), isFalse);
    });

    testWidgets('ticked recipes reach addRecipes in list (A–Ö) order', (
      tester,
    ) async {
      await openPicker(tester, cookbookTag(cookbook: const CookbookDetails()));

      // Ticked Ö before Ä; the list order is Aprikoskaka, Äppelpaj, Örtsoppa.
      await tester.tap(find.text('Örtsoppa'));
      await tester.pump();
      await tester.tap(find.text('Äppelpaj'));
      await tester.pump();
      await tester.tap(find.byKey(CookbookRecipePickerSheet.confirmKey));
      await tester.pumpAndSettle();

      final chosen =
          verify(
                () => service.addRecipes(any(), captureAny()),
              ).captured.single
              as List<Recipe>;
      expect(chosen.map((r) => r.id), ['appel', 'orts']);
      expect(find.text(l10n.cookbookAdded(2)), findsOneWidget);
    });
  });

  group('book view wiring', () {
    setUp(() {
      library = [
        cookbookRecipe('r1', 'Kanelbullar', tagIds: ['book']),
        cookbookRecipe('r2', 'Köttbullar', tagIds: ['book']),
        cookbookRecipe('r3', 'Pannkakor', tagIds: ['book']),
        cookbookRecipe('x1', 'Äppelpaj'),
      ];
    });

    testWidgets('the app bar pencil opens the edit sheet', (tester) async {
      await openBook(tester);
      expect(find.text(l10n.cookbookEditTitle), findsNothing);

      await tester.tap(find.byTooltip(l10n.cookbookEdit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.cookbookEditTitle), findsOneWidget);
    });

    testWidgets('"Lägg till recept" opens the picker with non-members', (
      tester,
    ) async {
      await openBook(tester);
      expect(find.text(l10n.cookbookPickerAdd(0)), findsNothing);

      await tester.tap(find.byKey(CookbookDetailView.addKey));
      await tester.pumpAndSettle();

      expect(find.text(l10n.cookbookPickerAdd(0)), findsOneWidget);
      expect(find.text('Äppelpaj'), findsOneWidget);
    });

    testWidgets('the description paragraph is shown', (tester) async {
      await openBook(
        tester,
        details: const CookbookDetails(description: 'Mormors bästa söndagsmat'),
      );
      expect(find.text('Mormors bästa söndagsmat'), findsOneWidget);
    });

    testWidgets('an empty book shows the empty state', (tester) async {
      library = [cookbookRecipe('x1', 'Äppelpaj')];
      await openBook(tester);
      expect(find.text(l10n.cookbookEmpty), findsOneWidget);
    });

    testWidgets('a book with recipes does not show the empty state', (
      tester,
    ) async {
      await openBook(tester);
      expect(find.text(l10n.cookbookEmpty), findsNothing);
    });

    testWidgets('tapping a row opens the recipe with the book name and note', (
      tester,
    ) async {
      await openBook(
        tester,
        details: const CookbookDetails(
          recipeNotes: {'r1': 'Dubbla kanelmängden'},
        ),
      );

      await tester.tap(find.text('Kanelbullar'));
      await tester.pumpAndSettle();

      expect(pushed.single.name, Routes.recipeDetail);
      final args = pushed.single.arguments! as Map<String, dynamic>;
      expect((args['recipe'] as Recipe).id, 'r1');
      expect(args['cookbookName'], 'Mormors favoriter');
      expect(args['cookbookNote'], 'Dubbla kanelmängden');
      expect(find.text('recipe-detail-page'), findsOneWidget);
    });

    testWidgets('a row without a note passes no note', (tester) async {
      await openBook(
        tester,
        details: const CookbookDetails(recipeNotes: {'r1': 'Bara på första'}),
      );

      await tester.tap(find.text('Köttbullar'));
      await tester.pumpAndSettle();

      final args = pushed.single.arguments! as Map<String, dynamic>;
      expect((args['recipe'] as Recipe).id, 'r2');
      expect(args.containsKey('cookbookNote'), isTrue);
      expect(args['cookbookNote'], isNull);
    });

    group('note dialog', () {
      testWidgets('a row pencil opens the dialog for that recipe, empty', (
        tester,
      ) async {
        await openBook(
          tester,
          details: const CookbookDetails(recipeNotes: {'r1': 'Gammal'}),
        );

        // r1 has a note; the first "Skriv text" belongs to r2.
        await tester.tap(find.byTooltip(l10n.cookbookWriteNote).first);
        await tester.pumpAndSettle();

        final dialog = find.byType(AlertDialog);
        expect(
          find.descendant(of: dialog, matching: find.text('Köttbullar')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          isEmpty,
        );

        await tester.enterText(find.byType(EditableText), '  Ny text  ');
        await tester.tap(find.text(l10n.cookbookSave));
        await tester.pumpAndSettle();

        final saved = capturedSave();
        expect(saved.details.recipeNotes, {
          'r1': 'Gammal',
          'r2': 'Ny text',
        });
      });

      testWidgets('pre-fills the existing note; empty text removes only it', (
        tester,
      ) async {
        await openBook(
          tester,
          details: const CookbookDetails(
            recipeNotes: {'r1': 'Gammal', 'r2': 'Behålls'},
          ),
        );

        await tester.tap(find.byTooltip(l10n.cookbookEditNote).first);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'Gammal',
        );

        await tester.enterText(find.byType(EditableText), '');
        await tester.tap(find.text(l10n.cookbookSave));
        await tester.pumpAndSettle();

        final saved = capturedSave();
        expect(saved.details.recipeNotes.containsKey('r1'), isFalse);
        expect(saved.details.recipeNotes, {'r2': 'Behålls'});
      });

      testWidgets('cancel writes nothing', (tester) async {
        await openBook(
          tester,
          details: const CookbookDetails(recipeNotes: {'r1': 'Gammal'}),
        );

        await tester.tap(find.byTooltip(l10n.cookbookEditNote));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText), 'Ändrad men ångrad');
        await tester.tap(find.text(l10n.commonCancel));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        verifyNever(() => service.save(any(), any()));
      });
    });
  });
}

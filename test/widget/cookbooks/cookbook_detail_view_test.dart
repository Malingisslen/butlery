import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/services/tagging/cookbook_service.dart';
import 'package:butlery/viewmodels/cookbook_viewmodel.dart';
import 'package:butlery/views/cookbooks/cookbook_detail_view.dart';

import '../../infrastructure/helpers/announce_channel.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';
import '../../test_support/cookbook_fixtures.dart';
import '../../test_support/semantics_announcement.dart';

class _MockCookbookService extends Mock implements CookbookService {}

void main() {
  final l10n = AppLocalizationsSv();
  late _MockCookbookService service;
  late StreamController<List<PersonalTag>> tagStream;
  late CookbookViewModel vm;

  const titles = ['Kanelbullar', 'Köttbullar', 'Pannkakor'];

  setUpAll(() {
    registerFallbackValue(cookbookTag());
    registerFallbackValue(const CookbookDetails());
  });

  setUp(() async {
    await BaseUnitTest.setupUnit();
    service = _MockCookbookService();
    tagStream = StreamController<List<PersonalTag>>.broadcast();
    when(() => service.watchTags()).thenAnswer((_) => tagStream.stream);
    when(() => service.libraryChanges).thenAnswer((_) => const Stream.empty());
    when(() => service.libraryRecipes).thenAnswer(
      (_) => <Recipe>[
        cookbookRecipe('r1', titles[0], tagIds: ['book']),
        cookbookRecipe('r2', titles[1], tagIds: ['book']),
        cookbookRecipe('r3', titles[2], tagIds: ['book']),
      ],
    );
    when(() => service.save(any(), any())).thenAnswer((_) async => true);
    vm = CookbookViewModel(service: service)..start();
  });

  tearDown(() async {
    vm.dispose();
    await tagStream.close();
    await BaseUnitTest.teardownUnit();
  });

  Future<void> openBook(
    WidgetTester tester, {
    CookbookDetails details = const CookbookDetails(),
  }) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
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

  Finder up(String title) => find.byTooltip(l10n.a11yMoveRecipeUp(title));
  Finder down(String title) => find.byTooltip(l10n.a11yMoveRecipeDown(title));

  Future<void> startReordering(WidgetTester tester) async {
    await tester.tap(find.text(l10n.cookbookReorder));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, Finder tooltip) {
    final button = find.ancestor(
      of: tooltip,
      matching: find.byType(IconButton),
    );
    return tester.widget<IconButton>(button).onPressed != null;
  }

  testWidgets(
    '"Ändra ordning" offers labelled move up/down buttons on every row',
    (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openBook(tester);
      expect(up(titles[0]), findsNothing);

      await startReordering(tester);

      for (final title in titles) {
        for (final button in [up(title), down(title)]) {
          expect(button, findsOneWidget);
          final size = tester.getSize(button);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
      }
      final lines = announcedLines(tester, down(titles[1]));
      expect(lines, contains(l10n.a11yMoveRecipeDown(titles[1])));
      expect(
        tester.getSemantics(down(titles[1])).flagsCollection.isButton,
        isTrue,
      );
      handle.dispose();
    },
  );

  testWidgets('"Flytta ner" on the first row moves it one step, no drag', (
    tester,
  ) async {
    final announces = AnnounceChannel.arm(tester);
    await openBook(tester);
    await startReordering(tester);

    await tester.tap(down(titles[0]));
    await tester.pumpAndSettle();

    final saved =
        verify(() => service.save(any(), captureAny())).captured.single
            as CookbookDetails;
    expect(saved.recipeOrder, ['r2', 'r1', 'r3']);
    expect(announces.last, l10n.a11yRecipeMoved(titles[0], 2, 3));
  });

  testWidgets('the first row cannot move up and the last cannot move down', (
    tester,
  ) async {
    await openBook(tester);
    await startReordering(tester);

    expect(enabled(tester, up(titles[0])), isFalse);
    expect(enabled(tester, down(titles[2])), isFalse);
    // Controls: the other directions on the same rows are live.
    expect(enabled(tester, down(titles[0])), isTrue);
    expect(enabled(tester, up(titles[2])), isTrue);
    expect(enabled(tester, up(titles[1])), isTrue);
    expect(enabled(tester, down(titles[1])), isTrue);
  });

  testWidgets('"Sortera A–Ö" is shown only when the book has its own order', (
    tester,
  ) async {
    await openBook(tester);
    expect(find.text(l10n.cookbookSortAlphabetical), findsNothing);
    expect(find.text(l10n.cookbookOrderHintAlphabetical), findsOneWidget);
  });

  testWidgets('"Sortera A–Ö" restores A–Ö for a book with its own order', (
    tester,
  ) async {
    await openBook(
      tester,
      details: const CookbookDetails(recipeOrder: ['r3', 'r1', 'r2']),
    );
    expect(find.text(l10n.cookbookOrderHintCustom), findsOneWidget);

    await tester.tap(find.text(l10n.cookbookSortAlphabetical));
    await tester.pumpAndSettle();

    final saved =
        verify(() => service.save(any(), captureAny())).captured.single
            as CookbookDetails;
    expect(saved.recipeOrder, isNull);
  });

  testWidgets('a recipe note shows under that recipe\'s title only', (
    tester,
  ) async {
    const note = 'Dubbla kanelmängden, då blir de bra';
    await openBook(
      tester,
      details: const CookbookDetails(recipeNotes: {'r1': note}),
    );

    expect(find.text(note), findsOneWidget);
    final title = find.text(titles[0]);
    expect(
      tester.getTopLeft(find.text(note)).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(title).dy),
    );
    expect(tester.getTopLeft(find.text(note)).dx, tester.getTopLeft(title).dx);
    // The row with a note offers to edit it; the others offer to write one.
    expect(find.byTooltip(l10n.cookbookEditNote), findsOneWidget);
    expect(find.byTooltip(l10n.cookbookWriteNote), findsNWidgets(2));
  });

  testWidgets('the book closes when its tag stops being a cookbook', (
    tester,
  ) async {
    await openBook(tester);
    expect(find.byType(CookbookDetailView), findsOneWidget);

    tagStream.add([cookbookTag()]);
    await tester.pumpAndSettle();

    expect(find.byType(CookbookDetailView), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}

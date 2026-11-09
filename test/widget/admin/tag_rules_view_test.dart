import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/tagging/config/occasion_lists.dart';
import 'package:butlery/viewmodels/admin/tag_rules_viewmodel.dart';
import 'package:butlery/views/admin/tag_rules_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';
import '../../test_support/ingredient_review_fixtures.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  Future<void> pump(WidgetTester tester, TagRulesViewModel vm) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: TagRulesView(viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists allergens with their triggers and diets with exclusions', (
    tester,
  ) async {
    final vm = TagRulesViewModel(
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(tester, vm);

    expect(find.text('gluten'), findsOneWidget);
    expect(find.text('contains-gluten'), findsOneWidget);
    expect(find.text('tree-nut, peanut'), findsOneWidget);
    expect(find.text('vegetarisk'), findsOneWidget);
    expect(find.text('meat, seafood'), findsOneWidget);
  });

  testWidgets('a missing tag config is an error, never empty tables', (
    tester,
  ) async {
    final vm = TagRulesViewModel(tagConfigService: FakeTagConfigService(null));
    await pump(tester, vm);

    expect(find.text('Taggkonfigurationen är inte laddad.'), findsOneWidget);
    expect(find.text('gluten'), findsNothing);
  });

  group('word lists', () {
    final list = kOccasionLists.firstWhere(
      (l) => l.key == 'christmas.titleWords',
    );

    Future<FakeChangeRequestRepository> pumpEditor(
      WidgetTester tester, {
      bool failWrites = false,
    }) async {
      final repo = FakeChangeRequestRepository(failWrites: failWrites);
      await pump(
        tester,
        TagRulesViewModel(
          tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
          repository: repo,
        ),
      );
      final edit = find.byKey(ValueKey('occasion-edit-${list.key}'));
      await tester.scrollUntilVisible(
        edit,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(edit);
      await tester.pumpAndSettle();
      return repo;
    }

    Finder saveButton() => find.descendant(
      of: find.byKey(const ValueKey('occasion-save')),
      matching: find.byType(FilledButton),
    );

    testWidgets('shows the info text, group headings and each list', (
      tester,
    ) async {
      final vm = TagRulesViewModel(
        tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
        repository: FakeChangeRequestRepository(),
      );
      await pump(tester, vm);
      await tester.scrollUntilVisible(
        find.text('Ordlistor för högtider och titelord'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.textContaining('når användarna först i nästa appversion'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Titelord'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Titelord'), findsOneWidget);
      expect(find.text('Stark: sätter taggen'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('occasion-list-titleKeywords.starkSet')),
        findsOneWidget,
      );
    });

    testWidgets(
      'the dialog is prefilled and save is disabled while unchanged',
      (
        tester,
      ) async {
        await pumpEditor(tester);
        expect(find.text('Ändra ordlistan: Jul: Ord i titeln'), findsOneWidget);
        final field = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const ValueKey('occasion-words')),
            matching: find.byType(TextField),
          ),
        );
        expect(field.controller!.text, list.words.join('\n'));
        expect(find.text('Inget är ändrat än.'), findsOneWidget);
        expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
      },
    );

    testWidgets('shows a Swedish message per validation error', (tester) async {
      await pumpEditor(tester);
      final words = find.byKey(const ValueKey('occasion-words'));

      await tester.enterText(words, '');
      await tester.pump();
      expect(find.text('Listan får inte vara tom.'), findsOneWidget);
      expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);

      await tester.enterText(words, 'bra\nfel!');
      await tester.pump();
      expect(
        find.textContaining('Orden får bara ha bokstäver'),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);

      await tester.enterText(words, 'a' * (kMaxOccasionWordLength + 1));
      await tester.pump();
      expect(
        find.text('Ett ord får vara högst $kMaxOccasionWordLength tecken.'),
        findsOneWidget,
      );

      await tester.enterText(
        words,
        List.generate(kMaxOccasionWords + 1, (i) => 'ord$i').join('\n'),
      );
      await tester.pump();
      expect(
        find.text('Listan får ha högst $kMaxOccasionWords ord.'),
        findsOneWidget,
      );
    });

    testWidgets('previews added and removed words and saves the proposal', (
      tester,
    ) async {
      final repo = await pumpEditor(tester);
      final words = find.byKey(const ValueKey('occasion-words'));
      final kept = list.words.skip(1).toList();
      await tester.enterText(words, [...kept, 'Nytt Ord'].join('\n'));
      await tester.enterText(
        find.byKey(const ValueKey('occasion-note')),
        'saknas',
      );
      await tester.pump();

      expect(find.text('Tillagda: nytt ord'), findsOneWidget);
      expect(find.text('Borttagna: ${list.words.first}'), findsOneWidget);
      expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);

      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      final p = repo.created.single;
      expect(p.listKey, list.key);
      expect(p.oldWords, list.words);
      expect(p.newWords, [...kept, 'nytt ord']);
      expect(p.note, 'saknas');
      expect(find.byKey(const ValueKey('occasion-words')), findsNothing);
      expect(find.textContaining('Förslaget är sparat'), findsOneWidget);
    });

    testWidgets('a reordering says so and can be saved', (tester) async {
      await pumpEditor(tester);
      await tester.enterText(
        find.byKey(const ValueKey('occasion-words')),
        list.words.reversed.join('\n'),
      );
      await tester.pump();
      expect(find.text('Samma ord i ny ordning'), findsOneWidget);
      expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);
    });

    testWidgets('a too long note disables save', (tester) async {
      await pumpEditor(tester);
      await tester.enterText(
        find.byKey(const ValueKey('occasion-words')),
        '${list.words.join('\n')}\nny',
      );
      await tester.enterText(
        find.byKey(const ValueKey('occasion-note')),
        'x' * 501,
      );
      await tester.pump();
      expect(
        find.text('Kommentaren får vara högst 500 tecken.'),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
    });

    testWidgets('a failed write keeps the dialog open with the error', (
      tester,
    ) async {
      final repo = await pumpEditor(tester, failWrites: true);
      await tester.enterText(
        find.byKey(const ValueKey('occasion-words')),
        '${list.words.join('\n')}\nny',
      );
      await tester.pump();
      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      expect(repo.created, isEmpty);
      expect(find.text('Kunde inte spara förslaget'), findsOneWidget);
      expect(find.byKey(const ValueKey('occasion-words')), findsOneWidget);
    });
  });
}

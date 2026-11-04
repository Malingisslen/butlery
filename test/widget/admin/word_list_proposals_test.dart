import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/models/tagging/ingredient_column.dart';
import 'package:butlery/services/tagging/ingredient_change_pr_service.dart';
import 'package:butlery/viewmodels/admin/pending_proposals_viewmodel.dart';
import 'package:butlery/views/admin/proposals_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';
import '../../test_support/ingredient_review_fixtures.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  Future<FakeChangeRequestRepository> pump(
    WidgetTester tester, {
    IngredientChangePrService? prService,
  }) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeChangeRequestRepository();
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: ProposalsView(
          viewModel: PendingProposalsViewModel(
            repository: repo,
            prService: prService,
          ),
        ),
      ),
    );
    await tester.pump();
    return repo;
  }

  IngredientChangeRequest proposal({String id = 'r1'}) =>
      IngredientChangeRequest(
        id: id,
        ingredientId: 'milk',
        createdAt: DateTime.utc(2026, 11, 1),
        changes: const [
          IngredientFieldChange(
            column: IngredientColumn.status,
            oldValue: 'draft',
            newValue: 'verified',
          ),
        ],
      );

  IngredientChangeRequest wordList({
    String id = 'w1',
    IngredientChangeStatus status = IngredientChangeStatus.pending,
    String? reason,
    Map<String, Object?>? csvValue,
    List<String> oldWords = const ['gran', 'tomte'],
    List<String> newWords = const ['gran', 'pepparkaka'],
  }) => IngredientChangeRequest(
    id: id,
    status: status,
    reason: reason,
    csvValue: csvValue,
    ingredientId: '',
    changes: const [],
    kind: IngredientChangeRequest.kOccasionListKind,
    listKey: 'christmas.titleWords',
    oldWords: oldWords,
    newWords: newWords,
    createdAt: DateTime.utc(2026, 11, 2),
  );

  group('word-list proposals', () {
    testWidgets('shows the list label, added and removed words', (
      tester,
    ) async {
      final repo = await pump(tester);
      repo.pending.add([wordList()]);
      await tester.pumpAndSettle();

      expect(find.text('Jul: Ord i titeln'), findsOneWidget);
      expect(find.text('Tillagda: pepparkaka'), findsOneWidget);
      expect(find.text('Borttagna: tomte'), findsOneWidget);
      expect(find.byKey(const ValueKey('allergen-mark')), findsNothing);
      expect(find.textContaining('Just nu i appens ordlista'), findsNothing);
    });

    testWidgets('a reordering reads as the same words in a new order', (
      tester,
    ) async {
      final repo = await pump(tester);
      repo.pending.add([
        wordList(newWords: const ['tomte', 'gran']),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Samma ord i ny ordning'), findsOneWidget);
      expect(find.textContaining('Tillagda'), findsNothing);
    });

    testWidgets('a conflict shows the reason and what the app holds now', (
      tester,
    ) async {
      final repo = await pump(tester);
      repo.pending.add([
        wordList(
          status: IngredientChangeStatus.conflict,
          reason: 'file-mismatch',
          csvValue: {
            'christmas.titleWords': ['gran', 'tomte', 'skinka'],
          },
        ),
      ]);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Ordlistan i appen har ändrats sedan du föreslog'),
        findsOneWidget,
      );
      expect(
        find.text('Just nu i appens ordlista: gran, tomte, skinka'),
        findsOneWidget,
      );
    });

    testWidgets('withdraw calls the repository with the proposal id', (
      tester,
    ) async {
      final repo = await pump(tester);
      repo.pending.add([wordList()]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('withdraw')));
      await tester.pumpAndSettle();
      expect(repo.withdrawn, ['w1']);
    });

    testWidgets('the confirmation names how many are word lists', (
      tester,
    ) async {
      final repo = await pump(tester, prService: _MockPrService());
      repo.pending.add([proposal(id: 'p'), wordList()]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create-review')));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 förslag'), findsOneWidget);
      expect(find.textContaining('1 gäller ordlistor'), findsOneWidget);
    });

    testWidgets('the summary reports the word-list review too', (
      tester,
    ) async {
      final pr = _MockPrService();
      when(pr.createPr).thenAnswer(
        (_) async => const IngredientChangePrResult(
          prNumber: 9,
          prUrl: 'https://github.com/Malingisslen/butlery/pull/9',
          applied: 1,
          conflicts: 0,
          rejected: 0,
          reopened: 0,
          skipped: 0,
          wordLists: IngredientChangePrResult(
            prNumber: 10,
            prUrl: 'https://github.com/Malingisslen/butlery/pull/10',
            applied: 3,
            conflicts: 1,
            rejected: 0,
            reopened: 0,
            skipped: 0,
          ),
        ),
      );
      final repo = await pump(tester, prService: pr);
      repo.pending.add([proposal(id: 'p'), wordList()]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skapa granskning').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Granskning skapad: 1 ändring, 0 konflikter'),
        findsOneWidget,
      );
      expect(find.text('Granskning #9'), findsOneWidget);
      expect(find.text('Ordlistor: 3 ändringar, 1 konflikt'), findsOneWidget);
      expect(find.text('Granskning #10'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('word-list-review-error')),
        findsNothing,
      );
    });

    testWidgets('a word-list-only run hides the empty ingredient part', (
      tester,
    ) async {
      final pr = _MockPrService();
      when(pr.createPr).thenAnswer(
        (_) async => const IngredientChangePrResult(
          prNumber: 0,
          prUrl: '',
          applied: 0,
          conflicts: 0,
          rejected: 0,
          reopened: 0,
          skipped: 0,
          wordLists: IngredientChangePrResult(
            prNumber: 10,
            prUrl: 'https://github.com/Malingisslen/butlery/pull/10',
            applied: 1,
            conflicts: 0,
            rejected: 0,
            reopened: 0,
            skipped: 0,
          ),
        ),
      );
      final repo = await pump(tester, prService: pr);
      repo.pending.add([wordList()]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skapa granskning').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('review-created')), findsNothing);
      expect(find.text('Ordlistor: 1 ändring, 0 konflikter'), findsOneWidget);
      expect(find.text('Granskning #10'), findsOneWidget);
      expect(find.text('Granskning #0'), findsNothing);
    });

    testWidgets('a word-list run that opened no pull request shows no link', (
      tester,
    ) async {
      final pr = _MockPrService();
      when(pr.createPr).thenAnswer(
        (_) async => const IngredientChangePrResult(
          prNumber: 0,
          prUrl: '',
          applied: 0,
          conflicts: 0,
          rejected: 0,
          reopened: 0,
          skipped: 0,
          wordLists: IngredientChangePrResult(
            prNumber: 0,
            prUrl: '',
            applied: 0,
            conflicts: 1,
            rejected: 0,
            reopened: 0,
            skipped: 0,
          ),
        ),
      );
      final repo = await pump(tester, prService: pr);
      repo.pending.add([wordList()]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skapa granskning').last);
      await tester.pumpAndSettle();

      expect(find.text('Ordlistor: 0 ändringar, 1 konflikt'), findsOneWidget);
      expect(find.byKey(const ValueKey('open-github')), findsNothing);
    });

    testWidgets('a word-list failure is reported next to the ingredient PR', (
      tester,
    ) async {
      final pr = _MockPrService();
      when(pr.createPr).thenAnswer(
        (_) async => const IngredientChangePrResult(
          prNumber: 9,
          prUrl: 'https://github.com/Malingisslen/butlery/pull/9',
          applied: 1,
          conflicts: 0,
          rejected: 0,
          reopened: 0,
          skipped: 0,
          wordListError: 'main-moved',
        ),
      );
      final repo = await pump(tester, prService: pr);
      repo.pending.add([proposal(id: 'p'), wordList()]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skapa granskning').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Granskning skapad: 1 ändring, 0 konflikter'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Ordlistorna kom inte med i granskningen'),
        findsOneWidget,
      );
    });
  });
}

class _MockPrService extends Mock implements IngredientChangePrService {}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/models/tagging/ingredient_column.dart';
import 'package:butlery/repositories/interfaces/ingredient_change_request_repository.dart';
import 'package:butlery/viewmodels/admin/pending_proposals_viewmodel.dart';
import 'package:butlery/views/admin/proposals_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';
import '../../test_support/ingredient_review_fixtures.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  Future<FakeChangeRequestRepository> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeChangeRequestRepository();
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: ProposalsView(
          viewModel: PendingProposalsViewModel(repository: repo),
        ),
      ),
    );
    await tester.pump();
    return repo;
  }

  IngredientChangeRequest proposal({
    String id = 'r1',
    List<String> oldProps = const ['dairy'],
    List<String> newProps = const ['dairy'],
  }) => IngredientChangeRequest(
    id: id,
    ingredientId: 'milk',
    note: 'rätta',
    createdAt: DateTime.utc(2026, 11, 1),
    changes: [
      IngredientFieldChange(
        column: IngredientColumn.status,
        oldValue: 'draft',
        newValue: 'verified',
      ),
      IngredientFieldChange(
        column: IngredientColumn.properties,
        oldValue: oldProps,
        newValue: newProps,
      ),
    ],
  );

  testWidgets('shows loading, then the empty state', (tester) async {
    final repo = await pump(tester);
    expect(find.textContaining('Laddar'), findsOneWidget);
    repo.pending.add([]);
    await tester.pumpAndSettle();
    expect(find.text('Inga väntande förslag'), findsOneWidget);
  });

  testWidgets('a stream error is an error state with retry, not empty', (
    tester,
  ) async {
    final repo = await pump(tester);
    repo.pending.addError(StateError('denied'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kunde inte ladda förslagen'), findsOneWidget);
    expect(find.text('Inga väntande förslag'), findsNothing);
  });

  testWidgets('shows old to new per field, note and no allergen mark', (
    tester,
  ) async {
    final repo = await pump(tester);
    repo.pending.add([proposal()]);
    await tester.pumpAndSettle();

    expect(find.text('Status: draft → verified'), findsOneWidget);
    expect(find.text('rätta'), findsOneWidget);
    expect(find.textContaining('Föreslaget 2026-11-01'), findsOneWidget);
    expect(find.byKey(const ValueKey('allergen-mark')), findsNothing);
  });

  testWidgets('a removed allergen property carries the allergen mark', (
    tester,
  ) async {
    final repo = await pump(tester);
    repo.pending.add([proposal(newProps: const [])]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('allergen-mark')), findsOneWidget);
  });

  testWidgets('withdraw calls the repository', (tester) async {
    final repo = await pump(tester);
    repo.pending.add([proposal()]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('withdraw')));
    await tester.pumpAndSettle();
    expect(repo.withdrawn, ['r1']);
  });

  testWidgets('a full page says more proposals are waiting', (tester) async {
    final repo = await pump(tester);
    repo.pending.add([proposal()]);
    await tester.pump();
    expect(find.byKey(const ValueKey('proposals-more-waiting')), findsNothing);

    repo.pending.add([
      for (var i = 0; i < IngredientChangeRequestRepository.maxPending; i++)
        proposal(id: 'r$i'),
    ]);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('proposals-more-waiting')),
      findsOneWidget,
    );
  });
}

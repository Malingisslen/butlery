import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/viewmodels/admin/ingredient_proposal_form_viewmodel.dart';
import 'package:butlery/views/admin/ingredient_proposal_form.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';
import '../../test_support/ingredient_review_fixtures.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  final milk = IngredientData(
    id: 'milk',
    swedish: 'mjölk',
    english: 'milk',
    group: 'protein/dairy',
    properties: const {'dairy', 'animal-product'},
    status: 'draft',
    updatedAt: DateTime.utc(2026, 10, 1),
  );

  Future<FakeChangeRequestRepository> pump(
    WidgetTester tester, {
    bool failWrites = false,
    Object? readError,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeChangeRequestRepository(failWrites: failWrites);
    final vm = IngredientProposalFormViewModel(
      ingredientId: 'milk',
      ingredientRepository: FakeIngredientRepository([milk], error: readError),
      repository: repo,
    );
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: IngredientProposalForm(ingredientId: 'milk', viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('shows all 16 columns and the no-personal-data help text', (
    tester,
  ) async {
    await pump(tester);
    for (final key in [
      'swedish',
      'english',
      'group',
      'properties',
      'aliases_sv',
      'aliases_en',
      'search_terms',
      'notes_sv',
      'notes_en',
      'season_availability',
      'typical_storage',
      'typical_unit',
      'price_category',
      'avg_price_sek',
      'carbon_footprint_category',
      'status',
    ]) {
      expect(
        find.byKey(ValueKey('field-$key'), skipOffstage: false),
        findsOneWidget,
        reason: key,
      );
    }
    expect(
      find.text('Skriv inga personuppgifter här.', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('save is disabled until something changes, then marks it', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Inget är ändrat än.'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('field-english')),
        matching: find.byType(EditableText),
      ),
      'Milk',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Ändrad'), findsOneWidget);
    expect(find.text('Inget är ändrat än.'), findsNothing);
  });

  testWidgets('an invalid value shows its message', (tester) async {
    await pump(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('field-aliases_sv')),
        matching: find.byType(EditableText),
      ),
      'a,b',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Får inte innehålla'), findsOneWidget);
  });

  testWidgets('saving writes only the changed column', (tester) async {
    final repo = await pump(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('field-english')),
        matching: find.byType(EditableText),
      ),
      'Milk',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proposal-save')));
    await tester.pumpAndSettle();

    expect(repo.created.single.changes.map((c) => c.column.csvName), [
      'english',
    ]);
  });

  testWidgets('an allergen change needs the extra confirmation', (
    tester,
  ) async {
    final repo = await pump(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('field-properties')),
        matching: find.byType(EditableText),
      ),
      'animal-product',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proposal-save')));
    await tester.pumpAndSettle();

    expect(find.text('Ändringen påverkar allergener'), findsOneWidget);
    expect(repo.created, isEmpty);

    await tester.tap(find.text('Avbryt').last);
    await tester.pumpAndSettle();
    expect(repo.created, isEmpty);

    await tester.tap(find.byKey(const ValueKey('proposal-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spara ändå'));
    await tester.pumpAndSettle();
    expect(repo.created.length, 1);
  });

  testWidgets('a failed server read shows an error, not a form', (
    tester,
  ) async {
    await pump(tester, readError: StateError('offline'));
    expect(
      find.textContaining('Kunde inte hämta ingrediensen'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('field-swedish')), findsNothing);
  });

  testWidgets('a failed write keeps the form and shows the error', (
    tester,
  ) async {
    await pump(tester, failWrites: true);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('field-english')),
        matching: find.byType(EditableText),
      ),
      'Milk',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proposal-save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kunde inte spara förslaget'), findsOneWidget);
    expect(find.byKey(const ValueKey('field-english')), findsOneWidget);
  });

  testWidgets('changing the status dropdown saves a status change', (
    tester,
  ) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('field-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('verified').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proposal-save')));
    await tester.pumpAndSettle();

    final change = repo.created.single.changes.single;
    expect(change.column.csvName, 'status');
    expect(change.oldValue, 'draft');
    expect(change.newValue, 'verified');
  });

  testWidgets('a comma-decimal price is saved as a number', (tester) async {
    final repo = await pump(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('field-avg_price_sek')),
        matching: find.byType(EditableText),
      ),
      '12,5',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proposal-save')));
    await tester.pumpAndSettle();

    final change = repo.created.single.changes.single;
    expect(change.column.csvName, 'avg_price_sek');
    expect(change.newValue, 12.5);
  });
}

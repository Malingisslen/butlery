import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/repositories/interfaces/ingredient_change_request_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/viewmodels/admin/ingredient_review_viewmodel.dart';
import 'package:butlery/viewmodels/admin/pending_proposals_viewmodel.dart';
import 'package:butlery/views/admin/ingredient_bulk_status.dart';
import 'package:butlery/views/admin/ingredient_review_view.dart';
import 'package:butlery/viewmodels/admin/bulk_status_proposal_viewmodel.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';
import '../../test_support/ingredient_review_fixtures.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  Future<void> pump(
    WidgetTester tester,
    IngredientReviewViewModel vm, {
    PendingProposalsViewModel? pending,
  }) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: IngredientReviewView(
          viewModel: vm,
          pendingViewModel:
              pending ??
              PendingProposalsViewModel(
                repository: FakeChangeRequestRepository(),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a status filter narrows the list', (tester) async {
    final vm = IngredientReviewViewModel(
      repository: FakeIngredientRepository(ingredientReviewSample()),
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(tester, vm);

    expect(find.text('vetemjöl'), findsOneWidget);
    expect(find.text('kycklingbröst'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('status-draft')));
    await tester.pumpAndSettle();

    expect(find.text('kycklingbröst'), findsOneWidget);
    expect(find.text('vetemjöl'), findsNothing);
  });

  testWidgets('an empty load shows an error, not a zero count', (tester) async {
    final vm = IngredientReviewViewModel(
      repository: FakeIngredientRepository(const []),
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(tester, vm);

    expect(find.textContaining('Kunde inte ladda'), findsOneWidget);
    expect(find.textContaining('Visar 0'), findsNothing);
  });

  testWidgets('shows when the data was last synced', (tester) async {
    final vm = IngredientReviewViewModel(
      repository: FakeIngredientRepository(ingredientReviewSample()),
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(tester, vm);

    expect(find.textContaining('Senast synkad: 2026-10-'), findsOneWidget);
    expect(find.textContaining('okänt'), findsNothing);
  });

  testWidgets(
    'without tag config the list stays but says allergens are unknown',
    (tester) async {
      final vm = IngredientReviewViewModel(
        repository: FakeIngredientRepository(ingredientReviewSample()),
        tagConfigService: FakeTagConfigService(null),
      );
      await pump(tester, vm);

      expect(find.text('vetemjöl'), findsOneWidget);
      expect(
        find.textContaining('Taggkonfigurationen är inte laddad'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('filter-allergen')), findsNothing);
    },
  );

  testWidgets('the row copy button puts that ingredient on the clipboard', (
    tester,
  ) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final vm = IngredientReviewViewModel(
      repository: FakeIngredientRepository(ingredientReviewSample()),
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(tester, vm);

    final row = find.byKey(const ValueKey('almond'));
    await tester.tap(
      find.descendant(
        of: row,
        matching: find.bySemanticsLabel(RegExp('Kopiera för Claude')),
      ),
    );
    await tester.pump();

    expect(clipboard, contains('Id: almond'));
    expect(clipboard, contains('Ger allergener: nötter'));
  });

  testWidgets('a dropdown picks a value, and "Alla" clears it again', (
    tester,
  ) async {
    final vm = IngredientReviewViewModel(
      repository: FakeIngredientRepository(ingredientReviewSample()),
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(tester, vm);
    final allergen = find.byKey(const ValueKey('filter-allergen'));

    await tester.tap(
      find.descendant(
        of: allergen,
        matching: find.byType(ButleryDropdown<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('gluten').last);
    await tester.pumpAndSettle();

    expect(vm.allergenFilter, 'gluten');
    expect(find.text('vetemjöl'), findsOneWidget);
    expect(find.text('kycklingbröst'), findsNothing);

    await tester.tap(
      find.descendant(
        of: allergen,
        matching: find.byType(ButleryDropdown<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alla').last);
    await tester.pumpAndSettle();

    expect(vm.allergenFilter, isNull);
    expect(find.text('kycklingbröst'), findsOneWidget);
  });

  testWidgets('tapping a row opens that ingredient\'s details', (tester) async {
    final vm = IngredientReviewViewModel(
      repository: FakeIngredientRepository(ingredientReviewSample()),
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(tester, vm);

    await tester.tap(find.text('mandel'));
    await tester.pumpAndSettle();

    expect(find.text('almond'), findsWidgets);
    expect(find.text('tree-nut'), findsOneWidget);
  });

  testWidgets('"Föreslå ändring" in the detail sheet opens the form for that '
      'ingredient', (tester) async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    addTearDown(() async => TestServiceLocator.reset());
    TestServiceLocator.registerSingleton<IngredientRepository>(
      FakeIngredientRepository(ingredientReviewSample()),
    );
    TestServiceLocator.registerSingleton<IngredientChangeRequestRepository>(
      FakeChangeRequestRepository(),
    );
    final vm = IngredientReviewViewModel(
      repository: FakeIngredientRepository(ingredientReviewSample()),
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(tester, vm);

    await tester.tap(find.text('mandel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('field-swedish')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('suggest-change')));
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizationsSv().adminProposalFormTitle('mandel')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('field-swedish')), findsOneWidget);
  });

  testWidgets('rows with a pending proposal are marked', (tester) async {
    final repo = FakeChangeRequestRepository();
    final vm = IngredientReviewViewModel(
      repository: FakeIngredientRepository(ingredientReviewSample()),
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(
      tester,
      vm,
      pending: PendingProposalsViewModel(repository: repo),
    );
    repo.pending.add([
      const IngredientChangeRequest(
        id: 'r',
        ingredientId: 'almond',
        changes: [],
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pending-almond')), findsOneWidget);
    expect(find.byKey(const ValueKey('pending-salt')), findsNothing);
  });

  testWidgets('a failed pending stream shows its error, not silence', (
    tester,
  ) async {
    final repo = FakeChangeRequestRepository();
    final vm = IngredientReviewViewModel(
      repository: FakeIngredientRepository(ingredientReviewSample()),
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(
      tester,
      vm,
      pending: PendingProposalsViewModel(repository: repo),
    );
    repo.pending.addError(StateError('denied'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kunde inte ladda förslagen'), findsOneWidget);
  });

  testWidgets('selecting rows shows the bulk bar with a count', (tester) async {
    final vm = IngredientReviewViewModel(
      repository: FakeIngredientRepository(ingredientReviewSample()),
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(tester, vm);
    expect(find.byKey(const ValueKey('bulk-status')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('select-almond')));
    await tester.tap(find.byKey(const ValueKey('select-salt')));
    await tester.pumpAndSettle();

    expect(find.text('2 valda'), findsOneWidget);
    expect(find.byKey(const ValueKey('bulk-status')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bulk-clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bulk-status')), findsNothing);
  });

  group('bulk status', () {
    final l10n = AppLocalizationsSv();

    Future<(IngredientReviewViewModel, FakeChangeRequestRepository)> pumpBar(
      WidgetTester tester, {
      bool failWrites = false,
    }) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = FakeChangeRequestRepository(failWrites: failWrites);
      final vm = IngredientReviewViewModel(
        repository: FakeIngredientRepository(ingredientReviewSample()),
        tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
      );
      await vm.load();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: ListenableBuilder(
            listenable: vm,
            builder: (context, _) => Column(
              children: [
                if (vm.selectedIds.isNotEmpty)
                  IngredientBulkBar(
                    vm: vm,
                    bulkFactory: (v) => BulkStatusProposalViewModel(
                      selected: v.selectedIngredients,
                      repository: repo,
                      batchIdFactory: () => 'batch-1',
                    ),
                  ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final i in vm.ingredients)
                        IngredientRow(
                          key: ValueKey(i.id),
                          ingredient: i,
                          vm: vm,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (vm, repo);
    }

    Future<void> selectAndPick(WidgetTester tester, String status) async {
      for (final id in ['wheat-flour', 'almond', 'salt']) {
        await tester.tap(find.byKey(ValueKey('select-$id')));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bulk-status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(status).last);
      await tester.pumpAndSettle();
    }

    testWidgets('confirming saves one batch of the changed rows and clears '
        'the selection', (tester) async {
      final (vm, repo) = await pumpBar(tester);
      await selectAndPick(tester, 'verified');

      expect(find.text(l10n.adminBulkConfirmTitle('verified')), findsOneWidget);
      expect(repo.batches, isEmpty);

      await tester.tap(find.text(l10n.adminBulkConfirm));
      await tester.pumpAndSettle();

      final batch = repo.batches.single;
      expect(batch.map((r) => r.ingredientId), ['almond', 'salt']);
      for (final r in batch) {
        expect(r.batchId, 'batch-1');
        final change = r.changes.single;
        expect(change.column.csvName, 'status');
        expect(change.newValue, 'verified');
      }
      expect(vm.selectedIds, isEmpty);
      expect(find.text(l10n.adminBulkSelectedCount('3')), findsNothing);
      expect(find.byKey(const ValueKey('bulk-status')), findsNothing);
      expect(find.text(l10n.adminProposalSaved), findsOneWidget);
    });

    testWidgets('cancelling the confirmation writes nothing and keeps the '
        'selection', (tester) async {
      final (vm, repo) = await pumpBar(tester);
      await selectAndPick(tester, 'verified');

      await tester.tap(find.text(l10n.commonCancel).last);
      await tester.pumpAndSettle();

      expect(repo.batches, isEmpty);
      expect(vm.selectedIds, {'wheat-flour', 'almond', 'salt'});
      expect(find.text(l10n.adminBulkSelectedCount('3')), findsOneWidget);
    });

    testWidgets('a failing write keeps the selection and shows the failure', (
      tester,
    ) async {
      final (vm, repo) = await pumpBar(tester, failWrites: true);
      await selectAndPick(tester, 'verified');

      await tester.tap(find.text(l10n.adminBulkConfirm));
      await tester.pumpAndSettle();

      expect(repo.batches, isEmpty);
      expect(vm.selectedIds, {'wheat-flour', 'almond', 'salt'});
      expect(find.text(l10n.adminBulkSelectedCount('3')), findsOneWidget);
      expect(
        find.textContaining(l10n.adminProposalSaveFailed),
        findsOneWidget,
      );
      expect(find.text(l10n.adminProposalSaved), findsNothing);
    });
  });
}

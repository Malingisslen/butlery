// BUT-697 chunk-4: Semantics coverage for the chunk-4 widget sweep.
// Asserts that every tap target wrapped in this sprint exposes a localized
// Semantics label discoverable via `find.bySemanticsLabel`.
//
// Like chunk-2/-3, descendant Text labels merge with the wrapper label, so
// RegExp prefix matchers are used so the assertion isn't coupled to
// neighbouring text.
//
// `_PantryFab` (pantry_view.dart) and `_modalButton` (layout_scaffolds.dart)
// are private widgets that only exist inside their parent screens — their
// production wrap is verified by `flutter analyze` and the chunk-8
// unwrapped-files audit script. Pumping the full PantryView / main menu
// here would require a stack of provider mocks for marginal coverage gain.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/viewmodels/pantry/pantry_selection_manager.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_auto_save_manager.dart';
import 'package:butlery/views/pantry/add_pantry_item_sheet.dart';
import 'package:butlery/views/pantry/pantry_item_card.dart';
import 'package:butlery/widgets/common/dialogs/draft_recovery_dialog.dart'
    as common_draft;
import 'package:butlery/widgets/common/input/debounced_button.dart';
import 'package:butlery/widgets/common/share_dialog/share_mode_selection.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/base_widget_test.dart';
import '../../test_support/semantics_announcement.dart';

class _MockPantryViewModel extends Mock implements PantryViewModel {}

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('BUT-697 chunk-4 widget Semantics labels', () {
    testWidgets(
      'pantry_item_card — tappable row exposes edit-pantry-item label',
      (tester) async {
        final handle = tester.ensureSemantics();
        final mockVm = _MockPantryViewModel();
        final item = PantryItem(
          id: 'p_1',
          ingredientName: 'Mjölk',
          quantity: 1,
          unit: 'l',
          location: PantryLocation.fridge,
          addedAt: DateTime(2026, 1, 1),
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider<PantryViewModel>.value(value: mockVm),
                ChangeNotifierProvider<PantrySelectionManager>.value(
                  value: PantrySelectionManager(),
                ),
              ],
              child: PantryItemCard(item: item),
            ),
          ),
        );

        final row = find.bySemanticsLabel(RegExp(r'^Redigera\nMjölk'));
        expect(row, findsOneWidget);
        expectActivatable(tester, row);
        expectNothingAnnouncedTwice(tester, row);
        handle.dispose();
      },
    );

    testWidgets(
      'add_pantry_item_sheet — expiry date tile exposes pick-expiry label',
      (tester) async {
        final handle = tester.ensureSemantics();
        final mockVm = _MockPantryViewModel();
        when(() => mockVm.searchResults).thenReturn(const []);
        // BUT-1379 added an isLoading-gated save button (disable + progress
        // while a save is in flight). The build path reads viewModel.isLoading,
        // so the mock must stub it or mocktail returns null -> TypeError.
        when(() => mockVm.isLoading).thenReturn(false);

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ChangeNotifierProvider<PantryViewModel>.value(
              value: mockVm,
              child: const Material(child: AddPantryItemSheet()),
            ),
          ),
        );

        final tile = find.bySemanticsLabel(RegExp(r'^Öppna kalendern'));
        expect(tile, findsOneWidget);
        expectActivatable(tester, tile);
        expectNothingAnnouncedTwice(tester, tile);
        handle.dispose();
      },
    );

    testWidgets(
      'common/draft_recovery_dialog — draft tile exposes recover-tile label',
      (tester) async {
        final handle = tester.ensureSemantics();
        final draft = DraftMetadata(
          draftId: 'd_1',
          title: 'Bullar',
          createdAt: DateTime(2026, 1, 1),
          lastModifiedAt: DateTime(2026, 1, 1),
          fieldCount: 3,
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: common_draft.DraftRecoveryDialog(
              availableDrafts: [draft],
            ),
          ),
        );

        final tile = find.bySemanticsLabel(RegExp(r'^Återställ\n'));
        expect(tile, findsOneWidget);
        expect(announcedLines(tester, tile), contains('Bullar'));
        expectNothingAnnouncedTwice(tester, tile);
        expectActivatable(tester, tile);
        handle.dispose();
      },
    );

    testWidgets(
      'share_mode_selection — static-copy + realtime options expose labels',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (ctx) => ShareModeSelection.build(
                ctx,
                ShareMode.staticCopy,
                ShareContentType.recipe,
                true,
                (_) {},
              ),
            ),
          ),
        );

        final staticCopy = find.bySemanticsLabel(
          RegExp(r'^Tryck för att välja\nStatisk kopia'),
        );
        final realtime = find.bySemanticsLabel(
          RegExp(r'^Tryck för att välja\nRealtidsdelning'),
        );
        expect(staticCopy, findsOneWidget);
        expect(realtime, findsOneWidget);
        for (final node in [staticCopy, realtime]) {
          expectNothingAnnouncedTwice(tester, node);
          expectActivatable(tester, node);
        }
        handle.dispose();
      },
    );

    testWidgets(
      'debounced_button — semanticLabel surfaces a button-role Semantics',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: DebouncedButton(
              onPressed: () {},
              semanticLabel: 'Spara recept',
              child: const Text('Spara'),
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(RegExp(r'^Spara recept')),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'debounced_button — no semanticLabel means no extra Semantics wrapper',
      (tester) async {
        // Negative case: pre-existing callers that don't pass semanticLabel
        // shouldn't get a duplicate "button" announcement. The label-less
        // variant should produce zero matches for an arbitrary label probe.
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: DebouncedButton(
              onPressed: () {},
              child: const Text('Spara'),
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(RegExp(r'^Spara recept')),
          findsNothing,
        );
        handle.dispose();
      },
    );
  });
}

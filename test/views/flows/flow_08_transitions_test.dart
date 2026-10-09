/// P8-U03 · flow 08, the draft transition that was built but had no test.
///
/// TR::FLOW::08::utkast::avbryt-behaller (fas2/block288-uxfrysning.json,
/// REQUIRED; produktregler.md § 3, the row "Avbryt"; flows-roles-budget.md
/// :38 "Avbryt lämnar vyn men behåller det lokala utkastet"): leaving the
/// editor without saving keeps the draft, and the next opening finds it.
///
/// The recipe editor leaves through its PopScope and "Lämna utan att spara"
/// (lib/views/skriv_sjalv_recept_view.dart:331-372) without touching the
/// draft; only a save clears it (recipe_persistence_manager.dart:315-330,
/// recipe_form_viewmodel.dart:571). What leaving does to the draft is the
/// auto-save manager being disposed with the view, so this drives the real
/// RecipeFormAutoSaveManager through that life: type, leave, open again.
/// SharedPreferences is the mocked platform edge.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/menu/weekly_menu_draft_store.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_auto_save_manager.dart';

import 'veckomeny_flow_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  group('TR::FLOW::08::utkast::avbryt-behaller', () {
    test('leaving the editor without saving keeps the draft, and the next '
        'opening offers it with what was written', () async {
      // The editor is open and the user writes a title.
      final editor = RecipeFormAutoSaveManager(ownerIdProvider: () => 'anna');
      editor.scheduleAutoSave(<String, dynamic>{'title': 'Linsgryta'});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final draftId = editor.currentDraftId;
      expect(draftId, isNotNull, reason: 'D-02: the first character is kept');

      // Avbryt: the view closes and its manager goes with it. Nothing
      // saves the recipe and nothing clears the draft.
      editor.dispose();

      // The next opening of the same view, same account.
      final next = RecipeFormAutoSaveManager(ownerIdProvider: () => 'anna');
      addTearDown(next.dispose);
      final drafts = await next.getAvailableDrafts();

      expect(drafts.map((d) => d.draftId), [draftId]);
      final data = await next.loadDraftData(draftId!);
      expect(data?['title'], 'Linsgryta');
    });
  });

  // BUT-2157: the week generation's draft, through the real week menu.
  group('BUT-2157 week menu draft', () {
    late VeckomenyFlowHarness h;

    setUp(() async {
      h = VeckomenyFlowHarness();
      await h.setUp();
      h.menu.next = {
        'Middag': [flowDinner(1), flowDinner(2)],
      };
    });

    tearDown(() => h.tearDown());

    MenuViewModel screenVm(WidgetTester tester) => Provider.of<MenuViewModel>(
      tester.element(find.byType(TextField).first),
      listen: false,
    );

    Future<void> leaveAndReopen(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await h.pump(tester);
      await tester.pumpAndSettle();
    }

    String draftKey() => WeeklyMenuDraftStore.keyFor(flowUserId);

    Future<bool> hasDraft() async =>
        (await SharedPreferences.getInstance()).containsKey(draftKey());

    testWidgets('an unsaved suggestion outlives the screen and comes back '
        'whole on the next opening', (tester) async {
      await withClock(Clock.fixed(flowMonday), () async {
        await h.pump(tester);
        await h.generate(tester, 'två middagar');
        await tester.pumpAndSettle();
        expect(find.text('Middag 1'), findsOneWidget);

        await leaveAndReopen(tester);
        const card = ValueKey('veckomeny-draft-resume-card');
        expect(find.byKey(card), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(card),
            matching: find.text('Middag 1'),
          ),
          findsOneWidget,
          reason: 'the dish is named by the resume card alone',
        );
        expect(find.text('Middag 1'), findsOneWidget);
        expect(h.repository.saves, isEmpty);

        final vm = screenVm(tester);
        await vm.checkForDraft();
        expect(vm.pendingDraft?.recipeCount, 2);
        expect(await vm.restoreDraft(), 0);
        await tester.pumpAndSettle();

        expect(find.byKey(card), findsNothing);
        expect(find.text('Middag 1'), findsOneWidget);
        expect(find.text('Middag 2'), findsOneWidget);
        expect(vm.lastPrompt, 'två middagar');
      });
    });

    testWidgets('discarding deletes the draft once the undo window closes; '
        'undo keeps it', (tester) async {
      await withClock(Clock.fixed(flowMonday), () async {
        await h.pump(tester);
        await h.generate(tester, 'två middagar');
        await tester.pumpAndSettle();
        await leaveAndReopen(tester);

        final vm = screenVm(tester);
        await vm.checkForDraft();
        final draft = vm.hideDraft()!;
        vm.undoDiscardDraft(draft);
        expect(vm.pendingDraft, same(draft));
        expect(await hasDraft(), isTrue);

        vm.hideDraft();
        await vm.discardDraft(draft);
        expect(await hasDraft(), isFalse);
      });
    });

    testWidgets('a draft untouched for more than 30 days is not offered and '
        'is deleted', (tester) async {
      await withClock(Clock.fixed(flowMonday), () async {
        await h.pump(tester);
        await h.generate(tester, 'två middagar');
        await tester.pumpAndSettle();
      });
      await withClock(
        Clock.fixed(flowMonday.add(const Duration(days: 31))),
        () async {
          await leaveAndReopen(tester);
          final vm = screenVm(tester);
          await vm.checkForDraft();
          expect(vm.pendingDraft, isNull);
          expect(await hasDraft(), isFalse);
        },
      );
    });

    testWidgets('placing the suggestion in the week deletes the draft', (
      tester,
    ) async {
      await withClock(Clock.fixed(flowMonday), () async {
        await h.pump(tester);
        await h.generate(tester, 'två middagar');
        await tester.pumpAndSettle();
        expect(await hasDraft(), isTrue);

        await tester.tap(find.text('Placera automatiskt i kalendern'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(h.repository.saves, hasLength(1));
        expect(await hasDraft(), isFalse);
      });
    });

    testWidgets('signing out yourself deletes the draft', (tester) async {
      await withClock(Clock.fixed(flowMonday), () async {
        await h.pump(tester);
        await h.generate(tester, 'två middagar');
        await tester.pumpAndSettle();
        expect(await hasDraft(), isTrue);

        await AuthService.clearDeviceDraftsOnExplicitSignOut(flowUserId);
        expect(await hasDraft(), isFalse);
      });
    });
  });
}

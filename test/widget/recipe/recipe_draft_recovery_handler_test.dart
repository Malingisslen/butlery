/// BUT-2175 · the recipe form's draft question (produktregler.md:171-173;
/// TR::FLOW::08::utkast::aterupptagning and ::slang-raderar).
///
/// The real RecipeDraftRecoveryHandler, DraftRecoveryDialog and
/// RecipeFormAutoSaveManager run; the view model is a thin fake that hands
/// the draft calls to that manager, and SharedPreferences is the mocked
/// platform edge.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_auto_save_manager.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/widgets/recipe/recipe_draft_recovery_handler.dart';

final _sv = AppLocalizationsSv();

class _Form extends Fake with ChangeNotifier implements RecipeFormViewModel {
  _Form(this.drafts);

  final RecipeFormAutoSaveManager drafts;
  final restored = <String>[];

  @override
  bool get isEditMode => false;

  @override
  Future<List<DraftMetadata>> getAvailableDrafts() =>
      drafts.getAvailableDrafts();

  @override
  Future<void> discardDrafts(Iterable<String> draftIds) async {
    for (final id in draftIds) {
      await drafts.deleteDraft(id);
    }
  }

  @override
  Future<bool> loadFromDraft(String draftId) async {
    restored.add(draftId);
    return true;
  }

  @override
  Map<String, dynamic> serializeCurrentFormData() => {'title': 'Linsgryta'};
}

void main() {
  late RecipeFormAutoSaveManager manager;
  late _Form form;
  late String draftId;

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(WidgetTester tester) async {
    await tester.runAsync(() async {
      final editor = RecipeFormAutoSaveManager(ownerIdProvider: () => 'anna');
      editor.scheduleAutoSave(<String, dynamic>{'title': 'Linsgryta'});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      draftId = editor.currentDraftId!;
      editor.dispose();
    });
    manager = RecipeFormAutoSaveManager(ownerIdProvider: () => 'anna');
    addTearDown(manager.dispose);
    form = _Form(manager);

    await tester.pumpWidget(
      ChangeNotifierProvider<RecipeFormViewModel>.value(
        value: form,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('sv'),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    RecipeDraftRecoveryHandler.checkAndShowDraftRecovery(
                      context,
                    ),
                child: const Text('Öppna'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öppna'));
    await tester.pumpAndSettle();
    expect(find.text('Linsgryta'), findsOneWidget);
  }

  Future<List<String>> left(WidgetTester tester) async {
    final drafts = await tester.runAsync(manager.getAvailableDrafts);
    return [for (final d in drafts!) d.draftId];
  }

  group('TR::FLOW::08::utkast::aterupptagning', () {
    testWidgets('the next opening asks, and Återställ restores that draft', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(find.text(_sv.draftRestore));
      await tester.pumpAndSettle();

      expect(form.restored, [draftId]);
    });

    testWidgets('Börja om closes the question and keeps the draft', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(find.text(_sv.draftStartFresh));
      await tester.pumpAndSettle();

      expect(form.restored, isEmpty);
      expect(find.text(_sv.draftsDiscarded(1)), findsNothing);
      expect(await left(tester), [draftId]);
    });
  });

  group('TR::FLOW::08::utkast::slang-raderar', () {
    testWidgets('Släng deletes the draft once the undo window has closed', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(find.text(_sv.draftDiscard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(_sv.draftsDiscarded(1)), findsOneWidget);

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();

      expect(form.restored, isEmpty);
      expect(await left(tester), isEmpty);
    });

    testWidgets('Ångra after Släng keeps the draft', (tester) async {
      await open(tester);

      await tester.tap(find.text(_sv.draftDiscard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(_sv.commonUndo));
      await tester.pumpAndSettle();

      expect(await left(tester), [draftId]);
    });
  });
}

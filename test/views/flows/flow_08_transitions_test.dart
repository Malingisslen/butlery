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

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/viewmodels/recipe_form/recipe_auto_save_manager.dart';

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
}

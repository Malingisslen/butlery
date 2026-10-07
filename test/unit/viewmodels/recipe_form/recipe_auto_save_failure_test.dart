/// BUT-2224: a failed draft write is no longer silent.
///
/// Before the fix `_performAutoSave` caught the error, logged one line and
/// left the editor showing nothing, so the user believed the draft was kept.
/// The manager now holds the failure until the next successful write, and
/// counts failure periods so the editor shows its snackbar once per period.
library;

import 'package:butlery/viewmodels/recipe_form/recipe_auto_save_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_form_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `jsonEncode` throws on an [Object], so the draft write fails the way a
/// storage write that throws does: inside `_performAutoSave`'s try.
Map<String, dynamic> _unwritable() => {'title': 'Soppa', 'extra': Object()};

Map<String, dynamic> _writable() => {'title': 'Soppa'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecipeFormAutoSaveManager manager;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    manager = RecipeFormAutoSaveManager(ownerIdProvider: () => 'me');
  });

  tearDown(() => manager.dispose());

  test('a failed draft write is reported, not swallowed', () async {
    expect(manager.hasAutoSaveFailed, isFalse);

    await manager.saveNow(_unwritable());

    expect(manager.hasAutoSaveFailed, isTrue);
    expect(manager.autoSaveFailurePeriod, 1);
    expect(manager.isAutoSaving, isFalse);
  });

  test('the last notification carries the failure, so the editor can '
      'redraw', () async {
    final seen = <bool>[];
    manager.addListener(() => seen.add(manager.hasAutoSaveFailed));

    await manager.saveNow(_unwritable());

    expect(seen.last, isTrue);
  });

  test('the form state passes the failure on without a keystroke', () async {
    final state = RecipeFormState();
    addTearDown(state.dispose);
    final seen = <bool>[];
    state.addListener(() => seen.add(state.hasAutoSaveFailed));

    await state.autoSaveManager.saveNow(_unwritable());

    expect(seen, isNotEmpty);
    expect(seen.last, isTrue);
  });

  test('repeated failures stay in one period', () async {
    await manager.saveNow(_unwritable());
    await manager.saveNow(_unwritable());
    await manager.saveNow(_unwritable());

    expect(manager.autoSaveFailurePeriod, 1);
  });

  test('a successful write ends the period; the next failure starts a new '
      'one', () async {
    await manager.saveNow(_unwritable());
    await manager.saveNow(_writable());

    expect(manager.hasAutoSaveFailed, isFalse);
    expect(manager.autoSaveFailurePeriod, 1);

    await manager.saveNow(_unwritable());

    expect(manager.hasAutoSaveFailed, isTrue);
    expect(manager.autoSaveFailurePeriod, 2);
  });

  test('saving the recipe clears the failure', () async {
    await manager.saveNow(_unwritable());

    await manager.clearCurrentDraft();

    expect(manager.hasAutoSaveFailed, isFalse);
  });
}

// test/unit/viewmodels/recipe_list/recipe_selection_manager_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/recipe_list/recipe_selection_manager.dart';

void main() {
  late RecipeSelectionManager manager;
  int notifyCount = 0;

  setUp(() {
    manager = RecipeSelectionManager();
    notifyCount = 0;
    manager.addListener(() => notifyCount++);
  });

  tearDown(() {
    manager.dispose();
  });

  group('RecipeSelectionManager - Initial State', () {
    test('should start with selection mode disabled', () {
      expect(manager.isSelectionMode, false);
      expect(manager.selectedIds, isEmpty);
      expect(manager.selectedCount, 0);
    });
  });

  group('RecipeSelectionManager - enterSelectionMode', () {
    test('should enable selection mode and select the first item', () {
      // Behavior: Long-press on a recipe enters selection mode with that recipe pre-selected
      manager.enterSelectionMode('recipe-1');

      expect(manager.isSelectionMode, true);
      expect(manager.selectedIds, {'recipe-1'});
      expect(manager.selectedCount, 1);
      expect(notifyCount, 1);
    });
  });

  group('RecipeSelectionManager - toggleSelection', () {
    test('should add an unselected item to the selection', () {
      // Behavior: Tapping an unselected recipe adds it to the selection
      manager.enterSelectionMode('recipe-1');
      notifyCount = 0;

      manager.toggleSelection('recipe-2');

      expect(manager.selectedIds, {'recipe-1', 'recipe-2'});
      expect(manager.selectedCount, 2);
      expect(notifyCount, 1);
    });

    test('should remove a selected item from the selection', () {
      // Behavior: Tapping an already-selected recipe deselects it
      manager.enterSelectionMode('recipe-1');
      manager.toggleSelection('recipe-2');
      notifyCount = 0;

      manager.toggleSelection('recipe-1');

      expect(manager.selectedIds, {'recipe-2'});
      expect(manager.selectedCount, 1);
      expect(notifyCount, 1);
    });

    test('should auto-exit selection mode when last item is deselected', () {
      // Behavior: Deselecting the final item automatically exits selection mode
      manager.enterSelectionMode('recipe-1');
      notifyCount = 0;

      manager.toggleSelection('recipe-1');

      expect(manager.isSelectionMode, false);
      expect(manager.selectedIds, isEmpty);
      expect(manager.selectedCount, 0);
      expect(notifyCount, 1);
    });
  });

  group('RecipeSelectionManager - selectAll', () {
    test('should add all visible items to the selection', () {
      // Behavior: "Select All" adds every currently visible recipe
      manager.enterSelectionMode('recipe-1');
      notifyCount = 0;

      manager.selectAll(['recipe-1', 'recipe-2', 'recipe-3']);

      expect(manager.selectedIds, {'recipe-1', 'recipe-2', 'recipe-3'});
      expect(manager.selectedCount, 3);
      expect(notifyCount, 1);
    });

    test('should not duplicate already-selected items', () {
      // Behavior: Select All is idempotent for already-selected items
      manager.enterSelectionMode('recipe-1');
      manager.toggleSelection('recipe-2');
      notifyCount = 0;

      manager.selectAll(['recipe-1', 'recipe-2', 'recipe-3']);

      expect(manager.selectedCount, 3);
      expect(notifyCount, 1);
    });
  });

  group('RecipeSelectionManager - clearSelection', () {
    test('should clear all selections and exit selection mode', () {
      // Behavior: "Cancel" clears all selections and returns to normal mode
      manager.enterSelectionMode('recipe-1');
      manager.toggleSelection('recipe-2');
      notifyCount = 0;

      manager.clearSelection();

      expect(manager.isSelectionMode, false);
      expect(manager.selectedIds, isEmpty);
      expect(manager.selectedCount, 0);
      expect(notifyCount, 1);
    });
  });

  group('RecipeSelectionManager - selectedIds immutability', () {
    test('should return an unmodifiable copy of selected IDs', () {
      // Behavior: External code cannot corrupt internal state via the getter
      manager.enterSelectionMode('recipe-1');

      final ids = manager.selectedIds;
      expect(() => ids.add('hack'), throwsUnsupportedError);
    });
  });
}

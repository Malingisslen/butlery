// test/unit/viewmodels/personal_tags/personal_tag_selection_manager_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/personal_tags/personal_tag_selection_manager.dart';

void main() {
  late PersonalTagSelectionManager manager;
  int notifyCount = 0;

  setUp(() {
    manager = PersonalTagSelectionManager();
    notifyCount = 0;
    manager.addListener(() => notifyCount++);
  });

  tearDown(() {
    manager.dispose();
  });

  group('Initial state', () {
    test('starts outside selection mode with nothing selected', () {
      expect(manager.isSelectionMode, false);
      expect(manager.selectedTagIds, isEmpty);
      expect(manager.selectedCount, 0);
    });
  });

  group('enterSelection', () {
    test('enables selection mode with the first tag pre-selected', () {
      // Behavior: long-press on a tag enters selection mode with that tag selected.
      manager.enterSelection('tag-1');

      expect(manager.isSelectionMode, true);
      expect(manager.selectedTagIds, {'tag-1'});
      expect(manager.selectedCount, 1);
      expect(manager.isSelected('tag-1'), true);
      expect(notifyCount, 1);
    });
  });

  group('toggle', () {
    test('adds an unselected tag to the selection and notifies', () {
      // Behavior: tapping an unselected tag while in selection mode adds it.
      manager.enterSelection('tag-1');
      notifyCount = 0;

      manager.toggle('tag-2');

      expect(manager.selectedTagIds, {'tag-1', 'tag-2'});
      expect(manager.selectedCount, 2);
      expect(notifyCount, 1);
    });

    test('toggling the same tag twice deselects it, returning count to 0', () {
      // Behavior: tap-select then tap-deselect leaves the tag unselected.
      manager.enterSelection('tag-1');
      // tag-1 is now selected (count 1). Toggle it off.
      notifyCount = 0;

      manager.toggle('tag-1');

      expect(manager.isSelected('tag-1'), false);
      expect(manager.selectedCount, 0);
    });

    test('auto-exits selection mode when the last tag is deselected', () {
      // Behavior (pinned from production line 27-29): deselecting the final
      // tag empties the selection AND drops out of selection mode — a UI with
      // an empty selection bar would be confusing, so this is intended.
      manager.enterSelection('tag-1');
      notifyCount = 0;

      manager.toggle('tag-1');

      expect(manager.isSelectionMode, false);
      expect(manager.selectedTagIds, isEmpty);
      expect(manager.selectedCount, 0);
      expect(notifyCount, 1);
    });

    test('stays in selection mode while at least one tag remains selected', () {
      // Behavior: deselecting one of several keeps selection mode active.
      manager.enterSelection('tag-1');
      manager.toggle('tag-2');
      notifyCount = 0;

      manager.toggle('tag-1');

      expect(manager.isSelectionMode, true);
      expect(manager.selectedTagIds, {'tag-2'});
      expect(notifyCount, 1);
    });
  });

  group('clear / exitSelection', () {
    test('exitSelection clears all selections and leaves selection mode', () {
      // Behavior: "Cancel" wipes the selection and returns to normal mode.
      manager.enterSelection('tag-1');
      manager.toggle('tag-2');
      notifyCount = 0;

      manager.exitSelection();

      expect(manager.isSelectionMode, false);
      expect(manager.selectedTagIds, isEmpty);
      expect(manager.selectedCount, 0);
      expect(notifyCount, 1);
    });

    test('clear behaves identically to exitSelection and notifies', () {
      // Behavior: clear() is the documented alias for exitSelection().
      manager.enterSelection('tag-1');
      manager.toggle('tag-2');
      notifyCount = 0;

      manager.clear();

      expect(manager.isSelectionMode, false);
      expect(manager.selectedTagIds, isEmpty);
      expect(notifyCount, 1);
    });
  });

  group('isSelected', () {
    test('reflects membership for selected and unselected tags', () {
      // Behavior: the per-tag checkbox state is driven by isSelected.
      manager.enterSelection('tag-1');
      manager.toggle('tag-3');

      expect(manager.isSelected('tag-1'), true);
      expect(manager.isSelected('tag-3'), true);
      expect(manager.isSelected('tag-2'), false);
    });
  });

  group('selectedTagIds immutability', () {
    test('returns an unmodifiable view so callers cannot corrupt state', () {
      // Behavior: the bulk-action UI reads selectedTagIds; it must not be able
      // to mutate the manager's internal set behind its back.
      manager.enterSelection('tag-1');

      final ids = manager.selectedTagIds;
      expect(() => ids.add('hack'), throwsUnsupportedError);
    });
  });
}

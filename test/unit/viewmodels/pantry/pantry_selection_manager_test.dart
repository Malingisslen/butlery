/// BUT-948: pins the pantry multi-select state machine — enter on long-press,
/// toggle on tap, auto-exit when the last item is deselected, and clear.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/pantry/pantry_selection_manager.dart';

void main() {
  late PantrySelectionManager manager;

  setUp(() => manager = PantrySelectionManager());
  tearDown(() => manager.dispose());

  test('starts not in selection mode', () {
    expect(manager.isSelectionMode, isFalse);
    expect(manager.selectedCount, 0);
  });

  test('enterSelectionMode selects the first id and turns the mode on', () {
    manager.enterSelectionMode('a');

    expect(manager.isSelectionMode, isTrue);
    expect(manager.isSelected('a'), isTrue);
    expect(manager.selectedCount, 1);
  });

  test('toggleSelection adds then removes an id', () {
    manager.enterSelectionMode('a');
    manager.toggleSelection('b');
    expect(manager.selectedIds, {'a', 'b'});

    manager.toggleSelection('b');
    expect(manager.selectedIds, {'a'});
  });

  test('deselecting the last id auto-exits selection mode', () {
    manager.enterSelectionMode('a');
    manager.toggleSelection('a');

    expect(manager.isSelectionMode, isFalse,
        reason: 'an empty selection should drop back to the normal list');
    expect(manager.selectedCount, 0);
  });

  test('clearSelection empties and exits', () {
    manager.enterSelectionMode('a');
    manager.toggleSelection('b');

    manager.clearSelection();

    expect(manager.isSelectionMode, isFalse);
    expect(manager.selectedCount, 0);
  });

  test('selectedIds is an unmodifiable view', () {
    manager.enterSelectionMode('a');
    expect(() => manager.selectedIds.add('x'), throwsUnsupportedError);
  });
}

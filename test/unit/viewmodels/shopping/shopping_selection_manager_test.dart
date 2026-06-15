/// BUT-948: pins the shopping multi-select state machine — enter on long-press,
/// toggle on tap, auto-exit when the last item is deselected, and clear.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/shopping/shopping_selection_manager.dart';

void main() {
  late ShoppingSelectionManager manager;

  setUp(() => manager = ShoppingSelectionManager());
  tearDown(() => manager.dispose());

  test('starts not in selection mode', () {
    expect(manager.isSelectionMode, isFalse);
    expect(manager.selectedCount, 0);
  });

  test('enterSelectionMode selects the first id and turns the mode on', () {
    manager.enterSelectionMode('a');

    expect(manager.isSelectionMode, isTrue);
    expect(manager.isSelected('a'), isTrue);
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

    expect(manager.isSelectionMode, isFalse);
    expect(manager.selectedCount, 0);
  });

  test('selectAll turns the mode on for a non-empty set', () {
    manager.selectAll(['a', 'b']);

    expect(manager.isSelectionMode, isTrue);
    expect(manager.selectedIds, {'a', 'b'});
  });

  test('clearSelection empties and exits', () {
    manager.enterSelectionMode('a');
    manager.clearSelection();

    expect(manager.isSelectionMode, isFalse);
    expect(manager.selectedCount, 0);
  });
}

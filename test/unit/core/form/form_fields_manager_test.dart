/// FormFieldsManager reorder primitives.
///
/// `reorderAt` (ReorderableListView semantics — decrement newIndex on a
/// downward drag) is refactored to delegate to the new raw `moveAt` (final
/// indices, used by the sectioned ingredient editor which computes its own
/// target). These pin both so the refactor stays behaviour-preserving for the
/// existing instruction/tag reorder callers.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/form/form_fields_manager.dart';

void main() {
  FormFieldsManager mgr(List<String> items) =>
      FormFieldsManager(initialItems: items);

  group('reorderAt (ReorderableListView semantics)', () {
    test('drag first item down to the end (newIndex past end)', () {
      final m = mgr(['a', 'b', 'c']);
      m.reorderAt(0, 3); // ReorderableListView passes length for end
      expect(m.values, ['b', 'c', 'a']);
      addTearDown(m.dispose);
    });

    test('drag last item up to the front', () {
      final m = mgr(['a', 'b', 'c']);
      m.reorderAt(2, 0);
      expect(m.values, ['c', 'a', 'b']);
      addTearDown(m.dispose);
    });

    test('adjacent swap downward', () {
      final m = mgr(['a', 'b', 'c']);
      m.reorderAt(0, 2); // move a to just after b
      expect(m.values, ['b', 'a', 'c']);
      addTearDown(m.dispose);
    });
  });

  group('moveAt (raw, final indices)', () {
    test('moves to an exact index without adjustment', () {
      final m = mgr(['a', 'b', 'c']);
      m.moveAt(2, 0); // last → first
      expect(m.values, ['c', 'a', 'b']);
      addTearDown(m.dispose);
    });

    test('moves forward to an exact index', () {
      final m = mgr(['a', 'b', 'c']);
      m.moveAt(0, 2);
      expect(m.values, ['b', 'c', 'a']);
      addTearDown(m.dispose);
    });

    test('no-op and out-of-range are ignored', () {
      final m = mgr(['a', 'b', 'c']);
      m.moveAt(1, 1);
      m.moveAt(-1, 0);
      m.moveAt(0, 9);
      expect(m.values, ['a', 'b', 'c']);
      addTearDown(m.dispose);
    });

    test('controllers rebuild with realigned text after a move', () {
      final m = mgr(['a', 'b', 'c']);
      m.moveAt(0, 2); // → b, c, a
      final controllers = m.controllers;
      expect(controllers.map((c) => c.text), ['b', 'c', 'a']);
      addTearDown(m.dispose);
    });
  });

  // BUT-2455: an import can cut one step in two; the form joins them back.
  group('mergeWithNext and splitAt', () {
    test('joins a line with the next one, separated by a space', () {
      final m = mgr(['Smält smöret. ', ' Häll i grädden.', 'Servera.']);
      addTearDown(m.dispose);
      expect(m.mergeWithNext(0), 'Smält smöret. Häll i grädden.');
      expect(m.values, ['Smält smöret. Häll i grädden.', 'Servera.']);
    });

    test('an empty side just drops out', () {
      final m = mgr(['Smält smöret.', '', 'Servera.']);
      addTearDown(m.dispose);
      expect(m.mergeWithNext(0), 'Smält smöret.');
      expect(m.values, ['Smält smöret.', 'Servera.']);
    });

    test('the last line has nothing to merge with', () {
      final m = mgr(['a', 'b']);
      addTearDown(m.dispose);
      expect(m.mergeWithNext(1), isNull);
      expect(m.mergeWithNext(-1), isNull);
      expect(m.values, ['a', 'b']);
    });

    test('splitAt puts both original lines back in place', () {
      final m = mgr(['a', ' b ', 'c', 'd']);
      addTearDown(m.dispose);
      final merged = m.mergeWithNext(1)!;
      expect(m.splitAt(1, merged, ' b ', 'c'), isTrue);
      expect(m.values, ['a', ' b ', 'c', 'd']);
    });

    test('splitAt does nothing once the merged line has moved', () {
      final m = mgr(['a', 'b', 'c']);
      addTearDown(m.dispose);
      final merged = m.mergeWithNext(0)!; // a b, c
      m.moveAt(0, 1); // c, a b
      expect(m.splitAt(0, merged, 'a', 'b'), isFalse);
      expect(m.values, ['c', 'a b']);
    });

    test('controllers show the merged and restored text at each index', () {
      final m = mgr(['a', 'b', 'c']);
      addTearDown(m.dispose);
      expect(m.controllers.map((c) => c.text), ['a', 'b', 'c']);
      final merged = m.mergeWithNext(0)!;
      expect(m.controllers.map((c) => c.text), ['a b', 'c']);
      m.splitAt(0, merged, 'a', 'b');
      expect(m.controllers.map((c) => c.text), ['a', 'b', 'c']);
    });
  });
}

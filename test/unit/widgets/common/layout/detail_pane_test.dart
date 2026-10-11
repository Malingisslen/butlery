// BUT-723: when a tab shows list and detail side by side, and what the
// controller does with picks and offers.

import 'package:butlery/widgets/common/layout/detail_pane.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('useDetailPane', () {
    test('is true for a tablet held in landscape', () {
      expect(useDetailPane(const Size(1280, 800)), isTrue);
      expect(useDetailPane(const Size(1024, 600)), isTrue);
    });

    test('is false in portrait and on a landscape screen below 1024', () {
      expect(useDetailPane(const Size(800, 1280)), isFalse);
      expect(useDetailPane(const Size(900, 600)), isFalse);
    });

    test('is false on a phone', () {
      expect(useDetailPane(const Size(360, 800)), isFalse);
      expect(useDetailPane(const Size(800, 360)), isFalse);
    });
  });

  group('DetailPaneController', () {
    const a = RouteSettings(name: '/a');
    const b = RouteSettings(name: '/b');

    late DetailPaneController controller;
    late int notified;

    setUp(() {
      controller = DetailPaneController();
      notified = 0;
      controller.addListener(() => notified++);
    });

    tearDown(() => controller.dispose());

    test('starts with nothing selected and not expanded', () {
      expect(controller.selected, isNull);
      expect(controller.expanded, isFalse);
      expect(controller.isSelected('a'), isFalse);
    });

    test('open selects, marks only its key and clears expanded', () {
      controller.setExpanded(true);
      notified = 0;

      controller.open(a, key: 'a');

      expect(controller.selected, same(a));
      expect(controller.isSelected('a'), isTrue);
      expect(controller.isSelected('b'), isFalse);
      expect(controller.expanded, isFalse);
      expect(notified, 1);
    });

    test('offerFirst shows and marks the offered item', () {
      controller.offerFirst(a, key: 'a');

      expect(controller.selected, same(a));
      expect(controller.isSelected('a'), isTrue);
      expect(notified, 1);
    });

    test('an offer after a pick is ignored', () {
      controller.open(a, key: 'a');
      notified = 0;

      controller.offerFirst(b, key: 'b');

      expect(controller.selected, same(a));
      expect(controller.isSelected('b'), isFalse);
      expect(notified, 0);
    });

    test('an offer with another key replaces an earlier offer', () {
      controller.offerFirst(a, key: 'a');
      notified = 0;

      controller.offerFirst(b, key: 'b');

      expect(controller.selected, same(b));
      expect(controller.isSelected('a'), isFalse);
      expect(controller.isSelected('b'), isTrue);
      expect(notified, 1);
    });

    test('an offer with the same key changes nothing', () {
      controller.offerFirst(a, key: 'a');
      notified = 0;

      controller.offerFirst(const RouteSettings(name: '/a'), key: 'a');

      expect(controller.selected, same(a));
      expect(notified, 0);
    });

    test('a pick replaces an offer, and a later offer cannot undo it', () {
      controller.offerFirst(a, key: 'a');
      controller.open(b, key: 'b');
      controller.offerFirst(a, key: 'a');

      expect(controller.selected, same(b));
      expect(controller.isSelected('b'), isTrue);
    });

    test('setExpanded notifies only on a change', () {
      controller.setExpanded(true);
      controller.setExpanded(true);
      expect(controller.expanded, isTrue);
      expect(notified, 1);

      controller.setExpanded(false);
      expect(controller.expanded, isFalse);
      expect(notified, 2);
    });

    test('clear empties a pick and Helskärm, and a later offer is shown', () {
      controller.open(b, key: 'b');
      controller.setExpanded(true);
      controller.clear();

      expect(controller.selected, isNull);
      expect(controller.isSelected('b'), isFalse);
      expect(controller.expanded, isFalse);
      expect(notified, 3);

      controller.clear();
      expect(notified, 3);

      controller.offerFirst(a, key: 'a');
      expect(controller.selected, same(a));
    });
  });
}

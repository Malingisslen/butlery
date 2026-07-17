/// BUT-1618: pins the property-dropdown value invariant that keeps editing a
/// rule with a retired property from crashing the DropdownButtonFormField.
///
/// The dropdown's `initialValue` is the stored condition value, and
/// DropdownButtonFormField asserts that value matches EXACTLY ONE item. A
/// retired stored value (e.g. 'wheat', BUT-1498) is not in the vocabulary, so
/// it must be added as its own flagged item — if that regresses the value
/// matches zero items and the dialog crashes on open. `_buildPropertyDropdown`
/// builds its items directly from `propertyDropdownEntries`, so testing that
/// seam exercises the real dropdown, not a parallel copy.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/tagging/config/valid_properties.dart';
import 'package:butlery/widgets/tagging/personal_tag_rule_dialog.dart';

void main() {
  /// The values of the SELECTABLE (non-header) dropdown items — exactly the
  /// values `DropdownButtonFormField.initialValue` may match.
  List<String> selectableValues(String storedValue) => [
    for (final e in propertyDropdownEntries(storedValue))
      if (!e.isHeader) e.value,
  ];

  group('property dropdown entries (BUT-1618)', () {
    test('a retired stored value stays selectable exactly once', () {
      expect(isRetiredProperty('wheat'), isTrue);
      expect(
        selectableValues('wheat').where((v) => v == 'wheat').length,
        1,
        reason:
            'initialValue = the retired stored value must match exactly one '
            'dropdown item, or DropdownButtonFormField asserts on open',
      );
      // It is the flagged retired entry, not a vocabulary item.
      final retired = propertyDropdownEntries(
        'wheat',
      ).where((e) => e.isRetired);
      expect(retired, hasLength(1));
      expect(retired.single.value, 'wheat');
    });

    test(
      'a valid stored value matches exactly one item and is not flagged',
      () {
        expect(isRetiredProperty('dairy'), isFalse);
        expect(selectableValues('dairy').where((v) => v == 'dairy').length, 1);
        expect(
          propertyDropdownEntries('dairy').where((e) => e.isRetired),
          isEmpty,
        );
      },
    );

    test('an empty stored value adds no flagged item', () {
      expect(isRetiredProperty(''), isFalse);
      final values = selectableValues('');
      expect(values.contains(''), isFalse);
      // With no retired value, the selectable set is exactly the vocabulary.
      expect(values.toSet(), kValidIngredientProperties);
    });

    test('a value shaped like a header sentinel is never flagged as retired', () {
      // Guards a malformed/imported stored value colliding with a header item
      // value ('__header_*'), which would otherwise produce two matching items.
      expect(isRetiredProperty('__header_allergens'), isFalse);
      expect(
        selectableValues(
          '__header_allergens',
        ).where((v) => v == '__header_allergens'),
        isEmpty,
      );
    });

    test('every header value is distinct from every selectable value', () {
      final entries = propertyDropdownEntries('wheat');
      final headers = entries.where((e) => e.isHeader).map((e) => e.value);
      final selectable = entries
          .where((e) => !e.isHeader)
          .map((e) => e.value)
          .toSet();
      for (final h in headers) {
        expect(selectable.contains(h), isFalse);
      }
    });
  });

  group('dropdown initialValue (BUT-1618)', () {
    test('a retired stored value is kept as the selected value', () {
      expect(dropdownInitialValue('wheat'), 'wheat');
    });

    test('a valid stored value is kept as the selected value', () {
      expect(dropdownInitialValue('dairy'), 'dairy');
    });

    test('an empty stored value selects nothing', () {
      expect(dropdownInitialValue(''), isNull);
    });

    test('a header-shaped value selects nothing (no dropdown crash)', () {
      // A corrupted/imported/legacy value shaped like a header sentinel matches
      // no item; keeping it as initialValue would assert-crash the dropdown.
      expect(dropdownInitialValue('__header_allergens'), isNull);
      expect(dropdownInitialValue('__header_foo'), isNull);
    });

    test(
      'initialValue always matches exactly one selectable item, or is null',
      () {
        for (final v in ['wheat', 'dairy', '', '__header_foo', 'not-a-prop']) {
          final initial = dropdownInitialValue(v);
          if (initial == null) continue;
          expect(
            selectableValues(v).where((e) => e == initial).length,
            1,
            reason: 'initialValue "$initial" must match exactly one item',
          );
        }
      },
    );
  });
}

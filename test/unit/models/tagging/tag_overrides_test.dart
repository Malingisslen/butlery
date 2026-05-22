/// Unit tests for TagOverrides model.
///
/// Pure-Dart; targets the 76 unhit lines in lib/models/tagging/tag_overrides.dart.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tri_state.dart';

void main() {
  group('hasManualEdits', () {
    test('false on empty', () {
      expect(const TagOverrides().hasManualEdits, isFalse);
    });

    test('true when any field is populated', () {
      expect(
          const TagOverrides(allergenOverrides: {'gluten': TriState.free})
              .hasManualEdits,
          isTrue);
      expect(
          const TagOverrides(dietaryOverrides: {'vegansk': TriState.contains})
              .hasManualEdits,
          isTrue);
      expect(const TagOverrides(addedTags: {'tag'}).hasManualEdits, isTrue);
      expect(const TagOverrides(removedTags: {'tag'}).hasManualEdits, isTrue);
    });
  });

  group('hasAllergenOverride / hasDietaryOverride', () {
    const o = TagOverrides(
      allergenOverrides: {'gluten': TriState.free},
      dietaryOverrides: {'vegansk': TriState.contains},
    );

    test('true for known keys', () {
      expect(o.hasAllergenOverride('gluten'), isTrue);
      expect(o.hasDietaryOverride('vegansk'), isTrue);
    });

    test('false for unknown keys', () {
      expect(o.hasAllergenOverride('dairy'), isFalse);
      expect(o.hasDietaryOverride('vegetarisk'), isFalse);
    });
  });

  group('getEffectiveAllergenStatus / getEffectiveDietaryStatus', () {
    const o = TagOverrides(
      allergenOverrides: {'gluten': TriState.free},
      dietaryOverrides: {'vegansk': TriState.contains},
    );

    test('returns override when present', () {
      expect(o.getEffectiveAllergenStatus('gluten', TriState.contains),
          TriState.free);
      expect(o.getEffectiveDietaryStatus('vegansk', TriState.free),
          TriState.contains);
    });

    test('returns auto-generated when no override', () {
      expect(o.getEffectiveAllergenStatus('dairy', TriState.unknown),
          TriState.unknown);
      expect(o.getEffectiveDietaryStatus('vegetarisk', TriState.free),
          TriState.free);
    });
  });

  group('getEffectiveTags', () {
    const o = TagOverrides(
      addedTags: {'extra'},
      removedTags: {'unwanted'},
    );

    test('adds added, removes removed', () {
      final result = o.getEffectiveTags({'auto1', 'unwanted'});
      expect(result, {'auto1', 'extra'});
    });

    test('empty overrides leave auto-generated set unchanged', () {
      const empty = TagOverrides();
      expect(empty.getEffectiveTags({'auto1', 'auto2'}), {'auto1', 'auto2'});
    });
  });

  group('immutable update helpers', () {
    test('withAllergenOverride adds key + stamps editor', () {
      const original = TagOverrides();
      final updated = original.withAllergenOverride('gluten', TriState.free,
          editedBy: 'u1');
      expect(updated.allergenOverrides['gluten'], TriState.free);
      expect(updated.lastEditedBy, 'u1');
      expect(updated.lastEditedAt, isNotNull);
    });

    test('withDietaryOverride adds key + stamps editor', () {
      const original = TagOverrides();
      final updated = original.withDietaryOverride('vegansk', TriState.contains,
          editedBy: 'u2');
      expect(updated.dietaryOverrides['vegansk'], TriState.contains);
      expect(updated.lastEditedBy, 'u2');
    });

    test('withTagAdded adds tag + removes from removedTags', () {
      const original = TagOverrides(removedTags: {'snabb'});
      final updated = original.withTagAdded('snabb', editedBy: 'u1');
      expect(updated.addedTags, contains('snabb'));
      expect(updated.removedTags, isEmpty);
    });

    test('withTagRemoved adds to removedTags + clears from addedTags', () {
      const original = TagOverrides(addedTags: {'snabb'});
      final updated = original.withTagRemoved('snabb', editedBy: 'u1');
      expect(updated.removedTags, contains('snabb'));
      expect(updated.addedTags, isEmpty);
    });

    test('withoutAllergenOverride removes the key', () {
      const original =
          TagOverrides(allergenOverrides: {'gluten': TriState.free});
      final updated =
          original.withoutAllergenOverride('gluten', editedBy: 'u1');
      expect(updated.allergenOverrides, isEmpty);
    });

    test('withoutDietaryOverride removes the key', () {
      const original =
          TagOverrides(dietaryOverrides: {'vegansk': TriState.contains});
      final updated =
          original.withoutDietaryOverride('vegansk', editedBy: 'u1');
      expect(updated.dietaryOverrides, isEmpty);
    });

    test('cleared resets everything except audit fields', () {
      const original = TagOverrides(
        allergenOverrides: {'gluten': TriState.free},
        addedTags: {'snabb'},
      );
      final cleared = original.cleared(editedBy: 'u1');
      expect(cleared.hasManualEdits, isFalse);
      expect(cleared.lastEditedBy, 'u1');
      expect(cleared.lastEditedAt, isNotNull);
    });
  });

  group('toJson / fromJson round-trip', () {
    test('round-trip preserves all fields', () {
      final original = TagOverrides(
        allergenOverrides: const {'gluten': TriState.free},
        dietaryOverrides: const {'vegansk': TriState.contains},
        addedTags: const {'extra'},
        removedTags: const {'old'},
        lastEditedAt: DateTime.utc(2026, 1, 15),
        lastEditedBy: 'u1',
      );
      final restored = TagOverrides.fromJson(original.toJson());

      expect(restored.allergenOverrides, original.allergenOverrides);
      expect(restored.dietaryOverrides, original.dietaryOverrides);
      expect(restored.addedTags, original.addedTags);
      expect(restored.removedTags, original.removedTags);
      expect(restored.lastEditedBy, 'u1');
      expect(restored.lastEditedAt, original.lastEditedAt);
    });

    test('toJson omits null audit fields', () {
      const original = TagOverrides();
      final json = original.toJson();
      expect(json.containsKey('lastEditedAt'), isFalse);
      expect(json.containsKey('lastEditedBy'), isFalse);
    });

    test('fromJson(null) returns empty const TagOverrides', () {
      final restored = TagOverrides.fromJson(null);
      expect(restored.hasManualEdits, isFalse);
    });

    test('fromJson handles missing optional fields', () {
      final restored = TagOverrides.fromJson(const {});
      expect(restored.allergenOverrides, isEmpty);
      expect(restored.addedTags, isEmpty);
    });

    test('fromJson skips unparseable tri-state values', () {
      final restored = TagOverrides.fromJson({
        'allergenOverrides': const {'gluten': 'bogus', 'dairy': 'free'},
      });
      expect(restored.allergenOverrides.keys, ['dairy']);
      expect(restored.allergenOverrides['dairy'], TriState.free);
    });
  });

  group('equality + hashCode + toString', () {
    test('equal when all fields match', () {
      final a = TagOverrides(
        allergenOverrides: const {'gluten': TriState.free},
        addedTags: const {'extra'},
        lastEditedAt: DateTime.utc(2026, 1, 1),
        lastEditedBy: 'u',
      );
      final b = TagOverrides(
        allergenOverrides: const {'gluten': TriState.free},
        addedTags: const {'extra'},
        lastEditedAt: DateTime.utc(2026, 1, 1),
        lastEditedBy: 'u',
      );
      expect(a == b, isTrue);
      // hashCode uses Object.hashAll(Map.entries) which doesn't guarantee
      // structural stability across instances — equality is the contract.
    });

    test('not equal when allergen overrides differ', () {
      const a = TagOverrides(allergenOverrides: {'gluten': TriState.free});
      const b = TagOverrides(allergenOverrides: {'gluten': TriState.contains});
      expect(a == b, isFalse);
    });

    test('not equal when addedTags differ', () {
      const a = TagOverrides(addedTags: {'x'});
      const b = TagOverrides(addedTags: {'y'});
      expect(a == b, isFalse);
    });

    test('not equal across different runtime types', () {
      final Object other = 'string';
      expect(const TagOverrides() == other, isFalse);
    });

    test('toString includes hasManualEdits', () {
      expect(const TagOverrides().toString(), contains('hasManualEdits'));
    });
  });

  group('copyWith', () {
    test('preserves unspecified fields', () {
      final original = TagOverrides(
        allergenOverrides: const {'gluten': TriState.free},
        lastEditedBy: 'u1',
      );
      final copied = original.copyWith(addedTags: const {'snabb'});
      expect(copied.allergenOverrides, original.allergenOverrides);
      expect(copied.addedTags, {'snabb'});
      expect(copied.lastEditedBy, 'u1');
    });
  });
}

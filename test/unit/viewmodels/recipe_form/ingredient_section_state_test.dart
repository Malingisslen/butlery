/// Ingredient sections (PR #211) — the form sidecar's row model + the
/// row↔line index mapping that reorder correctness hinges on.
///
/// This is the highest-risk logic in the feature: a wrong index mapping would
/// silently move the wrong ingredient or mis-assign a section on save. The
/// reorder matrix (line up/down, heading up/down, line across a heading) is
/// pinned exhaustively.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/viewmodels/recipe_form/ingredient_section_state.dart';

RecipeIngredient ing(String raw, {String? section}) =>
    RecipeIngredient(name: raw, raw: raw, section: section);

/// Compact description of the row list for assertions: headings as "H:<label>"
/// (label read from the live controller), lines as "L".
String describe(IngredientSectionState s) => s.rows
    .map(
      (r) => switch (r) {
        HeadingRow(:final id) => 'H:${s.headingController(id).text}',
        LineRow() => 'L',
      },
    )
    .join(', ');

void main() {
  group('seedFromStructured', () {
    test('inserts one heading per contiguous section run', () {
      final s = IngredientSectionState();
      s.seedFromStructured([
        ing('5 dl vetemjöl', section: 'Deg'),
        ing('25 g jäst', section: 'Deg'),
        ing('75 g smör', section: 'Fyllning'),
      ], 3);

      expect(describe(s), 'H:Deg, L, L, H:Fyllning, L');
      addTearDown(s.dispose);
    });

    test('a trailing empty auto-add line becomes a bare line row', () {
      final s = IngredientSectionState();
      // 2 structured + 1 trailing empty line = lineCount 3.
      s.seedFromStructured([
        ing('a', section: 'Deg'),
        ing('b', section: 'Deg'),
      ], 3);
      expect(describe(s), 'H:Deg, L, L, L');
      addTearDown(s.dispose);
    });

    test('a flat recipe seeds line rows only', () {
      final s = IngredientSectionState();
      s.seedFromStructured([ing('a'), ing('b')], 2);
      expect(describe(s), 'L, L');
      addTearDown(s.dispose);
    });

    test('a recurring section after another emits a fresh heading', () {
      final s = IngredientSectionState();
      s.seedFromStructured([
        ing('a', section: 'Deg'),
        ing('b', section: 'Fyllning'),
        ing('c', section: 'Deg'),
      ], 3);
      expect(describe(s), 'H:Deg, L, H:Fyllning, L, H:Deg, L');
      addTearDown(s.dispose);
    });

    test('no lines still yields one line slot (form contract)', () {
      final s = IngredientSectionState();
      s.seedFromStructured(const [], 0);
      expect(describe(s), 'L');
      addTearDown(s.dispose);
    });
  });

  group('sectionsForValues (the single save-time derivation)', () {
    test('assigns each non-empty line its heading; empties excluded', () {
      final s = IngredientSectionState();
      s.seedFromStructured([
        ing('5 dl vetemjöl', section: 'Deg'),
        ing('25 g jäst', section: 'Deg'),
        ing('75 g smör', section: 'Fyllning'),
      ], 4); // trailing empty line

      // Values incl. the trailing empty (filtered out at save).
      final sections = s.sectionsForValues([
        '5 dl vetemjöl',
        '25 g jäst',
        '75 g smör',
        '',
      ]);
      expect(sections, ['Deg', 'Deg', 'Fyllning']);
      addTearDown(s.dispose);
    });

    test(
      'an empty line in the MIDDLE is skipped without shifting sections',
      () {
        final s = IngredientSectionState();
        s.seedFromStructured([
          ing('a', section: 'Deg'),
          ing('b', section: 'Deg'),
          ing('c', section: 'Fyllning'),
        ], 3);
        // Middle line blanked by the user.
        final sections = s.sectionsForValues(['a', '', 'c']);
        expect(sections, ['Deg', 'Fyllning']);
        addTearDown(s.dispose);
      },
    );

    test('a blank heading label yields null section (no phantom group)', () {
      final s = IngredientSectionState();
      final id = s.addHeading()!;
      s.headingController(id).text = '   ';
      s.onLineAppended();
      final sections = s.sectionsForValues(['salt']);
      expect(sections, [null]);
      addTearDown(s.dispose);
    });

    test('lines before the first heading are ungrouped (null)', () {
      final s = IngredientSectionState();
      s.seedFromStructured([
        ing('salt'),
        ing('75 g smör', section: 'Fyllning'),
      ], 2);
      expect(describe(s), 'L, H:Fyllning, L');
      expect(s.sectionsForValues(['salt', '75 g smör']), [null, 'Fyllning']);
      addTearDown(s.dispose);
    });
  });

  group('addHeading / removeHeading', () {
    test('addHeading appends and respects the 20-heading cap', () {
      final s = IngredientSectionState();
      for (var i = 0; i < IngredientSectionState.maxHeadings; i++) {
        expect(s.addHeading(), isNotNull);
      }
      expect(s.canAddHeading, isFalse);
      expect(s.addHeading(), isNull, reason: 'past the cap');
      expect(s.headingCount, IngredientSectionState.maxHeadings);
      addTearDown(s.dispose);
    });

    test('removeHeading drops the row; following lines fall to prev group', () {
      final s = IngredientSectionState();
      s.seedFromStructured([
        ing('a', section: 'Deg'),
        ing('b', section: 'Fyllning'),
      ], 2);
      final fyllningId = (s.rows[2] as HeadingRow).id;

      s.removeHeading(fyllningId);

      expect(describe(s), 'H:Deg, L, L');
      // 'b' now falls under Deg (the heading above it).
      expect(s.sectionsForValues(['a', 'b']), ['Deg', 'Deg']);
      addTearDown(s.dispose);
    });
  });

  group('line add / remove sync', () {
    test('onLineAppended adds a trailing line row', () {
      final s = IngredientSectionState();
      s.seedFromStructured([ing('a', section: 'Deg')], 1);
      s.onLineAppended();
      expect(describe(s), 'H:Deg, L, L');
      addTearDown(s.dispose);
    });

    test('onLineRemoved drops the right line row by flat index', () {
      final s = IngredientSectionState();
      s.seedFromStructured([
        ing('a', section: 'Deg'),
        ing('b', section: 'Fyllning'),
        ing('c', section: 'Fyllning'),
      ], 3); // rows: H:Deg L H:Fyllning L L  → lines 0,1,2

      s.onLineRemoved(1); // remove 'b' (the first Fyllning line)

      expect(describe(s), 'H:Deg, L, H:Fyllning, L');
      addTearDown(s.dispose);
    });
  });

  group('moveRow — the 4-way reorder matrix + line-move mapping', () {
    // Rows: H:Deg(0) L(1) L(2) H:Fyllning(3) L(4)  → line rows at 1,2,4
    IngredientSectionState seeded() {
      final s = IngredientSectionState();
      s.seedFromStructured([
        ing('m1', section: 'Deg'),
        ing('m2', section: 'Deg'),
        ing('f1', section: 'Fyllning'),
      ], 3);
      return s;
    }

    test('LINE up: last line dragged above the first line', () {
      final s = seeded();
      // Drag row 4 (line idx 2) to row 1 (above the first line).
      final move = s.moveRow(4, 1);
      expect(describe(s), 'H:Deg, L, L, L, H:Fyllning');
      expect(move, (
        from: 2,
        to: 0,
      ), reason: 'the 3rd line becomes the 1st in the flat manager');
      addTearDown(s.dispose);
    });

    test('LINE down across a heading changes its section on save', () {
      final s = seeded();
      // Drag row 1 (line idx 0, "m1" under Deg) down past Fyllning to the end.
      final move = s.moveRow(1, 5); // newIndex past end
      // m1 now sits after the Fyllning heading.
      expect(describe(s), 'H:Deg, L, H:Fyllning, L, L');
      expect(move, (from: 0, to: 2));
      // After the manager applies from:0→to:2, values become [m2, f1, m1].
      expect(s.sectionsForValues(['m2', 'f1', 'm1']), [
        'Deg',
        'Fyllning',
        'Fyllning',
      ]);
      addTearDown(s.dispose);
    });

    test(
      'LINE dragged to a heading boundary reassigns section with NO line move',
      () {
        final s = seeded();
        // Drag the 2nd Deg line (row 2, flat line idx 1, "m2") down to just
        // below the Fyllning heading — WITHOUT crossing the f1 line. Its flat
        // position is unchanged, so no manager line-move is needed, but it now
        // belongs to Fyllning. This is the positional-section invariant and the
        // moveRow `fromLine == toLine → null` branch.
        final move = s.moveRow(2, 4);
        expect(describe(s), 'H:Deg, L, H:Fyllning, L, L');
        expect(
          move,
          isNull,
          reason: 'flat line index unchanged → manager must not move a line',
        );
        // Values stay in their original flat order; only the section changes.
        expect(s.sectionsForValues(['m1', 'm2', 'f1']), [
          'Deg',
          'Fyllning',
          'Fyllning',
        ]);
        addTearDown(s.dispose);
      },
    );

    test('HEADING up: moving a heading returns null (no line move)', () {
      final s = seeded();
      // Drag Fyllning heading (row 3) above the first line (row 1).
      final move = s.moveRow(3, 1);
      expect(move, isNull, reason: 'a heading drag moves no line');
      expect(describe(s), 'H:Deg, H:Fyllning, L, L, L');
      addTearDown(s.dispose);
    });

    test('HEADING down: heading dragged to the end, still no line move', () {
      final s = seeded();
      final move = s.moveRow(0, 5); // Deg heading to end
      expect(move, isNull);
      expect(describe(s), 'L, L, H:Fyllning, L, H:Deg');
      addTearDown(s.dispose);
    });

    test('a no-op move (same position) returns null and changes nothing', () {
      final s = seeded();
      final before = describe(s);
      expect(s.moveRow(2, 2), isNull);
      expect(s.moveRow(2, 3), isNull); // adjustedTo == fromRow
      expect(describe(s), before);
      addTearDown(s.dispose);
    });

    test('out-of-range indices are ignored', () {
      final s = seeded();
      expect(s.moveRow(-1, 2), isNull);
      expect(s.moveRow(99, 2), isNull);
      addTearDown(s.dispose);
    });
  });

  group('moveLineToSection — the WCAG non-drag reassignment', () {
    // Rows: H:Deg(0) L(1) L(2) H:Fyllning(3) L(4)  → lines m1,m2,f1
    IngredientSectionState seeded() {
      final s = IngredientSectionState();
      s.seedFromStructured([
        ing('m1', section: 'Deg'),
        ing('m2', section: 'Deg'),
        ing('f1', section: 'Fyllning'),
      ], 3);
      return s;
    }

    test('moves a Deg line under Fyllning (line index shifts)', () {
      final s = seeded();
      final fyllningId = (s.rows[3] as HeadingRow).id;
      // Move m1 (row 1, line 0) under Fyllning — it lands immediately after
      // the heading, i.e. BEFORE f1 (flat line index 1).
      final move = s.moveLineToSection(1, fyllningId);
      expect(describe(s), 'H:Deg, L, H:Fyllning, L, L');
      expect(move, (from: 0, to: 1));
      // Manager applies moveAt(0→1): [m1,m2,f1] → [m2,m1,f1].
      expect(s.sectionsForValues(['m2', 'm1', 'f1']), [
        'Deg',
        'Fyllning',
        'Fyllning',
      ]);
      addTearDown(s.dispose);
    });

    test('moves a Fyllning line up under Deg', () {
      final s = seeded();
      final degId = (s.rows[0] as HeadingRow).id;
      // Move f1 (row 4, line 2) under Deg.
      final move = s.moveLineToSection(4, degId);
      expect(describe(s), 'H:Deg, L, L, L, H:Fyllning');
      expect(move, (from: 2, to: 0));
      addTearDown(s.dispose);
    });

    test('null heading ungroups the line to the top', () {
      final s = seeded();
      final move = s.moveLineToSection(4, null); // f1 → ungrouped top
      expect(describe(s), 'L, H:Deg, L, L, H:Fyllning');
      expect(move, (from: 2, to: 0));
      expect(s.sectionsForValues(['f1', 'm1', 'm2']), [null, 'Deg', 'Deg']);
      addTearDown(s.dispose);
    });

    test('a non-line row or unknown heading is ignored', () {
      final s = seeded();
      expect(s.moveLineToSection(0, 'anything'), isNull); // row 0 is a heading
      expect(s.moveLineToSection(1, 'no-such-id'), isNull);
      addTearDown(s.dispose);
    });
  });
}

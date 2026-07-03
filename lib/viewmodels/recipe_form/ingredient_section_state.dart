import 'package:flutter/widgets.dart';

import 'package:butlery/models/recipe/recipe_ingredient.dart';

/// A row in the sectioned ingredient editor. The ingredient LINE values live
/// in the shared ingredients [FormFieldsManager] (also used by instructions
/// and tags); this sidecar tracks only WHERE component headings sit in the
/// visible order and their labels. The Nth [LineRow] in [rows] corresponds to
/// the Nth value in that manager.
sealed class IngredientRow {
  const IngredientRow();
}

/// A component heading ("Deg", "Fyllning"). [id] is stable for the lifetime of
/// the row so its ValueKey and [TextEditingController] survive reorders (a
/// controller detach mid-drag would drop the user's keystrokes).
class HeadingRow extends IngredientRow {
  final String id;
  const HeadingRow(this.id);
}

/// A placeholder for "the next ingredient line" — its text and controller are
/// owned by the ingredients FormFieldsManager, matched by order.
class LineRow extends IngredientRow {
  const LineRow();
}

/// Owns the ordered heading/line row list and the heading text controllers for
/// the recipe form's sectioned ingredient editor.
///
/// Design note: sections are POSITIONAL — a line belongs to the nearest
/// heading above it. There is no per-line section field in the form; the
/// single derivation point is [sectionsForValues], called once at save. This
/// keeps the form's line storage (FormFieldsManager) unaware of sections.
class IngredientSectionState {
  final List<IngredientRow> _rows = [];
  final Map<String, TextEditingController> _headingControllers = {};
  int _headingCounter = 0;

  /// Product caps (PM): a recipe can't sprout unlimited headings, and a
  /// heading label is a short group name, not a sentence.
  static const int maxHeadings = 20;
  static const int maxHeadingLength = 60;

  List<IngredientRow> get rows => List.unmodifiable(_rows);

  int get headingCount => _rows.whereType<HeadingRow>().length;

  bool get canAddHeading => headingCount < maxHeadings;

  /// The controller backing heading [id]. Created lazily so seeding can set an
  /// initial label. Callers must not dispose it directly — [dispose] owns them.
  TextEditingController headingController(String id) =>
      _headingControllers.putIfAbsent(id, TextEditingController.new);

  /// Rebuilds the row list from a recipe's [structured] entries (index-aligned
  /// with the form's [lineCount] line values, which usually includes one
  /// trailing empty auto-add line). A heading row is inserted whenever the
  /// section changes between consecutive lines; contiguous same-section runs
  /// share one heading. Lines beyond [structured] (the trailing empty) become
  /// bare line rows under whatever heading preceded them.
  void seedFromStructured(List<RecipeIngredient> structured, int lineCount) {
    _clearControllers();
    _rows.clear();

    Object? current = _noSection;
    for (var i = 0; i < lineCount; i++) {
      final section = i < structured.length
          ? RecipeIngredient.normalizeSection(structured[i].section)
          : null;
      if (section != null && section != current) {
        final id = _newHeadingId();
        _headingControllers[id] = TextEditingController(text: section);
        _rows.add(HeadingRow(id));
      }
      // A null section after a real one resets the group so a later heading
      // re-emits; it does not itself add a heading row.
      if (section != current) current = section;
      _rows.add(const LineRow());
    }
    // A recipe with no lines still shows one line slot (matches the form's
    // "always one empty field" contract).
    if (_rows.whereType<LineRow>().isEmpty) _rows.add(const LineRow());
  }

  /// Appends a heading at the end (after the last line). No-op past the cap.
  /// Returns the new heading id, or null if capped.
  String? addHeading() {
    if (!canAddHeading) return null;
    final id = _newHeadingId();
    _headingControllers[id] = TextEditingController();
    _rows.add(HeadingRow(id));
    return id;
  }

  /// Removes heading [id]; its lines fall under the previous heading (or become
  /// ungrouped). Immediate, no confirmation (accepted degradation — a heading
  /// carries no data of its own beyond its label).
  void removeHeading(String id) {
    _rows.removeWhere((r) => r is HeadingRow && r.id == id);
    _headingControllers.remove(id)?.dispose();
  }

  /// Keeps the row list in sync when the FormFieldsManager appends a line
  /// (auto-add on typing). The new line always lands at the end.
  void onLineAppended() => _rows.add(const LineRow());

  /// Keeps the row list in sync when the FormFieldsManager removes the line at
  /// flat index [lineIndex]. Removes that line's row marker; a heading left
  /// with no following lines is harmless (produces nothing at save).
  void onLineRemoved(int lineIndex) {
    final rowIndex = _rowIndexForLine(lineIndex);
    if (rowIndex != null) _rows.removeAt(rowIndex);
  }

  /// Moves the row at [fromRow] to [toRow] (ReorderableListView semantics: when
  /// dragging down, [toRow] is the index AFTER removal). Returns the equivalent
  /// (fromLine, toLine) move to apply to the FormFieldsManager when a LINE was
  /// dragged, or null when a heading was dragged (no line move needed).
  ({int from, int to})? moveRow(int fromRow, int toRow) {
    if (fromRow < 0 || fromRow >= _rows.length) return null;
    var adjustedTo = toRow;
    if (adjustedTo > fromRow) adjustedTo--;
    if (adjustedTo < 0 || adjustedTo >= _rows.length) return null;
    if (adjustedTo == fromRow) return null;

    final moved = _rows[fromRow];
    // Line index BEFORE the move = number of line rows strictly before it.
    final fromLine = moved is LineRow ? _lineIndexOfRow(fromRow) : -1;

    _rows.removeAt(fromRow);
    _rows.insert(adjustedTo, moved);

    if (moved is! LineRow) return null;
    final toLine = _lineIndexOfRow(adjustedTo);
    if (fromLine == toLine) return null;
    return (from: fromLine, to: toLine);
  }

  /// The single section-derivation point, called once at save. Walks the rows
  /// in order tracking the current heading label, and for every NON-EMPTY line
  /// value (in flat order) records that heading. The result is index-aligned
  /// with the caller's filtered non-empty values — the same filter
  /// `RecipeFormState.createRecipe` applies — so sections and values stay in
  /// lockstep. Blank heading labels normalize to null (no phantom group).
  List<String?> sectionsForValues(List<String> values) {
    final sections = <String?>[];
    String? current;
    var lineIndex = 0;
    for (final row in _rows) {
      if (row is HeadingRow) {
        current = RecipeIngredient.normalizeSection(
          _headingControllers[row.id]?.text,
        );
      } else {
        // Only count values that survive createRecipe's non-empty filter.
        if (lineIndex < values.length && values[lineIndex].trim().isNotEmpty) {
          sections.add(current);
        }
        lineIndex++;
      }
    }
    return sections;
  }

  void dispose() {
    _clearControllers();
    _rows.clear();
  }

  // --- internals ---

  static const Object _noSection = Object();

  String _newHeadingId() => 'hdr_${_headingCounter++}';

  void _clearControllers() {
    for (final c in _headingControllers.values) {
      c.dispose();
    }
    _headingControllers.clear();
  }

  /// Flat line index of the line row at [rowIndex] = count of line rows before
  /// it. Assumes _rows[rowIndex] is a LineRow.
  int _lineIndexOfRow(int rowIndex) {
    var count = 0;
    for (var i = 0; i < rowIndex; i++) {
      if (_rows[i] is LineRow) count++;
    }
    return count;
  }

  /// Row index of the [lineIndex]-th line row, or null if out of range.
  int? _rowIndexForLine(int lineIndex) {
    var count = 0;
    for (var i = 0; i < _rows.length; i++) {
      if (_rows[i] is LineRow) {
        if (count == lineIndex) return i;
        count++;
      }
    }
    return null;
  }
}

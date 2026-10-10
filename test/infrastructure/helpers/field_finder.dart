// Finds a text field by the label a person reads on screen, whether the label
// floats inside the box (a bare TextFormField with labelText) or stands above
// it (StyledInput). The label is exact-matched, so it never collides with a
// hint such as 'Varunamn...'.

import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder fieldLabelled(String label) {
  final floating = find.ancestor(
    of: find.text(label),
    matching: find.byType(TextFormField),
  );
  final above = find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(StyledInput)),
    matching: find.byType(TextFormField),
  );
  return find.byElementPredicate(
    (e) => floating.evaluate().contains(e) || above.evaluate().contains(e),
    description: 'text field labelled "$label"',
  );
}

// Finds a text field by the label a person reads on screen, whether the label
// floats inside the box (a bare TextFormField with labelText) or stands above
// it (LabeledField). [type] is TextFormField or TextField. The label is
// exact-matched, so it never collides with a hint such as 'Varunamn...'.

import 'package:butlery/widgets/common/input/labeled_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder fieldLabelled(String label, {Type type = TextFormField}) {
  final floating = find.ancestor(
    of: find.text(label),
    matching: find.byType(type),
  );
  final above = find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(LabeledField),
    ),
    matching: find.byType(type),
  );
  return find.byElementPredicate(
    (e) => floating.evaluate().contains(e) || above.evaluate().contains(e),
    description: '$type labelled "$label"',
  );
}

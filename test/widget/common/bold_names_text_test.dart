/// A finished ARB sentence with the names it was built from set in bold.
library;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/bold_names_text.dart';

void main() {
  const bold = TextStyle(fontWeight: FontWeight.w700);

  List<(String, bool)> parts(String text, List<String> names) => [
    for (final span in boldNameSpans(text, names, bold))
      ((span as TextSpan).text!, span.style == bold),
  ];

  test('both names are bold and the words around them are kept', () {
    expect(
      parts('Erik delade menyn Snabb vardag med dig', [
        'Erik',
        'Snabb vardag',
      ]),
      [
        ('Erik', true),
        (' delade menyn ', false),
        ('Snabb vardag', true),
        (' med dig', false),
      ],
    );
  });

  test('a name that is not in the text is left out', () {
    expect(parts('Erik delade menyn', ['Erik', 'Saknas']), [
      ('Erik', true),
      (' delade menyn', false),
    ]);
  });

  test('an empty name is left out and the text stays whole', () {
    expect(parts('Erik delade menyn', ['']), [('Erik delade menyn', false)]);
  });

  test('a name that occurs twice is bold only where it first occurs', () {
    expect(parts('Ann och Ann', ['Ann']), [
      ('Ann', true),
      (' och Ann', false),
    ]);
  });

  test('a second name that sits before the first is not found again', () {
    // The names are consumed in order, so one that came earlier is gone.
    expect(parts('Snabb vardag delades av Erik', ['Erik', 'Snabb vardag']), [
      ('Snabb vardag delades av ', false),
      ('Erik', true),
    ]);
  });
}

// A screen reader hears which image a carousel dot stands for, and whether
// tapping it switches image.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/image/image_components.dart';
import 'package:butlery/widgets/image/image_config.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

Widget _dots({void Function(int)? onDotTap}) => Stack(
  children: [
    ImageComponents.buildNavigationDots(
      currentIndex: 0,
      totalImages: 3,
      config: ImageConfig.recipeCard(),
      onDotTap: onDotTap,
    ),
  ],
);

void main() {
  testWidgets('tappable dots say "Byt till bild N av M" and switch on tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    int? tapped;
    await tester.pumpWidget(
      createLocalizedTestApp(child: _dots(onDotTap: (i) => tapped = i)),
    );

    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp('^Byt till bild 2 av 3')),
    );
    expect(node.label, 'Byt till bild 2 av 3');
    expect(find.bySemanticsLabel(RegExp('^Bild ')), findsNothing);

    tester.semantics.tap(
      find.semantics.byLabel(RegExp('^Byt till bild 3 av 3')),
    );
    expect(tapped, 2);
    handle.dispose();
  });

  testWidgets('display-only dots say "Bild N av M" and are not buttons', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(createLocalizedTestApp(child: _dots()));

    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp('^Bild 2 av 3')),
    );
    expect(node.label, 'Bild 2 av 3');
    expect(node.flagsCollection.isButton, isFalse);
    expect(find.bySemanticsLabel(RegExp('^Byt till')), findsNothing);
    handle.dispose();
  });
}

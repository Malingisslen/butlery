import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/surfaces/butlery_swatch.dart';

void main() {
  testWidgets('draws a 24 px square in the colour given', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: ButlerySwatch(color: Color(0xFF3F6B4F))),
      ),
    );

    expect(
      tester.getSize(find.byType(ButlerySwatch)),
      const Size(AppDimensions.space24, AppDimensions.space24),
    );
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(ButlerySwatch),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((box.decoration as BoxDecoration).color, const Color(0xFF3F6B4F));
  });
}

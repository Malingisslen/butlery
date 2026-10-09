import 'package:butlery/widgets/common/icons/butlery_expansion_chevron.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the tile chevron is a Butlery glyph that turns with the tile', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExpansionTile(
            title: Text('Fråga'),
            trailing: ButleryExpansionChevron(),
            children: [Text('Svar')],
          ),
        ),
      ),
    );

    final icon = tester.widget<ButleryIcon>(find.byType(ButleryIcon));
    expect(icon.icon, ButleryIcons.chevronDown);
    expect(
      tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
      0,
    );

    await tester.tap(find.text('Fråga'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
      0.5,
    );
  });
}

// The root keeps the app clear of the Android navigation bar once. A bar that
// pads for the system bar below it must then see no bottom padding left, or
// the bottom menu grows by the system bar's height.

import 'package:butlery/app/butlery_app.dart';
import 'package:butlery/core/utils/accessibility_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the system bar padding is used once, and the text scale is '
      'clamped', (tester) async {
    late MediaQueryData inner;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          padding: EdgeInsets.only(top: 24, bottom: 48),
          viewPadding: EdgeInsets.only(top: 24, bottom: 48),
          textScaler: TextScaler.linear(3),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: appRootInsets(
            Builder(
              builder: (context) {
                inner = MediaQuery.of(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );

    expect(inner.padding.bottom, 0);
    // The top stays for the top bars to pad for.
    expect(inner.padding.top, 24);
    expect(
      tester.getSize(find.byType(SizedBox)).height,
      tester.getSize(find.byType(Directionality).first).height - 48,
    );
    expect(inner.textScaler.scale(1), AccessibilityUtils.maxTextScale);
  });
}

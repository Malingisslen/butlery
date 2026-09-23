/// Widget tests for AdaptiveActivityIndicator.
///
/// The widget used to draw a spinner (Cupertino on iOS, Material elsewhere).
/// B-18 forbids spinners and B-45 forbids a Cupertino branch, so every
/// constructor now draws the indeterminate plate line, on every platform.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/widgets/common/indicators/adaptive_activity_indicator.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(colorScheme: AppColors.lightColorScheme),
  home: Scaffold(
    body: Center(child: SizedBox(width: 200, child: child)),
  ),
);

void main() {
  const constructors = <String, AdaptiveActivityIndicator>{
    'default': AdaptiveActivityIndicator(),
    'small': AdaptiveActivityIndicator.small(),
    'medium': AdaptiveActivityIndicator.medium(),
    'large': AdaptiveActivityIndicator.large(),
  };

  for (final MapEntry(key: name, value: widget) in constructors.entries) {
    testWidgets('$name draws the plate line and no spinner', (tester) async {
      await tester.pumpWidget(_wrap(widget));
      expect(find.byType(PlateLine), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });
  }

  testWidgets('the line is indeterminate and carries the label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const AdaptiveActivityIndicator(semanticLabel: 'Hämtar recept')),
    );
    final line = tester.widget<PlateLine>(find.byType(PlateLine));
    expect(line.value, isNull);
    expect(line.semanticLabel, 'Hämtar recept');
  });
}

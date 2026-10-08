import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';

Widget _harness({required bool disableAnimations}) => MaterialApp(
  locale: const Locale('sv'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: const Scaffold(
      body: Center(
        child: ExpandableImageWidget(
          imageUrl: '',
          config: ImageConfig(
            type: ImageType.thumbnail,
            enableHapticFeedback: false,
          ),
        ),
      ),
    ),
  ),
);

double _scale(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.byType(ExpandableImageWidget),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .getMaxScaleOnAxis();

void main() {
  testWidgets('reduced motion: expands to its end state on the next frame', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(disableAnimations: true));
    await tester.tap(find.byType(ExpandableImageWidget));
    await tester.pump();
    expect(_scale(tester), closeTo(1.5, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('motion on: expansion is still in progress one frame in', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(disableAnimations: false));
    await tester.tap(find.byType(ExpandableImageWidget));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_scale(tester), lessThan(1.5));
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(1.5, 0.001));
  });
}

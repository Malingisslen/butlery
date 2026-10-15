// The shared frame of form-style dialogs: it caps the body at the token
// ceilings and pads it only when asked to.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog_frame.dart';

import '../../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  const bodyKey = Key('body');

  Future<Size> bodySize(
    WidgetTester tester, {
    EdgeInsetsGeometry? padding,
    double? maxHeight,
    double? maxWidth,
  }) async {
    // A viewport larger than the ceilings, so the screen is not what clamps.
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: ButleryDialogFrame(
          maxWidth: maxWidth ?? AppDimensions.dialogMaxWidthMedium,
          maxHeight: maxHeight,
          padding: padding,
          child: const SizedBox(key: bodyKey, width: 2000, height: 2000),
        ),
      ),
    );
    return tester.getSize(find.byKey(bodyKey));
  }

  testWidgets('a body wider than the ceiling is held to the width token', (
    tester,
  ) async {
    final size = await bodySize(tester);

    expect(size.width, AppDimensions.dialogMaxWidthMedium);
  });

  testWidgets('maxHeight caps the body, and without it the height is free', (
    tester,
  ) async {
    final capped = await bodySize(
      tester,
      maxHeight: AppDimensions.dialogMaxHeightSmall,
    );
    expect(capped.height, AppDimensions.dialogMaxHeightSmall);

    final free = await bodySize(tester);
    expect(free.height, greaterThan(AppDimensions.dialogMaxHeightLarge));
  });

  testWidgets('padding insets the body inside the ceiling, none adds none', (
    tester,
  ) async {
    final padded = await bodySize(
      tester,
      padding: const EdgeInsets.all(AppDimensions.space16),
    );
    expect(
      padded.width,
      AppDimensions.dialogMaxWidthMedium - 2 * AppDimensions.space16,
    );

    final bare = await bodySize(tester);
    expect(bare.width, AppDimensions.dialogMaxWidthMedium);
  });
}

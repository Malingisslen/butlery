import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

/// Canonical runner for visual golden tests in the Butlery project.
///
/// Centralises the ceremony every golden test shares:
///  * `createLocalizedTestApp` wrapping — Swedish locale, AppTheme.lightTheme,
///    all 4 localization delegates;
///  * pinned surface size + device pixel ratio of 1.0, so the same render
///    produces the same pixel grid on any OS;
///  * the default test font (Ahem) — we intentionally do *not* load the
///    app's JosefinSans / SpaceGrotesk fonts so glyphs stay deterministic
///    across platforms without a CI-vs-local split;
///  * silenced FlutterError during render — protects goldens from asset-
///    load / network-image error bleed that doesn't affect the pixel output.
///
/// Update goldens with `flutter test --update-goldens test/widget/golden`.
///
/// Usage:
/// ```dart
/// butleryGolden(
///   'empty state matches golden',
///   file: 'goldens/state_widget_empty.png',
///   build: () => StateWidget.empty(...),
/// );
/// ```
///
/// For goldens that target a specific widget (not the outer SizedBox) pass
/// `target: find.byType(ContentCard)` and a `width` only (height becomes
/// intrinsic so the widget sizes itself).
@isTest
void butleryGolden(
  String description, {
  required Widget Function() build,
  required String file,
  double width = 375,
  double? height = 400,
  Finder? target,
}) {
  testWidgets(description, (tester) async {
    final surfaceWidth = width;
    final surfaceHeight = height ?? 800; // tall enough for intrinsic layouts

    final previousSize = tester.view.physicalSize;
    final previousRatio = tester.view.devicePixelRatio;
    tester.view.physicalSize = Size(surfaceWidth, surfaceHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = previousSize;
      tester.view.devicePixelRatio = previousRatio;
    });

    final child = height == null
        ? SizedBox(width: width, child: build())
        : SizedBox(width: width, height: height, child: build());

    await tester.pumpWidget(createLocalizedTestApp(child: child));

    // Don't let stray asset-load errors fail a golden render.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = previousOnError);

    await expectLater(
      target ?? find.byType(SizedBox).first,
      matchesGoldenFile(file),
    );
  });
}

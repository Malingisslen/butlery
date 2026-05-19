import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

/// Installs a method-channel stub for path_provider so widgets that use
/// flutter_cache_manager (CachedNetworkImage, etc.) can resolve a temp dir
/// during render — otherwise DefaultCacheManager throws inside
/// IOFileSystem.createDirectory and bubbles up as a pending exception that
/// `FlutterError.onError = (_) {}` can't swallow (async / outside the zone).
void _installPathProviderStub() {
  final tempDir = Directory.systemTemp.createTempSync('butlery_golden_cache');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      // The cache manager only needs a writable path — same temp dir for
      // every documented method keeps things simple.
      return tempDir.path;
    },
  );
}

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
    _installPathProviderStub();

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

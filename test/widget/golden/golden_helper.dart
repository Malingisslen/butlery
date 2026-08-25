import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

/// Installs method-channel stubs that widgets using flutter_cache_manager
/// (CachedNetworkImage, etc.) hit during render:
///   * path_provider — returns a real temp dir so DefaultCacheManager's
///     IOFileSystem.createDirectory call doesn't throw;
///   * com.tekartik.sqflite — returns no-op responses so CacheStore can
///     "open" its database and "read" zero rows. On macOS runners the
///     sqflite native plugin isn't initialised in widget-test mode and
///     the call surfaces an unhandled exception that bypasses
///     `FlutterError.onError`.
/// In both cases the goal is to let the cache pipeline proceed all the way
/// to "we don't have this image cached, place placeholder/errorWidget" —
/// which is what the golden actually captures.
void _installCacheStubs() {
  final tempDir = Directory.systemTemp.createTempSync('butlery_golden_cache');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => tempDir.path,
  );

  messenger.setMockMethodCallHandler(
    const MethodChannel('com.tekartik.sqflite'),
    (call) async {
      switch (call.method) {
        case 'openDatabase':
          return 1; // database handle id; any int will do
        case 'query':
          return <Map<String, Object?>>[];
        case 'getDatabasesPath':
          return tempDir.path;
        default:
          return null;
      }
    },
  );
}

/// The `FlutterErrorDetails.library` stamped on a failed image load. It is the only error class a golden is
/// allowed to ignore: the placeholder or errorWidget that replaces the image
/// is what the golden captures, so the load failure itself changes nothing.
const _imageErrorLibrary = 'image resource service';

/// Swallows failed-image-load reports and hands every other error back to the
/// test binding. Returns the handler it replaced, so the caller can restore it.
///
/// Why this is a filter and not `FlutterError.onError = (_) {}`: a golden
/// comparison reports its verdict as a thrown error, not as a return value.
/// `matchesGoldenFile` runs the comparator inside `binding.runAsync`, which
/// catches whatever the comparator throws, routes it to `FlutterError.onError`
/// and completes with `null` — and `null` is the matcher's word for "matched".
/// A handler that drops everything therefore turns every pixel mismatch and
/// every wrong-size render into a passing test, while still writing the diff
/// images to `failures/`. `golden_helper_redness_test`
/// pins both halves of this filter.
void Function(FlutterErrorDetails)? installGoldenImageErrorFilter() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.library == _imageErrorLibrary) {
      return;
    }
    (previous ?? FlutterError.presentError)(details);
  };
  return previous;
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
///  * an image-error filter around the comparison — drops asset-load /
///    network-image noise that doesn't affect the pixel output, and lets
///    everything else through so a real mismatch still fails the test.
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
    _installCacheStubs();

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

    final previousOnError = installGoldenImageErrorFilter();
    addTearDown(() => FlutterError.onError = previousOnError);

    await expectLater(
      target ?? find.byType(SizedBox).first,
      matchesGoldenFile(file),
    );
  });
}

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

/// Whether this host is the one the committed PNGs were rendered on.
///
/// Pixel goldens are NOT portable, which `butleryGolden` below used to claim
/// they were. Until BUT-1931 the comparison was silenced by a blanket
/// `FlutterError.onError`, so every mismatch reported a pass and no measurement
/// of this could exist. Taken once it started working, 2026-08-25/26: every
/// comparison passed on Windows, most differed on ubuntu by 0.16-0.86 %, and
/// most of those that ran on macOS differed by up to
/// 3.90 %. Same code, same PNGs, so the platform is the whole variable; the
/// macOS spread is also why a percentage tolerance is not the answer instead
/// of a pin.
///
/// Windows is the pin because that is where the PNGs are authored. Two things
/// still compare them, and NEITHER is the commit gate — `lefthook.yml` runs no
/// Flutter test at all, and the verify skill's mapping does not route a widget
/// edit to that widget's golden:
///  * any local `flutter test` run that covers these directories;
///  * the nightly `widget (windows-latest)` leg of the cross-OS matrix, which
///    does not skip and is a different machine from the authoring one — it
///    passed against the committed set on 2026-08-26 (run 32930327481), which
///    is what makes the pin a real check rather than a local habit.
///
/// Everywhere else CI reports these as skipped instead of as passed, which is
/// the honest version of what it was already doing.
///
/// Moving the pin means regenerating every committed PNG on the new platform
/// and verifying each one by eye. Do not regenerate on one platform while
/// comparing on another: that only moves the red.
bool get _goldensCompareHere => Platform.isWindows;

/// The same pin, reachable from a golden that cannot run through
/// [butleryGolden] because it needs providers in scope that the helper's own
/// `MaterialApp` does not carry (BUT-1978). An alias rather than a rename: the
/// goldens that DO go through the helper keep reading the private getter, so
/// their behaviour is untouched by exposing it.
bool get goldensCompareHere => _goldensCompareHere;

/// Canonical runner for visual golden tests in the Butlery project.
///
/// Centralises the ceremony every golden test shares:
///  * `createLocalizedTestApp` wrapping — Swedish locale, AppTheme.lightTheme,
///    all 4 localization delegates;
///  * pinned surface size + device pixel ratio of 1.0, so a given widget
///    always lands on the same pixel grid;
///  * the default test font (Ahem) rather than the app's JosefinSans /
///    SpaceGrotesk, so glyph shapes don't depend on which fonts resolved;
///  * an image-error filter around the comparison — drops asset-load /
///    network-image noise that doesn't affect the pixel output, and lets
///    everything else through so a real mismatch still fails the test;
///  * the comparison itself pinned to one platform — see [_goldensCompareHere].
///
/// Update goldens on the pinned platform with
/// `flutter test --update-goldens test/widget/golden
/// test/widget/common/tappable_wrapper_test.dart`. Both paths are needed: a
/// `butleryGolden` lives outside `test/widget/golden`, so the shorter command
/// does not reach it. `test/widget/menu` holds a further golden that does not
/// run through [butleryGolden] and carries its own update instruction.
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
  }, skip: !_goldensCompareHere);
}

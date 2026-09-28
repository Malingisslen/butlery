/// P8-U04: the Linux pin for the key-screen goldens.
///
/// Pixel goldens are not portable (test/widget/golden/golden_helper.dart:
/// 77-110 measured 0.16-0.86 % on ubuntu and up to 3.90 % on macOS against
/// PNGs made on Windows). These PNGs are made on Linux, by the
/// goldens-linux-update workflow, and compared on Linux only: the views
/// (ubuntu) job is where they are checked. On any other platform the tests
/// report as skipped, and --update-goldens refuses to run, so a PNG is never
/// regenerated on one platform and compared on another.
///
/// The ten Windows-pinned PNGs and golden_helper.dart are not touched.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../widget/golden/golden_helper.dart'
    show installGoldenImageErrorFilter;
import '../design_states/state_harness.dart';

/// Where the Linux PNGs live, from the package root.
const linuxGoldenDir = 'test/views/golden_linux/goldens';

/// No PNGs committed yet, and this is not the run that makes them.
///
/// The PNGs can only be made by the goldens-linux-update workflow, and
/// GitHub runs a workflow_dispatch workflow only once its file is on the
/// default branch. Until the PNGs are committed (NY-P8-18) the comparison
/// is skipped rather than failing views (ubuntu) on files that cannot exist
/// yet. Once goldens/ exists, a missing or changed PNG fails as usual.
bool get linuxBaselinesMissing =>
    !autoUpdateGoldenFiles && !Directory(linuxGoldenDir).existsSync();

/// Whether this host compares (and may write) the Linux PNGs.
bool get linuxGoldensCompareHere => Platform.isLinux && !linuxBaselinesMissing;

/// BUTLERY_GOLDEN_SMOKE=1: pump the key screens off Linux without taking
/// or comparing a picture, to see locally that every host still builds.
bool get goldenSmokeRun => Platform.environment['BUTLERY_GOLDEN_SMOKE'] == '1';

/// Refuses --update-goldens anywhere but Linux.
void refuseUpdateOffLinux() {
  if (autoUpdateGoldenFiles && !Platform.isLinux) {
    throw StateError(
      'The key-screen goldens are made on Linux only. Run the '
      'goldens-linux-update workflow instead of --update-goldens on '
      '${Platform.operatingSystem}.',
    );
  }
}

/// Loads the fonts the screens draw with: ButlerySans (pubspec.yaml) and
/// the Material icon font the framework ships, so a PNG shows glyphs and
/// not the test font's boxes.
Future<void> loadGoldenFonts() async {
  await loadButlerySans();
  // The icon font is vendored with the tests (test/fixtures/fonts, Apache
  // 2.0, licence alongside) so a golden never depends on what a runner's
  // Flutter cache happens to hold: ubuntu-latest's hosted Flutter had no
  // material_fonts artifact and failed the first render. The SDK copy is
  // only the fallback.
  final vendored = File('test/fixtures/fonts/materialicons-regular.otf');
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = vendored.existsSync()
      ? vendored
      : root == null
      ? null
      : File(
          '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        );
  if (icons == null || !icons.existsSync()) {
    if (linuxGoldensCompareHere) {
      throw StateError(
        'MaterialIcons not found in test/fixtures/fonts or under '
        'FLUTTER_ROOT=$root',
      );
    }
    return;
  }
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
  await loader.load();
}

/// Compares the whole screen with [file], with the approved image-error
/// filter around the comparison (BUT-1946; golden_helper.dart:66).
Future<void> expectScreenGolden(String file) async {
  final previous = installGoldenImageErrorFilter();
  try {
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(file));
  } finally {
    FlutterError.onError = previous;
  }
}

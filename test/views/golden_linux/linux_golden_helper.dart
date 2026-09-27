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

/// Whether this host compares (and may write) the Linux PNGs.
bool get linuxGoldensCompareHere => Platform.isLinux;

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
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = root == null
      ? null
      : File(
          '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        );
  if (icons == null || !icons.existsSync()) {
    if (linuxGoldensCompareHere) {
      throw StateError('MaterialIcons not found under FLUTTER_ROOT=$root');
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

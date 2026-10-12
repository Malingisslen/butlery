/// The two buttons that start a picture import: each asks for its own source,
/// and both go quiet together while a picture is being read.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/buttons/image_source_buttons.dart';

void main() {
  Widget host({VoidCallback? onCamera, VoidCallback? onLibrary}) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: ImageSourceButtons(
        cameraLabel: 'Fota nu',
        libraryLabel: 'Ur bildbiblioteket',
        onCamera: onCamera,
        onLibrary: onLibrary,
      ),
    ),
  );

  testWidgets('each button runs only its own action', (tester) async {
    var camera = 0;
    var library = 0;
    await tester.pumpWidget(
      host(onCamera: () => camera++, onLibrary: () => library++),
    );

    await tester.tap(find.text('Fota nu'));
    expect(camera, 1);
    expect(library, 0);

    await tester.tap(find.text('Ur bildbiblioteket'));
    expect(camera, 1);
    expect(library, 1);
  });

  testWidgets('without actions neither button reports itself as enabled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host());

    for (final label in ['Fota nu', 'Ur bildbiblioteket']) {
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      expect(
        node.flagsCollection.isEnabled,
        Tristate.isFalse,
        reason: label,
      );
    }
    handle.dispose();
  });
}

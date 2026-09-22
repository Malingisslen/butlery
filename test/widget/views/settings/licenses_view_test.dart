// LicensesView is the OFL 1.1 condition 2 surface for the bundled fonts: the
// copyright notices and the licence must reach whoever receives a font. The
// view reads each document from the bundle, so these tests compare what it
// renders against the files on disk — a view that paraphrased, truncated or
// dropped a document would fail here, and so would a pubspec that stopped
// bundling one.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/views/settings/licenses_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  const assetChannel = 'flutter/assets';
  late TestDefaultBinaryMessenger messenger;

  setUp(() {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    rootBundle.clear();
  });

  tearDown(() {
    messenger.setMockMessageHandler(assetChannel, null);
    rootBundle.clear();
  });

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const LicensesView(),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String?> renderedDocuments(WidgetTester tester) => tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .map((t) => t.data)
      .toList();

  group('LicensesView', () {
    testWidgets('renders every bundled document verbatim, notices first', (
      tester,
    ) async {
      final sv = AppLocalizationsSv();
      await pumpView(tester);

      expect(
        renderedDocuments(tester),
        LicensesView.assets.map((a) => File(a).readAsStringSync()).toList(),
      );
      expect(LicensesView.assets.first, LicensesView.noticesAsset);
      for (final heading in [
        sv.licensesNoticesHeading,
        sv.licensesOflHeading,
        'Josefin Sans',
        'Space Grotesk',
      ]) {
        expect(find.text(heading), findsOneWidget);
      }
    });

    testWidgets('every font family in pubspec has its licence on the page', (
      tester,
    ) async {
      // A family added to `fonts:` without its licence here would ship
      // without the text OFL condition 2 requires.
      final families = RegExp(r'^    - family: (\w+)$', multiLine: true)
          .allMatches(File('pubspec.yaml').readAsStringSync())
          .map((m) => m.group(1))
          .toList();
      expect(families, ['ButlerySans', 'JosefinSans', 'SpaceGrotesk']);
      expect(LicensesView.assets, contains(LicensesView.oflAsset));
      expect(LicensesView.assets, contains(LicensesView.josefinSansAsset));
      expect(LicensesView.assets, contains(LicensesView.spaceGroteskAsset));
    });

    testWidgets('shows the error copy, and retry recovers once the bundle '
        'is back', (tester) async {
      final sv = AppLocalizationsSv();
      // Removing a mock handler also removes the test binding's own asset
      // handler, so the "bundle is back" half serves the files from disk.
      var bundleBroken = true;
      messenger.setMockMessageHandler(assetChannel, (ByteData? message) async {
        if (bundleBroken) return null;
        final key = utf8.decode(message!.buffer.asUint8List());
        final bytes = File(Uri.decodeFull(key)).readAsBytesSync();
        return ByteData.sublistView(bytes);
      });

      await pumpView(tester);

      expect(find.text(sv.licensesCouldNotLoad), findsOneWidget);
      expect(find.text(sv.commonRetry), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);

      bundleBroken = false;
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(find.text(sv.licensesCouldNotLoad), findsNothing);
      expect(
        renderedDocuments(tester),
        LicensesView.assets.map((a) => File(a).readAsStringSync()).toList(),
      );
    });
  });
}

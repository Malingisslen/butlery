/// The Inköp and Veckomeny root bars leave the title and its line whole on a
/// 320 and a 360 dp phone (P4-U09, P4-U10).
///
/// Skarmar v12 del 2 #inkop draws one outlined "more" button on the root bar;
/// del 1 #veckomeny draws none. Five 48 dp icons left "Inköp" about 0-32 dp,
/// so the secondary actions moved into one overflow menu. Veckomeny keeps the
/// group-week icon beside it.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';

const _titleKey = ValueKey('butleryTopBar.title');
const _secondaryKey = ValueKey('butleryTopBar.secondaryLine');

RenderParagraph _paragraph(WidgetTester tester, Key key) {
  final finder = find.descendant(
    of: find.byKey(key),
    matching: find.byType(RichText),
  );
  return tester.renderObject<RenderParagraph>(
    finder.evaluate().isEmpty ? find.byKey(key) : finder,
  );
}

void _expectWhole(WidgetTester tester, Key key) {
  final p = _paragraph(tester, key);
  expect(p.didExceedMaxLines, isFalse, reason: '$key is cut');
  expect(
    p.size.width + 0.5,
    greaterThanOrEqualTo(p.getMaxIntrinsicWidth(double.infinity)),
    reason: '$key wraps inside its text',
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required String title,
  required String line,
  required List<Widget> actions,
  bool dark = false,
}) async {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(
        appBar: ButleryTopBar.rot(
          title: title,
          secondaryLine: line,
          actions: actions,
        ),
      ),
    ),
  );
  await tester.pump();
}

Widget _more() => PopupMenuButton<int>(
  icon: const Icon(Icons.more_vert),
  itemBuilder: (_) => const [PopupMenuItem(value: 0, child: Text('x'))],
);

/// The test font draws every glyph one em wide, which is far wider than
/// ButlerySans, so the measure loads the real family (pubspec.yaml fonts).
Future<void> _loadButlerySans() async {
  final loader = FontLoader('ButlerySans');
  for (final face in ['Regular', 'Semibold', 'Bold']) {
    final bytes = File(
      'assets/fonts/ButlerySans-0.626-$face.ttf',
    ).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadButlerySans);

  for (final width in [320.0, 360.0]) {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('Inköp and its count line are whole at $width dp ($mode)', (
        tester,
      ) async {
        await _pump(
          tester,
          width: width,
          title: 'Inköp',
          line: 'Veckans inköp · 4 av 16 klara',
          actions: [_more()],
          dark: dark,
        );
        _expectWhole(tester, _titleKey);
        _expectWhole(tester, _secondaryKey);
      });

      testWidgets('Veckomeny and its week line are whole at $width dp '
          '($mode)', (tester) async {
        await _pump(
          tester,
          width: width,
          title: 'Veckomeny',
          line: 'Vecka 28 · inget planerat',
          actions: [
            IconButton(
              icon: const Icon(Icons.groups_outlined),
              onPressed: () {},
            ),
            _more(),
          ],
          dark: dark,
        );
        _expectWhole(tester, _titleKey);
        _expectWhole(tester, _secondaryKey);
      });
    }
  }

  test('the root bars carry these actions and no more', () {
    String code(String path) =>
        File(path).readAsStringSync().replaceAll(RegExp(r'//.*'), '');

    final shopping = code(
      'lib/views/unified_shopping/widgets/shopping_app_bar.dart',
    );
    final header = shopping.substring(
      shopping.indexOf('static List<Widget> buildHeaderActions('),
      shopping.indexOf('static Widget buildFloatingActionButton('),
    );
    expect(RegExp(r'PopupMenuButton<').allMatches(header).length, 1);
    expect(RegExp(r'[^\w]IconButton\(').hasMatch(header), isFalse);

    final week = code('lib/views/veckomeny_view.dart');
    final weekHeader = week.substring(
      week.indexOf('List<Widget> _buildHeaderActions('),
      week.indexOf('ButleryMenuItem<_VeckomenyRootAction> _rootItem('),
    );
    expect(RegExp(r'PopupMenuButton<').allMatches(weekHeader).length, 1);
    expect(RegExp(r'[^\w]IconButton\(').hasMatch(weekHeader), isFalse);
    expect(weekHeader.contains('GroupMenuEntryButton()'), isTrue);
  });

  test('"Från veckomenyn" opens the Meny tab, never a second shell', () {
    final code = File(
      'lib/views/unified_shopping/widgets/shopping_list_content.dart',
    ).readAsStringSync().replaceAll(RegExp(r'//.*'), '');
    expect(code.contains('Routes.weeklyMenu'), isFalse);
    expect(code.contains('mainTabSwitchRequest.value = 1'), isTrue);
  });
}

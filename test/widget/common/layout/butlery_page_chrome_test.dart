/// The page template's chrome (P4-U02).
///
/// The bar's side margin is tokens.json space.layoutMargin, so the title and
/// the content below share a left edge (Q-P4-14). Grafisk manual v6:582:
/// sticky layers never cover the focused element.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: home,
);

void _setSize(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A root page that pushes [page], so the subpage has somewhere to go back.
Widget _pusher(Widget page) => Builder(
  builder: (context) => Scaffold(
    body: TextButton(
      onPressed: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
      child: const Text('open'),
    ),
  ),
);

Future<void> _open(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(_app(_pusher(page)));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('ButleryPage actions', () {
    testWidgets('draws the subpage top bar with its actions', (tester) async {
      await _open(
        tester,
        ButleryPage.undersida(
          title: 'Vänner',
          actions: [
            IconButton(
              tooltip: 'Sök',
              icon: const ButleryIcon(ButleryIcons.search),
              onPressed: () {},
            ),
          ],
          body: const SizedBox(),
        ),
      );
      final bar = tester.widget<ButleryTopBar>(find.byType(ButleryTopBar));
      expect(bar.pattern, ButleryTopBarPattern.undersida);
      expect(find.byTooltip('Tillbaka'), findsOneWidget);
      expect(find.byTooltip('Sök'), findsOneWidget);
    });
  });

  group('the top bar margin is space.layoutMargin (Q-P4-14)', () {
    for (final (width, margin) in [
      (320.0, AppDimensions.layoutMarginNarrow),
      (400.0, AppDimensions.layoutMargin),
    ]) {
      testWidgets('title and content share a left edge at $width dp', (
        tester,
      ) async {
        _setSize(tester, Size(width, 800));
        await tester.pumpWidget(
          _app(
            Scaffold(
              appBar: const ButleryTopBar.rot(title: 'Inköp'),
              body: Padding(
                padding: EdgeInsets.symmetric(horizontal: margin),
                child: const Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Text('Mjölk'),
                ),
              ),
            ),
          ),
        );
        final title = tester.getRect(
          find.byKey(const ValueKey('butleryTopBar.title')),
        );
        final content = tester.getRect(find.text('Mjölk'));
        expect(title.left, margin);
        expect(content.left, title.left);
        expect(
          ButleryTopBar.sideMargin(tester.element(find.text('Mjölk'))),
          margin,
        );
      });
    }
  });

  testWidgets('the bottom navigation never covers a focused field', (
    tester,
  ) async {
    _setSize(tester, const Size(400, 800));
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      _app(
        ButleryPage.undersida(
          title: 'Anteckning',
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 1200),
                TextField(focusNode: node),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    node.requestFocus();
    await tester.pumpAndSettle();

    final field = tester.getRect(find.byType(TextField));
    final navTop = tester.getRect(find.byType(ButleryBottomNavigation)).top;
    expect(field.bottom, lessThanOrEqualTo(navTop));
    expect(field.top, greaterThanOrEqualTo(0));
  });
}

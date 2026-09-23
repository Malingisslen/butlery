/// P4-U18: the shared-component defects phase 2 found, closed.
///
/// * ButleryTab reports Material's own tab height, so a tab with an icon
///   above its label gets the 72 dp Material draws, not 48.
/// * A TextButton among the subpage top bar's actions takes the bar's
///   foreground: paper on surface.ink (Komponentark v1:73), never ink on ink.
/// * The selected tab carries the 3 px saffron plate line (Komponentark
///   v1:106-112; tokens.json:165-168 progressIndicator), visible on the dark
///   page too.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/components/navigation_themes.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';

final _boundaryKey = GlobalKey();

Widget _app(Widget home, {required ThemeData theme}) => RepaintBoundary(
  key: _boundaryKey,
  child: MaterialApp(
    theme: theme,
    locale: const Locale('sv'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

Future<Color> _pixel(WidgetTester tester, Offset at) async {
  final boundary =
      _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    image.dispose();
    return (data!, width);
  });
  final (ByteData data, int width) = bytes!;
  final i = (at.dy.floor() * width + at.dx.floor()) * 4;
  return Color.fromARGB(
    data.getUint8(i + 3),
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
  );
}

Color _textColor(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)),
  );
  return rich.text.style!.color!;
}

void main() {
  group('ButleryTab.preferredSize', () {
    test('a label or an icon alone reserves the 48 dp target', () {
      expect(const ButleryTab(text: 'Flöde').preferredSize.height, 48);
      expect(
        const ButleryTab(icon: Icon(Icons.people)).preferredSize.height,
        48,
      );
    });

    test('an icon above a label reserves the 72 dp Material draws', () {
      expect(
        const ButleryTab(
          text: 'Vänner',
          icon: Icon(Icons.people),
        ).preferredSize.height,
        72,
      );
    });

    testWidgets('a TabBar of icon-and-label tabs fits its tabs', (
      tester,
    ) async {
      const tabs = [
        ButleryTab(text: 'Flöde', icon: Icon(Icons.dynamic_feed)),
        ButleryTab(text: 'Vänner', icon: Icon(Icons.people)),
      ];
      final bar = TabBar(tabs: tabs);
      expect(bar.preferredSize.height, greaterThanOrEqualTo(72));
      await tester.pumpWidget(
        _app(
          DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: PreferredSize(
                preferredSize: bar.preferredSize,
                child: Material(child: bar),
              ),
            ),
          ),
          theme: AppTheme.lightTheme,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(TabBar)).height,
        bar.preferredSize.height,
      );
    });
  });

  group('ButleryTopBar actions', () {
    for (final (mode, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('$mode: a TextButton on the subpage bar is paper', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            Scaffold(
              appBar: ButleryTopBar.undersida(
                title: 'Receptet',
                actions: [
                  TextButton(onPressed: () {}, child: const Text('Spara')),
                ],
              ),
            ),
            theme: theme,
          ),
        );
        // Paper #F5F4ED on surface.ink #24382C in both modes
        // (Komponentark v1:73).
        expect(_textColor(tester, 'Spara'), AppColors.textOnPrimary);
        expect(AppColorsDark.textOnPrimary, AppColors.textOnPrimary);
      });

      testWidgets('$mode: a TextButton on the root bar is text.primary', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            Scaffold(
              appBar: ButleryTopBar.rot(
                title: 'Inköp',
                actions: [
                  TextButton(onPressed: () {}, child: const Text('Rensa')),
                ],
              ),
            ),
            theme: theme,
          ),
        );
        expect(_textColor(tester, 'Rensa'), theme.colorScheme.onSurface);
      });

      testWidgets('$mode: a disabled TextButton keeps the app colour', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            const Scaffold(
              appBar: ButleryTopBar.undersida(
                title: 'Receptet',
                actions: [TextButton(onPressed: null, child: Text('Spara'))],
              ),
            ),
            theme: theme,
          ),
        );
        final base = theme.textButtonTheme.style!.foregroundColor!.resolve({
          WidgetState.disabled,
        });
        expect(_textColor(tester, 'Spara'), base);
      });
    }
  });

  group('the tab plate line', () {
    for (final (mode, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('$mode: saffron under the selected word', (tester) async {
        await tester.pumpWidget(
          _app(
            DefaultTabController(
              length: 2,
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 320,
                    child: TabBar(
                      tabs: const [
                        ButleryTab(text: 'Flöde'),
                        ButleryTab(text: 'Vänner'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();
        final label = tester.getRect(find.byType(ButleryTab).first);
        final bar = tester.getRect(find.byType(TabBar));
        // The line lies on the bar's bottom edge, under the label's centre.
        final at = Offset(
          label.center.dx,
          bar.bottom - NavigationThemes.tabPlateLineHeight / 2,
        );
        expect(await _pixel(tester, at), const Color(0xFFCE7C1E));
        // And 5 px past the word's edge (Komponentark v1:106).
        final edge = Offset(
          label.left - NavigationThemes.tabPlateLineOverhang + 1.5,
          at.dy,
        );
        expect(await _pixel(tester, edge), const Color(0xFFCE7C1E));
      });
    }
  });
}

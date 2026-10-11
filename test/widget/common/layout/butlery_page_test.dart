/// Contract of the shared page template (BUT-2368): which top-bar pattern a
/// page draws, how wide its column may grow, where the column stands and what
/// side margin the content takes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

const _fill = SizedBox(
  key: ValueKey('fill'),
  width: double.infinity,
  height: 10,
);

void _setWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpBody(
  WidgetTester tester,
  double screenWidth,
  PageWidth width, {
  TextDirection direction = TextDirection.ltr,
}) async {
  _setWidth(tester, screenWidth);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: Size(screenWidth, 900)),
      child: Directionality(
        textDirection: direction,
        child: ButleryPageBody(width: width, child: _fill),
      ),
    ),
  );
}

void main() {
  group('ButleryPage top bar', () {
    Future<void> pushPage(WidgetTester tester, ButleryPage page) async {
      await tester.pumpWidget(createLocalizedTestApp(child: const SizedBox()));
      Navigator.of(tester.element(find.byType(Scaffold))).push(
        MaterialPageRoute<void>(builder: (_) => page),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('undersida draws the subpage bar and names where Back goes', (
      tester,
    ) async {
      await pushPage(
        tester,
        const ButleryPage.undersida(
          title: 'Aviseringar',
          backTo: 'Mer',
          body: SizedBox(),
        ),
      );

      final bar = tester.widget<ButleryTopBar>(find.byType(ButleryTopBar));
      expect(bar.pattern, ButleryTopBarPattern.undersida);
      expect(find.text('Aviseringar'), findsOneWidget);
      expect(find.byTooltip('Tillbaka till Mer'), findsOneWidget);
    });

    testWidgets('undersida without backTo keeps the plain Back name', (
      tester,
    ) async {
      await pushPage(
        tester,
        const ButleryPage.undersida(title: 'Aviseringar', body: SizedBox()),
      );

      expect(find.byTooltip('Tillbaka'), findsOneWidget);
    });

    testWidgets('rot draws the root bar and never a back arrow', (
      tester,
    ) async {
      await pushPage(
        tester,
        const ButleryPage.rot(title: 'Hem', body: SizedBox()),
      );

      final bar = tester.widget<ButleryTopBar>(find.byType(ButleryTopBar));
      expect(bar.pattern, ButleryTopBarPattern.rot);
      expect(find.byKey(const ValueKey('butleryTopBar.back')), findsNothing);
    });

    testWidgets('the page hands its width to the column', (tester) async {
      _setWidth(tester, 1300);
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const ButleryPage.rot(
            title: 'Hem',
            width: PageWidth.compact,
            body: _fill,
          ),
        ),
      );

      expect(tester.getSize(find.byKey(const ValueKey('fill'))).width, 480);
    });
  });

  group('ButleryPageBody column width', () {
    testWidgets('compact stops at 480 on a tablet and on a desktop', (
      tester,
    ) async {
      for (final screen in [900.0, 1300.0]) {
        await _pumpBody(tester, screen, PageWidth.compact);
        expect(
          tester.getSize(find.byKey(const ValueKey('fill'))).width,
          480,
          reason: 'screen $screen',
        );
      }
    });

    testWidgets('text stops at 600 on a tablet and on a desktop', (
      tester,
    ) async {
      for (final screen in [900.0, 1300.0]) {
        await _pumpBody(tester, screen, PageWidth.text);
        expect(
          tester.getSize(find.byKey(const ValueKey('fill'))).width,
          600,
          reason: 'screen $screen',
        );
      }
    });

    testWidgets('wide follows getMaxContentWidth per breakpoint', (
      tester,
    ) async {
      late double expectedTablet;
      late double expectedDesktop;
      for (final screen in [900.0, 1300.0]) {
        await _pumpBody(tester, screen, PageWidth.wide);
        final expected = Breakpoints.getMaxContentWidth(
          tester.element(find.byKey(const ValueKey('fill'))),
        );
        if (screen == 900) expectedTablet = expected;
        if (screen == 1300) expectedDesktop = expected;
        expect(
          tester.getSize(find.byKey(const ValueKey('fill'))).width,
          expected,
        );
      }
      // The two screens must resolve to different caps, or this proves nothing.
      expect(expectedTablet, lessThan(expectedDesktop));
      expect(expectedTablet, lessThan(900));
    });

    testWidgets('a phone narrower than the cap gets the whole width', (
      tester,
    ) async {
      await _pumpBody(tester, 400, PageWidth.text);
      expect(tester.getSize(find.byKey(const ValueKey('fill'))).width, 400);
    });

    testWidgets('the column stands at the start edge, in both directions', (
      tester,
    ) async {
      await _pumpBody(tester, 1300, PageWidth.text);
      expect(tester.getTopLeft(find.byKey(const ValueKey('fill'))).dx, 0);

      await _pumpBody(
        tester,
        1300,
        PageWidth.text,
        direction: TextDirection.rtl,
      );
      expect(tester.getTopRight(find.byKey(const ValueKey('fill'))).dx, 1300);
    });
  });

  group('ButleryPageBody.margin', () {
    Future<EdgeInsetsDirectional> marginAt(
      WidgetTester tester,
      double screenWidth,
    ) async {
      late EdgeInsetsDirectional result;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: Size(screenWidth, 800)),
          child: Builder(
            builder: (context) {
              result = ButleryPageBody.margin(context, top: 3, bottom: 5);
              return const SizedBox();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('is 20 below 360 dp and 24 from 360', (tester) async {
      for (final entry in {
        320.0: 20.0,
        359.0: 20.0,
        360.0: 24.0,
        430.0: 24.0,
      }.entries) {
        final m = await marginAt(tester, entry.key);
        expect(m.start, entry.value, reason: 'width ${entry.key}');
        expect(m.end, entry.value, reason: 'width ${entry.key}');
      }
    });

    testWidgets('keeps top and bottom as given', (tester) async {
      final m = await marginAt(tester, 400);
      expect(m.top, 3);
      expect(m.bottom, 5);
    });
  });
}

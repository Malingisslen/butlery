/// Unit tests for Breakpoints + DeviceCategoryExtension.
///
/// The width-based static methods and DeviceCategoryExtension don't
/// need a BuildContext, so they're tested as pure functions. The
/// context-aware methods (isMobile/isTablet/isDesktop, valueFor,
/// getDeviceCategory, layout-helper getters) are exercised through
/// widget tests with a sized MediaQuery.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/responsive/breakpoints.dart';

Widget _atWidth(double width, Widget Function(BuildContext) build) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Builder(builder: build),
    ),
  );
}

void main() {
  group('width-based pure-function helpers', () {
    test('isMobileWidth: <600 true; >=600 false', () {
      expect(Breakpoints.isMobileWidth(0), isTrue);
      expect(Breakpoints.isMobileWidth(599.9), isTrue);
      expect(Breakpoints.isMobileWidth(600), isFalse);
      expect(Breakpoints.isMobileWidth(1024), isFalse);
    });

    test('isTabletWidth: [600, 1024) true; outside false', () {
      expect(Breakpoints.isTabletWidth(599.9), isFalse);
      expect(Breakpoints.isTabletWidth(600), isTrue);
      expect(Breakpoints.isTabletWidth(1023.9), isTrue);
      expect(Breakpoints.isTabletWidth(1024), isFalse);
    });

    test('isDesktopWidth: >=1024 true', () {
      expect(Breakpoints.isDesktopWidth(1023), isFalse);
      expect(Breakpoints.isDesktopWidth(1024), isTrue);
      expect(Breakpoints.isDesktopWidth(2000), isTrue);
    });
  });

  group('getDeviceCategoryFromWidth', () {
    test('maps each band to the right category', () {
      expect(
          Breakpoints.getDeviceCategoryFromWidth(500), DeviceCategory.mobile);
      expect(Breakpoints.getDeviceCategoryFromWidth(700),
          DeviceCategory.mobileLarge);
      expect(
          Breakpoints.getDeviceCategoryFromWidth(800), DeviceCategory.tablet);
      expect(Breakpoints.getDeviceCategoryFromWidth(1100),
          DeviceCategory.tabletLarge);
      expect(
          Breakpoints.getDeviceCategoryFromWidth(1500), DeviceCategory.desktop);
      expect(Breakpoints.getDeviceCategoryFromWidth(2200),
          DeviceCategory.desktopLarge);
    });

    test('boundary inclusivity matches the < comparisons', () {
      // mobile-cutoff exclusivity (600 is mobileLarge, not mobile)
      expect(
          Breakpoints.getDeviceCategoryFromWidth(599.9), DeviceCategory.mobile);
      expect(Breakpoints.getDeviceCategoryFromWidth(600),
          DeviceCategory.mobileLarge);
    });
  });

  group('DeviceCategoryExtension', () {
    test('isMobile true for mobile + mobileLarge', () {
      expect(DeviceCategory.mobile.isMobile, isTrue);
      expect(DeviceCategory.mobileLarge.isMobile, isTrue);
      expect(DeviceCategory.tablet.isMobile, isFalse);
      expect(DeviceCategory.desktop.isMobile, isFalse);
    });

    test('isTablet true for tablet + tabletLarge', () {
      expect(DeviceCategory.tablet.isTablet, isTrue);
      expect(DeviceCategory.tabletLarge.isTablet, isTrue);
      expect(DeviceCategory.mobile.isTablet, isFalse);
      expect(DeviceCategory.desktop.isTablet, isFalse);
    });

    test('isDesktop true for desktop + desktopLarge', () {
      expect(DeviceCategory.desktop.isDesktop, isTrue);
      expect(DeviceCategory.desktopLarge.isDesktop, isTrue);
      expect(DeviceCategory.tablet.isDesktop, isFalse);
    });

    test('displayName per category', () {
      expect(DeviceCategory.mobile.displayName, 'Mobile');
      expect(DeviceCategory.mobileLarge.displayName, 'Large Mobile');
      expect(DeviceCategory.tablet.displayName, 'Tablet');
      expect(DeviceCategory.tabletLarge.displayName, 'Large Tablet');
      expect(DeviceCategory.desktop.displayName, 'Desktop');
      expect(DeviceCategory.desktopLarge.displayName, 'Large Desktop');
    });
  });

  group('context-aware classifiers (widget tests)', () {
    testWidgets('isMobile / isTablet / isDesktop boundaries', (tester) async {
      late bool isMobile, isTablet, isDesktop;
      await tester.pumpWidget(_atWidth(500, (ctx) {
        isMobile = Breakpoints.isMobile(ctx);
        isTablet = Breakpoints.isTablet(ctx);
        isDesktop = Breakpoints.isDesktop(ctx);
        return const SizedBox.shrink();
      }));
      expect(isMobile, isTrue);
      expect(isTablet, isFalse);
      expect(isDesktop, isFalse);

      await tester.pumpWidget(_atWidth(800, (ctx) {
        isMobile = Breakpoints.isMobile(ctx);
        isTablet = Breakpoints.isTablet(ctx);
        isDesktop = Breakpoints.isDesktop(ctx);
        return const SizedBox.shrink();
      }));
      expect(isTablet, isTrue);

      await tester.pumpWidget(_atWidth(1500, (ctx) {
        isMobile = Breakpoints.isMobile(ctx);
        isDesktop = Breakpoints.isDesktop(ctx);
        return const SizedBox.shrink();
      }));
      expect(isMobile, isFalse);
      expect(isDesktop, isTrue);
    });

    testWidgets('isSmallMobile / isLargeTablet / isLargeDesktop',
        (tester) async {
      late bool isSmallMobile, isLargeTablet, isLargeDesktop;
      await tester.pumpWidget(_atWidth(500, (ctx) {
        isSmallMobile = Breakpoints.isSmallMobile(ctx);
        isLargeTablet = Breakpoints.isLargeTablet(ctx);
        isLargeDesktop = Breakpoints.isLargeDesktop(ctx);
        return const SizedBox.shrink();
      }));
      expect(isSmallMobile, isTrue);
      expect(isLargeTablet, isFalse);
      expect(isLargeDesktop, isFalse);

      await tester.pumpWidget(_atWidth(1100, (ctx) {
        isLargeTablet = Breakpoints.isLargeTablet(ctx);
        return const SizedBox.shrink();
      }));
      expect(isLargeTablet, isTrue);

      await tester.pumpWidget(_atWidth(1500, (ctx) {
        isLargeDesktop = Breakpoints.isLargeDesktop(ctx);
        return const SizedBox.shrink();
      }));
      expect(isLargeDesktop, isTrue);
    });

    testWidgets('getDeviceCategory mirrors getDeviceCategoryFromWidth',
        (tester) async {
      late DeviceCategory cat;
      await tester.pumpWidget(_atWidth(700, (ctx) {
        cat = Breakpoints.getDeviceCategory(ctx);
        return const SizedBox.shrink();
      }));
      expect(cat, DeviceCategory.mobileLarge);
    });
  });

  group('valueFor (BuildContext)', () {
    testWidgets('mobile-only param falls through to desktop', (tester) async {
      late int columns;
      await tester.pumpWidget(_atWidth(1500, (ctx) {
        columns = Breakpoints.valueFor(context: ctx, mobile: 7);
        return const SizedBox.shrink();
      }));
      // Only mobile provided; desktop branch returns desktop ?? tablet ?? mobile.
      expect(columns, 7);
    });

    testWidgets('tablet param wins on tablet widths', (tester) async {
      late int columns;
      await tester.pumpWidget(_atWidth(800, (ctx) {
        columns = Breakpoints.valueFor(
          context: ctx,
          mobile: 1,
          tablet: 2,
          desktop: 3,
        );
        return const SizedBox.shrink();
      }));
      expect(columns, 2);
    });

    testWidgets('desktop param wins on desktop widths', (tester) async {
      late int columns;
      await tester.pumpWidget(_atWidth(1500, (ctx) {
        columns = Breakpoints.valueFor(
          context: ctx,
          mobile: 1,
          tablet: 2,
          desktop: 3,
        );
        return const SizedBox.shrink();
      }));
      expect(columns, 3);
    });
  });

  group('valueForCategory cascade', () {
    testWidgets('desktopLarge fall-back chains to mobile', (tester) async {
      // Width is desktopLarge but only mobile is provided.
      late int v;
      await tester.pumpWidget(_atWidth(2200, (ctx) {
        v = Breakpoints.valueForCategory(context: ctx, mobile: 1);
        return const SizedBox.shrink();
      }));
      expect(v, 1);
    });

    testWidgets('tablet param wins over mobile on tablet width',
        (tester) async {
      late int v;
      await tester.pumpWidget(_atWidth(800, (ctx) {
        v = Breakpoints.valueForCategory(
          context: ctx,
          mobile: 1,
          tablet: 2,
        );
        return const SizedBox.shrink();
      }));
      expect(v, 2);
    });
  });

  group('layout-helper convenience getters', () {
    testWidgets('getGridColumnCount: mobile=1, tablet=2, desktopLarge=4',
        (tester) async {
      late int mobileCols, tabletCols, dlCols;
      await tester.pumpWidget(_atWidth(500, (ctx) {
        mobileCols = Breakpoints.getGridColumnCount(ctx);
        return const SizedBox.shrink();
      }));
      expect(mobileCols, 1);

      await tester.pumpWidget(_atWidth(800, (ctx) {
        tabletCols = Breakpoints.getGridColumnCount(ctx);
        return const SizedBox.shrink();
      }));
      expect(tabletCols, 2);

      await tester.pumpWidget(_atWidth(2200, (ctx) {
        dlCols = Breakpoints.getGridColumnCount(ctx);
        return const SizedBox.shrink();
      }));
      expect(dlCols, 4);
    });

    testWidgets('getCardColumnCount more conservative on desktop',
        (tester) async {
      late int desktopCols;
      await tester.pumpWidget(_atWidth(1500, (ctx) {
        desktopCols = Breakpoints.getCardColumnCount(ctx);
        return const SizedBox.shrink();
      }));
      expect(desktopCols, 2);
    });

    testWidgets('getMaxContentWidth: infinity on mobile, capped on others',
        (tester) async {
      late double mobileMax, desktopMax;
      await tester.pumpWidget(_atWidth(500, (ctx) {
        mobileMax = Breakpoints.getMaxContentWidth(ctx);
        return const SizedBox.shrink();
      }));
      expect(mobileMax, double.infinity);

      await tester.pumpWidget(_atWidth(1500, (ctx) {
        desktopMax = Breakpoints.getMaxContentWidth(ctx);
        return const SizedBox.shrink();
      }));
      expect(desktopMax, 1200);
    });

    testWidgets('getMaxFormWidth caps at 600 on tablet+', (tester) async {
      late double w;
      await tester.pumpWidget(_atWidth(1500, (ctx) {
        w = Breakpoints.getMaxFormWidth(ctx);
        return const SizedBox.shrink();
      }));
      expect(w, 600);
    });

    testWidgets('getMaxDialogWidth scales per device category', (tester) async {
      late double mobileDialog, dlDialog;
      await tester.pumpWidget(_atWidth(500, (ctx) {
        mobileDialog = Breakpoints.getMaxDialogWidth(ctx);
        return const SizedBox.shrink();
      }));
      expect(mobileDialog, double.infinity);

      await tester.pumpWidget(_atWidth(2200, (ctx) {
        dlDialog = Breakpoints.getMaxDialogWidth(ctx);
        return const SizedBox.shrink();
      }));
      expect(dlDialog, 700);
    });
  });

  group('isPortrait / isLandscape', () {
    testWidgets('portrait when height > width', (tester) async {
      late bool portrait;
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Builder(builder: (ctx) {
            portrait = Breakpoints.isPortrait(ctx);
            return const SizedBox.shrink();
          }),
        ),
      ));
      expect(portrait, isTrue);
    });

    testWidgets('landscape when width > height', (tester) async {
      late bool landscape;
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(800, 400)),
          child: Builder(builder: (ctx) {
            landscape = Breakpoints.isLandscape(ctx);
            return const SizedBox.shrink();
          }),
        ),
      ));
      expect(landscape, isTrue);
    });
  });
}

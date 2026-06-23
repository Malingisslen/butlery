/// Tests for `lib/core/responsive/responsive_builder.dart`.
///
/// Covered behaviours:
/// - `ResponsiveBuilder` picks the right builder per breakpoint and falls
///   back desktop → tablet → mobile when an optional builder is null.
/// - Breakpoint boundaries match `Breakpoints.is*Width` semantics: 600 is
///   the first tablet pixel, 1024 is the first desktop pixel.
/// - `ResponsiveBuilderFull` uses `DeviceCategory` 6-band classification
///   and cascades fallbacks upward (e.g. tabletLarge → tablet → mobileLarge
///   → mobile).
/// - `OrientationResponsiveBuilder` composes orientation × size correctly,
///   including fallback to portrait variant when landscape variant is null.
/// - `ResponsiveWidget` mirrors `ResponsiveBuilder`'s null-passing semantics
///   (omitting `onTablet` does NOT show a placeholder — mobile is used).
/// - `ResponsiveVisibility`: explicit `visible` flag overrides `visibleWhen`;
///   `visibleWhen` honours device category; hidden falls back to provided
///   replacement (or `SizedBox.shrink`).
/// - `ResponsiveConstrainedBox` applies the calculated `maxWidth` to its
///   constraints and uses an explicit `maxWidth` override when provided.
/// - `ResponsivePadding` resolves to the per-breakpoint EdgeInsets via the
///   ambient MediaQuery (not the LayoutBuilder of the parent — distinct
///   code path from `ResponsiveBuilder`).
/// - `ResponsiveSpacing.getSpacing` computes derived defaults (1.25x / 1.5x).
/// - `ResponsiveUtils` static multipliers and helpers return the documented
///   values at each breakpoint.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/core/responsive/responsive_builder.dart';

/// Pump `child` inside a MaterialApp whose surface width is `width`.
/// Uses `tester.view.physicalSize` so both LayoutBuilder (constraints) and
/// MediaQuery (size) report the same width.
Future<void> _pumpAt(
  WidgetTester tester,
  double width,
  Widget child, {
  double height = 800,
}) async {
  tester.view.devicePixelRatio = 1.0;
  // Portrait vs landscape is derived from the width:height ratio of
  // physicalSize, so callers pick orientation by overriding `height`.
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('ResponsiveBuilder — picks layout by width', () {
    /// At < 600px the mobile builder runs even when tablet/desktop exist.
    testWidgets('width 400 → mobile', (tester) async {
      await _pumpAt(
        tester,
        400,
        ResponsiveBuilder(
          mobile: (_) => const Text('M'),
          tablet: (_) => const Text('T'),
          desktop: (_) => const Text('D'),
        ),
      );
      expect(find.text('M'), findsOneWidget);
      expect(find.text('T'), findsNothing);
      expect(find.text('D'), findsNothing);
    });

    /// At [600, 1024) the tablet builder runs.
    testWidgets('width 800 → tablet', (tester) async {
      await _pumpAt(
        tester,
        800,
        ResponsiveBuilder(
          mobile: (_) => const Text('M'),
          tablet: (_) => const Text('T'),
          desktop: (_) => const Text('D'),
        ),
      );
      expect(find.text('T'), findsOneWidget);
    });

    /// At >= 1024 the desktop builder runs.
    testWidgets('width 1400 → desktop', (tester) async {
      await _pumpAt(
        tester,
        1400,
        ResponsiveBuilder(
          mobile: (_) => const Text('M'),
          tablet: (_) => const Text('T'),
          desktop: (_) => const Text('D'),
        ),
      );
      expect(find.text('D'), findsOneWidget);
    });
  });

  group('ResponsiveBuilder — breakpoint boundary exactness', () {
    /// Exactly 600 px is the first tablet pixel (matches isTabletWidth(600)).
    testWidgets('width=600 → tablet, not mobile', (tester) async {
      await _pumpAt(
        tester,
        600,
        ResponsiveBuilder(
          mobile: (_) => const Text('M'),
          tablet: (_) => const Text('T'),
        ),
      );
      expect(find.text('T'), findsOneWidget);
      expect(find.text('M'), findsNothing);
    });

    /// 599 px is still mobile (off-by-one regression guard).
    testWidgets('width=599 → mobile', (tester) async {
      await _pumpAt(
        tester,
        599,
        ResponsiveBuilder(
          mobile: (_) => const Text('M'),
          tablet: (_) => const Text('T'),
        ),
      );
      expect(find.text('M'), findsOneWidget);
    });

    /// 1024 px is the first desktop pixel.
    testWidgets('width=1024 → desktop', (tester) async {
      await _pumpAt(
        tester,
        1024,
        ResponsiveBuilder(
          mobile: (_) => const Text('M'),
          tablet: (_) => const Text('T'),
          desktop: (_) => const Text('D'),
        ),
      );
      expect(find.text('D'), findsOneWidget);
    });

    /// 1023 px is still tablet (off-by-one regression guard).
    testWidgets('width=1023 → tablet', (tester) async {
      await _pumpAt(
        tester,
        1023,
        ResponsiveBuilder(
          mobile: (_) => const Text('M'),
          tablet: (_) => const Text('T'),
          desktop: (_) => const Text('D'),
        ),
      );
      expect(find.text('T'), findsOneWidget);
    });
  });

  group('ResponsiveBuilder — fallback semantics', () {
    /// Desktop width with no desktop builder falls back to tablet.
    testWidgets('desktop width, no desktop → uses tablet', (tester) async {
      await _pumpAt(
        tester,
        1400,
        ResponsiveBuilder(
          mobile: (_) => const Text('M'),
          tablet: (_) => const Text('T'),
        ),
      );
      expect(find.text('T'), findsOneWidget);
    });

    /// Desktop width with neither desktop nor tablet falls back to mobile.
    testWidgets('desktop width, no desktop+tablet → uses mobile', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        1400,
        ResponsiveBuilder(mobile: (_) => const Text('M')),
      );
      expect(find.text('M'), findsOneWidget);
    });

    /// Tablet width with no tablet falls back to mobile.
    testWidgets('tablet width, no tablet → uses mobile', (tester) async {
      await _pumpAt(
        tester,
        800,
        ResponsiveBuilder(mobile: (_) => const Text('M')),
      );
      expect(find.text('M'), findsOneWidget);
    });
  });

  group('ResponsiveBuilderFull — 6-band classification', () {
    /// 500 → mobile
    testWidgets('mobile band uses mobile builder', (tester) async {
      await _pumpAt(
        tester,
        500,
        ResponsiveBuilderFull(
          mobile: (_) => const Text('m'),
          mobileLarge: (_) => const Text('ml'),
          tablet: (_) => const Text('t'),
        ),
      );
      expect(find.text('m'), findsOneWidget);
    });

    /// 700 → mobileLarge (600 <= width < 768).
    testWidgets('mobileLarge band uses mobileLarge builder', (tester) async {
      await _pumpAt(
        tester,
        700,
        ResponsiveBuilderFull(
          mobile: (_) => const Text('m'),
          mobileLarge: (_) => const Text('ml'),
        ),
      );
      expect(find.text('ml'), findsOneWidget);
    });

    /// 700 with no mobileLarge → falls back to mobile.
    testWidgets('mobileLarge band, no mobileLarge → mobile', (tester) async {
      await _pumpAt(
        tester,
        700,
        ResponsiveBuilderFull(mobile: (_) => const Text('m')),
      );
      expect(find.text('m'), findsOneWidget);
    });

    /// 1100 → tabletLarge; if tabletLarge missing, cascades through
    /// tablet → mobileLarge → mobile.
    testWidgets('tabletLarge cascades to next available smaller builder', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        1100,
        ResponsiveBuilderFull(
          mobile: (_) => const Text('m'),
          mobileLarge: (_) => const Text('ml'),
        ),
      );
      // No tabletLarge, no tablet → falls to mobileLarge.
      expect(find.text('ml'), findsOneWidget);
    });

    /// 2200 → desktopLarge; with only mobile defined, cascades all the way
    /// down to mobile.
    testWidgets(
      'desktopLarge cascades all the way to mobile when nothing else',
      (tester) async {
        await _pumpAt(
          tester,
          2200,
          ResponsiveBuilderFull(mobile: (_) => const Text('m')),
        );
        expect(find.text('m'), findsOneWidget);
      },
    );

    /// 1500 → desktop band picks desktop builder if defined.
    testWidgets('desktop band picks desktop builder', (tester) async {
      await _pumpAt(
        tester,
        1500,
        ResponsiveBuilderFull(
          mobile: (_) => const Text('m'),
          desktop: (_) => const Text('d'),
        ),
      );
      expect(find.text('d'), findsOneWidget);
    });
  });

  group('OrientationResponsiveBuilder', () {
    /// Portrait mobile uses mobilePortrait.
    testWidgets('mobile portrait → mobilePortrait', (tester) async {
      await _pumpAt(
        tester,
        400,
        OrientationResponsiveBuilder(
          mobilePortrait: (_) => const Text('mp'),
          mobileLandscape: (_) => const Text('ml'),
        ),
      );
      expect(find.text('mp'), findsOneWidget);
    });

    /// Landscape mobile (wide-but-still-mobile would be unusual but
    /// orientation is height vs width). Use width=400, height=200 → landscape.
    testWidgets('mobile landscape → mobileLandscape', (tester) async {
      await _pumpAt(
        tester,
        400,
        OrientationResponsiveBuilder(
          mobilePortrait: (_) => const Text('mp'),
          mobileLandscape: (_) => const Text('ml'),
        ),
        height: 200,
      );
      expect(find.text('ml'), findsOneWidget);
    });

    /// Landscape with no mobileLandscape falls back to mobilePortrait.
    testWidgets('mobile landscape, no landscape → mobilePortrait', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        400,
        OrientationResponsiveBuilder(
          mobilePortrait: (_) => const Text('mp'),
        ),
        height: 200,
      );
      expect(find.text('mp'), findsOneWidget);
    });

    /// Tablet portrait without tabletPortrait → mobilePortrait fallback.
    testWidgets('tablet portrait, no tablet variants → mobilePortrait', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        800,
        OrientationResponsiveBuilder(
          mobilePortrait: (_) => const Text('mp'),
        ),
      );
      expect(find.text('mp'), findsOneWidget);
    });

    /// Tablet with tabletPortrait defined uses it.
    testWidgets('tablet portrait uses tabletPortrait', (tester) async {
      await _pumpAt(
        tester,
        800,
        OrientationResponsiveBuilder(
          mobilePortrait: (_) => const Text('mp'),
          tabletPortrait: (_) => const Text('tp'),
        ),
      );
      expect(find.text('tp'), findsOneWidget);
    });

    /// Desktop with desktopLayout uses it.
    testWidgets('desktop uses desktopLayout when provided', (tester) async {
      await _pumpAt(
        tester,
        1400,
        OrientationResponsiveBuilder(
          mobilePortrait: (_) => const Text('mp'),
          desktopLayout: (_) => const Text('d'),
        ),
      );
      expect(find.text('d'), findsOneWidget);
    });
  });

  group('ResponsiveWidget', () {
    /// Omitting onTablet does NOT yield a "tablet placeholder" — it
    /// falls through to onMobile (parity with ResponsiveBuilder semantics).
    testWidgets('tablet width without onTablet → onMobile', (tester) async {
      await _pumpAt(
        tester,
        800,
        const ResponsiveWidget(
          onMobile: Text('m'),
          onDesktop: Text('d'),
        ),
      );
      expect(find.text('m'), findsOneWidget);
      expect(find.text('d'), findsNothing);
    });

    testWidgets('desktop width with onDesktop → onDesktop', (tester) async {
      await _pumpAt(
        tester,
        1400,
        const ResponsiveWidget(
          onMobile: Text('m'),
          onTablet: Text('t'),
          onDesktop: Text('d'),
        ),
      );
      expect(find.text('d'), findsOneWidget);
    });
  });

  group('ResponsiveVisibility', () {
    /// `visible: false` overrides everything and renders the replacement.
    testWidgets('visible=false renders explicit replacement', (tester) async {
      await _pumpAt(
        tester,
        400,
        const ResponsiveVisibility(
          visible: false,
          replacement: Text('REPLACE'),
          child: Text('CHILD'),
        ),
      );
      expect(find.text('REPLACE'), findsOneWidget);
      expect(find.text('CHILD'), findsNothing);
    });

    /// `visible: false` with no replacement renders SizedBox.shrink (so
    /// neither the child nor any text appears).
    testWidgets('visible=false no replacement → SizedBox.shrink', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        400,
        const ResponsiveVisibility(
          visible: false,
          child: Text('CHILD'),
        ),
      );
      expect(find.text('CHILD'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    /// `visible: true` overrides `visibleWhen` and shows the child even
    /// when the current category is not in the list.
    testWidgets('visible=true overrides visibleWhen', (tester) async {
      await _pumpAt(
        tester,
        400, // mobile category
        const ResponsiveVisibility(
          visible: true,
          visibleWhen: [DeviceCategory.desktop],
          child: Text('CHILD'),
        ),
      );
      expect(find.text('CHILD'), findsOneWidget);
    });

    /// `visibleWhen` matches → child rendered.
    testWidgets('visibleWhen contains current category → child shown', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        800, // tablet
        const ResponsiveVisibility(
          visibleWhen: [DeviceCategory.tablet, DeviceCategory.desktop],
          child: Text('CHILD'),
        ),
      );
      expect(find.text('CHILD'), findsOneWidget);
    });

    /// `visibleWhen` does NOT match → replacement (or shrink) rendered.
    testWidgets('visibleWhen excludes current category → hidden', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        400, // mobile
        const ResponsiveVisibility(
          visibleWhen: [DeviceCategory.tablet, DeviceCategory.desktop],
          replacement: Text('HIDDEN'),
          child: Text('CHILD'),
        ),
      );
      expect(find.text('HIDDEN'), findsOneWidget);
      expect(find.text('CHILD'), findsNothing);
    });

    /// Default: no visible flag, no visibleWhen → always shown.
    testWidgets('no flags → always visible', (tester) async {
      await _pumpAt(
        tester,
        400,
        const ResponsiveVisibility(child: Text('CHILD')),
      );
      expect(find.text('CHILD'), findsOneWidget);
    });
  });

  group('ResponsiveConstrainedBox', () {
    /// Explicit maxWidth overrides the breakpoint calculation.
    testWidgets('explicit maxWidth wins over breakpoint default', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        1400, // desktop default would be 1200
        const ResponsiveConstrainedBox(
          maxWidth: 321,
          child: SizedBox(key: ValueKey('child')),
        ),
      );
      final container = tester.widget<Container>(find.byType(Container));
      expect(container.constraints?.maxWidth, 321);
    });

    /// At mobile width, default maxContentWidth is infinity → constraint
    /// equals infinity (Center handles the layout).
    testWidgets('mobile default → infinity maxWidth', (tester) async {
      await _pumpAt(
        tester,
        400,
        const ResponsiveConstrainedBox(
          child: SizedBox(key: ValueKey('child')),
        ),
      );
      final container = tester.widget<Container>(find.byType(Container));
      expect(container.constraints?.maxWidth, double.infinity);
    });

    /// At desktop, the breakpoint-derived maxWidth (1200) is applied.
    testWidgets('desktop default → 1200 maxWidth', (tester) async {
      await _pumpAt(
        tester,
        1400,
        const ResponsiveConstrainedBox(
          child: SizedBox(key: ValueKey('child')),
        ),
      );
      final container = tester.widget<Container>(find.byType(Container));
      expect(container.constraints?.maxWidth, 1200);
    });

    /// Padding parameter is passed through to the inner Container.
    testWidgets('padding is forwarded to inner Container', (tester) async {
      await _pumpAt(
        tester,
        400,
        const ResponsiveConstrainedBox(
          padding: EdgeInsets.all(7),
          child: SizedBox(),
        ),
      );
      final container = tester.widget<Container>(find.byType(Container));
      expect(container.padding, const EdgeInsets.all(7));
    });
  });

  group('ResponsivePadding', () {
    /// Tablet width picks the tablet EdgeInsets via Breakpoints.valueFor.
    testWidgets('tablet width → tablet EdgeInsets', (tester) async {
      await _pumpAt(
        tester,
        800,
        const ResponsivePadding(
          mobile: EdgeInsets.all(8),
          tablet: EdgeInsets.all(16),
          desktop: EdgeInsets.all(24),
          child: SizedBox(key: ValueKey('inside')),
        ),
      );
      final padding = tester.widget<Padding>(find.byType(Padding));
      expect(padding.padding, const EdgeInsets.all(16));
    });

    /// Mobile width with all three defined picks mobile.
    testWidgets('mobile width → mobile EdgeInsets', (tester) async {
      await _pumpAt(
        tester,
        400,
        const ResponsivePadding(
          mobile: EdgeInsets.all(8),
          tablet: EdgeInsets.all(16),
          desktop: EdgeInsets.all(24),
          child: SizedBox(),
        ),
      );
      final padding = tester.widget<Padding>(find.byType(Padding));
      expect(padding.padding, const EdgeInsets.all(8));
    });

    /// Tablet width but no tablet param → falls back to mobile (not null!).
    /// Regression guard: if Breakpoints.valueFor stops cascading nulls,
    /// this would explode with a null cast at Padding.padding.
    testWidgets('tablet width, no tablet param → falls back to mobile', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        800,
        const ResponsivePadding(
          mobile: EdgeInsets.all(8),
          child: SizedBox(),
        ),
      );
      final padding = tester.widget<Padding>(find.byType(Padding));
      expect(padding.padding, const EdgeInsets.all(8));
    });
  });

  group('ResponsiveSpacing.getSpacing', () {
    /// At mobile width returns base unchanged.
    testWidgets('mobile returns base', (tester) async {
      late double spacing;
      await _pumpAt(
        tester,
        400,
        Builder(
          builder: (context) {
            spacing = const ResponsiveSpacing(
              mobile: 10,
              child: SizedBox(),
            ).getSpacing(context);
            return const SizedBox();
          },
        ),
      );
      expect(spacing, 10.0);
    });

    /// At tablet width, default tablet = mobile * 1.25.
    testWidgets('tablet default = mobile * 1.25', (tester) async {
      late double spacing;
      await _pumpAt(
        tester,
        800,
        Builder(
          builder: (context) {
            spacing = const ResponsiveSpacing(
              mobile: 10,
              child: SizedBox(),
            ).getSpacing(context);
            return const SizedBox();
          },
        ),
      );
      expect(spacing, 12.5);
    });

    /// At desktop width with no explicit desktop or tablet, default desktop
    /// = mobile * 1.5.
    testWidgets('desktop default = mobile * 1.5', (tester) async {
      late double spacing;
      await _pumpAt(
        tester,
        1400,
        Builder(
          builder: (context) {
            spacing = const ResponsiveSpacing(
              mobile: 10,
              child: SizedBox(),
            ).getSpacing(context);
            return const SizedBox();
          },
        ),
      );
      expect(spacing, 15.0);
    });

    /// build() returns the child unchanged (it's a passive accessor widget).
    testWidgets('build returns the child directly', (tester) async {
      await _pumpAt(
        tester,
        400,
        const ResponsiveSpacing(
          mobile: 10,
          child: Text('child-text'),
        ),
      );
      expect(find.text('child-text'), findsOneWidget);
    });
  });

  group('ResponsiveUtils — multipliers per breakpoint', () {
    Future<T> at<T>(
      WidgetTester tester,
      double width,
      T Function(BuildContext) read,
    ) async {
      late T value;
      await _pumpAt(
        tester,
        width,
        Builder(
          builder: (context) {
            value = read(context);
            return const SizedBox();
          },
        ),
      );
      return value;
    }

    testWidgets('getFontSizeMultiplier: 1.0 / 1.1 / 1.15', (tester) async {
      expect(await at(tester, 400, ResponsiveUtils.getFontSizeMultiplier), 1.0);
      expect(await at(tester, 800, ResponsiveUtils.getFontSizeMultiplier), 1.1);
      expect(
        await at(tester, 1400, ResponsiveUtils.getFontSizeMultiplier),
        1.15,
      );
    });

    testWidgets('getSpacingMultiplier: 1.0 / 1.25 / 1.5', (tester) async {
      expect(await at(tester, 400, ResponsiveUtils.getSpacingMultiplier), 1.0);
      expect(await at(tester, 800, ResponsiveUtils.getSpacingMultiplier), 1.25);
      expect(await at(tester, 1400, ResponsiveUtils.getSpacingMultiplier), 1.5);
    });

    testWidgets('getIconSizeMultiplier: 1.0 / 1.15 / 1.25', (tester) async {
      expect(await at(tester, 400, ResponsiveUtils.getIconSizeMultiplier), 1.0);
      expect(
        await at(tester, 800, ResponsiveUtils.getIconSizeMultiplier),
        1.15,
      );
      expect(
        await at(tester, 1400, ResponsiveUtils.getIconSizeMultiplier),
        1.25,
      );
    });

    testWidgets('responsive() applies multiplier to base', (tester) async {
      final result = await at(
        tester,
        800,
        (ctx) => ResponsiveUtils.responsive(context: ctx, base: 16),
      );
      // 800px → tablet → default tabletMultiplier 1.25 → 16 * 1.25 = 20
      expect(result, 20.0);
    });

    testWidgets('responsive() honours custom multipliers', (tester) async {
      final result = await at(
        tester,
        1400,
        (ctx) => ResponsiveUtils.responsive(
          context: ctx,
          base: 10,
          desktopMultiplier: 3.0,
        ),
      );
      expect(result, 30.0);
    });

    testWidgets('getSidebarWidth: 0 / 72 / 256', (tester) async {
      expect(await at(tester, 400, ResponsiveUtils.getSidebarWidth), 0.0);
      expect(await at(tester, 800, ResponsiveUtils.getSidebarWidth), 72.0);
      expect(await at(tester, 1400, ResponsiveUtils.getSidebarWidth), 256.0);
    });

    testWidgets('useMasterDetail: false on mobile, true on tablet+desktop', (
      tester,
    ) async {
      expect(await at(tester, 400, ResponsiveUtils.useMasterDetail), isFalse);
      expect(await at(tester, 800, ResponsiveUtils.useMasterDetail), isTrue);
      expect(await at(tester, 1400, ResponsiveUtils.useMasterDetail), isTrue);
    });

    testWidgets('getGridCrossAxisCount: defaults 1 / 2 / 3', (tester) async {
      expect(await at(tester, 400, ResponsiveUtils.getGridCrossAxisCount), 1);
      expect(await at(tester, 800, ResponsiveUtils.getGridCrossAxisCount), 2);
      expect(await at(tester, 1400, ResponsiveUtils.getGridCrossAxisCount), 3);
    });

    testWidgets('getGridCrossAxisCount: overrides win', (tester) async {
      final v = await at(
        tester,
        1400,
        (ctx) => ResponsiveUtils.getGridCrossAxisCount(ctx, desktop: 7),
      );
      expect(v, 7);
    });

    /// Dialog constraints: maxWidth from breakpoint, maxHeight = 90% of
    /// MediaQuery height. At width 800 (tablet) maxWidth = 500.
    testWidgets(
      'getDialogConstraints: width per breakpoint, height = 0.9 * H',
      (tester) async {
        final box = await at(
          tester,
          800,
          ResponsiveUtils.getDialogConstraints,
        );
        expect(box.maxWidth, 500);
        expect(box.maxHeight, closeTo(800 * 0.9, 0.001));
      },
    );

    /// Form constraints: tablet+ caps at 600; mobile is infinity.
    testWidgets(
      'getFormConstraints: 600 cap on tablet/desktop, inf on mobile',
      (tester) async {
        expect(
          (await at(tester, 400, ResponsiveUtils.getFormConstraints)).maxWidth,
          double.infinity,
        );
        expect(
          (await at(tester, 800, ResponsiveUtils.getFormConstraints)).maxWidth,
          600,
        );
        expect(
          (await at(tester, 1400, ResponsiveUtils.getFormConstraints)).maxWidth,
          600,
        );
      },
    );
  });
}

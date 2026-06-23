/// Widget tests for PeaLoadingAnimation, PeaLoadingOverlay, and
/// PeaLoadingIndicatorSmall.
///
/// PeaLoadingAnimation drives a repeating Timer.periodic. We use bounded
/// `pump(Duration)` calls instead of `pumpAndSettle`, and wrap the tree in
/// MediaQuery(disableAnimations: true) defensively where helpful.
///
/// Image assets bundled at `assets/illustrations/arta/artskida*.PNG` are
/// not loaded by the asset bundle in plain widget tests. We assert only that
/// the `Image` widget renders, not the fallback path — Image.asset's
/// errorBuilder fires non-deterministically across pump cycles.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/indicators/pea_loading_animation.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: Scaffold(body: child),
  ),
);

void main() {
  group('PeaLoadingAnimation — render', () {
    testWidgets('renders a SizedBox with default size 80', (tester) async {
      await tester.pumpWidget(_wrap(const PeaLoadingAnimation()));
      await tester.pump();

      final sized = tester.firstWidget<SizedBox>(
        find.descendant(
          of: find.byType(PeaLoadingAnimation),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sized.width, 80);
      expect(sized.height, 80);
    });

    testWidgets('explicit size sets the outer SizedBox dimensions', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const PeaLoadingAnimation(size: 120)));
      await tester.pump();

      final sized = tester.firstWidget<SizedBox>(
        find.descendant(
          of: find.byType(PeaLoadingAnimation),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sized.width, 120);
      expect(sized.height, 120);
    });

    testWidgets('contains an Image.asset for the current frame', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const PeaLoadingAnimation()));
      await tester.pump();

      // Whether or not the asset resolves, the Image widget must exist.
      expect(
        find.descendant(
          of: find.byType(PeaLoadingAnimation),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
    });
  });

  group('PeaLoadingAnimation — animation lifecycle', () {
    testWidgets('advances frames over time without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PeaLoadingAnimation(
            frameInterval: Duration(milliseconds: 50),
          ),
        ),
      );
      await tester.pump();

      // Drive several timer ticks. The widget calls setState in each tick,
      // which would throw if it leaked past dispose or hit a guard miss.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 55));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(PeaLoadingAnimation), findsOneWidget);
    });

    testWidgets('cancels its timer cleanly on dispose (no late setState)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const PeaLoadingAnimation(
            frameInterval: Duration(milliseconds: 30),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Replace the subtree — the State's dispose() must cancel the timer.
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      // If the timer kept ticking it would call setState on an unmounted
      // State and throw on the next pump.
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.byType(PeaLoadingAnimation), findsNothing);
    });
  });

  group('PeaLoadingOverlay', () {
    testWidgets(
      'renders a PeaLoadingAnimation child sized via the `size` prop',
      (tester) async {
        await tester.pumpWidget(_wrap(const PeaLoadingOverlay(size: 60)));
        await tester.pump();

        expect(find.byType(PeaLoadingAnimation), findsOneWidget);
        final inner = tester.widget<PeaLoadingAnimation>(
          find.byType(PeaLoadingAnimation),
        );
        expect(inner.size, 60);
      },
    );

    testWidgets('renders message when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PeaLoadingOverlay(message: 'Laddar recept'),
        ),
      );
      await tester.pump();

      expect(find.text('Laddar recept'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PeaLoadingOverlay(
            message: 'Vänta',
            subtitle: 'Det kan ta en stund',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Vänta'), findsOneWidget);
      expect(find.text('Det kan ta en stund'), findsOneWidget);
    });

    testWidgets('omits message and subtitle widgets when not provided', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const PeaLoadingOverlay()));
      await tester.pump();

      // Only the animation should be present in the overlay column — no
      // unexpected Text widgets beyond what Image fallback paints internally.
      // (CircularProgressIndicator carries no Text.)
      final overlay = find.byType(PeaLoadingOverlay);
      expect(
        find.descendant(of: overlay, matching: find.byType(Text)),
        findsNothing,
      );
    });

    testWidgets('uses surface color with 0.9 alpha as the background tint', (
      tester,
    ) async {
      const surface = Color(0xFFAABBCC);
      final theme = ThemeData(
        colorScheme: const ColorScheme.light(surface: surface),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: PeaLoadingOverlay()),
          ),
        ),
      );
      await tester.pump();

      final box = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(PeaLoadingOverlay),
          matching: find.byType(ColoredBox),
        ),
      );
      // withValues(alpha: 0.9) — match by alpha, not exact RGB equality
      // (the surface color is preserved verbatim by the production widget).
      expect(box.color.r, surface.r);
      expect(box.color.g, surface.g);
      expect(box.color.b, surface.b);
      expect(box.color.a, closeTo(0.9, 0.01));
    });

    testWidgets('uses spacingMd between animation and message', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PeaLoadingOverlay(message: 'Hej'),
        ),
      );
      await tester.pump();

      // The SizedBox spacer with height = spacingMd should be present as a
      // descendant of the overlay's Column.
      final spacers = tester.widgetList<SizedBox>(
        find.descendant(
          of: find.byType(PeaLoadingOverlay),
          matching: find.byType(SizedBox),
        ),
      );
      expect(
        spacers.any((s) => s.height == AppDimensions.spacingMd),
        isTrue,
      );
    });
  });

  group('PeaLoadingIndicatorSmall', () {
    testWidgets('default size is 40 and forwards to PeaLoadingAnimation', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const PeaLoadingIndicatorSmall()));
      await tester.pump();

      final inner = tester.widget<PeaLoadingAnimation>(
        find.byType(PeaLoadingAnimation),
      );
      expect(inner.size, 40);
    });

    testWidgets('uses a faster 100ms frame interval', (tester) async {
      await tester.pumpWidget(_wrap(const PeaLoadingIndicatorSmall()));
      await tester.pump();

      final inner = tester.widget<PeaLoadingAnimation>(
        find.byType(PeaLoadingAnimation),
      );
      expect(inner.frameInterval, const Duration(milliseconds: 100));
    });

    testWidgets('explicit size overrides the default', (tester) async {
      await tester.pumpWidget(_wrap(const PeaLoadingIndicatorSmall(size: 24)));
      await tester.pump();

      final inner = tester.widget<PeaLoadingAnimation>(
        find.byType(PeaLoadingAnimation),
      );
      expect(inner.size, 24);
    });

    testWidgets('disposes cleanly when removed from the tree', (tester) async {
      await tester.pumpWidget(_wrap(const PeaLoadingIndicatorSmall()));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });
}

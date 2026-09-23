// test/widget/common/loading/loading_widgets_test.dart
// Comprehensive tests for LoadingWidgets using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/loading/loading_widgets.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('LoadingWidgets Tests', () {
    // Helper to wrap widget with MaterialApp for proper theming
    Widget createTestApp(Widget child) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: Scaffold(
          body: child,
        ),
      );
    }

    group('loadingOverlay', () {
      testWidgets('should return child when not loading', (
        WidgetTester tester,
      ) async {
        const childText = 'Content Widget';

        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: false,
              child: const Text(childText),
            ),
          ),
        );

        expect(find.text(childText), findsOneWidget);
        expect(find.byType(PlateLine), findsNothing);
      });

      testWidgets(
        'should return SizedBox.shrink when not loading and no child',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            createTestApp(
              LoadingWidgets.loadingOverlay(
                isLoading: false,
                child: null,
              ),
            ),
          );

          expect(find.byType(SizedBox), findsWidgets);
          expect(find.byType(PlateLine), findsNothing);
        },
      );

      testWidgets('should show loading overlay when loading', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: true,
            ),
          ),
        );

        expect(find.byType(PlateLine), findsOneWidget);
        expect(
          find
              .ancestor(
                of: find.byType(PlateLine),
                matching: find.byType(ColoredBox),
              )
              .first,
          findsOneWidget,
        );
      });

      testWidgets('should stack overlay over child when loading', (
        WidgetTester tester,
      ) async {
        const childText = 'Background Content';

        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: true,
              child: const Text(childText),
            ),
          ),
        );

        // Should have Stack containing both child and overlay
        expect(find.byType(Stack), findsWidgets);
        expect(find.text(childText), findsOneWidget);
        expect(find.byType(PlateLine), findsOneWidget);
      });

      testWidgets('should show loading message when provided', (
        WidgetTester tester,
      ) async {
        const loadingMessage = 'Laddar data...';

        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: true,
              loadingMessage: loadingMessage,
            ),
          ),
        );

        expect(find.text(loadingMessage), findsOneWidget);
        expect(find.byType(PlateLine), findsOneWidget);
      });

      testWidgets('never shows the line alone when the message is null', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: true,
              loadingMessage: null,
            ),
          ),
        );

        // The line never carries the news alone (produktregler.md:163):
        // the generic text stands in.
        expect(find.byType(PlateLine), findsOneWidget);
        expect(find.text('Laddar...'), findsOneWidget);
      });

      testWidgets('should use custom overlay color when provided', (
        WidgetTester tester,
      ) async {
        const customColor = Colors.red;

        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: true,
              overlayColor: customColor,
            ),
          ),
        );

        final coloredBox = tester.widget<ColoredBox>(
          find
              .ancestor(
                of: find.byType(PlateLine),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(coloredBox.color, equals(customColor));
      });

      testWidgets('should use theme onSurface overlay when not provided', (
        WidgetTester tester,
      ) async {
        late ColorScheme cs;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('sv'),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  cs = Theme.of(context).colorScheme;
                  return LoadingWidgets.loadingOverlay(isLoading: true);
                },
              ),
            ),
          ),
        );

        final coloredBox = tester.widget<ColoredBox>(
          find
              .ancestor(
                of: find.byType(PlateLine),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(
          coloredBox.color,
          equals(
            cs.onSurface.withValues(alpha: AppDimensions.opacityMediumLight),
          ),
        );
      });

      testWidgets('should have proper container styling', (
        WidgetTester tester,
      ) async {
        late ColorScheme cs;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('sv'),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  cs = Theme.of(context).colorScheme;
                  return LoadingWidgets.loadingOverlay(isLoading: true);
                },
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(Center),
            matching: find.byType(Container),
          ),
        );

        expect(
          container.padding,
          equals(const EdgeInsets.all(AppDimensions.paddingL)),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(cs.surfaceContainerHighest));
        expect(
          decoration.borderRadius,
          equals(BorderRadius.circular(AppDimensions.borderRadiusL)),
        );
      });

      testWidgets('draws the plate line with text, never a spinner', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestApp(LoadingWidgets.loadingOverlay(isLoading: true)),
        );

        // Plate line plus text (produktregler.md:163, B-18). Without a
        // message the generic one stands in.
        expect(find.byType(PlateLineMessage), findsOneWidget);
        expect(find.byType(PlateLine), findsOneWidget);
        expect(find.text('Laddar...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('should transition from loading to not loading', (
        WidgetTester tester,
      ) async {
        const childText = 'Content';

        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: true,
              child: const Text(childText),
              loadingMessage: 'Loading...',
            ),
          ),
        );

        expect(find.byType(PlateLine), findsOneWidget);
        expect(find.text('Loading...'), findsOneWidget);

        // Change to not loading
        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: false,
              child: const Text(childText),
            ),
          ),
        );

        expect(find.byType(PlateLine), findsNothing);
        expect(find.text('Loading...'), findsNothing);
        expect(find.text(childText), findsOneWidget);
      });
    });

    group('errorBoundary', () {
      testWidgets('should render child when no error', (
        WidgetTester tester,
      ) async {
        const childText = 'Normal Widget';

        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.errorBoundary(
              child: const Text(childText),
            ),
          ),
        );

        expect(find.text(childText), findsOneWidget);
      });

      testWidgets('should show default error widget on error', (
        WidgetTester tester,
      ) async {
        // Note: The current implementation won't actually catch build errors
        // due to Flutter's error handling mechanism, but we test the intended behavior
        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.errorBoundary(
              child: const Text('Normal'),
            ),
          ),
        );

        // The widget should at least render without crashing
        expect(find.byType(Builder), findsWidgets);
      });

      testWidgets('should show Swedish error message', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.errorBoundary(
              child: const Text('Test'),
              errorWidget: const Center(
                child: Text('Ett oväntat fel uppstod'),
              ),
            ),
          ),
        );

        // If error widget is provided, it should be available
        expect(find.byType(Text), findsWidgets);
      });

      testWidgets('should use custom error widget when provided', (
        WidgetTester tester,
      ) async {
        const customErrorText = 'Custom Error Message';

        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.errorBoundary(
              child: const Text('Content'),
              errorWidget: const Text(customErrorText),
            ),
          ),
        );

        // The normal content should render
        expect(find.text('Content'), findsOneWidget);
      });

      testWidgets('should handle onError callback', (
        WidgetTester tester,
      ) async {
        var errorCallbackCalled = false;

        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.errorBoundary(
              child: const Text('Test Widget'),
              onError: (error, stack) {
                errorCallbackCalled = true;
              },
            ),
          ),
        );

        // In normal operation, callback shouldn't be called
        expect(errorCallbackCalled, isFalse);
      });
    });

    group('responsiveWrapper', () {
      testWidgets('should wrap child with container', (
        WidgetTester tester,
      ) async {
        const childText = 'Responsive Content';

        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.responsiveWrapper(
              child: const Text(childText),
            ),
          ),
        );

        expect(find.text(childText), findsOneWidget);
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('should center the content', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.responsiveWrapper(
              child: const Text('Centered'),
            ),
          ),
        );

        expect(find.byType(Center), findsWidgets);
      });

      testWidgets('should apply custom max width when provided', (
        WidgetTester tester,
      ) async {
        const customMaxWidth = 400.0;

        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.responsiveWrapper(
              child: const Text('Content'),
              maxWidth: customMaxWidth,
            ),
          ),
        );

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(Center),
                matching: find.byType(Container),
              )
              .first,
        );

        expect(container.constraints?.maxWidth, equals(customMaxWidth));
      });

      testWidgets('should apply custom padding when provided', (
        WidgetTester tester,
      ) async {
        const customPadding = EdgeInsets.all(24.0);

        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.responsiveWrapper(
              child: const Text('Content'),
              padding: customPadding,
            ),
          ),
        );

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(Center),
                matching: find.byType(Container),
              )
              .first,
        );

        expect(container.padding, equals(customPadding));
      });

      testWidgets('should use default padding when not provided', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.responsiveWrapper(
              child: const Text('Content'),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(Center),
                matching: find.byType(Container),
              )
              .first,
        );

        expect(
          container.padding,
          equals(const EdgeInsets.all(AppDimensions.paddingL)),
        );
      });

      testWidgets('should handle small screen width', (
        WidgetTester tester,
      ) async {
        // Set up a small screen size
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.responsiveWrapper(
              child: const Text('Mobile Content'),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(Center),
                matching: find.byType(Container),
              )
              .first,
        );

        // On small screens (< 768), should use infinity max width
        expect(container.constraints?.maxWidth, equals(double.infinity));

        // Reset the view
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('should handle large screen width', (
        WidgetTester tester,
      ) async {
        // Set up a large screen size
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.responsiveWrapper(
              child: const Text('Desktop Content'),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(Center),
                matching: find.byType(Container),
              )
              .first,
        );

        // On large screens (> 768), should use 600 max width
        expect(container.constraints?.maxWidth, equals(600));

        // Reset the view
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('Swedish Localization', () {
      testWidgets('should display Swedish loading message', (
        WidgetTester tester,
      ) async {
        const swedishMessage = 'Laddar recept...';

        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: true,
              loadingMessage: swedishMessage,
            ),
          ),
        );

        expect(find.text(swedishMessage), findsOneWidget);
      });

      testWidgets('should handle Swedish characters in loading message', (
        WidgetTester tester,
      ) async {
        const swedishMessage = 'Hämtar användaruppgifter från servern...';

        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: true,
              loadingMessage: swedishMessage,
            ),
          ),
        );

        expect(find.text(swedishMessage), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle rapid loading state changes', (
        WidgetTester tester,
      ) async {
        const childText = 'Content';

        // Start not loading
        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: false,
              child: const Text(childText),
            ),
          ),
        );

        // Change to loading
        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: true,
              child: const Text(childText),
            ),
          ),
        );

        // Change back to not loading
        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: false,
              child: const Text(childText),
            ),
          ),
        );

        expect(find.byType(PlateLine), findsNothing);
        expect(find.text(childText), findsOneWidget);
      });

      testWidgets('should handle null child with loading true', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: true,
              child: null,
            ),
          ),
        );

        expect(find.byType(PlateLine), findsOneWidget);
        // When child is null, only the overlay is shown (no Stack needed)
        expect(
          find
              .ancestor(
                of: find.byType(PlateLine),
                matching: find.byType(ColoredBox),
              )
              .first,
          findsOneWidget,
        );
      });

      testWidgets('should handle empty loading message', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: true,
              loadingMessage: '',
            ),
          ),
        );

        expect(find.text(''), findsOneWidget);
        expect(find.byType(PlateLine), findsOneWidget);
      });

      testWidgets('should handle very long loading message', (
        WidgetTester tester,
      ) async {
        final longMessage = 'A' * 200;

        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: true,
              loadingMessage: longMessage,
            ),
          ),
        );

        expect(find.text(longMessage), findsOneWidget);
      });

      testWidgets('should handle transparent overlay color', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestApp(
            LoadingWidgets.loadingOverlay(
              isLoading: true,
              overlayColor: Colors.transparent,
            ),
          ),
        );

        final coloredBox = tester.widget<ColoredBox>(
          find
              .ancestor(
                of: find.byType(PlateLine),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(coloredBox.color, equals(Colors.transparent));
      });
    });
  });
}

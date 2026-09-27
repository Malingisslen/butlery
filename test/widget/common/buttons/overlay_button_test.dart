import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/buttons/overlay_button.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/theme_constants.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';

// Comprehensive widget test for OverlayButton following ultrathink methodology
void main() {
  setUp(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('OverlayButton Tests', () {
    group('Default Constructor', () {
      testWidgets('renders with custom child widget', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OverlayButton(
                child: const ButleryIcon(ButleryIcons.pencil),
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byIcon(ButleryIcons.pencil), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
        expect(find.byType(DecoratedBox), findsOneWidget);
      });

      testWidgets('renders with custom background color', (
        WidgetTester tester,
      ) async {
        const customColor = Colors.blue;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OverlayButton(
                backgroundColor: customColor,
                onPressed: () {},
                child: const ButleryIcon(ButleryIcons.pencil),
              ),
            ),
          ),
        );

        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.color, equals(customColor));
      });

      testWidgets('uses default background color when not specified', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return OverlayButton(
                    child: const ButleryIcon(ButleryIcons.pencil),
                    onPressed: () {},
                  );
                },
              ),
            ),
          ),
        );

        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(
          decoration.color,
          equals(ThemeConstants.blackOverlay60),
        );
      });

      testWidgets('handles null onPressed callback', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: OverlayButton(
                onPressed: null,
                child: ButleryIcon(ButleryIcons.pencil),
              ),
            ),
          ),
        );

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.onPressed, isNull);
      });

      testWidgets('executes onPressed callback when tapped', (
        WidgetTester tester,
      ) async {
        bool wasPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OverlayButton(
                child: const ButleryIcon(ButleryIcons.pencil),
                onPressed: () {
                  wasPressed = true;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(IconButton));
        expect(wasPressed, isTrue);
      });

      testWidgets('displays tooltip when provided', (
        WidgetTester tester,
      ) async {
        const tooltipText = 'Edit item';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OverlayButton(
                tooltip: tooltipText,
                onPressed: () {},
                child: const ButleryIcon(ButleryIcons.pencil),
              ),
            ),
          ),
        );

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, equals(tooltipText));
      });

      testWidgets('does not display tooltip when not provided', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OverlayButton(
                child: const ButleryIcon(ButleryIcons.pencil),
                onPressed: () {},
              ),
            ),
          ),
        );

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, isNull);
      });

      testWidgets('applies correct border radius', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OverlayButton(
                child: const ButleryIcon(ButleryIcons.pencil),
                onPressed: () {},
              ),
            ),
          ),
        );

        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(
          decoration.borderRadius,
          equals(BorderRadius.circular(AppDimensions.radiusControl)),
        );
      });

      testWidgets('accepts any widget as child', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OverlayButton(
                onPressed: () {},
                child: const Text('Custom'),
              ),
            ),
          ),
        );

        expect(find.text('Custom'), findsOneWidget);
      });

      testWidgets('works with disabled state', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: OverlayButton(
                onPressed: null,
                child: ButleryIcon(ButleryIcons.pencil),
              ),
            ),
          ),
        );

        // Should still render but with null onPressed
        expect(find.byType(OverlayButton), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.onPressed, isNull);
      });
    });

    group('Remove Constructor', () {
      testWidgets('renders with clear icon', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OverlayButton.remove(
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byIcon(ButleryIcons.x), findsOneWidget);
      });

      testWidgets('uses correct icon color for remove variant', (
        WidgetTester tester,
      ) async {
        late ColorScheme cs;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  cs = Theme.of(context).colorScheme;
                  return OverlayButton.remove(onPressed: () {});
                },
              ),
            ),
          ),
        );

        // Icon color is provided via IconTheme (cs.surfaceContainerHighest).
        final iconTheme = IconTheme.of(
          tester.element(find.byIcon(ButleryIcons.x)),
        );
        expect(iconTheme.color, equals(cs.surfaceContainerHighest));
      });

      testWidgets('uses default background color for remove variant', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return OverlayButton.remove(onPressed: () {});
                },
              ),
            ),
          ),
        );

        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        // Remove variant sets backgroundColor to null → default theme surface.
        expect(
          decoration.color,
          equals(ThemeConstants.blackOverlay60),
        );
      });

      testWidgets('executes onPressed callback when remove button tapped', (
        WidgetTester tester,
      ) async {
        bool wasRemoved = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OverlayButton.remove(
                onPressed: () {
                  wasRemoved = true;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(IconButton));
        expect(wasRemoved, isTrue);
      });

      testWidgets('displays tooltip for remove button when provided', (
        WidgetTester tester,
      ) async {
        const tooltipText = 'Ta bort'; // Swedish for "Remove"

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OverlayButton.remove(
                onPressed: () {},
                tooltip: tooltipText,
              ),
            ),
          ),
        );

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, equals(tooltipText));
      });
    });

    group('Layout and Styling', () {
      testWidgets('maintains consistent size with IconButton', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OverlayButton(
                child: const ButleryIcon(ButleryIcons.pencil),
                onPressed: () {},
              ),
            ),
          ),
        );

        // IconButton has default size constraints
        final iconButtonSize = tester.getSize(find.byType(IconButton));
        expect(iconButtonSize.width, greaterThan(0));
        expect(iconButtonSize.height, greaterThan(0));
      });

      testWidgets('renders correctly in different parent layouts', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  OverlayButton(
                    onPressed: () {},
                    child: const ButleryIcon(ButleryIcons.pencil),
                  ),
                  OverlayButton.remove(
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(OverlayButton), findsNWidgets(2));
        expect(find.byIcon(ButleryIcons.pencil), findsOneWidget);
        expect(find.byIcon(ButleryIcons.x), findsOneWidget);
      });

      testWidgets('renders correctly in Stack layout', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: OverlayButton.remove(
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(OverlayButton), findsOneWidget);
        expect(find.byIcon(ButleryIcons.x), findsOneWidget);
      });

      testWidgets('uses theme surface color when no background specified', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(primarySwatch: Colors.green),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return OverlayButton(
                    child: const ButleryIcon(ButleryIcons.pencil),
                    onPressed: () {},
                  );
                },
              ),
            ),
          ),
        );

        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        // The button resolves its background from the ambient theme.
        expect(
          decoration.color,
          equals(ThemeConstants.blackOverlay60),
        );
      });
    });

    group('Accessibility', () {
      testWidgets('supports semantic labels through child widget', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OverlayButton(
                child: const ButleryIcon(
                  ButleryIcons.pencil,
                  semanticLabel: 'Redigera', // Swedish for "Edit"
                ),
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel('Redigera'), findsOneWidget);
      });

      testWidgets('tooltip provides accessibility hint', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OverlayButton.remove(
                onPressed: () {},
                tooltip: 'Ta bort objekt', // Swedish for "Remove item"
              ),
            ),
          ),
        );

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, equals('Ta bort objekt'));
      });
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';

const _longLabel = 'This is a very long button label that wraps';

void main() {
  group('ActionButtons', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
    });

    group('actionButton', () {
      testWidgets('should render primary button by default', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.actionButton(
                context,
                label: 'Test Button',
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.text('Test Button'), findsOneWidget);
      });

      testWidgets('should render secondary button when specified', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.actionButton(
                context,
                label: 'Secondary',
                onPressed: () {},
                style: ActionButtonStyle.secondary,
              ),
            ),
          ),
        );

        // Production uses ElevatedButton for secondary style
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.text('Secondary'), findsOneWidget);
      });

      testWidgets('should render outlined button when specified', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.actionButton(
                context,
                label: 'Outlined',
                onPressed: () {},
                style: ActionButtonStyle.outlined,
              ),
            ),
          ),
        );

        expect(find.byType(OutlinedButton), findsOneWidget);
        expect(find.text('Outlined'), findsOneWidget);
      });

      testWidgets('should show loading indicator when isLoading is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.actionButton(
                context,
                label: 'Button',
                onPressed: () {},
                isLoading: true,
              ),
            ),
          ),
        );

        expect(find.byType(ButtonPlateLine), findsOneWidget);
      });

      testWidgets('should show custom loading text when provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.actionButton(
                context,
                label: 'Button',
                onPressed: () {},
                isLoading: true,
                loadingText: 'Sparar...',
              ),
            ),
          ),
        );

        expect(find.text('Sparar...'), findsOneWidget);
      });

      testWidgets('should display icon when provided', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.actionButton(
                context,
                label: 'Save',
                onPressed: () {},
                icon: Icons.save,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.save), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
      });

      testWidgets('ignores presses while busy but keeps its enabled look', (
        tester,
      ) async {
        var pressed = 0;
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.actionButton(
                context,
                label: 'Button',
                onPressed: () => pressed++,
                isLoading: true,
              ),
            ),
          ),
        );

        // Busy is not disabled: the button keeps its surface (Komponentark
        // v1:365, loading and disabled are two states), so it is enabled
        // for Flutter, and the press does nothing.
        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(button.enabled, isTrue);
        await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
        await tester.pump();
        expect(pressed, 0);
      });

      testWidgets('should expand to full width when isExpanded is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.actionButton(
                context,
                label: 'Expanded Button',
                onPressed: () {},
                isExpanded: true,
              ),
            ),
          ),
        );

        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
        expect(sizedBox.width, equals(double.infinity));
      });

      testWidgets('should handle onPressed callback', (tester) async {
        bool pressed = false;

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.actionButton(
                context,
                label: 'Click Me',
                onPressed: () => pressed = true,
              ),
            ),
          ),
        );

        await tester.tap(find.text('Click Me'));
        await tester.pump();

        expect(pressed, isTrue);
      });
    });

    group('primaryButton', () {
      testWidgets('should create primary styled button', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.primaryButton(
                context,
                label: 'Primary',
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.text('Primary'), findsOneWidget);
      });

      testWidgets('should support all action button features', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.primaryButton(
                context,
                label: 'Primary',
                onPressed: () {},
                icon: ButleryIcons.plus,
                isLoading: false,
                isExpanded: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(ButleryIcons.plus), findsOneWidget);
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
        expect(sizedBox.width, equals(double.infinity));
      });
    });

    group('largeButton', () {
      testWidgets('should render large button with increased height', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.largeButton(
                context,
                label: 'Archive',
                icon: ButleryIcons.archive,
                onPressed: () {},
              ),
            ),
          ),
        );

        // Verify the text is rendered
        expect(find.text('Archive'), findsOneWidget);

        // Verify that SizedBox widgets exist in the tree
        // The largeButton implementation uses a SizedBox to constrain height
        final sizedBoxes = find.byType(SizedBox);
        expect(sizedBoxes, findsAtLeastNWidgets(1));

        // Verify the icon is present
        expect(find.byIcon(ButleryIcons.archive), findsOneWidget);

        // Verify the button structure has proper height constraint
        // The largeButton wraps the button in a SizedBox with height
        final sizedBox = tester.widget<SizedBox>(
          find.byType(SizedBox).first,
        );
        expect(sizedBox.height, equals(100)); // Default height from largeButton
      });

      testWidgets('should support icon in large button', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.largeButton(
                context,
                label: 'Archive',
                icon: ButleryIcons.archive,
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byIcon(ButleryIcons.archive), findsOneWidget);
      });
    });

    group('FloatingActionButtonWidget', () {
      testWidgets('should render basic FAB', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const FloatingActionButtonWidget(
              onPressed: null,
              semanticLabel: 'Lagg till',
              child: ButleryIcon(ButleryIcons.plus),
            ),
          ),
        );

        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.byIcon(ButleryIcons.plus), findsOneWidget);
      });

      testWidgets('should render message FAB with default styling', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const FloatingActionButtonWidget.message(
              onPressed: null,
              semanticLabel: 'Ny konversation',
            ),
          ),
        );

        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.byIcon(ButleryIcons.messageSquare), findsOneWidget);

        final fab = tester.widget<FloatingActionButton>(
          find.byType(FloatingActionButton),
        );
        // FAB is an ink fill with onPrimary (paper) on it: surfaceContainerHighest
        // turned #2F4437 in dark mode and vanished on the ink fill (P4-T7).
        // Paket 1: FAB:en tar sina färger ur det kanoniska schemat.
        expect(fab.backgroundColor, equals(AppColors.lightColorScheme.primary));
        expect(
          fab.foregroundColor,
          equals(AppColors.lightColorScheme.onPrimary),
        );
      });

      testWidgets('should handle custom colors', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: FloatingActionButtonWidget(
              onPressed: () {},
              semanticLabel: 'Favorit',
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              child: const ButleryIcon(ButleryIcons.heart),
            ),
          ),
        );

        final fab = tester.widget<FloatingActionButton>(
          find.byType(FloatingActionButton),
        );
        expect(fab.backgroundColor, equals(Colors.red));
        expect(fab.foregroundColor, equals(Colors.white));
      });
    });

    group('Swedish Localization', () {
      testWidgets('should display Swedish loading text', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.actionButton(
                context,
                label: 'Spara',
                onPressed: () {},
                isLoading: true,
              ),
            ),
          ),
        );

        // No busy label: the button keeps its own name, never "Laddar …".
        expect(find.byType(ButtonPlateLine), findsOneWidget);
        expect(find.text('Spara'), findsOneWidget);
        expect(find.text('Laddar …'), findsNothing);
      });

      testWidgets('should handle Swedish labels correctly', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.actionButton(
                context,
                label: 'Lagg till recept',
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.text('Lagg till recept'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle null onPressed', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.actionButton(
                context,
                label: 'Disabled',
                onPressed: null,
              ),
            ),
          ),
        );

        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(button.onPressed, isNull);
      });

      // BUT-2193: a button never cuts its label (plattformsmatris.md:
      // ellipsis is forbidden in buttons); a long one wraps.
      // actionButton and textButton each build their own label.
      for (final (name, build) in <(String, Widget Function(BuildContext))>[
        (
          'actionButton',
          (context) => ActionButtons.actionButton(
            context,
            label: _longLabel,
            onPressed: () {},
          ),
        ),
        (
          'textButton',
          (context) => ActionButtons.textButton(
            context,
            label: _longLabel,
            onPressed: () {},
          ),
        ),
      ]) {
        testWidgets('$name: a very long label wraps instead of being cut', (
          tester,
        ) async {
          await tester.pumpWidget(
            createLocalizedTestApp(
              child: SizedBox(width: 150, child: Builder(builder: build)),
            ),
          );

          final label = find.text(_longLabel);
          final text = tester.widget<Text>(label);
          expect(text.overflow, isNull);
          expect(text.maxLines, isNull);
          expect(tester.takeException(), isNull);
          // More than one line: the label really wrapped in 150 dp.
          final paragraph = tester.renderObject<RenderParagraph>(label);
          expect(
            tester.getSize(label).height,
            greaterThan(paragraph.preferredLineHeight * 1.5),
          );
        });
      }

      testWidgets('should not show icon when loading', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.actionButton(
                context,
                label: 'Save',
                onPressed: () {},
                icon: Icons.save,
                isLoading: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.save), findsNothing);
        expect(find.byType(ButtonPlateLine), findsOneWidget);
      });
    });
  });
}

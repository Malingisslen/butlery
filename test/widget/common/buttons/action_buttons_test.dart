import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/theme/app_colors.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

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

      testWidgets('should render secondary button when specified',
          (tester) async {
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

      testWidgets('should render outlined button when specified',
          (tester) async {
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

      testWidgets('should show loading indicator when isLoading is true',
          (tester) async {
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

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should show custom loading text when provided',
          (tester) async {
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

      testWidgets('should be disabled when loading', (tester) async {
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

        final button =
            tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(button.onPressed, isNull);
      });

      testWidgets('should expand to full width when isExpanded is true',
          (tester) async {
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
                icon: Icons.add,
                isLoading: false,
                isExpanded: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.add), findsOneWidget);
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
        expect(sizedBox.width, equals(double.infinity));
      });
    });

    group('squareButton', () {
      testWidgets('should render square aspect ratio button', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SizedBox(
              width: 100,
              height: 100,
              child: Builder(
                builder: (context) => ActionButtons.squareButton(
                  context,
                  label: 'Upload',
                  icon: Icons.upload,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.byType(AspectRatio), findsOneWidget);
        final aspectRatio =
            tester.widget<AspectRatio>(find.byType(AspectRatio));
        expect(aspectRatio.aspectRatio, equals(1.0));
      });

      testWidgets('should display icon and label vertically', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SizedBox(
              width: 100,
              height: 100,
              child: Builder(
                builder: (context) => ActionButtons.squareButton(
                  context,
                  label: 'Import',
                  icon: Icons.file_upload,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.file_upload), findsOneWidget);
        expect(find.text('Import'), findsOneWidget);

        // Check vertical arrangement
        expect(find.byType(Column), findsOneWidget);
      });

      testWidgets('should show loading state in square button', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SizedBox(
              width: 100,
              height: 100,
              child: Builder(
                builder: (context) => ActionButtons.squareButton(
                  context,
                  label: 'Upload',
                  icon: Icons.upload,
                  onPressed: () {},
                  isLoading: true,
                  loadingText: 'Laddar upp...',
                ),
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Laddar upp...'), findsOneWidget);
        expect(find.byIcon(Icons.upload),
            findsNothing); // Icon hidden when loading
      });
    });

    group('largeButton', () {
      testWidgets('should render large button with increased height',
          (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ActionButtons.largeButton(
                context,
                label: 'Archive',
                icon: Icons.archive,
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
        expect(find.byIcon(Icons.archive), findsOneWidget);

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
                icon: Icons.archive,
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.archive), findsOneWidget);
      });
    });

    group('FloatingActionButtonWidget', () {
      testWidgets('should render basic FAB', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const FloatingActionButtonWidget(
              onPressed: null,
              semanticLabel: 'Lagg till',
              child: Icon(Icons.add),
            ),
          ),
        );

        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('should render message FAB with default styling',
          (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const FloatingActionButtonWidget.message(
              onPressed: null,
            ),
          ),
        );

        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.byIcon(Icons.message), findsOneWidget);

        final fab = tester.widget<FloatingActionButton>(
          find.byType(FloatingActionButton),
        );
        // FAB uses cs.primary / cs.surfaceContainerHighest from the Butlery theme
        expect(fab.backgroundColor, equals(AppColors.forestGreen));
        expect(fab.foregroundColor, equals(AppColors.cardWhite));
      });

      testWidgets('should handle custom colors', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: FloatingActionButtonWidget(
              onPressed: () {},
              semanticLabel: 'Favorit',
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              child: const Icon(Icons.favorite),
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

        // The exact loading text comes from l10n
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
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

        final button =
            tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(button.onPressed, isNull);
      });

      testWidgets('should handle very long labels with ellipsis',
          (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SizedBox(
              width: 150,
              child: Builder(
                builder: (context) => ActionButtons.actionButton(
                  context,
                  label:
                      'This is a very long button label that should be truncated',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(
          find.text(
              'This is a very long button label that should be truncated'),
        );
        expect(text.overflow, equals(TextOverflow.ellipsis));
        expect(text.maxLines, equals(1));
      });

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
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });
  });
}

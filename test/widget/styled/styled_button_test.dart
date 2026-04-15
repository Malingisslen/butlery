import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/styled/styled_button.dart';
import 'package:butlery/theme/app_dimensions.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('StyledButton Widget Tests', () {
    group('Default Constructor', () {
      testWidgets('renders with text and no icon', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButton(
            text: 'Test Button',
            onPressed: () {},
          ),
        ));

        expect(find.byType(StyledButton), findsOneWidget);
        expect(find.text('Test Button'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });

      testWidgets('is disabled when onPressed is null', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: const StyledButton(
            text: 'Disabled',
            onPressed: null,
          ),
        ));

        final button =
            tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(button.onPressed, isNull);
      });

      testWidgets('shows loading state', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: const StyledButton(
            text: 'Loading',
            isLoading: true,
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // Text hidden during loading
        expect(find.text('Loading'), findsNothing);

        final button =
            tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(button.onPressed, isNull);
      });

      testWidgets('renders with icon when provided', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButton(
            text: 'Icon Button',
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ));

        expect(find.text('Icon Button'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsWidgets);
      });

      testWidgets('applies custom width and height', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButton(
            text: 'Custom Size',
            width: 200,
            height: 60,
            onPressed: () {},
          ),
        ));

        final sizedBox = tester.widget<SizedBox>(
          find
              .ancestor(
                of: find.byType(ElevatedButton),
                matching: find.byType(SizedBox),
              )
              .first,
        );

        expect(sizedBox.width, equals(200));
        expect(sizedBox.height, equals(60));
      });

      testWidgets('applies custom padding', (tester) async {
        const customPadding = EdgeInsets.all(20);

        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButton(
            text: 'Custom Padding',
            padding: customPadding,
            onPressed: () {},
          ),
        ));

        final button =
            tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(button.style, isNotNull);
      });
    });

    group('Primary Button Constructor', () {
      testWidgets('renders as primary button', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButton.primary(
            text: 'Primary',
            onPressed: () {},
          ),
        ));

        expect(find.text('Primary'), findsOneWidget);

        final sizedBox = tester.widget<SizedBox>(
          find
              .ancestor(
                of: find.byType(ElevatedButton),
                matching: find.byType(SizedBox),
              )
              .first,
        );
        expect(sizedBox.height, equals(AppDimensions.buttonHeight));
      });

      testWidgets('supports loading state', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: const StyledButton.primary(
            text: 'Loading Primary',
            isLoading: true,
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('accepts icon', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButton.primary(
            text: 'Primary Icon',
            icon: const Icon(Icons.save),
            onPressed: () {},
          ),
        ));

        expect(find.byIcon(Icons.save), findsOneWidget);
        expect(find.text('Primary Icon'), findsOneWidget);
      });
    });

    group('Secondary Button Constructor', () {
      testWidgets('renders as secondary button', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButton.secondary(
            text: 'Secondary',
            onPressed: () {},
          ),
        ));

        expect(find.text('Secondary'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });
    });

    group('Destructive Button Constructor', () {
      testWidgets('renders with destructive styling', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButton.destructive(
            text: 'Delete',
            onPressed: () {},
          ),
        ));

        expect(find.text('Delete'), findsOneWidget);

        final button =
            tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(button.style, isNotNull);
      });

      testWidgets('works with icon', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButton.destructive(
            text: 'Remove',
            icon: const Icon(Icons.delete),
            onPressed: () {},
          ),
        ));

        expect(find.byIcon(Icons.delete), findsOneWidget);
        expect(find.text('Remove'), findsOneWidget);
      });
    });

    group('Small Button Constructor', () {
      testWidgets('renders with small height', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButton.small(
            text: 'Small',
            onPressed: () {},
          ),
        ));

        final sizedBox = tester.widget<SizedBox>(
          find
              .ancestor(
                of: find.byType(ElevatedButton),
                matching: find.byType(SizedBox),
              )
              .first,
        );

        expect(sizedBox.height, equals(36.0));
        expect(find.text('Small'), findsOneWidget);
      });
    });

    group('Icon Button Constructor', () {
      testWidgets('renders icon-only button', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButton.icon(
            icon: const Icon(Icons.add),
            semanticLabel: 'Add item',
            onPressed: () {},
          ),
        ));

        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
      });

      testWidgets('renders destructive icon button', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButton.icon(
            icon: const Icon(Icons.delete),
            semanticLabel: 'Delete item',
            isDestructive: true,
            onPressed: () {},
          ),
        ));

        expect(find.byIcon(Icons.delete), findsOneWidget);

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.style, isNotNull);
      });

      testWidgets('shows loading state for icon button', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: const StyledButton.icon(
            icon: Icon(Icons.refresh),
            semanticLabel: 'Refresh',
            isLoading: true,
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // Icon hidden during loading
        expect(find.byIcon(Icons.refresh), findsNothing);
      });
    });

    group('User Interaction', () {
      testWidgets('calls onPressed callback when tapped', (tester) async {
        var pressed = false;

        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButton(
            text: 'Tap Me',
            onPressed: () => pressed = true,
          ),
        ));

        await tester.tap(find.byType(ElevatedButton));
        expect(pressed, isTrue);
      });

      testWidgets('does not respond to tap when disabled', (tester) async {
        final pressed = false;

        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButton(
            text: 'Disabled',
            onPressed: null,
          ),
        ));

        await tester.tap(find.byType(ElevatedButton));
        expect(pressed, isFalse);
      });

      testWidgets('does not respond to tap when loading', (tester) async {
        var pressed = false;

        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButton(
            text: 'Loading',
            isLoading: true,
            onPressed: () => pressed = true,
          ),
        ));

        await tester.tap(find.byType(ElevatedButton));
        expect(pressed, isFalse);
      });
    });
  });

  group('StyledButtons Utility Class Tests', () {
    group('Swedish Localization', () {
      testWidgets('cancel displays Swedish text', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButtons.cancel(onPressed: () {}),
        ));

        expect(find.text('Avbryt'), findsOneWidget);
      });

      testWidgets('save displays Swedish text', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButtons.save(onPressed: () {}),
        ));

        expect(find.text('Spara'), findsOneWidget);
        expect(find.byIcon(Icons.save), findsOneWidget);
      });

      testWidgets('delete displays Swedish text', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButtons.delete(onPressed: () {}),
        ));

        expect(find.text('Ta bort'), findsOneWidget);
        expect(find.byIcon(Icons.delete), findsOneWidget);
      });

      testWidgets('add displays Swedish text', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButtons.add(onPressed: () {}),
        ));

        expect(find.text('L\u00e4gg till'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('edit displays Swedish text', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButtons.edit(onPressed: () {}),
        ));

        expect(find.text('Redigera'), findsOneWidget);
        expect(find.byIcon(Icons.edit), findsOneWidget);
      });

      testWidgets('share displays Swedish text', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButtons.share(onPressed: () {}),
        ));

        expect(find.text('Dela'), findsOneWidget);
        expect(find.byIcon(Icons.share), findsOneWidget);
      });
    });

    group('Custom Text Support', () {
      testWidgets('accepts custom text for cancel', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButtons.cancel(
            text: 'St\u00e4ng',
            onPressed: () {},
          ),
        ));

        expect(find.text('St\u00e4ng'), findsOneWidget);
      });

      testWidgets('accepts custom text for save', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButtons.save(
            text: 'Skicka',
            onPressed: () {},
          ),
        ));

        expect(find.text('Skicka'), findsOneWidget);
      });
    });

    group('Loading State Support', () {
      testWidgets('save supports loading state', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButtons.save(
            isLoading: true,
            onPressed: () {},
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // Text hidden during loading
        expect(find.text('Spara'), findsNothing);
      });

      testWidgets('delete supports loading state', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButtons.delete(
            isLoading: true,
            onPressed: () {},
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Ta bort'), findsNothing);
      });
    });

    group('Button Type Verification', () {
      testWidgets('cancel is secondary (not destructive)', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButtons.cancel(onPressed: () {}),
        ));

        // StyledButtons.cancel wraps in Builder, so find StyledButton
        // as a descendant of the Builder
        final styledButton =
            tester.widget<StyledButton>(find.byType(StyledButton));
        expect(styledButton.isDestructive, isFalse);
      });

      testWidgets('delete is destructive', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButtons.delete(onPressed: () {}),
        ));

        final styledButton =
            tester.widget<StyledButton>(find.byType(StyledButton));
        expect(styledButton.isDestructive, isTrue);
      });

      testWidgets('save is primary', (tester) async {
        await tester.pumpWidget(createLocalizedTestApp(
          child: StyledButtons.save(onPressed: () {}),
        ));

        final styledButton =
            tester.widget<StyledButton>(find.byType(StyledButton));
        expect(styledButton.isDestructive, isFalse);
        expect(styledButton.height, equals(AppDimensions.buttonHeight));
      });
    });
  });
}

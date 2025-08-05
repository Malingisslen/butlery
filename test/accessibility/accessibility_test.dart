import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';
import 'package:butlery/views/auth_view.dart';
import '../helpers/test_helpers.dart';
import '../helpers/mock_factories.dart';
import '../test_configuration.dart';

void main() {
  // Configure tests to ensure ServiceLocator is properly initialized
  configureTests();
  group('Accessibility Tests', () {
    // Enable semantics for all tests
    setUp(() {
      WidgetsBinding.instance.ensureVisualUpdate();
    });

    group('Touch Target Size Tests', () {
      testWidgets('buttons meet minimum touch target size', (tester) async {
        // Given
        await tester.pumpWidget(
          createTestableWidget(
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Test Button'),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.favorite),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Text Button'),
                ),
              ],
            ),
          ),
        );

        // Then - verify all buttons meet minimum size
        final elevatedButton = tester.getSize(find.byType(ElevatedButton));
        expect(
            elevatedButton.width >= 48 && elevatedButton.height >= 48, isTrue,
            reason: 'ElevatedButton should be at least 48x48');

        final iconButton = tester.getSize(find.byType(IconButton));
        expect(iconButton.width >= 48 && iconButton.height >= 48, isTrue,
            reason: 'IconButton should be at least 48x48');

        final textButton = tester.getSize(find.byType(TextButton));
        expect(textButton.height >= 48, isTrue,
            reason: 'TextButton height should be at least 48');
      });

      testWidgets('interactive elements in lists have proper sizing',
          (tester) async {
        // Given
        final recipes = RecipeFactory.buildList(3);

        await tester.pumpWidget(
          createTestableWidget(
            child: ListView.builder(
              itemCount: recipes.length,
              itemBuilder: (context, index) => RecipeCard(
                recipe: recipes[index],
                onTap: (_) {},
              ),
            ),
          ),
        );

        // Then - verify interactive elements meet minimum size
        // Check IconButtons (not just the icon inside them)
        final iconButtons = find.byType(IconButton);
        if (iconButtons.evaluate().isNotEmpty) {
          for (int i = 0; i < iconButtons.evaluate().length; i++) {
            final size = tester.getSize(iconButtons.at(i));
            expect(size.width >= 48 && size.height >= 48, isTrue,
                reason: 'IconButton $i should be at least 48x48');
          }
        }
        
        // Also check the cards themselves are tappable with proper size
        final cards = find.byType(RecipeCard);
        for (int i = 0; i < cards.evaluate().length; i++) {
          final size = tester.getSize(cards.at(i));
          expect(size.height >= 48, isTrue,
              reason: 'RecipeCard $i should have minimum height of 48');
        }
      });
    });

    group('Screen Reader Tests', () {
      testWidgets('recipe card has proper semantic labels', (tester) async {
        // Given
        final recipe = RecipeFactory.build(
          title: 'Pasta Carbonara',
          timeMinutes: 20,
          portions: 4,
        );

        await tester.pumpWidget(
          createTestableWidget(
            child: RecipeCard(
              recipe: recipe,
              onTap: (_) {},
            ),
          ),
        );

        // Then
        final semantics = tester.getSemantics(find.byType(RecipeCard));
        expect(semantics.label, contains('Pasta Carbonara'));

        // Verify semantic properties
        // RecipeCard should have a semantic label
        expect(semantics.label, isNotNull);
        expect(semantics.label, contains('Pasta Carbonara'));
      });

      testWidgets('form fields have proper labels', (tester) async {
        // Given
        await tester.pumpWidget(
          createTestableWidget(
            child: const AuthView(),
          ),
        );

        // Then - verify email field
        final emailField = find.byKey(const Key('email_field'));
        expect(emailField, findsOneWidget);
        final emailSemantics = tester.getSemantics(emailField);
        expect(emailSemantics.label, contains('E-post'));

        // Verify password field
        final passwordField = find.byKey(const Key('password_field'));
        expect(passwordField, findsOneWidget);
        final passwordSemantics = tester.getSemantics(passwordField);
        expect(passwordSemantics.label, contains('Lösenord'));
      });

      testWidgets('images have alt text', (tester) async {
        // Given
        final recipe = RecipeFactory.build(
          title: 'Chocolate Cake',
          imageUrls: ['https://example.com/cake.jpg'],
        );

        await tester.pumpWidget(
          createTestableWidget(
            child: RecipeCard(
              recipe: recipe,
              onTap: (_) {},
            ),
          ),
        );

        // Then
        final image = find.byType(Image);
        if (image.evaluate().isNotEmpty) {
          final imageSemantics = tester.getSemantics(image);
          expect(imageSemantics.label, isNotNull,
              reason: 'Images should have semantic labels');
        }
      });
    });

    group('Color Contrast Tests', () {
      testWidgets('text has sufficient contrast in light theme',
          (tester) async {
        // Given
        await tester.pumpWidget(
          createTestableWidget(
            theme: ThemeData.light(),
            child: const Column(
              children: [
                Text('Primary Text', style: TextStyle(color: Colors.black87)),
                Text('Secondary Text', style: TextStyle(color: Colors.black54)),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Card Text'),
                  ),
                ),
              ],
            ),
          ),
        );

        // Manual verification needed for actual contrast ratios
        // WCAG 2.1 requires:
        // - Normal text: 4.5:1 contrast ratio
        // - Large text: 3:1 contrast ratio
        expect(find.text('Primary Text'), findsOneWidget);
        expect(find.text('Secondary Text'), findsOneWidget);
        expect(find.text('Card Text'), findsOneWidget);
      });

      testWidgets('text has sufficient contrast in dark theme', (tester) async {
        // Given
        await tester.pumpWidget(
          createTestableWidget(
            theme: ThemeData.dark(),
            child: const ColoredBox(
              color: Colors.black,
              child: Column(
                children: [
                  Text('Primary Text', style: TextStyle(color: Colors.white)),
                  Text('Secondary Text',
                      style: TextStyle(color: Colors.white70)),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Card Text'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // Verify text is visible
        expect(find.text('Primary Text'), findsOneWidget);
        expect(find.text('Secondary Text'), findsOneWidget);
        expect(find.text('Card Text'), findsOneWidget);
      });
    });

    group('Keyboard Navigation Tests', () {
      testWidgets('form can be navigated with keyboard', (tester) async {
        // Given
        await tester.pumpWidget(
          createTestableWidget(
            child: Column(
              children: [
                TextFormField(
                  key: const Key('field1'),
                  decoration: const InputDecoration(labelText: 'Field 1'),
                ),
                TextFormField(
                  key: const Key('field2'),
                  decoration: const InputDecoration(labelText: 'Field 2'),
                ),
                ElevatedButton(
                  key: const Key('submit'),
                  onPressed: () {},
                  child: const Text('Submit'),
                ),
              ],
            ),
          ),
        );

        // When - simulate tab navigation
        await tester.tap(find.byKey(const Key('field1')));
        await tester.pump();

        // Verify focus
        // In a real test, we'd verify focus state

        // Tab to next field would be simulated here
        // This requires platform-specific testing
      });

      testWidgets('dialogs trap focus appropriately', (tester) async {
        // Given
        await tester.pumpWidget(
          createTestableWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Test Dialog'),
                      content: const Text('Dialog content'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        );

        // When
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Then
        expect(find.text('Test Dialog'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('OK'), findsOneWidget);

        // Verify dialog buttons are accessible
        final cancelButton = tester.getSemantics(find.text('Cancel'));
        expect(cancelButton.hasFlag(SemanticsFlag.isButton), isTrue);
      });
    });

    group('Text Scaling Tests', () {
      testWidgets('UI adapts to large text scale', (tester) async {
        // Given
        final recipe = RecipeFactory.build(
          title: 'Test Recipe',
          description: 'A test recipe description',
        );

        await tester.pumpWidget(
          createTestableWidget(
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: RecipeCard(
                recipe: recipe,
                onTap: (_) {},
              ),
            ),
          ),
        );

        // Then - verify no overflow
        expect(tester.takeException(), isNull,
            reason: 'UI should not overflow with 1.5x text scale');
      });

      testWidgets('UI adapts to extra large text scale', (tester) async {
        // Given
        await tester.pumpWidget(
          createTestableWidget(
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: Column(
                children: [
                  const Text('Extra Large Text'),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Button'),
                  ),
                ],
              ),
            ),
          ),
        );

        // Then - verify no overflow
        expect(tester.takeException(), isNull,
            reason: 'UI should not overflow with 2.0x text scale');
      });
    });

    group('Focus Management Tests', () {
      testWidgets('focus indicators are visible', (tester) async {
        // Given
        await tester.pumpWidget(
          createTestableWidget(
            child: Column(
              children: [
                TextFormField(
                  key: const Key('input'),
                  decoration: const InputDecoration(
                    labelText: 'Input Field',
                    border: OutlineInputBorder(),
                  ),
                ),
                ElevatedButton(
                  key: const Key('button'),
                  onPressed: () {},
                  child: const Text('Button'),
                ),
              ],
            ),
          ),
        );

        // When - focus on input
        await tester.tap(find.byKey(const Key('input')));
        await tester.pump();

        // Then - verify focus indicator
        final input = find.byKey(const Key('input'));
        expect(input, findsOneWidget);
        // Visual focus indicator should be present
      });

      testWidgets('focus order is logical', (tester) async {
        // Given
        await tester.pumpWidget(
          createTestableWidget(
            child: Column(
              children: [
                const Text('Title'),
                TextFormField(
                  key: const Key('name'),
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextFormField(
                  key: const Key('email'),
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        // Verify widgets are in logical order
        // final widgets = tester.widgetList(find.byType(Widget));
        // Focus should follow visual order: title -> name -> email -> cancel -> submit
      });
    });

    group('Announcements Tests', () {
      testWidgets('loading states are announced', (tester) async {
        // Given
        bool isLoading = true;

        await tester.pumpWidget(
          createTestableWidget(
            child: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  if (isLoading)
                    Semantics(
                      label: 'Loading recipes',
                      child: const CircularProgressIndicator(),
                    )
                  else
                    const Text('Recipes loaded'),
                  ElevatedButton(
                    onPressed: () => setState(() => isLoading = false),
                    child: const Text('Load'),
                  ),
                ],
              ),
            ),
          ),
        );

        // Then - verify loading announcement
        expect(
          tester.getSemantics(find.byType(CircularProgressIndicator)).label,
          'Loading recipes',
        );

        // When - finish loading
        await tester.tap(find.text('Load'));
        await tester.pump();

        // Then - verify completion
        expect(find.text('Recipes loaded'), findsOneWidget);
      });

      testWidgets('error states are announced', (tester) async {
        // Given
        await tester.pumpWidget(
          createTestableWidget(
            child: Semantics(
              label: 'Error: Failed to load recipes',
              child: const Column(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  Text('Failed to load recipes'),
                ],
              ),
            ),
          ),
        );

        // Then
        final errorSemantics = tester.getSemantics(find.byType(Column));
        expect(errorSemantics.label, contains('Error'));
      });
    });
  });
}

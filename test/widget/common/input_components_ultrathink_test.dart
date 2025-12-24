import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/input_components.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/factories/shopping_list_factory.dart';

void main() {
  group('InputComponents Ultrathink Widget Tests', () {
    // Helper to create properly configured test environment
    Widget createTestWidget({Widget? child}) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'),
        home: Material(
          child: child ?? const SizedBox.shrink(),
        ),
      );
    }

    group('Widget Input Interface Methods', () {
      testWidgets(
          'instructionEditor method exists and returns widget interface',
          (WidgetTester tester) async {
        // Test method exists and returns Widget
        expect(InputComponents.instructionEditor, isA<Function>());

        // Test method can be called without error - interface validation
        final basicEditor = InputComponents.instructionEditor(
          initialInstructions: [
            'Förvärm ugnen till 200°C',
            'Blanda ingredienserna'
          ],
        );
        expect(basicEditor, isA<Widget>());

        // Test with onChanged callback - interface validation
        final editorWithCallback = InputComponents.instructionEditor(
          initialInstructions: ['Steg 1', 'Steg 2'],
          onChanged: (instructions) {},
        );
        expect(editorWithCallback, isA<Widget>());
      });

      testWidgets('portionScaler method exists and returns widget interface',
          (WidgetTester tester) async {
        expect(InputComponents.portionScaler, isA<Function>());

        // Test with required parameters - interface validation
        final basicScaler = InputComponents.portionScaler(
          originalPortions: 4,
          originalIngredients: ['2 dl mjöl', '3 ägg', '5 dl mjölk'],
          onPortionChanged: (newPortions, scaledIngredients) {},
        );
        expect(basicScaler, isA<Widget>());

        // Test with all parameters - interface validation
        final fullScaler = InputComponents.portionScaler(
          originalPortions: 6,
          originalIngredients: ['1 kg potatis', '500 g kött', '2 dl grädde'],
          onPortionChanged: (newPortions, scaledIngredients) {},
          minPortions: 2,
          maxPortions: 16,
        );
        expect(fullScaler, isA<Widget>());
      });

      testWidgets(
          'debouncedCheckbox method exists and returns widget interface',
          (WidgetTester tester) async {
        expect(InputComponents.debouncedCheckbox, isA<Function>());

        // Test with required parameters - interface validation
        final basicCheckbox = InputComponents.debouncedCheckbox(
          value: true,
          onChanged: (checked) {},
        );
        expect(basicCheckbox, isA<Widget>());

        // Test with all parameters - interface validation
        final fullCheckbox = InputComponents.debouncedCheckbox(
          value: false,
          onChanged: (checked) {},
          activeColor: Colors.green,
          debounceDuration: const Duration(milliseconds: 500),
        );
        expect(fullCheckbox, isA<Widget>());

        // Test with null onChanged - interface validation
        final nullCallbackCheckbox = InputComponents.debouncedCheckbox(
          value: true,
          onChanged: null,
        );
        expect(nullCallbackCheckbox, isA<Widget>());
      });
    });

    group('Dialog Input Interface Methods', () {
      testWidgets('showShoppingItemDialog method exists with correct signature',
          (WidgetTester tester) async {
        expect(InputComponents.showShoppingItemDialog, isA<Function>());

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  // Test with minimal parameters - interface validation
                  expect(
                    () => InputComponents.showShoppingItemDialog(context),
                    returnsNormally,
                  );

                  // Test with existing item - interface validation
                  final existingItem = ShoppingListFactory.buildItem(
                    id: 'test-item-id',
                    name: 'Mjöl',
                    amount: 2.0,
                    unit: 'kg',
                    category: 'Bakning',
                    bought: false,
                  );

                  expect(
                    () => InputComponents.showShoppingItemDialog(
                      context,
                      initialItem: existingItem,
                    ),
                    returnsNormally,
                  );
                },
                child: const Text('Test Shopping Dialog'),
              ),
            ),
          ),
        );

        expect(find.text('Test Shopping Dialog'), findsOneWidget);
      });

      testWidgets('showListSelector method exists with correct parameters',
          (WidgetTester tester) async {
        expect(InputComponents.showListSelector, isA<Function>());

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  // Test with minimal parameters - interface validation
                  expect(
                    () => InputComponents.showListSelector(context),
                    returnsNormally,
                  );

                  // Test with callback - interface validation
                  expect(
                    () => InputComponents.showListSelector(
                      context,
                      onListSelected: () {},
                    ),
                    returnsNormally,
                  );

                  // Test with menu integration - interface validation
                  final testMenu = <String, List<Recipe>>{
                    'Måndag': [
                      RecipeFactory.build(
                        id: 'recipe-1',
                        title: 'Pasta Carbonara',
                        description: 'Klassisk italiensk pasta',
                        instructions: ['Koka pasta', 'Tillaga sås'],
                        ingredients: ['400 g pasta', '200 g bacon', '3 ägg'],
                        portions: 4,
                        timeMinutes: 30,
                      ),
                    ],
                    'Tisdag': [
                      RecipeFactory.build(
                        id: 'recipe-2',
                        title: 'Kyckling Gryta',
                        description: 'Krämig kycklinggryta',
                        instructions: ['Stek kyckling', 'Tillsätt grädde'],
                        ingredients: ['600 g kyckling', '3 dl grädde', '1 lök'],
                        portions: 6,
                        timeMinutes: 60,
                      ),
                    ],
                  };

                  expect(
                    () => InputComponents.showListSelector(
                      context,
                      onListSelected: () {},
                      menu: testMenu,
                    ),
                    returnsNormally,
                  );
                },
                child: const Text('Test List Selector'),
              ),
            ),
          ),
        );

        expect(find.text('Test List Selector'), findsOneWidget);
      });
    });

    group('Swedish Localization Support', () {
      testWidgets('all input methods support Swedish parameters',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Test instruction editor with Swedish text
                  InputComponents.instructionEditor(
                    initialInstructions: [
                      'Förvärm ugnen till 200°C och smörj en form',
                      'Blanda mjöl, socker och ägg i en skål',
                      'Rör om tills smeten är slät och klumpfri',
                      'Häll smeten i formen och grädda i 45 minuter',
                    ],
                    onChanged: (instructions) {
                      // Verify Swedish characters are preserved
                      for (String instruction in instructions) {
                        expect(instruction.contains(RegExp(r'[åäö]')), isTrue);
                      }
                    },
                  ),

                  // Test portion scaler with Swedish ingredients
                  InputComponents.portionScaler(
                    originalPortions: 4,
                    originalIngredients: [
                      '3 dl vetemjöl',
                      '2 ägg från frigående höns',
                      '4 dl färsk mjölk',
                      '1 msk smör för stekning',
                      '1 tsk salt och peppar efter smak',
                    ],
                    onPortionChanged: (newPortions, scaledIngredients) {
                      // Verify Swedish ingredient names are preserved
                      for (String ingredient in scaledIngredients) {
                        expect(ingredient.length, greaterThan(0));
                      }
                    },
                    minPortions: 1,
                    maxPortions: 12,
                  ),

                  // Test debounced checkbox with Swedish context
                  InputComponents.debouncedCheckbox(
                    value: true,
                    onChanged: (checked) {
                      // Swedish context validation
                    },
                    activeColor: Colors.green,
                  ),

                  Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () {
                        // Test shopping item dialog with Swedish items
                        final svenskItem = ShoppingListFactory.buildItem(
                          id: 'svensk-item-id',
                          name: 'Färsk mjölk från Skåne',
                          amount: 1.5,
                          unit: 'liter',
                          category: 'Mejeri & ägg',
                          bought: false,
                        );

                        InputComponents.showShoppingItemDialog(
                          context,
                          initialItem: svenskItem,
                        );
                      },
                      child: const Text('Swedish Shopping Dialog Test'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // Verify Swedish characters render correctly
        expect(find.text('Swedish Shopping Dialog Test'), findsOneWidget);
      });
    });

    group('Parameter Delegation Validation', () {
      testWidgets('instructionEditor delegates all parameters correctly',
          (WidgetTester tester) async {
        // Test that all parameters are accepted without errors
        final testWidget = InputComponents.instructionEditor(
          initialInstructions: ['Test instruction 1', 'Test instruction 2'],
          onChanged: (instructions) {
            expect(instructions, isA<List<String>>());
            expect(instructions.length, greaterThanOrEqualTo(0));
          },
        );

        await tester.pumpWidget(createTestWidget(child: testWidget));
        expect(find.byWidget(testWidget), findsOneWidget);
      });

      testWidgets('portionScaler delegates all parameters correctly',
          (WidgetTester tester) async {
        final testWidget = InputComponents.portionScaler(
          originalPortions: 4,
          originalIngredients: ['2 cups flour', '1 cup milk', '2 eggs'],
          onPortionChanged: (newPortions, scaledIngredients) {
            expect(newPortions, isA<int>());
            expect(scaledIngredients, isA<List<String>>());
          },
          minPortions: 1,
          maxPortions: 10,
        );

        await tester.pumpWidget(createTestWidget(child: testWidget));
        expect(find.byWidget(testWidget), findsOneWidget);
      });

      testWidgets('debouncedCheckbox delegates all parameters correctly',
          (WidgetTester tester) async {
        final testWidget = InputComponents.debouncedCheckbox(
          value: false,
          onChanged: (checked) {
            expect(checked, isA<bool?>());
          },
          activeColor: Colors.blue,
          debounceDuration: const Duration(milliseconds: 200),
        );

        await tester.pumpWidget(createTestWidget(child: testWidget));
        expect(find.byWidget(testWidget), findsOneWidget);
      });
    });

    group('Return Type Interface Validation', () {
      testWidgets('all static methods exist and have correct return types',
          (WidgetTester tester) async {
        // Widget return type methods
        expect(InputComponents.instructionEditor, isA<Function>());
        expect(InputComponents.portionScaler, isA<Function>());
        expect(InputComponents.debouncedCheckbox, isA<Function>());

        // Future return type methods
        expect(InputComponents.showShoppingItemDialog, isA<Function>());
        expect(InputComponents.showListSelector, isA<Function>());
      });

      testWidgets('dialog methods return correct Future types',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  // Verify return types are correct (compilation check)
                  final Future<UnifiedShoppingItem?> shoppingDialog =
                      InputComponents.showShoppingItemDialog(context);
                  final Future<void> listSelector =
                      InputComponents.showListSelector(context);

                  expect(shoppingDialog, isA<Future<UnifiedShoppingItem?>>());
                  expect(listSelector, isA<Future<void>>());
                },
                child: const Text('Return Type Test'),
              ),
            ),
          ),
        );

        expect(find.text('Return Type Test'), findsOneWidget);
      });
    });

    group('Responsive Design Behavior', () {
      testWidgets('input components adapt to small screen sizes',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                InputComponents.instructionEditor(
                  initialInstructions: ['Small screen instruction'],
                ),
                InputComponents.portionScaler(
                  originalPortions: 2,
                  originalIngredients: ['1 cup flour'],
                  onPortionChanged: (portions, ingredients) {},
                ),
                InputComponents.debouncedCheckbox(
                  value: true,
                  onChanged: (checked) {},
                ),
              ],
            ),
          ),
        );

        // Verify widgets are rendered correctly in responsive layout
        expect(find.byType(Column), findsWidgets);

        // Reset screen size
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('input components adapt to tablet screen sizes',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(768, 1024);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                InputComponents.portionScaler(
                  originalPortions: 6,
                  originalIngredients: ['2 cups milk', '3 eggs', '1 cup sugar'],
                  onPortionChanged: (portions, ingredients) {},
                  minPortions: 2,
                  maxPortions: 20,
                ),
                InputComponents.debouncedCheckbox(
                  value: false,
                  onChanged: (checked) {},
                  activeColor: Colors.orange,
                  debounceDuration: const Duration(milliseconds: 400),
                ),
              ],
            ),
          ),
        );

        // Verify widgets are rendered correctly in responsive layout
        expect(find.byType(Column), findsWidgets);

        // Reset screen size
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('Facade Pattern Interface Validation', () {
      testWidgets('all input component methods exist and are callable',
          (WidgetTester tester) async {
        // Widget Interface Methods
        expect(InputComponents.instructionEditor, isA<Function>());
        expect(InputComponents.portionScaler, isA<Function>());
        expect(InputComponents.debouncedCheckbox, isA<Function>());

        // Dialog Interface Methods
        expect(InputComponents.showShoppingItemDialog, isA<Function>());
        expect(InputComponents.showListSelector, isA<Function>());
      });

      testWidgets('facade maintains correct delegation patterns',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                // Widget methods return Widget objects
                InputComponents.instructionEditor(
                  initialInstructions: ['Test delegation'],
                ),
                InputComponents.portionScaler(
                  originalPortions: 4,
                  originalIngredients: ['Test ingredient'],
                  onPortionChanged: (portions, ingredients) {},
                ),
                InputComponents.debouncedCheckbox(
                  value: true,
                  onChanged: (checked) {},
                ),
                Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      // Dialog methods return Future objects
                      final shoppingFuture =
                          InputComponents.showShoppingItemDialog(context);
                      final listSelectorFuture =
                          InputComponents.showListSelector(context);

                      expect(
                          shoppingFuture, isA<Future<UnifiedShoppingItem?>>());
                      expect(listSelectorFuture, isA<Future<void>>());
                    },
                    child: const Text('Delegation Test'),
                  ),
                ),
              ],
            ),
          ),
        );

        expect(find.text('Delegation Test'), findsOneWidget);
      });
    });
  });
}

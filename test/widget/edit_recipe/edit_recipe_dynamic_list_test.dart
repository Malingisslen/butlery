import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/views/edit_recipe/edit_recipe_dynamic_list.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

// StatefulWidget wrapper for testing dynamic list behavior
class _DynamicListTestWrapper extends StatefulWidget {
  final String label;
  final List<TextEditingController> initialControllers;
  final List<String> initialItems;
  
  const _DynamicListTestWrapper({
    required this.label,
    required this.initialControllers,
    required this.initialItems,
  });
  
  @override
  State<_DynamicListTestWrapper> createState() => _DynamicListTestWrapperState();
}

class _DynamicListTestWrapperState extends State<_DynamicListTestWrapper> {
  late List<TextEditingController> controllers;
  late List<String> items;
  
  @override
  void initState() {
    super.initState();
    controllers = List.from(widget.initialControllers);
    items = List.from(widget.initialItems);
  }
  
  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  void _onUpdate(int index, String value) {
    if (mounted && index < items.length) {
      setState(() {
        items[index] = value;
      });
    }
  }
  
  void _onAdd() {
    if (mounted) {
      setState(() {
        controllers.add(TextEditingController());
        items.add('');
      });
    }
  }
  
  void _onRemove(int index) {
    if (mounted && index < controllers.length) {
      setState(() {
        controllers[index].dispose();
        controllers.removeAt(index);
        items.removeAt(index);
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return EditRecipeDynamicList.build(
      context: context,
      label: widget.label,
      controllers: controllers,
      onUpdate: _onUpdate,
      onAdd: _onAdd,
      onRemove: _onRemove,
    );
  }
}

void main() {
  setUp(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('EditRecipeDynamicList Widget Tests', () {
    Widget createTestWidget({
      required String label,
      List<TextEditingController>? initialControllers,
      List<String>? initialItems,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _DynamicListTestWrapper(
                label: label,
                initialControllers: initialControllers ?? [],
                initialItems: initialItems ?? [],
              ),
            ),
          ),
        ),
      );
    }

    group('Basic Rendering', () {
      testWidgets('renders with label and empty list', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            label: 'Ingredienser',
          ),
        );

        expect(find.text('Ingredienser'), findsOneWidget);
        expect(find.text('Lägg till Ingredienser'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing); // No fields yet
      });

      testWidgets('renders with existing items', (WidgetTester tester) async {
        final initialControllers = [
          TextEditingController(text: '2 dl mjölk'),
          TextEditingController(text: '3 ägg'),
          TextEditingController(text: '1 dl mjöl'),
        ];
        final initialItems = ['2 dl mjölk', '3 ägg', '1 dl mjöl'];

        await tester.pumpWidget(
          createTestWidget(
            label: 'Ingredienser',
            initialControllers: initialControllers,
            initialItems: initialItems,
          ),
        );

        expect(find.text('Ingredienser'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(3));
        expect(find.text('2 dl mjölk'), findsOneWidget);
        expect(find.text('3 ägg'), findsOneWidget);
        expect(find.text('1 dl mjöl'), findsOneWidget);
        expect(find.byIcon(Icons.delete), findsNWidgets(3));
        expect(find.text('Lägg till Ingredienser'), findsOneWidget);
      });

      testWidgets('hides delete button for single item', (WidgetTester tester) async {
        final initialControllers = [TextEditingController(text: 'Single item')];
        final initialItems = ['Single item'];

        await tester.pumpWidget(
          createTestWidget(
            label: 'Ingredienser',
            initialControllers: initialControllers,
            initialItems: initialItems,
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.byIcon(Icons.delete), findsNothing);
      });
    });

    group('Adding Items', () {
      testWidgets('adds new item when add button is pressed', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            label: 'Ingredienser',
          ),
        );

        // Initial state
        expect(find.byType(TextFormField), findsNothing);

        // Add first item
        await tester.tap(find.text('Lägg till Ingredienser'));
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Ingredienser 1'), findsOneWidget); // Check hint text
      });

      testWidgets('can add multiple items sequentially', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            label: 'Instruktioner',
          ),
        );

        // Add first item
        await tester.tap(find.text('Lägg till Instruktioner'));
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsOneWidget);

        // Enter text in first field to enable add button
        await tester.enterText(find.byType(TextFormField), 'First instruction');
        await tester.pumpAndSettle();

        // Add second item
        await tester.tap(find.text('Lägg till Instruktioner'));
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNWidgets(2));

        // Enter text in second field
        await tester.enterText(find.byType(TextFormField).last, 'Second instruction');
        await tester.pumpAndSettle();

        // Add third item
        await tester.tap(find.text('Lägg till Instruktioner'));
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNWidgets(3));
      });
    });

    group('Removing Items', () {
      testWidgets('removes item when delete button is pressed', (WidgetTester tester) async {
        final initialControllers = [
          TextEditingController(text: '2 dl mjölk'),
          TextEditingController(text: '3 ägg'),
        ];
        final initialItems = ['2 dl mjölk', '3 ägg'];

        await tester.pumpWidget(
          createTestWidget(
            label: 'Ingredienser',
            initialControllers: initialControllers,
            initialItems: initialItems,
          ),
        );

        expect(find.byType(TextFormField), findsNWidgets(2));

        // Remove first item
        await tester.tap(find.byIcon(Icons.delete).first);
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('3 ägg'), findsOneWidget); // Second item should remain
      });
    });

    group('Text Input', () {
      testWidgets('handles text input correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            label: 'Ingredienser',
          ),
        );

        // Add an item
        await tester.tap(find.text('Lägg till Ingredienser'));
        await tester.pumpAndSettle();

        // Enter text
        await tester.enterText(find.byType(TextFormField), 'Test ingredient');
        await tester.pumpAndSettle();

        // Verify text appears
        expect(find.text('Test ingredient'), findsOneWidget);
      });
    });

    group('Add Button Visibility', () {
      testWidgets('shows add button when last item has content', (WidgetTester tester) async {
        final initialControllers = [TextEditingController(text: 'Content')];
        final initialItems = ['Content'];

        await tester.pumpWidget(
          createTestWidget(
            label: 'Ingredienser',
            initialControllers: initialControllers,
            initialItems: initialItems,
          ),
        );

        expect(find.text('Lägg till Ingredienser'), findsOneWidget);
      });

      testWidgets('hides add button when last item is empty', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            label: 'Ingredienser',
          ),
        );

        // Add empty item
        await tester.tap(find.text('Lägg till Ingredienser'));
        await tester.pumpAndSettle();

        // Add button should be hidden since last item is empty
        await tester.pump();
        expect(find.text('Lägg till Ingredienser'), findsNothing);
      });
    });

    group('Layout and Styling', () {
      testWidgets('has proper spacing between elements', (WidgetTester tester) async {
        final initialControllers = [
          TextEditingController(text: 'Item 1'),
          TextEditingController(text: 'Item 2'),
        ];
        final initialItems = ['Item 1', 'Item 2'];

        await tester.pumpWidget(
          createTestWidget(
            label: 'Ingredienser',
            initialControllers: initialControllers,
            initialItems: initialItems,
          ),
        );

        // Check that Padding widgets exist for spacing
        expect(find.byType(Padding), findsWidgets);
        expect(find.byType(SizedBox), findsWidgets);
      });

      testWidgets('add button has icon and text', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            label: 'Ingredienser',
          ),
        );

        // The production code uses TextButton.icon, so find by the text content
        expect(find.text('Lägg till Ingredienser'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
        
        // Verify it's a clickable button by tapping it
        await tester.tap(find.text('Lägg till Ingredienser'));
        await tester.pumpAndSettle();
        
        // Should add a field
        expect(find.byType(TextFormField), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('handles empty controller list', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            label: 'Ingredienser',
            initialControllers: [],
            initialItems: [],
          ),
        );

        expect(find.text('Ingredienser'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        expect(find.text('Lägg till Ingredienser'), findsOneWidget);
      });
    });
  });
}
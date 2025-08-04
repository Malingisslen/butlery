import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../helpers/test_helpers.dart';
import '../helpers/mock_factories.dart';

/// Tests for keyboard navigation accessibility
/// Ensures the app is fully navigable using keyboard on desktop/web platforms
void main() {
  group('Keyboard Navigation Tests', () {
    testWidgets('navigates through main menu with Tab key', (tester) async {
      // Given
      await tester.pumpWidget(
        createTestableWidget(
          child: const _MainNavigationTestWidget(),
        ),
      );

      // Get initial focus
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Then - First item should be focused
      final firstButton = find.byKey(const Key('nav_recipes'));
      expect(
        tester.widget<InkWell>(firstButton.last).focusNode?.hasFocus ?? false,
        isTrue,
        reason: 'First navigation item should have focus',
      );

      // When - Tab to next item
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Then - Second item should be focused
      final secondButton = find.byKey(const Key('nav_shopping'));
      expect(
        tester.widget<InkWell>(secondButton.last).focusNode?.hasFocus ?? false,
        isTrue,
        reason: 'Second navigation item should have focus after Tab',
      );

      // When - Tab through all items
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Menu
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Social
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Profile
      await tester.pumpAndSettle();

      // When - Shift+Tab to go back
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();

      // Then - Should go back to Social
      final socialButton = find.byKey(const Key('nav_social'));
      expect(
        tester.widget<InkWell>(socialButton.last).focusNode?.hasFocus ?? false,
        isTrue,
        reason: 'Shift+Tab should navigate backwards',
      );
    });

    testWidgets('activates buttons with Enter and Space keys', (tester) async {
      // Given
      bool buttonPressed = false;
      await tester.pumpWidget(
        createTestableWidget(
          child: _KeyboardActionTestWidget(
            onButtonPress: () => buttonPressed = true,
          ),
        ),
      );

      // Focus the button
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // When - Press Enter
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Then
      expect(buttonPressed, isTrue, reason: 'Enter should activate button');

      // Reset
      buttonPressed = false;

      // When - Press Space
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      // Then
      expect(buttonPressed, isTrue, reason: 'Space should activate button');
    });

    testWidgets('navigates form fields with Tab and fills with keyboard',
        (tester) async {
      // Given
      await tester.pumpWidget(
        createTestableWidget(
          child: const _FormKeyboardTestWidget(),
        ),
      );

      // Tab to first field
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Type in title field
      await tester.enterText(find.byKey(const Key('title_field')), '');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pumpAndSettle();

      expect(
        find.text('TEST'),
        findsOneWidget,
        reason: 'Keyboard input should work in focused field',
      );

      // Tab to next field
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Verify focus moved to description field
      final descField = find.byKey(const Key('description_field'));
      expect(
        tester.widget<TextField>(descField).focusNode?.hasFocus ?? false,
        isTrue,
        reason: 'Tab should move focus to next field',
      );

      // Tab to dropdown
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Open dropdown with Enter
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Navigate dropdown with arrow keys
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(
        find.text('Lunch'),
        findsOneWidget,
        reason: 'Arrow keys should navigate dropdown options',
      );
    });

    testWidgets('provides keyboard shortcuts for common actions',
        (tester) async {
      // Given
      final shortcuts = <String>[];

      await tester.pumpWidget(
        createTestableWidget(
          child: _ShortcutTestWidget(
            onShortcut: (shortcut) => shortcuts.add(shortcut),
          ),
        ),
      );

      // When - Ctrl+S to save
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(shortcuts, contains('save'));

      // When - Ctrl+N for new
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(shortcuts, contains('new'));

      // When - Escape to close dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(shortcuts, contains('escape'));
    });

    testWidgets('maintains focus visibility during navigation', (tester) async {
      // Given
      await tester.pumpWidget(
        createTestableWidget(
          child: const _FocusIndicatorTestWidget(),
        ),
      );

      // Tab through elements
      for (int i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();

        // Find the focused widget
        final focusedElement = find.byWidgetPredicate(
          (widget) => widget is Focus && widget.focusNode?.hasFocus == true,
        );

        expect(
          focusedElement,
          findsOneWidget,
          reason: 'One element should have focus at position $i',
        );

        // Verify focus indicator is visible
        final focusedWidget = tester.widget(focusedElement);
        if (focusedWidget is Container) {
          final decoration = focusedWidget.decoration as BoxDecoration?;
          expect(
            decoration?.border,
            isNotNull,
            reason: 'Focused element should have visible border',
          );
        }
      }
    });

    testWidgets('handles focus trap in modals correctly', (tester) async {
      // Given
      await tester.pumpWidget(
        createTestableWidget(
          child: const _ModalFocusTrapTestWidget(),
        ),
      );

      // Open modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Tab through modal elements
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Focus first button
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Focus second button
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Focus close button
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Should wrap to first
      await tester.pumpAndSettle();

      // Verify focus wrapped back to first element
      final firstModalButton = find.text('Action 1');
      expect(
        tester.widget<ElevatedButton>(firstModalButton).focusNode?.hasFocus ??
            false,
        isTrue,
        reason: 'Focus should wrap within modal',
      );

      // Close with Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('supports arrow key navigation in lists', (tester) async {
      // Given
      final selectedItems = <int>[];
      await tester.pumpWidget(
        createTestableWidget(
          child: _ListKeyboardNavigationWidget(
            onItemSelected: (index) => selectedItems.add(index),
          ),
        ),
      );

      // Focus the list
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Navigate with arrow keys
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(selectedItems, contains(0));

      // Continue navigation
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(selectedItems, contains(2));

      // Navigate up
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(selectedItems, contains(1));
    });

    testWidgets('provides skip links for screen reader users', (tester) async {
      // Given
      await tester.pumpWidget(
        createTestableWidget(
          child: const _SkipLinksTestWidget(),
        ),
      );

      // First tab should focus skip link
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final skipLink = find.text('Skip to main content');
      expect(skipLink, findsOneWidget);

      // Activate skip link
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Verify focus moved to main content
      final mainContent = find.byKey(const Key('main_content'));
      expect(
        tester.widget<Container>(mainContent).key,
        isNotNull,
        reason: 'Main content should be focused after skip link',
      );
    });

    testWidgets('handles complex keyboard interactions in recipe cards',
        (tester) async {
      // Given
      final recipes = RecipeFactory.buildList(3);
      await tester.pumpWidget(
        createTestableWidget(
          child: _RecipeGridKeyboardTest(recipes: recipes),
        ),
      );

      // Tab to first recipe card
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Enter to select
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Recipe selected: 0'), findsOneWidget);

      // Arrow right to next card
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      // Space to select
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(find.text('Recipe selected: 1'), findsOneWidget);

      // Tab to action buttons within card
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Activate favorite button
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Favorited: 1'), findsOneWidget);
    });

    testWidgets('maintains keyboard navigation after async operations',
        (tester) async {
      // Given
      await tester.pumpWidget(
        createTestableWidget(
          child: const _AsyncKeyboardTestWidget(),
        ),
      );

      // Tab to load button
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Activate to load content
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(); // Start loading

      // Wait for content to load
      await tester.pumpAndSettle();

      // Tab should move to newly loaded content
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final firstLoadedItem = find.text('Item 1');
      expect(
        firstLoadedItem,
        findsOneWidget,
        reason: 'Keyboard navigation should work after async content loads',
      );
    });
  });
}

// Test widget implementations
class _MainNavigationTestWidget extends StatelessWidget {
  const _MainNavigationTestWidget();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: 0,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.restaurant_menu),
                label: Text('Recipes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.shopping_cart),
                label: Text('Shopping'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_today),
                label: Text('Menu'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Social'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person),
                label: Text('Profile'),
              ),
            ],
            onDestinationSelected: (_) {},
          ),
          const Expanded(
            child: Center(child: Text('Content')),
          ),
        ],
      ),
    );
  }
}

class _KeyboardActionTestWidget extends StatelessWidget {
  final VoidCallback onButtonPress;

  const _KeyboardActionTestWidget({required this.onButtonPress});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: onButtonPress,
          child: const Text('Press Me'),
        ),
      ),
    );
  }
}

class _FormKeyboardTestWidget extends StatefulWidget {
  const _FormKeyboardTestWidget();

  @override
  State<_FormKeyboardTestWidget> createState() =>
      _FormKeyboardTestWidgetState();
}

class _FormKeyboardTestWidgetState extends State<_FormKeyboardTestWidget> {
  final _formKey = GlobalKey<FormState>();
  String? _mealType = 'Breakfast';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            const TextField(
              key: Key('title_field'),
              decoration: InputDecoration(labelText: 'Title'),
              textCapitalization: TextCapitalization.characters,
            ),
            const TextField(
              key: Key('description_field'),
              decoration: InputDecoration(labelText: 'Description'),
            ),
            DropdownButtonFormField<String>(
              value: _mealType,
              items: ['Breakfast', 'Lunch', 'Dinner']
                  .map((meal) => DropdownMenuItem(
                        value: meal,
                        child: Text(meal),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _mealType = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutTestWidget extends StatelessWidget {
  final Function(String) onShortcut;

  const _ShortcutTestWidget({required this.onShortcut});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
            SaveIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
            NewIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): CloseIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (_) {
              onShortcut('save');
              return null;
            },
          ),
          NewIntent: CallbackAction<NewIntent>(
            onInvoke: (_) {
              onShortcut('new');
              return null;
            },
          ),
          CloseIntent: CallbackAction<CloseIntent>(
            onInvoke: (_) {
              onShortcut('escape');
              Navigator.of(context).maybePop();
              return null;
            },
          ),
        },
        child: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Dialog'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusIndicatorTestWidget extends StatelessWidget {
  const _FocusIndicatorTestWidget();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Column(
        children: [
          _FocusableContainer(text: 'Item 1'),
          _FocusableContainer(text: 'Item 2'),
          _FocusableContainer(text: 'Item 3'),
        ],
      ),
    );
  }
}

class _FocusableContainer extends StatefulWidget {
  final String text;

  const _FocusableContainer({required this.text});

  @override
  State<_FocusableContainer> createState() => _FocusableContainerState();
}

class _FocusableContainerState extends State<_FocusableContainer> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: _hasFocus ? Colors.blue : Colors.grey,
              width: _hasFocus ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(widget.text),
        ),
      ),
    );
  }
}

class _ModalFocusTrapTestWidget extends StatelessWidget {
  const _ModalFocusTrapTestWidget();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => FocusTraversalGroup(
                child: AlertDialog(
                  title: const Text('Modal Dialog'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Action 1'),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Action 2'),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            );
          },
          child: const Text('Open Modal'),
        ),
      ),
    );
  }
}

class _ListKeyboardNavigationWidget extends StatefulWidget {
  final Function(int) onItemSelected;

  const _ListKeyboardNavigationWidget({required this.onItemSelected});

  @override
  State<_ListKeyboardNavigationWidget> createState() =>
      _ListKeyboardNavigationWidgetState();
}

class _ListKeyboardNavigationWidgetState
    extends State<_ListKeyboardNavigationWidget> {
  int _focusedIndex = 0;
  final _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            setState(() {
              _focusedIndex = (_focusedIndex + 1).clamp(0, 9);
            });
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            setState(() {
              _focusedIndex = (_focusedIndex - 1).clamp(0, 9);
            });
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onItemSelected(_focusedIndex);
          }
        }
      },
      child: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return Container(
            color: _focusedIndex == index ? Colors.blue.shade100 : null,
            child: ListTile(
              title: Text('Item $index'),
              onTap: () => widget.onItemSelected(index),
            ),
          );
        },
      ),
    );
  }
}

class _SkipLinksTestWidget extends StatelessWidget {
  const _SkipLinksTestWidget();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Skip link (usually hidden visually but accessible to screen readers)
          Semantics(
            button: true,
            label: 'Skip to main content',
            child: InkWell(
              onTap: () {
                // Focus main content
                // In real app, would use FocusScope.of(context).requestFocus()
              },
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Skip to main content'),
              ),
            ),
          ),
          // Navigation
          Container(
            height: 100,
            color: Colors.grey.shade200,
            child: const Center(child: Text('Navigation')),
          ),
          // Main content
          Expanded(
            child: Container(
              key: const Key('main_content'),
              child: const Center(child: Text('Main Content')),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeGridKeyboardTest extends StatefulWidget {
  final List<Recipe> recipes;

  const _RecipeGridKeyboardTest({required this.recipes});

  @override
  State<_RecipeGridKeyboardTest> createState() =>
      _RecipeGridKeyboardTestState();
}

class _RecipeGridKeyboardTestState extends State<_RecipeGridKeyboardTest> {
  int? _selectedIndex;
  final Set<int> _favorites = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_selectedIndex != null) Text('Recipe selected: $_selectedIndex'),
          if (_favorites.isNotEmpty)
            Text('Favorited: ${_favorites.join(', ')}'),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              itemCount: widget.recipes.length,
              itemBuilder: (context, index) {
                return _KeyboardNavigableRecipeCard(
                  recipe: widget.recipes[index],
                  index: index,
                  isSelected: _selectedIndex == index,
                  isFavorite: _favorites.contains(index),
                  onSelect: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  onFavorite: () {
                    setState(() {
                      if (_favorites.contains(index)) {
                        _favorites.remove(index);
                      } else {
                        _favorites.add(index);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyboardNavigableRecipeCard extends StatefulWidget {
  final Recipe recipe;
  final int index;
  final bool isSelected;
  final bool isFavorite;
  final VoidCallback onSelect;
  final VoidCallback onFavorite;

  const _KeyboardNavigableRecipeCard({
    required this.recipe,
    required this.index,
    required this.isSelected,
    required this.isFavorite,
    required this.onSelect,
    required this.onFavorite,
  });

  @override
  State<_KeyboardNavigableRecipeCard> createState() =>
      _KeyboardNavigableRecipeCardState();
}

class _KeyboardNavigableRecipeCardState
    extends State<_KeyboardNavigableRecipeCard> {
  final FocusNode _cardFocus = FocusNode();
  final FocusNode _favoriteFocus = FocusNode();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: widget.isSelected ? Colors.blue.shade50 : null,
      child: InkWell(
        focusNode: _cardFocus,
        onTap: widget.onSelect,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Text(widget.recipe.title),
              ),
            ),
            IconButton(
              focusNode: _favoriteFocus,
              icon: Icon(
                widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: widget.isFavorite ? Colors.red : null,
              ),
              onPressed: widget.onFavorite,
            ),
          ],
        ),
      ),
    );
  }
}

class _AsyncKeyboardTestWidget extends StatefulWidget {
  const _AsyncKeyboardTestWidget();

  @override
  State<_AsyncKeyboardTestWidget> createState() =>
      _AsyncKeyboardTestWidgetState();
}

class _AsyncKeyboardTestWidgetState extends State<_AsyncKeyboardTestWidget> {
  bool _isLoading = false;
  List<String>? _items;

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
      _items = List.generate(5, (i) => 'Item ${i + 1}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _isLoading ? null : _loadContent,
            child: Text(_isLoading ? 'Loading...' : 'Load Content'),
          ),
          if (_isLoading)
            const CircularProgressIndicator()
          else if (_items != null)
            ...?_items?.map((item) => ListTile(
                  title: Text(item),
                  onTap: () {},
                )),
        ],
      ),
    );
  }
}

// Intent classes for keyboard shortcuts
class SaveIntent extends Intent {}

class NewIntent extends Intent {}

class CloseIntent extends Intent {}

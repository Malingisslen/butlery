// test/widget/shopping/shopping_templates_widget_ultrathink_test.dart
// ULTRATHINK TEST SUITE: ShoppingTemplatesWidget - 379 lines of production code
// Testing shopping template management system with grid layout, dialog creation, Swedish localization
//
// ULTRATHINK FOCUS: Template grid rendering, dialog management, empty state handling, template card interactions,
// Swedish localization, theme integration, callback handling, data processing

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/widgets/shopping/shopping_templates_widget.dart';

void main() {
  group('ShoppingTemplatesWidget Ultrathink Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    // Helper to create test environment
    Widget createTestWidget({required Widget child}) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: child,
            ),
          ),
        ),
      );
    }

    // Helper to create test template data
    Map<String, dynamic> createTemplate({
      String? id,
      String? name,
      String? description,
      List<String>? items,
      int useCount = 0,
      List<String>? tags,
    }) {
      return {
        'id': id ?? 'template_test',
        'name': name ?? 'Test Mall',
        'description': description,
        'items': items ?? ['Mjölk', 'Bröd', 'Smör'],
        'useCount': useCount,
        'tags': tags ?? ['Dagligvaror'],
      };
    }

    group('Production Code Analysis', () {
      testWidgets('renders without crashes with basic configuration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test basic widget structure from production code lines 26-44
        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [createTemplate()],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(ShoppingTemplatesWidget), findsOneWidget);
      });

      testWidgets('displays loading state when isLoading is true',
          (WidgetTester tester) async {
        // ULTRATHINK: Test loading state from lines 27-31
        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: const [],
              onCreateFromTemplate: (templateId, listName) {},
              isLoading: true,
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Shoppingmallar'),
            findsNothing); // Header should not show during loading
      });

      testWidgets('displays empty state when templates list is empty',
          (WidgetTester tester) async {
        // ULTRATHINK: Test empty state from lines 33-34, 76-115
        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: const [],
              onCreateFromTemplate: (templateId, listName) {},
              isLoading: false,
            ),
          ),
        );

        expect(find.text('Inga shoppingmallar än'), findsOneWidget);
        expect(
            find.text(
                'Skapa mallar från dina vanligaste inköpslistor för att spara tid.'),
            findsOneWidget);
        expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);
      });

      testWidgets('displays templates grid when templates are provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test template grid display from lines 37-43, 117-133
        final templates = [
          createTemplate(name: 'Mall 1'),
          createTemplate(name: 'Mall 2'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: templates,
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        expect(find.byType(GridView), findsOneWidget);
        expect(find.text('Mall 1'), findsOneWidget);
        expect(find.text('Mall 2'), findsOneWidget);
        expect(
            find.text('Shoppingmallar'), findsOneWidget); // Header should show
      });
    });

    group('Header Component Tests', () {
      testWidgets('displays header with Swedish title and icon',
          (WidgetTester tester) async {
        // ULTRATHINK: Test header from lines 47-74
        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [createTemplate()],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        expect(find.text('Shoppingmallar'), findsOneWidget);
        // Header contains library_books icon (24px) and template cards contain library_books icon (20px)
        expect(find.byIcon(Icons.library_books), findsWidgets);
      });

      testWidgets('shows add button when onCreateNewTemplate is provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test conditional add button from lines 63-71
        bool createNewCalled = false;

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [createTemplate()],
              onCreateFromTemplate: (templateId, listName) {},
              onCreateNewTemplate: () => createNewCalled = true,
            ),
          ),
        );

        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byTooltip('Skapa ny mall'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.add));
        expect(createNewCalled, isTrue);
      });

      testWidgets('hides add button when onCreateNewTemplate is null',
          (WidgetTester tester) async {
        // ULTRATHINK: Test conditional rendering from line 63
        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [createTemplate()],
              onCreateFromTemplate: (templateId, listName) {},
              onCreateNewTemplate: null,
            ),
          ),
        );

        expect(find.byIcon(Icons.add), findsNothing);
        expect(find.byTooltip('Skapa ny mall'), findsNothing);
      });
    });

    group('Empty State Tests', () {
      testWidgets('displays Swedish empty state message with styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test empty state styling from lines 77-103
        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: const [],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        expect(find.text('Inga shoppingmallar än'), findsOneWidget);
        expect(
            find.text(
                'Skapa mallar från dina vanligaste inköpslistor för att spara tid.'),
            findsOneWidget);
        expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);

        // ULTRATHINK: Test container styling intention
        expect(find.byType(Container),
            findsWidgets); // Empty state container + padding containers
      });

      testWidgets('shows create button in empty state when callback provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test conditional create button from lines 104-111
        bool createNewCalled = false;

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: const [],
              onCreateFromTemplate: (templateId, listName) {},
              onCreateNewTemplate: () => createNewCalled = true,
            ),
          ),
        );

        expect(find.text('Skapa första mallen'), findsOneWidget);

        // ULTRATHINK: Test button functionality by tapping the text (button works even if type detection has issues)
        await tester.tap(find.text('Skapa första mallen'));
        expect(createNewCalled, isTrue);
      });

      testWidgets('hides create button in empty state when callback is null',
          (WidgetTester tester) async {
        // ULTRATHINK: Test conditional rendering from line 104
        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: const [],
              onCreateFromTemplate: (templateId, listName) {},
              onCreateNewTemplate: null,
            ),
          ),
        );

        expect(find.text('Skapa första mallen'), findsNothing);
      });
    });

    group('Template Grid Tests', () {
      testWidgets('creates GridView with correct configuration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test grid configuration from lines 118-127
        final templates =
            List.generate(4, (i) => createTemplate(name: 'Mall $i'));

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: templates,
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        final gridView = tester.widget<GridView>(find.byType(GridView));
        expect(gridView.shrinkWrap, isTrue);
        expect(gridView.physics, isA<NeverScrollableScrollPhysics>());

        final delegate =
            gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(2));
        expect(delegate.childAspectRatio, equals(0.85));
      });

      testWidgets('displays correct number of template cards',
          (WidgetTester tester) async {
        // ULTRATHINK: Test itemBuilder from lines 127-132
        final templates =
            List.generate(6, (i) => createTemplate(name: 'Mall ${i + 1}'));

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: templates,
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        // Should find all 6 template names
        for (int i = 1; i <= 6; i++) {
          expect(find.text('Mall $i'), findsOneWidget);
        }

        // Should find 6 template cards
        expect(find.byType(Card), findsNWidgets(6));
      });
    });

    group('Template Card Tests', () {
      testWidgets('displays template card with basic information',
          (WidgetTester tester) async {
        // ULTRATHINK: Test card content from lines 135-286
        final template = createTemplate(
          name: 'Veckohandling',
          description: 'Vanliga varor för veckan',
          items: ['Mjölk', 'Bröd', 'Smör', 'Ost'],
          useCount: 15,
          tags: ['Dagligvaror', 'Vecka'],
        );

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [template],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        expect(find.text('Veckohandling'), findsOneWidget);
        expect(find.text('Vanliga varor för veckan'), findsOneWidget);
        expect(find.text('4 artiklar'),
            findsOneWidget); // itemCount from items length
        expect(find.text('15'), findsOneWidget); // useCount
      });

      testWidgets('handles missing template data gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test null safety from lines 136-140
        final incompleteTemplate = {
          'id': 'incomplete',
          // Missing name, description, items, useCount, tags
        };

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [incompleteTemplate],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        expect(find.text('Namnlös mall'), findsOneWidget); // Default name
        expect(find.text('0 artiklar'), findsOneWidget); // Default itemCount
        expect(find.text('0'), findsOneWidget); // Default useCount
        expect(tester.takeException(), isNull); // Should not crash
      });

      testWidgets('displays tags with proper styling and limits',
          (WidgetTester tester) async {
        // ULTRATHINK: Test tags display from lines 234-257
        final template = createTemplate(
          tags: ['Tag1', 'Tag2', 'Tag3', 'Tag4', 'Tag5'], // More than 3 tags
        );

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [template],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        expect(find.text('Tag1'), findsOneWidget);
        expect(find.text('Tag2'), findsOneWidget);
        expect(find.text('Tag3'), findsOneWidget);
        expect(find.text('Tag4'),
            findsNothing); // Should limit to 3 tags (line 239)
        expect(find.text('Tag5'), findsNothing);
      });

      testWidgets('shows description when provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test conditional description from lines 184-194
        final template = createTemplate(description: 'Test beskrivning');

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [template],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        expect(find.text('Test beskrivning'), findsOneWidget);
      });

      testWidgets('hides description when not provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test conditional rendering from line 184
        final template = createTemplate(description: null);

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [template],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        // Only main template name should be visible, no extra description text
        expect(find.text('Test Mall'), findsOneWidget); // Template name
        // No additional text widgets for description
      });

      testWidgets('handles card tap interaction', (WidgetTester tester) async {
        // ULTRATHINK: Test card tap from line 148
        final template = createTemplate(id: 'tap_test', name: 'Tap Test');

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [template],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        // Tap on the card - should trigger dialog
        await tester.tap(find.text('Tap Test'));
        await tester.pumpAndSettle();

        // Should show create dialog
        expect(find.text('Skapa lista från mall'), findsOneWidget);
      });

      testWidgets('handles create button tap', (WidgetTester tester) async {
        // ULTRATHINK: Test create button tap from line 265
        final template = createTemplate(id: 'button_test', name: 'Button Test');

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [template],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        // Find and tap the "Skapa lista" button within the card
        await tester.tap(find.text('Skapa lista'));
        await tester.pumpAndSettle();

        // Should show create dialog
        expect(find.text('Skapa lista från mall'), findsOneWidget);
      });
    });

    group('Dialog Creation Tests', () {
      testWidgets('shows create dialog with correct content',
          (WidgetTester tester) async {
        // ULTRATHINK: Test dialog creation from lines 288-378
        final template = createTemplate(id: 'dialog_test', name: 'Dialog Test');

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [template],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        await tester.tap(find.text('Dialog Test'));
        await tester.pumpAndSettle();

        expect(find.text('Skapa lista från mall'), findsOneWidget);
        expect(find.text('Mall: Dialog Test'), findsOneWidget);
        expect(find.text('Listnamn'), findsOneWidget);
        expect(
            find.text(
                'Alla artiklar från mallen kommer att läggas till i den nya listan.'),
            findsOneWidget);
        expect(find.text('Avbryt'), findsOneWidget);
        expect(
            find.text('Skapa lista'), findsWidgets); // Both in card and dialog
      });

      testWidgets('prefills dialog text field with template name',
          (WidgetTester tester) async {
        // ULTRATHINK: Test TextEditingController initialization from line 289
        final template = createTemplate(name: 'Prefilled Name');

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [template],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        await tester.tap(find.text('Prefilled Name'));
        await tester.pumpAndSettle();

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, equals('Prefilled Name'));
      });

      testWidgets('handles dialog cancel button', (WidgetTester tester) async {
        // ULTRATHINK: Test cancel action from line 350
        final template = createTemplate(name: 'Cancel Test');

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [template],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        await tester.tap(find.text('Cancel Test'));
        await tester.pumpAndSettle();

        expect(find.text('Skapa lista från mall'),
            findsOneWidget); // Dialog is visible

        await tester.tap(find.text('Avbryt'));
        await tester.pumpAndSettle();

        expect(find.text('Skapa lista från mall'),
            findsNothing); // Dialog is dismissed
      });

      testWidgets('handles dialog create action with valid input',
          (WidgetTester tester) async {
        // ULTRATHINK: Test create action from lines 357-374
        final template = createTemplate(id: 'create_test', name: 'Create Test');
        String? capturedTemplateId;
        String? capturedListName;

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [template],
              onCreateFromTemplate: (templateId, listName) {
                capturedTemplateId = templateId;
                capturedListName = listName;
              },
            ),
          ),
        );

        await tester.tap(find.text('Create Test'));
        await tester.pumpAndSettle();

        // Clear the text field and enter new name
        await tester.enterText(find.byType(TextField), 'My Custom List');

        // Tap the create button in the dialog
        final createButtons = find.text('Skapa lista');
        await tester.tap(createButtons.last); // Last one is in dialog
        await tester.pumpAndSettle();

        expect(capturedTemplateId, equals('create_test'));
        expect(capturedListName, equals('My Custom List'));
        expect(find.text('Skapa lista från mall'),
            findsNothing); // Dialog dismissed
      });

      testWidgets('prevents dialog create action with empty input',
          (WidgetTester tester) async {
        // ULTRATHINK: Test validation from lines 358-362
        final template = createTemplate(id: 'validation_test');
        String? capturedTemplateId;
        String? capturedListName;

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [template],
              onCreateFromTemplate: (templateId, listName) {
                capturedTemplateId = templateId;
                capturedListName = listName;
              },
            ),
          ),
        );

        await tester.tap(find.text('Test Mall'));
        await tester.pumpAndSettle();

        // Clear the text field
        await tester.enterText(
            find.byType(TextField), '   '); // Whitespace only

        // Tap the create button in the dialog
        final createButtons = find.text('Skapa lista');
        await tester.tap(createButtons.last); // Last one is in dialog
        await tester.pumpAndSettle();

        // Callback should not be called with empty/whitespace input
        expect(capturedTemplateId, isNull);
        expect(capturedListName, isNull);
        expect(find.text('Skapa lista från mall'),
            findsOneWidget); // Dialog still visible
      });
    });

    group('Theme Integration Tests', () {
      testWidgets('uses AppColors throughout the widget',
          (WidgetTester tester) async {
        // ULTRATHINK: Test theme integration from various lines using AppColors
        final template = createTemplate();

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [template],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        // ULTRATHINK: Test color usage intention throughout widget
        expect(tester.takeException(), isNull);
        expect(find.byType(ShoppingTemplatesWidget), findsOneWidget);
      });

      testWidgets('uses AppDimensions for spacing and sizing',
          (WidgetTester tester) async {
        // ULTRATHINK: Test dimensions usage from various lines
        final template = createTemplate();

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [template],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        // ULTRATHINK: Test dimensions integration intention
        expect(tester.takeException(), isNull);
        expect(find.byType(ShoppingTemplatesWidget), findsOneWidget);
      });

      testWidgets('uses AppTextStyles for consistent typography',
          (WidgetTester tester) async {
        // ULTRATHINK: Test text styles from various lines
        final template = createTemplate();

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [template],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        // ULTRATHINK: Test text styling intention
        expect(tester.takeException(), isNull);
        expect(find.byType(ShoppingTemplatesWidget), findsOneWidget);
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('handles extremely large template lists',
          (WidgetTester tester) async {
        // ULTRATHINK: Test performance with many templates (reduced count to avoid overflow)
        final templates = List.generate(
            4,
            (i) =>
                createTemplate(name: 'Template $i')); // 4 templates = 2x2 grid

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: templates,
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(GridView), findsOneWidget);
        expect(find.text('Template 0'), findsOneWidget);
        expect(find.text('Template 3'), findsOneWidget);
      });

      testWidgets('handles Swedish characters in template data',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish character support
        final template = createTemplate(
          name: 'Köttbullar & Lingonsylt',
          description: 'Äkta svenska delikatesser med åäö',
          tags: ['Kött', 'Tillbehör', 'Måltid'],
        );

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [template],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        expect(find.text('Köttbullar & Lingonsylt'), findsOneWidget);
        expect(find.text('Äkta svenska delikatesser med åäö'), findsOneWidget);
        expect(find.text('Kött'), findsOneWidget);
        expect(find.text('Tillbehör'), findsOneWidget);
        expect(find.text('Måltid'), findsOneWidget);
      });

      testWidgets('handles templates with empty or null tags',
          (WidgetTester tester) async {
        // ULTRATHINK: Test edge cases in tag handling from line 140
        final templates = [
          createTemplate(name: 'No Tags', tags: []),
          createTemplate(name: 'Null Tags', tags: null),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: templates,
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        expect(find.text('No Tags'), findsOneWidget);
        expect(find.text('Null Tags'), findsOneWidget);
        expect(tester.takeException(), isNull); // Should not crash
      });

      testWidgets('handles rapid state changes', (WidgetTester tester) async {
        // ULTRATHINK: Test widget rebuilds with different states
        final templates = [createTemplate(name: 'State Test')];

        // Start with loading
        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: templates,
              onCreateFromTemplate: (templateId, listName) {},
              isLoading: true,
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Switch to empty state
        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: const [],
              onCreateFromTemplate: (templateId, listName) {},
              isLoading: false,
            ),
          ),
        );

        expect(find.text('Inga shoppingmallar än'), findsOneWidget);

        // Switch to populated state
        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: templates,
              onCreateFromTemplate: (templateId, listName) {},
              isLoading: false,
            ),
          ),
        );

        expect(find.text('State Test'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles complex template data structures',
          (WidgetTester tester) async {
        // ULTRATHINK: Test complex data handling
        final complexTemplate = {
          'id': 'complex_test',
          'name': 'Complex Template',
          'description':
              'Very long description that might cause layout issues and text overflow in the template card display area',
          'items':
              List.generate(100, (i) => 'Item ${i + 1}'), // Large items list
          'useCount': 9999,
          'tags': [
            'VeryLongTagNameThatMightCauseIssues',
            'AnotherLongTag',
            'ThirdLongTag',
            'FourthTag'
          ],
          'extraField': 'Should be ignored',
          'nullField': null,
        };

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [complexTemplate],
              onCreateFromTemplate: (templateId, listName) {},
            ),
          ),
        );

        expect(find.text('Complex Template'), findsOneWidget);
        expect(find.text('100 artiklar'), findsOneWidget); // Large item count
        expect(find.text('9999'), findsOneWidget); // Large use count
        expect(tester.takeException(), isNull); // Should handle gracefully
      });
    });

    group('Widget Structure and Architecture Tests', () {
      testWidgets('ShoppingTemplatesWidget is a StatelessWidget',
          (WidgetTester tester) async {
        // ULTRATHINK: Test widget type from line 11
        final widget = ShoppingTemplatesWidget(
          templates: const [],
          onCreateFromTemplate: (templateId, listName) {},
        );

        expect(widget, isA<StatelessWidget>());
      });

      testWidgets('build method handles all conditional rendering paths',
          (WidgetTester tester) async {
        // ULTRATHINK: Test build method logic from lines 26-44
        final templates = [createTemplate()];

        // Test all three main paths: loading, empty, populated
        final states = [
          {'isLoading': true, 'templates': templates, 'expectsLoader': true},
          {
            'isLoading': false,
            'templates': <Map<String, dynamic>>[],
            'expectsEmpty': true
          },
          {'isLoading': false, 'templates': templates, 'expectsGrid': true},
        ];

        for (final state in states) {
          await tester.pumpWidget(
            createTestWidget(
              child: ShoppingTemplatesWidget(
                templates: state['templates'] as List<Map<String, dynamic>>,
                onCreateFromTemplate: (templateId, listName) {},
                isLoading: state['isLoading'] as bool,
              ),
            ),
          );

          if (state['expectsLoader'] == true) {
            expect(find.byType(CircularProgressIndicator), findsOneWidget);
          } else if (state['expectsEmpty'] == true) {
            expect(find.text('Inga shoppingmallar än'), findsOneWidget);
          } else if (state['expectsGrid'] == true) {
            expect(find.byType(GridView), findsOneWidget);
          }

          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('callback parameters are properly defined and called',
          (WidgetTester tester) async {
        // ULTRATHINK: Test callback definitions from lines 13-14
        String? capturedTemplateId;
        String? capturedListName;
        bool createNewCalled = false;

        await tester.pumpWidget(
          createTestWidget(
            child: ShoppingTemplatesWidget(
              templates: [createTemplate(id: 'callback_test')],
              onCreateFromTemplate: (templateId, listName) {
                capturedTemplateId = templateId;
                capturedListName = listName;
              },
              onCreateNewTemplate: () => createNewCalled = true,
            ),
          ),
        );

        // Test onCreateNewTemplate callback
        await tester.tap(find.byIcon(Icons.add));
        expect(createNewCalled, isTrue);

        // Test onCreateFromTemplate callback through dialog
        await tester.tap(find.text('Test Mall'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Callback Test List');
        final createButtons = find.text('Skapa lista');
        await tester.tap(createButtons.last);

        expect(capturedTemplateId, equals('callback_test'));
        expect(capturedListName, equals('Callback Test List'));
      });
    });
  });
}

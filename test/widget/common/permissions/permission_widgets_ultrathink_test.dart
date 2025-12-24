// test/widget/common/permissions/permission_widgets_ultrathink_test.dart
// Comprehensive tests for PermissionWidgets using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/permissions/permission_widgets.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('PermissionWidgets Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to wrap widget with MaterialApp for proper theming
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Colors.blue,
            error: Colors.red,
          ),
        ),
        home: Scaffold(
          body: SizedBox(
            height: 600,
            width: 400,
            child: child,
          ),
        ),
      );
    }

    group('Vertical Layout - permissionsActionButtons Tests', () {
      group('EditMode.owner Tests', () {
        testWidgets('should show single primary save button for owner mode',
            (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.owner,
                onSave: () {},
              ),
            ),
          ));

          expect(find.byType(ElevatedButton), findsOneWidget);
          expect(find.text('Spara ändringar'), findsOneWidget);
          expect(find.byIcon(Icons.save), findsOneWidget);
          expect(find.byType(OutlinedButton), findsNothing);
          expect(find.byType(Column),
              findsNothing); // Should be single button, not column
        });

        testWidgets('should handle save button press for owner mode',
            (WidgetTester tester) async {
          bool savePressed = false;

          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.owner,
                onSave: () => savePressed = true,
              ),
            ),
          ));

          await tester.tap(find.byType(ElevatedButton));
          expect(savePressed, isTrue);
        });

        testWidgets('should show loading state for owner mode',
            (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.owner,
                onSave: () {},
                isSaving: true,
              ),
            ),
          ));

          expect(find.text('Sparar...'), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.text('Spara ändringar'), findsNothing);
        });

        testWidgets('should apply custom save label for owner mode',
            (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.owner,
                onSave: () {},
                saveLabel: 'Custom Save',
              ),
            ),
          ));

          expect(find.text('Custom Save'), findsOneWidget);
          expect(find.text('Spara ändringar'), findsNothing);
        });
      });

      group('EditMode.edit Tests', () {
        testWidgets('should behave identical to owner mode for edit mode',
            (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.edit,
                onSave: () {},
              ),
            ),
          ));

          expect(find.byType(ElevatedButton), findsOneWidget);
          expect(find.text('Spara ändringar'), findsOneWidget);
          expect(find.byIcon(Icons.save), findsOneWidget);
          expect(find.byType(OutlinedButton), findsNothing);
        });
      });

      group('EditMode.collaborative Tests', () {
        testWidgets('should show both save and fork buttons in column layout',
            (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.collaborative,
                onSave: () {},
                onFork: () {},
              ),
            ),
          ));

          expect(find.byType(Column), findsOneWidget);
          expect(find.byType(ElevatedButton),
              findsOneWidget); // Primary save button
          expect(find.byType(OutlinedButton), findsOneWidget); // Fork button
          expect(find.text('Spara ändringar'), findsOneWidget);
          expect(find.text('Spara min kopia'), findsOneWidget);
          expect(find.byIcon(Icons.save), findsOneWidget);
          expect(find.byIcon(Icons.content_copy), findsOneWidget);
        });

        testWidgets(
            'should have correct spacing between buttons in collaborative mode',
            (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.collaborative,
                onSave: () {},
                onFork: () {},
              ),
            ),
          ));

          final column = tester.widget<Column>(find.byType(Column));
          expect(column.children.length,
              equals(3)); // save button + SizedBox + fork button

          final sizedBox = column.children[1] as SizedBox;
          expect(sizedBox.height, equals(AppDimensions.spacingM));
        });

        testWidgets('should handle save button press in collaborative mode',
            (WidgetTester tester) async {
          bool savePressed = false;

          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.collaborative,
                onSave: () => savePressed = true,
                onFork: () {},
              ),
            ),
          ));

          await tester.tap(find.byType(ElevatedButton));
          expect(savePressed, isTrue);
        });

        testWidgets('should handle fork button press in collaborative mode',
            (WidgetTester tester) async {
          bool forkPressed = false;

          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.collaborative,
                onSave: () {},
                onFork: () => forkPressed = true,
              ),
            ),
          ));

          await tester.tap(find.byType(OutlinedButton));
          expect(forkPressed, isTrue);
        });

        testWidgets('should show save loading state in collaborative mode',
            (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.collaborative,
                onSave: () {},
                onFork: () {},
                isSaving: true,
              ),
            ),
          ));

          expect(find.text('Sparar...'), findsOneWidget);
          expect(find.text('Spara ändringar'), findsNothing);
          expect(find.text('Spara min kopia'),
              findsOneWidget); // Fork button unchanged
        });

        testWidgets('should show fork loading state in collaborative mode',
            (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.collaborative,
                onSave: () {},
                onFork: () {},
                isForking: true,
              ),
            ),
          ));

          expect(find.text('Skapar kopia...'), findsOneWidget);
          expect(find.text('Spara min kopia'), findsNothing);
          expect(find.text('Spara ändringar'),
              findsOneWidget); // Save button unchanged
        });
      });

      group('EditMode.readOnlyWithFork Tests', () {
        testWidgets(
            'should show single primary fork button for readOnlyWithFork mode',
            (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.readOnlyWithFork,
                onFork: () {},
              ),
            ),
          ));

          expect(find.byType(ElevatedButton), findsOneWidget);
          expect(find.text('Spara min kopia'), findsOneWidget);
          expect(find.byIcon(Icons.content_copy), findsOneWidget);
          expect(find.byType(OutlinedButton), findsNothing);
          expect(find.byType(Column), findsNothing);
        });

        testWidgets('should handle fork button press for readOnlyWithFork mode',
            (WidgetTester tester) async {
          bool forkPressed = false;

          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.readOnlyWithFork,
                onFork: () => forkPressed = true,
              ),
            ),
          ));

          await tester.tap(find.byType(ElevatedButton));
          expect(forkPressed, isTrue);
        });
      });

      group('EditMode.view Tests', () {
        testWidgets('should behave identical to readOnlyWithFork mode',
            (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.view,
                onFork: () {},
              ),
            ),
          ));

          expect(find.byType(ElevatedButton), findsOneWidget);
          expect(find.text('Spara min kopia'), findsOneWidget);
          expect(find.byIcon(Icons.content_copy), findsOneWidget);
        });
      });

      group('EditMode.noAccess Tests', () {
        testWidgets('should show error container with no access message',
            (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.noAccess,
              ),
            ),
          ));

          expect(find.text('Ingen åtkomst'), findsOneWidget);
          expect(find.byIcon(Icons.block), findsOneWidget);
          expect(find.byType(ElevatedButton), findsNothing);
          expect(find.byType(OutlinedButton), findsNothing);
        });

        testWidgets('should apply correct error styling for noAccess mode',
            (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.noAccess,
              ),
            ),
          ));

          // Verify error components are present - key functional behavior
          expect(find.text('Ingen åtkomst'), findsOneWidget);
          expect(find.byIcon(Icons.block), findsOneWidget);

          // Verify correct Row structure (Icon + SizedBox + Text)
          expect(find.byType(Row), findsWidgets); // Row exists for layout

          // Find the error container with expected structure
          final containers = tester
              .widgetList<Container>(find.byType(Container))
              .where((c) => c.decoration != null && c.padding != null)
              .toList();
          expect(containers, isNotEmpty);

          // Verify at least one container has the expected padding and border radius
          final hasCorrectContainer = containers.any((container) {
            return container.padding ==
                    const EdgeInsets.all(AppDimensions.spacingL) &&
                container.decoration is BoxDecoration &&
                (container.decoration as BoxDecoration).borderRadius ==
                    BorderRadius.circular(AppDimensions.borderRadiusM);
          });
          expect(hasCorrectContainer, isTrue);
        });
      });
    });

    group('Horizontal Layout - permissionsActionButtonsHorizontal Tests', () {
      group('EditMode.owner Horizontal Tests', () {
        testWidgets(
            'should show single primary button for owner horizontal mode',
            (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) =>
                  PermissionWidgets.permissionsActionButtonsHorizontal(
                context: context,
                editMode: EditMode.owner,
                onSave: () {},
              ),
            ),
          ));

          expect(find.byType(ElevatedButton), findsOneWidget);
          expect(find.text('Spara ändringar'), findsOneWidget);
          expect(find.byIcon(Icons.save), findsOneWidget);

          // ActionButtons.primaryButton uses Row internally for icon+text layout
          expect(find.byType(Row),
              findsWidgets); // Row exists inside ActionButtons

          // Should NOT have OutlinedButton (that would indicate collaborative mode)
          expect(find.byType(OutlinedButton), findsNothing);
        });
      });

      group('EditMode.collaborative Horizontal Tests', () {
        testWidgets(
            'should show buttons in row layout with correct flex weights',
            (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) =>
                  PermissionWidgets.permissionsActionButtonsHorizontal(
                context: context,
                editMode: EditMode.collaborative,
                onSave: () {},
                onFork: () {},
              ),
            ),
          ));

          expect(find.byType(ElevatedButton), findsOneWidget);
          expect(find.byType(OutlinedButton), findsOneWidget);
          expect(find.text('Spara ändringar'), findsOneWidget);
          expect(find.text('Kopia'),
              findsOneWidget); // Shortened label in horizontal

          // Find the Row widget among multiple Row widgets in the test tree
          final rows = tester.widgetList<Row>(find.byType(Row)).toList();
          expect(rows, isNotEmpty);

          // Find the row with 3 children (our production Row)
          final productionRow = rows.firstWhere(
            (row) => row.children.length == 3,
            orElse: () =>
                throw StateError('Production Row with 3 children not found'),
          );

          expect(productionRow.children.length,
              equals(3)); // Expanded + SizedBox + Expanded

          // Check flex weights
          final firstExpanded = productionRow.children[0] as Expanded;
          final lastExpanded = productionRow.children[2] as Expanded;
          expect(firstExpanded.flex, equals(2)); // Save button gets flex: 2
          expect(lastExpanded.flex,
              equals(1)); // Fork button gets flex: 1 (default)
        });

        testWidgets(
            'should use hardcoded "Kopia" label for fork button in horizontal mode',
            (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) =>
                  PermissionWidgets.permissionsActionButtonsHorizontal(
                context: context,
                editMode: EditMode.collaborative,
                onSave: () {},
                onFork: () {},
                forkLabel: 'Custom Fork', // Should be ignored
              ),
            ),
          ));

          expect(find.text('Kopia'),
              findsOneWidget); // Hardcoded in horizontal method
          expect(find.text('Custom Fork'), findsNothing);
        });
      });

      group('EditMode.noAccess Horizontal Tests', () {
        testWidgets(
            'should return SizedBox.shrink for noAccess horizontal mode',
            (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) =>
                  PermissionWidgets.permissionsActionButtonsHorizontal(
                context: context,
                editMode: EditMode.noAccess,
              ),
            ),
          ));

          // Should find SizedBox.shrink (width=0, height=0) among other SizedBox widgets
          final shrinkBoxes = tester
              .widgetList<SizedBox>(find.byType(SizedBox))
              .where((box) => box.width == 0.0 && box.height == 0.0)
              .toList();
          expect(shrinkBoxes, isNotEmpty);

          // Should not show any buttons or error messages
          expect(find.byType(ElevatedButton), findsNothing);
          expect(find.byType(OutlinedButton), findsNothing);
          expect(find.text('Ingen åtkomst'), findsNothing);
        });
      });
    });

    group('Helper Methods and Labels Tests', () {
      testWidgets('should apply correct save labels from _getSaveLabel helper',
          (WidgetTester tester) async {
        final testCases = [
          (EditMode.owner, 'Spara ändringar'),
          (EditMode.edit, 'Spara ändringar'),
          (EditMode.collaborative, 'Spara ändringar'),
          (EditMode.readOnlyWithFork, 'Spara min kopia'),
          (EditMode.view, 'Spara min kopia'),
        ];

        for (final (editMode, expectedLabel) in testCases) {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: editMode,
                onSave: () {},
                onFork: () {},
              ),
            ),
          ));

          expect(find.text(expectedLabel), findsOneWidget);

          // Clear widget tree for next test
          await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        }
      });

      testWidgets('should apply correct fork labels from _getForkLabel helper',
          (WidgetTester tester) async {
        final testCases = [
          (EditMode.collaborative, 'Spara min kopia'),
          (EditMode.readOnlyWithFork, 'Spara min kopia'),
          (EditMode.view, 'Spara min kopia'),
        ];

        for (final (editMode, expectedLabel) in testCases) {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: editMode,
                onSave: () {},
                onFork: () {},
              ),
            ),
          ));

          expect(find.text(expectedLabel), findsOneWidget);

          // Clear widget tree for next test
          await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        }
      });
    });

    group('Edge Cases and Integration Tests', () {
      testWidgets('should handle null callbacks gracefully',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => PermissionWidgets.permissionsActionButtons(
              context: context,
              editMode: EditMode.collaborative,
              onSave: null,
              onFork: null,
            ),
          ),
        ));

        final saveButton =
            tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        final forkButton =
            tester.widget<OutlinedButton>(find.byType(OutlinedButton));
        expect(saveButton.onPressed, isNull);
        expect(forkButton.onPressed, isNull);
      });

      testWidgets('should disable buttons when loading states are active',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => PermissionWidgets.permissionsActionButtons(
              context: context,
              editMode: EditMode.collaborative,
              onSave: () {},
              onFork: () {},
              isSaving: true,
              isForking: true,
            ),
          ),
        ));

        final saveButton =
            tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        final forkButton =
            tester.widget<OutlinedButton>(find.byType(OutlinedButton));
        expect(saveButton.onPressed, isNull); // Disabled due to loading
        expect(forkButton.onPressed, isNull); // Disabled due to loading
      });

      testWidgets('should handle all EditMode enum values without errors',
          (WidgetTester tester) async {
        for (final editMode in EditMode.values) {
          await tester.pumpWidget(createTestWidget(
            Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: editMode,
                onSave: () {},
                onFork: () {},
              ),
            ),
          ));

          // Should not throw any errors
          expect(tester.takeException(), isNull);

          // Clear widget tree
          await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        }
      });

      testWidgets('should integrate correctly with ActionButtons theme',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => PermissionWidgets.permissionsActionButtons(
              context: context,
              editMode: EditMode.collaborative,
              onSave: () {},
              onFork: () {},
            ),
          ),
        ));

        // ActionButtons should apply proper theming
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);

        final elevatedButton =
            tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        final outlinedButton =
            tester.widget<OutlinedButton>(find.byType(OutlinedButton));

        // Buttons should have proper structure from ActionButtons
        expect(elevatedButton.child, isA<Padding>());
        expect(outlinedButton.child, isA<Padding>());
      });

      testWidgets('should handle Swedish text rendering correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => PermissionWidgets.permissionsActionButtons(
              context: context,
              editMode: EditMode.collaborative,
              onSave: () {},
              onFork: () {},
              isSaving: true,
              isForking: true,
            ),
          ),
        ));

        // All Swedish text should render without issues
        expect(find.text('Sparar...'), findsOneWidget);
        expect(find.text('Skapar kopia...'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}

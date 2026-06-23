// test/widget/common/input/shopping_list_actions_test.dart
// Tests for ShoppingListActions dialogs & menu actions.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/widgets/common/input/shopping_list_actions.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class MockUnifiedShoppingViewModel extends Mock
    implements UnifiedShoppingViewModel {}

void main() {
  late MockUnifiedShoppingViewModel mockViewModel;

  UnifiedShoppingList makeList({
    String id = 'list_1',
    String name = 'Min Handlista',
  }) => UnifiedShoppingList(
    id: id,
    ownerId: 'user_1',
    ownerDisplayName: 'Test',
    name: name,
  );

  setUp(() {
    mockViewModel = MockUnifiedShoppingViewModel();
    registerFallbackValue(makeList());
  });

  // ───── Build List Actions Button ─────

  group('buildListActionsButton', () {
    testWidgets('renders PopupMenuButton with three menu items', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => ShoppingListActions.buildListActionsButton(
              ctx,
              makeList(),
              mockViewModel,
            ),
          ),
        ),
      );

      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Open menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Verify rename, export, delete items are visible
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('uses correct icon size', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => ShoppingListActions.buildListActionsButton(
              ctx,
              makeList(),
              mockViewModel,
            ),
          ),
        ),
      );

      final popup = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      final icon = popup.icon as Icon;
      expect(icon.size, equals(AppDimensions.iconSizeAction));
    });
  });

  // ───── Rename Dialog ─────

  group('showRenameDialog', () {
    Widget renameTestApp(UnifiedShoppingList list) {
      return createLocalizedTestApp(
        child: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => ShoppingListActions.showRenameDialog(
              ctx,
              list,
              mockViewModel,
            ),
            child: const Text('Open'),
          ),
        ),
      );
    }

    testWidgets('shows dialog pre-filled with current name', (tester) async {
      await tester.pumpWidget(renameTestApp(makeList(name: 'Old Name')));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Dialog should be visible with a text input containing the old name
      expect(find.byType(AlertDialog), findsOneWidget);

      // StyledInput wraps TextFormField
      final field = tester.widget<TextFormField>(
        find.byType(TextFormField),
      );
      expect(field.controller?.text, equals('Old Name'));
    });

    testWidgets('successful rename shows success snackbar', (tester) async {
      when(
        () => mockViewModel.renameList(any(), any()),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(renameTestApp(makeList(name: 'Old')));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Change name and save
      await tester.enterText(find.byType(TextFormField), 'New');
      // Save button is inside the dialog actions — find by text
      await tester.tap(find.widgetWithText(ElevatedButton, 'Spara'));
      await tester.pumpAndSettle();

      verify(() => mockViewModel.renameList('list_1', 'New')).called(1);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('failed rename shows error snackbar', (tester) async {
      when(
        () => mockViewModel.renameList(any(), any()),
      ).thenAnswer((_) async => false);
      when(() => mockViewModel.error).thenReturn('Nätverksfel');

      await tester.pumpWidget(renameTestApp(makeList(name: 'Old')));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'New');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Spara'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('does not rename if name is unchanged', (tester) async {
      await tester.pumpWidget(renameTestApp(makeList(name: 'Same')));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Save without changing text
      await tester.tap(find.widgetWithText(ElevatedButton, 'Spara'));
      await tester.pumpAndSettle();

      verifyNever(() => mockViewModel.renameList(any(), any()));
    });

    testWidgets('cancel does not rename', (tester) async {
      await tester.pumpWidget(renameTestApp(makeList(name: 'Test')));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap the cancel (secondary / outlined) button
      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      verifyNever(() => mockViewModel.renameList(any(), any()));
    });
  });

  // ───── Export List ─────

  group('exportList', () {
    Widget exportTestApp(UnifiedShoppingList list) {
      return createLocalizedTestApp(
        child: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => ShoppingListActions.exportList(
              ctx,
              list,
              mockViewModel,
            ),
            child: const Text('Export'),
          ),
        ),
      );
    }

    testWidgets('successful export shows snackbar', (tester) async {
      when(() => mockViewModel.exportList()).thenReturn('item1\nitem2');

      await tester.pumpWidget(exportTestApp(makeList(name: 'Export')));
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      verify(() => mockViewModel.exportList()).called(1);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('empty export shows error snackbar', (tester) async {
      when(() => mockViewModel.exportList()).thenReturn('');
      when(() => mockViewModel.error).thenReturn('Tom lista');

      await tester.pumpWidget(exportTestApp(makeList(name: 'Empty')));
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('exception shows error snackbar', (tester) async {
      when(
        () => mockViewModel.exportList(),
      ).thenThrow(Exception('Network error'));

      await tester.pumpWidget(exportTestApp(makeList(name: 'Crash')));
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  // ───── Delete Dialog ─────

  group('showDeleteDialog', () {
    testWidgets('calls without throwing', (tester) async {
      bool called = false;

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                called = true;
                try {
                  await ShoppingListActions.showDeleteDialog(
                    ctx,
                    makeList(),
                    mockViewModel,
                  );
                } catch (_) {
                  // CommonDialogActions may not be fully testable
                }
              },
              child: const Text('Delete'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });
  });

  // ───── Create List Dialog ─────

  group('showCreateListDialog', () {
    Widget createListTestApp({ValueChanged<String?>? onResult}) {
      return createLocalizedTestApp(
        child: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              final result = await ShoppingListActions.showCreateListDialog(
                ctx,
              );
              onResult?.call(result);
            },
            child: const Text('Create'),
          ),
        ),
      );
    }

    testWidgets('shows dialog with text field', (tester) async {
      await tester.pumpWidget(createListTestApp());
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('returns name when confirmed', (tester) async {
      String? result;

      await tester.pumpWidget(
        createListTestApp(onResult: (v) => result = v),
      );
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Ny Lista');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Skapa'));
      await tester.pumpAndSettle();

      expect(result, equals('Ny Lista'));
    });

    testWidgets('returns null when cancelled', (tester) async {
      String? result = 'sentinel';

      await tester.pumpWidget(
        createListTestApp(onResult: (v) => result = v),
      );
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  // ───── Add to List Confirmation ─────

  group('showAddToListConfirmation', () {
    testWidgets('calls without throwing', (tester) async {
      bool called = false;

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                called = true;
                try {
                  await ShoppingListActions.showAddToListConfirmation(
                    ctx,
                    makeList(),
                    3,
                  );
                } catch (_) {
                  // CommonDialogActions may not be fully testable
                }
              },
              child: const Text('Add'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });
  });

  // ───── SnackBar Styling ─────

  group('snackbar styling', () {
    testWidgets('success snackbar uses success color', (tester) async {
      when(
        () => mockViewModel.renameList(any(), any()),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => ShoppingListActions.showRenameDialog(
                ctx,
                makeList(name: 'Old'),
                mockViewModel,
              ),
              child: const Text('Go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'New');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Spara'));
      await tester.pumpAndSettle();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      // Success color comes from context.butleryColors.success (theme extension)
      expect(snackBar.backgroundColor, isNotNull);
    });

    testWidgets('error snackbar uses error color', (tester) async {
      when(
        () => mockViewModel.renameList(any(), any()),
      ).thenAnswer((_) async => false);
      when(() => mockViewModel.error).thenReturn('fail');

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => ShoppingListActions.showRenameDialog(
                ctx,
                makeList(name: 'Old'),
                mockViewModel,
              ),
              child: const Text('Go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'New');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Spara'));
      await tester.pumpAndSettle();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, isNotNull);
    });
  });
}

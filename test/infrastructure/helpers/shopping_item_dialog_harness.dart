// Shared by the two suites that drive the shopping-item dialogs through their
// public entry points, so the field-lookup and open-the-dialog plumbing is
// written once.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_item_dialogs.dart';

import 'field_finder.dart';
import 'widget_test_app.dart';

export 'field_finder.dart';

class MockUnifiedShoppingViewModel extends Mock
    implements UnifiedShoppingViewModel {}

String textIn(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(fieldLabelled(label)).controller!.text;

Future<void> openAddDialog(
  WidgetTester tester,
  UnifiedShoppingViewModel viewModel, {
  void Function(String)? onError,
}) async {
  await tester.pumpWidget(
    createLocalizedTestApp(
      child: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => ShoppingItemDialogs.showAddItemDialog(
            ctx,
            viewModel,
            onError ?? (_) {},
          ),
          child: const Text('öppna'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('öppna'));
  await tester.pumpAndSettle();
}

Future<void> openEditDialog(
  WidgetTester tester,
  UnifiedShoppingViewModel viewModel,
  UnifiedShoppingItem item, {
  void Function(String)? onError,
}) async {
  await tester.pumpWidget(
    createLocalizedTestApp(
      child: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => ShoppingItemDialogs.showEditItemDialog(
            ctx,
            item,
            viewModel,
            onError ?? (_) {},
          ),
          child: const Text('öppna'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('öppna'));
  await tester.pumpAndSettle();
}

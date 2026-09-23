// P3-U09: the category-move receipt.
//
// A category move is class 3 (produktregler.md:133): no Ångra. The row leaves
// the user's view, so the receipt 'Flyttade till {kategori}' stays, and a
// snackbar with no possible follow-up action gets `Stäng`
// (content-style-guide.md:96-97), never `OK`. With an action Flutter keeps a
// snackbar until tapped, so the receipt must close on its own, after the app's
// normal snackbar time. Under assistive navigation it stays until Stäng: the
// action is a real focusable target (tillganglighetshandoff:172).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/snackbar_utils.dart' show SnackBarConfig;
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_content.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

const _source = 'lib/views/unified_shopping/widgets/shopping_list_content.dart';

Future<void> _showReceipt(
  WidgetTester tester,
  String category, {
  Locale locale = const Locale('sv'),
}) async {
  await tester.pumpWidget(
    createLocalizedTestApp(
      locale: locale,
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => ShoppingListContentWidget.showCategoryMoveReceipt(
            context,
            category,
          ),
          child: const Text('move'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('move'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 750));
}

void main() {
  testWidgets('one receipt names the category and carries Stäng', (
    tester,
  ) async {
    await _showReceipt(tester, ShoppingCategory.dairy);

    expect(find.byType(SnackBar), findsOneWidget);
    final name = ShoppingCategory.displayName(ShoppingCategory.dairy);
    expect(find.text('Flyttade till $name'), findsOneWidget);

    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    expect(action.label, 'Stäng');
    expect(find.text('OK'), findsNothing);
    expect(find.text('Ångra'), findsNothing);
  });

  testWidgets('the English receipt reads Close', (tester) async {
    await _showReceipt(
      tester,
      ShoppingCategory.dairy,
      locale: const Locale('en'),
    );

    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    expect(action.label, 'Close');
    expect(find.textContaining('Moved to'), findsOneWidget);
  });

  testWidgets('it closes on its own, although it has an action', (
    tester,
  ) async {
    await _showReceipt(tester, ShoppingCategory.frozen);

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.persist, isFalse);
    expect(snackBar.duration, SnackBarConfig.normalDuration);
    await tester.pump(SnackBarConfig.normalDuration);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('under assistive navigation it stays until Stäng', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _showReceipt(tester, ShoppingCategory.frozen);

    expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isTrue);
    await tester.pump(SnackBarConfig.normalDuration * 3);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.tap(find.text('Stäng'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Stäng closes it at once', (tester) async {
    await _showReceipt(tester, ShoppingCategory.frozen);

    await tester.tap(find.text('Stäng'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  test('both move paths show this receipt once the move went through', () {
    final source = File(_source).readAsStringSync();

    // Only the two move handlers are pinned, not the rest of the file.
    String body(String name) {
      final start = source.indexOf('Future<void> $name(');
      expect(start, isNonNegative, reason: '$name is missing');
      final end = source.indexOf(RegExp(r'\r?\n  \}\r?\n'), start);
      return source.substring(start, end);
    }

    for (final handler in ['_handleItemDrop', '_showCategoryPicker']) {
      expect(
        body(handler),
        matches(
          RegExp(
            r'if \(moved && (context\.)?mounted\) \{\s*'
            r'ShoppingListContentWidget\.showCategoryMoveReceipt\(context, ',
          ),
        ),
        reason: handler,
      );
    }
  });
}

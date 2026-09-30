// BUT-2201: the shopping list header draws only the list selector and its
// rename/convert/delete icon buttons.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_header.dart';

import '../../../infrastructure/factories/shopping_list_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

class _MockUnifiedShoppingViewModel extends Mock
    implements UnifiedShoppingViewModel {}

void main() {
  // The dropdown item reads PermissionService via the production
  // ServiceLocator to show each list's sharing status.
  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDown(() async {
    await BaseUnitTest.teardownUnit();
  });

  testWidgets(
    'no longer renders Sortera kategorier / Rensa N / Avmarkera alla',
    (
      tester,
    ) async {
      final viewModel = _MockUnifiedShoppingViewModel();
      final list = ShoppingListFactory.build(
        items: [
          ShoppingListFactory.buildItem(id: 'i1', bought: true),
          ShoppingListFactory.buildItem(id: 'i2', bought: false),
        ],
      );

      when(() => viewModel.activeList).thenReturn(list);
      when(() => viewModel.lists).thenReturn([list]);
      when(() => viewModel.boughtItems).thenReturn(1);
      when(() => viewModel.totalItems).thenReturn(2);

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => ShoppingListHeader.build(
              context,
              viewModel,
              () {},
              () {},
            ),
          ),
        ),
      );

      expect(find.text('Sortera kategorier'), findsNothing);
      expect(find.textContaining('Rensa'), findsNothing);
      expect(find.text('Avmarkera alla'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);

      // The selector itself still renders.
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    },
  );

  testWidgets(
    'the item count and the permission stay on screen at 320 dp and 200 % text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final me = ServiceLocator.get<PermissionService>().currentUser?.uid;
      expect(
        me,
        isNotNull,
        reason: 'the permission text needs a signed-in user',
      );

      // Someone else's list the current user may edit, so the meta line
      // carries " • Redigera" after the count.
      final list = ShoppingListFactory.build(
        id: 'delad',
        ownerId: 'u-owner',
        type: ListType.collaborative,
        memberPermissions: {
          'u-owner': SharedListPermission.admin,
          me!: SharedListPermission.edit,
        },
        items: [
          ShoppingListFactory.buildItem(id: 'i1'),
          ShoppingListFactory.buildItem(id: 'i2'),
        ],
      );
      final viewModel = _MockUnifiedShoppingViewModel();
      when(() => viewModel.activeList).thenReturn(list);
      when(() => viewModel.lists).thenReturn([list]);

      final sv = AppLocalizationsSv();
      final countText = sv.shoppingItemCount(2);
      final permissionText = ' • ${sv.shoppingPermissionEdit}';

      // Layout errors are collected rather than read via takeException, so
      // an overflow elsewhere in the header cannot answer for this line.
      final layoutErrors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = layoutErrors.add;
      try {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ShoppingListHeader.build(
                context,
                viewModel,
                () {},
                () {},
              ),
            ),
          ),
        );
        await tester.pump();
      } finally {
        FlutterError.onError = previousOnError;
      }

      final count = find.text(countText);
      final permission = find.text(permissionText);
      expect(count, findsOneWidget);
      expect(permission, findsOneWidget);

      final metaLine = tester.renderObject(count).parent!;
      final metaLineId = describeIdentity(metaLine);
      expect(
        layoutErrors.where((e) => e.toString().contains(metaLineId)),
        isEmpty,
        reason: 'the count + permission line must not overflow',
      );

      final lineBox = metaLine as RenderBox;
      final lineRect = lineBox.localToGlobal(Offset.zero) & lineBox.size;
      for (final text in [count, permission]) {
        final rect = tester.getRect(text);
        expect(rect.left, greaterThanOrEqualTo(lineRect.left));
        expect(rect.right, lessThanOrEqualTo(lineRect.right));
      }
    },
  );
}

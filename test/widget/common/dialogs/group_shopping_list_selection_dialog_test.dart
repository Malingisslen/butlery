// BUT-2208: the list rows in the group shopping-list dialog had no colour
// test; only the old opacity steps were guarded against.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/dialogs/group_shopping_list_selection_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

class _MockShoppingService extends Mock implements UnifiedShoppingService {}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    final service = _MockShoppingService();
    when(() => service.isInitialized).thenReturn(true);
    when(() => service.loadLists()).thenAnswer((_) async {});
    when(() => service.personalLists).thenReturn([
      UnifiedShoppingList(
        name: 'Veckohandling',
        ownerId: 'u1',
        ownerDisplayName: 'Malin',
      ),
    ]);
    TestServiceLocator.registerMock<UnifiedShoppingService>(service);
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    final cs = theme.colorScheme;
    testWidgets('a list row draws its cart on surface.raised '
        '(${theme.brightness.name})', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Theme(
            data: theme,
            child: const GroupShoppingListSelectionDialog(
              groupName: 'Familjen',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final cart = find.byIcon(ButleryIcons.shoppingCart);
      expect(cart, findsOneWidget);
      final tile = tester
          .widgetList<Container>(
            find.ancestor(of: cart, matching: find.byType(Container)),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color != null);
      expect(tile.color, cs.surfaceContainerHighest);
      expect(tester.widget<Icon>(cart).color, cs.onSurface);
      expect(
        tester.widget<Text>(find.textContaining('0')).style?.color,
        cs.onSurface,
      );
    });
  }
}

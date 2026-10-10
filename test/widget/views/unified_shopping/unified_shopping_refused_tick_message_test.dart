// BUT-1710: a tick that is refused on a shared list must say WHICH of three
// things happened. These drive the real UnifiedShoppingView over the real view
// model; only the service seam is faked.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/modules/shopping_category_preferences_module.dart';
import 'package:butlery/services/unified/shopping_failure_message.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/shopping_list_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../views/design_states/state_harness.dart';

class _MockCategoryPreferences extends Mock
    implements CategoryPreferencesRepository {}

final _sv = AppLocalizationsSv();

const _listId = 'list-delad';
const _me = 'test-user-123';

void main() {
  late StateEnvironment environment;
  late MockUnifiedShoppingService service;

  setUp(() async {
    environment = await StateEnvironment.setUp(online: true);

    service = MockUnifiedShoppingService();
    service.setShoppingState(
      lists: [
        ShoppingListFactory.build(
          id: _listId,
          name: 'Delad lista',
          ownerId: 'someone-else',
          type: ListType.collaborative,
          items: [
            ShoppingListFactory.buildItem(
              id: 'i1',
              name: 'Gul lök',
              category: 'Frukt & grönt',
            ),
          ],
        ),
      ],
      activeListId: _listId,
    );
    when(service.loadLists).thenAnswer((_) async {});
    when(service.initialize).thenAnswer((_) async {});
    final repository = _MockCategoryPreferences();
    when(repository.getPreferences).thenAnswer((_) async => null);
    when(
      () => service.categoryPreferences,
    ).thenReturn(ShoppingCategoryPreferencesModule(repository: repository));

    TestServiceLocator.registerMock<UnifiedShoppingService>(service);
    TestServiceLocator.registerMock<UnifiedShoppingViewModel>(
      UnifiedShoppingViewModel(),
    );
  });

  tearDown(() async {
    await environment.tearDown();
  });

  Future<void> tick(WidgetTester tester) async {
    setStateSurface(tester);
    await tester.pumpWidget(
      stateApp(mode: Brightness.light, home: const UnifiedShoppingView()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.textContaining('Gul lök'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // The service seam as the real one behaves: a failure is parked once and
  // handed to whoever consumes it next.
  void parkOnService() {
    String? parked;
    when(
      () => service.reportMutationFailure(any()),
    ).thenAnswer((i) => parked = i.positionalArguments.single as String);
    when(() => service.consumeMutationError()).thenAnswer((_) {
      final message = parked;
      parked = null;
      return message;
    });
  }

  void refusedWith(Object error) {
    when(() => service.toggleItemBought(any())).thenAnswer((_) async => false);
    when(
      () => service.consumeMutationError(),
    ).thenReturn(shoppingFailureMessage(error, shared: true));
  }

  void expectOnlyMessage(WidgetTester tester, String expected) {
    expect(find.text(expected), findsOneWidget);
    expect(
      find.text(_sv.shoppingCouldNotUpdateItem('Gul lök')),
      findsNothing,
      reason: 'the cause-free fallback means the reason was dropped',
    );
    for (final other in {
      _sv.shoppingNoEditPermissionShared,
      _sv.shoppingListNotFound,
      _sv.errorNetwork,
    }.difference({expected})) {
      expect(find.text(other), findsNothing);
    }
  }

  testWidgets('a view-only member is told they lack permission', (
    tester,
  ) async {
    final viewOnly = FakePermissionService()
      ..setPermissionState(
        currentUserId: _me,
        defaultHasPermission: false,
        permissions: {
          _listId: {
            ResourcePermission.viewer: true,
            ResourcePermission.editor: false,
          },
        },
      );
    TestServiceLocator.registerMock<PermissionService>(viewOnly);
    parkOnService();

    await tick(tester);

    expectOnlyMessage(tester, _sv.shoppingNoEditPermissionShared);
    verifyNever(() => service.toggleItemBought(any()));
  });

  testWidgets('a list removed under the shopper says the list is gone', (
    tester,
  ) async {
    refusedWith(
      ResourceNotFoundException('gone', resourceType: 'shopping_list'),
    );

    await tick(tester);

    expectOnlyMessage(tester, _sv.shoppingListNotFound);
  });

  testWidgets('a lost connection says so', (tester) async {
    refusedWith(Exception('socket'));

    await tick(tester);

    expectOnlyMessage(tester, _sv.errorNetwork);
  });

  test('the three messages differ and are the pinned Swedish sentences', () {
    final messages = {
      _sv.shoppingNoEditPermissionShared,
      _sv.shoppingListNotFound,
      _sv.errorNetwork,
    };
    expect(messages, hasLength(3));
    expect(
      _sv.shoppingNoEditPermissionShared,
      'Du har inte behörighet att redigera denna delade inköpslista',
    );
    expect(_sv.shoppingListNotFound, 'Lista hittades inte');
    expect(
      _sv.errorNetwork,
      'Nätverksfel. Kontrollera din internetanslutning.',
    );
  });
}

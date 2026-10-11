// BUT-2089: an invitation to a shared list reaches the invitee as a card at
// the top of the shopping tab. Mounts the real UnifiedShoppingView so the
// section's place on the screen is what is tested, not the section alone.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/services/unified/modules/shopping_category_preferences_module.dart';
import 'package:butlery/services/unified/operations/list_invitation_operations.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/viewmodels/list_invitations_viewmodel.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/shopping_list_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../views/design_states/state_harness.dart';

class _MockCategoryPreferences extends Mock
    implements CategoryPreferencesRepository {}

class _MockInvitations extends Mock implements ListInvitationOperations {}

final _sv = AppLocalizationsSv();

void main() {
  late StateEnvironment environment;
  late StreamController<List<SocialRequest>> rows;

  setUp(() async {
    environment = await StateEnvironment.setUp(online: true);
    final list = ShoppingListFactory.build(
      id: 'list-vecka',
      name: 'Veckans inköp',
      ownerId: 'test-user-123',
      items: const [],
    );
    final service = MockUnifiedShoppingService()
      ..setShoppingState(lists: [list], activeListId: list.id);
    when(service.loadLists).thenAnswer((_) async {});
    when(service.initialize).thenAnswer((_) async {});
    final repository = _MockCategoryPreferences();
    when(repository.getPreferences).thenAnswer((_) async => null);
    when(() => service.categoryPreferences).thenReturn(
      ShoppingCategoryPreferencesModule(repository: repository),
    );
    TestServiceLocator.registerMock<UnifiedShoppingService>(service);
    TestServiceLocator.registerMock<UnifiedShoppingViewModel>(
      UnifiedShoppingViewModel(),
    );

    rows = StreamController<List<SocialRequest>>.broadcast();
    final ops = _MockInvitations();
    when(() => ops.pendingReceived).thenAnswer((_) => rows.stream);
    TestServiceLocator.registerMock<ListInvitationsViewModel>(
      ListInvitationsViewModel(operations: ops, analytics: null),
    );
  });

  tearDown(() async {
    await rows.close();
    await environment.tearDown();
  });

  testWidgets('a pending invitation shows as a card on the shopping tab', (
    tester,
  ) async {
    setStateSurface(tester);
    await tester.pumpWidget(
      stateApp(mode: Brightness.light, home: const UnifiedShoppingView()),
    );
    await tester.pump();
    rows.add([
      SocialRequest(
        id: 'inv-1',
        type: SocialRequestType.listInvitation,
        fromUserId: 'anna',
        toUserId: 'test-user-123',
        listId: 'l-fest',
        listName: 'Fest',
        permission: 'edit',
        fromUserName: 'Anna',
      ),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Fest'), findsOneWidget);
    expect(find.text(_sv.listInvitationJoin), findsOneWidget);
  });
}

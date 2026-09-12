// test/widget/shopping/shopping_leave_list_action_test.dart

/// BUT-1718: what happens after the user says yes to "Lämna listan".
///
/// The three cases in `shopping_share_status_dialog_test.dart` prove only that
/// the BUTTON appears for the right people. Everything below it — the confirm
/// dialog's wording, the `onConfirmed` callback firing at all, and
/// the outcome message on both a success and a refusal — was executed by no
/// test at all, and each of those is a decision that would fail silently.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping_operations.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_leave_list_action.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart';

class _MockCollaborativeOps extends Mock
    implements CollaborativeShoppingOperations {}

UnifiedShoppingList _list() => UnifiedShoppingList(
  id: 'list-1',
  name: 'Familjehandling',
  ownerId: 'owner-uid',
  ownerDisplayName: 'Malin',
  type: ListType.collaborative,
  memberPermissions: const {
    'owner-uid': SharedListPermission.admin,
    'bob': SharedListPermission.edit,
  },
);

void main() {
  late MockUnifiedShoppingService service;
  late _MockCollaborativeOps collaborative;
  late AppLocalizations l10n;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() {
    service = MockUnifiedShoppingService();
    collaborative = _MockCollaborativeOps();
    when(() => service.collaborative).thenReturn(collaborative);

    if (GetIt.instance.isRegistered<UnifiedShoppingService>()) {
      GetIt.instance.unregister<UnifiedShoppingService>();
    }
    GetIt.instance.registerSingleton<UnifiedShoppingService>(service);
  });

  tearDown(() {
    if (GetIt.instance.isRegistered<UnifiedShoppingService>()) {
      GetIt.instance.unregister<UnifiedShoppingService>();
    }
  });

  /// Pumps a host with one button that runs the action, so the confirm dialog
  /// is pushed on a live route the way the sharing dialog pushes it.
  Future<int> pumpAndTap(
    WidgetTester tester, {
    required String confirmLabel,
  }) async {
    var confirmedCount = 0;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            l10n = context.l10n;
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => ShoppingLeaveListAction.confirmAndLeave(
                    context,
                    _list(),
                    onConfirmed: () => confirmedCount++,
                  ),
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(confirmLabel));
    await tester.pumpAndSettle();
    return confirmedCount;
  }

  testWidgets('a confirmed leave reports the list by name', (tester) async {
    when(() => collaborative.leaveList(any())).thenAnswer((_) async => true);

    final confirmed = await pumpAndTap(tester, confirmLabel: 'Lämna');

    expect(confirmed, 1, reason: 'the caller closes its own dialog');
    verify(() => collaborative.leaveList('list-1')).called(1);
    expect(find.text(l10n.shoppingLeftList('Familjehandling')), findsOneWidget);
  });

  testWidgets('a refused leave reports the service reason, not a generic one', (
    tester,
  ) async {
    // The reason is parked by the service and read back once. If the action
    // ever stopped consuming it, the user would get the fallback sentence while
    // a truer one sat unread — the BUT-1696 class.
    when(() => collaborative.leaveList(any())).thenAnswer((_) async => false);
    when(
      () => service.consumeMutationError(),
    ).thenReturn('Listan har ändrats på en annan enhet');

    await pumpAndTap(tester, confirmLabel: 'Lämna');

    expect(find.text('Listan har ändrats på en annan enhet'), findsOneWidget);
    verify(() => service.consumeMutationError()).called(1);
  });

  testWidgets('a refusal with no parked reason falls back', (tester) async {
    when(() => collaborative.leaveList(any())).thenAnswer((_) async => false);
    when(() => service.consumeMutationError()).thenReturn(null);

    await pumpAndTap(tester, confirmLabel: 'Lämna');

    expect(find.text(l10n.shoppingCouldNotLeaveList), findsOneWidget);
  });

  testWidgets('cancelling writes nothing and closes nothing', (tester) async {
    // The co-assertion that makes the three above non-vacuous: the same host,
    // the same tap, only the answer differs.
    final confirmed = await pumpAndTap(tester, confirmLabel: 'Avbryt');

    expect(confirmed, 0, reason: 'the caller must not close its dialog');
    verifyNever(() => collaborative.leaveList(any()));
  });
}

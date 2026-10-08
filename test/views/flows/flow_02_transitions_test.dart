/// P8-U03 · flow 02, the step from the week menu into the merge sheet.
///
/// TR::FLOW::02::veckomeny::till-inköpslistan (fas2/block288-uxfrysning.json,
/// REQUIRED; flows-roles-budget.md:44): "Till inköpslistan" on the week menu
/// opens the merge sheet (#inkopmerge), and nothing is written before the
/// sheet is answered. test/widget/menu/shopping_merge_sheet_test.dart pins
/// the sheet itself; this drives the tap on the real VeckomenyView
/// (veckomeny_view.dart:401-460).
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/widgets/menu/shopping_merge_sheet.dart';

import '../../infrastructure/di/test_service_locator.dart';
import 'veckomeny_flow_harness.dart';

class _Pantry extends Mock implements PantryService {
  @override
  Stream<List<PantryItem>> watchAll(String userId) =>
      Stream.value(const <PantryItem>[]);
}

final _sv = AppLocalizationsSv();

void main() {
  late VeckomenyFlowHarness h;

  setUpAll(() {
    registerFallbackValue(
      PersonalMergeRequest(rows: (_) => const [], replace: false),
    );
  });

  setUp(() async {
    h = VeckomenyFlowHarness();
    await h.setUp();
    h.menu.next = {
      'Middag': [flowDinner(1), flowDinner(2)],
    };
    TestServiceLocator.registerMock<PantryService>(_Pantry());
  });

  tearDown(() => h.tearDown());

  group('TR::FLOW::02::veckomeny::till-inköpslistan', () {
    testWidgets('Till inköpslista on the week menu opens the merge sheet, and '
        'nothing is written before it is answered', (tester) async {
      await withClock(Clock.fixed(flowMonday), () async {
        await h.pump(tester);
        await h.generate(tester, 'två middagar');
        await tester.pumpAndSettle();

        await tester.tap(find.text(_sv.menuToShoppingList));
        // The FAB spins while the flow runs, so the tree never settles:
        // pump past the sheet's entry instead.
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.byType(ShoppingMergeSheet), findsOneWidget);
        expect(find.text(_sv.shoppingMergeTitle), findsOneWidget);
        expect(find.byKey(ShoppingMergeSheet.confirmKey), findsOneWidget);

        final shopping = TestServiceLocator.get<UnifiedShoppingService>();
        verifyNever(() => shopping.updateList(any()));
        verifyNever(() => shopping.applyPersonalMerge(any(), any()));
        verifyNever(() => shopping.createPersonalList(any()));
      });
    });
  });
}

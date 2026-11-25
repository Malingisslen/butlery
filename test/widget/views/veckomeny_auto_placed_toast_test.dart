/// BUT-2486 part 6: what the week menu tells the user right after a suggested
/// week was placed, with and without fridge and freezer boxes.
///
/// Pinned at the mixin the view uses, `VeckomenyPlacementFlow.showAutoPlacedToast`,
/// with a mocked calendar view model that answers how many boxes were placed
/// and whether they could not be read. The end-to-end placement is in
/// `test/views/flows/veckomeny_lunchbox_days_flow_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/views/veckomeny_view/veckomeny_placement_flow.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _MockPlanVm extends Mock implements WeeklyMenuPlanViewModel {}

class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with VeckomenyPlacementFlow<_Host> {
  @override
  VeckomenyViewMode get viewMode => VeckomenyViewMode.lista;
  @override
  TextEditingController get promptController => TextEditingController();
  @override
  FocusNode get promptFocusNode => FocusNode();
  @override
  Future<void> setViewMode(VeckomenyViewMode mode) async {}
  @override
  void markRevealing() {}
  @override
  bool get fillPantryFocus => false;
  @override
  Set<DayOfWeek> get lunchboxDays => const {};
  @override
  Future<void> afterMenuGenerated({
    required String text,
    required bool pantryFocus,
  }) async {}

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => showAutoPlacedToast(_placed),
    child: const Text('visa'),
  );
}

int _placed = 0;

final _sv = AppLocalizationsSv();

void main() {
  late _MockPlanVm vm;

  setUp(() {
    vm = _MockPlanVm();
    when(() => vm.lastStockLunchCount).thenReturn(0);
    when(() => vm.lastStockLunchReadFailed).thenReturn(false);
  });

  Future<void> announce(WidgetTester tester, {required int placed}) async {
    _placed = placed;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ChangeNotifierProvider<WeeklyMenuPlanViewModel>.value(
          value: vm,
          child: const _Host(),
        ),
      ),
    );
    await tester.tap(find.text('visa'));
    await tester.pump();
  }

  Finder text(String s) => find.text(s);

  testWidgets('dishes only: the plain receipt, no box wording', (tester) async {
    await announce(tester, placed: 3);

    expect(text(_sv.menuAutoPlacedToast(3)), findsOneWidget);
    expect(text(_sv.menuStockLunchesUnreadable), findsNothing);
  });

  testWidgets('dishes and boxes: one receipt naming both counts', (
    tester,
  ) async {
    when(() => vm.lastStockLunchCount).thenReturn(2);
    await announce(tester, placed: 3);

    expect(text(_sv.menuAutoPlacedWithBoxesToast(3, 2)), findsOneWidget);
    expect(text(_sv.menuAutoPlacedToast(3)), findsNothing);
  });

  testWidgets('boxes only: a receipt naming just the boxes', (tester) async {
    when(() => vm.lastStockLunchCount).thenReturn(2);
    await announce(tester, placed: 0);

    expect(text(_sv.menuAutoPlacedBoxesOnlyToast(2)), findsOneWidget);
    expect(text(_sv.menuAutoPlacedWithBoxesToast(0, 2)), findsNothing);
  });

  testWidgets('nothing placed and no boxes shows no receipt at all', (
    tester,
  ) async {
    await announce(tester, placed: 0);

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('boxes that could not be read are said so, and with nothing '
      'placed that is the only line', (tester) async {
    when(() => vm.lastStockLunchReadFailed).thenReturn(true);
    await announce(tester, placed: 0);

    expect(text(_sv.menuStockLunchesUnreadable), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('boxes that could not be read are still said after a dish '
      'receipt', (tester) async {
    when(() => vm.lastStockLunchReadFailed).thenReturn(true);
    await announce(tester, placed: 3);

    expect(text(_sv.menuAutoPlacedToast(3)), findsOneWidget);
    ScaffoldMessenger.of(
      tester.element(find.byType(SnackBar)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(text(_sv.menuStockLunchesUnreadable), findsOneWidget);
  });
}

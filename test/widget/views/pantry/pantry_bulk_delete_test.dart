/// BUT-948: gates the pantry bulk-bar wiring in PantryView — entering selection
/// shows the contextual bar, tapping "Ta bort" calls bulkRemoveItems with the
/// selected ids, and the undo snackbar restores the pre-delete snapshot. This is
/// the view-level half the card/VM unit tests don't reach (the _deleteSelected
/// snapshot-before-await + clearSelection ordering).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/pantry_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

class _MockPantryViewModel extends Mock implements PantryViewModel {}

void main() {
  final item = PantryItem(
    id: 'p_1',
    ingredientName: 'Mjölk',
    quantity: 1,
    unit: 'l',
    location: PantryLocation.fridge,
    addedAt: DateTime(2026, 1, 1),
  );

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(<String>{});
    registerFallbackValue(<PantryItem>[]);
    registerFallbackValue(PantryLocation.fridge);
  });

  late _MockPantryViewModel vm;

  setUp(() async {
    await TestServiceLocator.initialize();
    vm = _MockPantryViewModel();
    when(() => vm.isLoading).thenReturn(false);
    when(() => vm.error).thenReturn(null);
    when(() => vm.hasError).thenReturn(false);
    when(() => vm.items).thenReturn([item]);
    // Put the row in the (initially-expanded) "expiring" section so it renders
    // without first tapping an ExpansionTile.
    when(() => vm.expiringItems).thenReturn([item]);
    when(() => vm.itemsByLocation(any())).thenReturn(const []);
    when(() => vm.loadPantry()).thenAnswer((_) async {});
    when(() => vm.bulkRemoveItems(any())).thenAnswer((_) async {});
    when(() => vm.restoreItems(any())).thenAnswer((_) async {});
    TestServiceLocator.registerFactory<PantryViewModel>(() => vm);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  testWidgets('bulk delete removes selected ids and undo restores them',
      (tester) async {
    await tester.pumpWidget(createLocalizedTestApp(child: const PantryView()));
    await tester.pumpAndSettle();

    // Enter selection by long-pressing the row, then the bulk bar appears.
    await tester.longPress(find.text('Mjölk'));
    await tester.pumpAndSettle();
    expect(find.text('Ta bort'), findsOneWidget,
        reason: 'the contextual bulk bar replaces the add FAB while selecting');

    await tester.tap(find.text('Ta bort'));
    await tester.pumpAndSettle();

    verify(() => vm.bulkRemoveItems({'p_1'})).called(1);

    // Undo snackbar appears and restores the captured pre-delete snapshot.
    expect(find.text('Ångra'), findsOneWidget);
    await tester.tap(find.text('Ångra'));
    await tester.pumpAndSettle();

    verify(() => vm.restoreItems(any(that: contains(item)))).called(1);
  });

  testWidgets('a failed bulk delete shows no undo snackbar', (tester) async {
    when(() => vm.bulkRemoveItems(any())).thenAnswer((_) async {});
    when(() => vm.hasError).thenReturn(true); // delete failed

    await tester.pumpWidget(createLocalizedTestApp(child: const PantryView()));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Mjölk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ta bort'));
    await tester.pumpAndSettle();

    expect(find.text('Ångra'), findsNothing,
        reason: 'a failed delete must not offer an undo that would re-add '
            'items still present');
  });
}

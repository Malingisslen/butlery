// BUT-2261: with nothing about to expire, the first place that holds items
// opens on arrival, so a stocked pantry never looks empty. Malin chose this
// on 2026-10-09; the headings keep their drawn lowercase.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/pantry_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/offline_banner_support.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

class _MockPantryViewModel extends Mock implements PantryViewModel {}

PantryItem _item(String id, String name, PantryLocation location) => PantryItem(
  id: id,
  ingredientName: name,
  quantity: 1,
  unit: 'st',
  location: location,
  addedAt: DateTime(2026, 1, 1),
);

void main() {
  final peas = _item('p_1', 'Ärtor', PantryLocation.freezer);
  final flour = _item('p_2', 'Vetemjöl', PantryLocation.pantry);
  final milk = _item('p_3', 'Mjölk', PantryLocation.fridge);

  late _MockPantryViewModel vm;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
    ensureOfflineService();
    registerFallbackValue(PantryLocation.fridge);
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    ensureOfflineService();
    vm = _MockPantryViewModel();
    when(() => vm.isLoading).thenReturn(false);
    when(() => vm.error).thenReturn(null);
    when(() => vm.hasError).thenReturn(false);
    when(() => vm.loadPantry()).thenAnswer((_) async {});
    TestServiceLocator.registerFactory<PantryViewModel>(() => vm);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  void stock(List<PantryItem> items, {List<PantryItem> expiring = const []}) {
    when(() => vm.items).thenReturn(items);
    when(() => vm.expiringItems).thenReturn(expiring);
    when(() => vm.itemsByLocation(any())).thenAnswer((call) {
      final location = call.positionalArguments.first as PantryLocation;
      return items.where((i) => i.location == location).toList();
    });
  }

  testWidgets('nothing expiring: the first place with items is open, the '
      'next is closed', (tester) async {
    // The fridge is empty, so the freezer is the first place with items.
    stock([peas, flour]);
    await tester.pumpWidget(createLocalizedTestApp(child: const PantryView()));
    await tester.pumpAndSettle();

    expect(find.text('Ärtor'), findsOneWidget);
    expect(find.text('Vetemjöl'), findsNothing);
  });

  testWidgets('something expiring: that group is open and the places stay '
      'closed', (tester) async {
    stock([milk, peas], expiring: [milk]);
    await tester.pumpWidget(createLocalizedTestApp(child: const PantryView()));
    await tester.pumpAndSettle();

    // Mjölk shows once, in the open expiring group, not again in the fridge.
    expect(find.text('Mjölk'), findsOneWidget);
    expect(find.text('Ärtor'), findsNothing);
  });
}

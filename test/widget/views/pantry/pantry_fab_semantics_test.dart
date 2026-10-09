// BUT-2261: with items in the list, the pantry's add button must reach a
// screen reader as a button of its own, under its own name. The pantry is
// hosted in a TabBarView as in the shopping view: that tab panel is the node
// the label merged into.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/pantry_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/offline_banner_support.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

class _MockPantryViewModel extends Mock implements PantryViewModel {}

final _sv = AppLocalizationsSv();

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
    ensureOfflineService();
    registerFallbackValue(PantryLocation.fridge);
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    ensureOfflineService();
    final vm = _MockPantryViewModel();
    when(() => vm.isLoading).thenReturn(false);
    when(() => vm.error).thenReturn(null);
    when(() => vm.hasError).thenReturn(false);
    when(() => vm.items).thenReturn([item]);
    when(() => vm.expiringItems).thenReturn([item]);
    when(() => vm.itemsByLocation(any())).thenReturn(const []);
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

  testWidgets('the add button is its own tappable button node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: DefaultTabController(
          length: 2,
          initialIndex: 1,
          child: Scaffold(
            body: const Column(
              children: [
                TabBar(
                  tabs: [
                    Tab(text: 'Listor'),
                    Tab(text: 'Skafferi'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [SizedBox.shrink(), PantryView()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mjölk'), findsOneWidget);

    final node = tester.getSemantics(
      find.bySemanticsLabel(_sv.a11yPantryAddItem),
    );
    expect(node.label, _sv.a11yPantryAddItem);
    // Merged upward, the label lands on a node the size of the whole tab;
    // its own node is the 56 px square.
    expect(node.rect.size, const Size(56, 56));
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });
}

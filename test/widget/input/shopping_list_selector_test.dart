// test/widget/input/shopping_list_selector_test.dart
// Basic tests for ShoppingListSelector

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/input/shopping_list_selector.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/di/di_container.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../../test_support/base_unit_test.dart';

/// Minimal mock that provides all properties the widget reads in initState/build.
class _TestShoppingViewModel extends MockUnifiedShoppingViewModel {
  @override
  List<UnifiedShoppingList> get lists => [];

  @override
  bool get isLoading => false;

  @override
  bool get hasError => false;

  @override
  String? get error => null;

  @override
  UnifiedShoppingList? get activeList => null;
}

void main() {
  group('ShoppingListSelector Widget Tests', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Register a mock UnifiedShoppingViewModel with safe defaults
      final mockVm = _TestShoppingViewModel();
      TestServiceLocator.registerMock<UnifiedShoppingViewModel>(mockVm);

      // Bridge production ServiceLocator to the same GetIt instance
      production.ServiceLocator.initialize(DIContainer());
    });

    tearDown(() async {
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Basic Widget Tests', () {
      testWidgets('should create ShoppingListSelector without crashing', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingListSelector(),
          ),
        );

        expect(find.byType(ShoppingListSelector), findsOneWidget);
      });

      testWidgets('should handle optional callback parameter', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingListSelector(
              onListSelected: () {},
            ),
          ),
        );

        expect(find.byType(ShoppingListSelector), findsOneWidget);
      });

      testWidgets('should handle optional menu parameter', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingListSelector(
              menu: const {},
            ),
          ),
        );

        expect(find.byType(ShoppingListSelector), findsOneWidget);
      });

      testWidgets('should handle null menu gracefully', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingListSelector(
              menu: null,
            ),
          ),
        );

        expect(find.byType(ShoppingListSelector), findsOneWidget);
      });

      testWidgets('should handle all parameters together', (
        WidgetTester tester,
      ) async {
        bool callbackCalled = false;

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ShoppingListSelector(
              onListSelected: () => callbackCalled = true,
              menu: const {
                'Test Day': [],
              },
            ),
          ),
        );

        expect(find.byType(ShoppingListSelector), findsOneWidget);
        expect(callbackCalled, isFalse);
      });
    });
  });
}

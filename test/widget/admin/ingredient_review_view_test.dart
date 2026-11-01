import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/viewmodels/admin/ingredient_review_viewmodel.dart';
import 'package:butlery/views/admin/ingredient_review_view.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';
import '../../test_support/ingredient_review_fixtures.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  Future<void> pump(WidgetTester tester, IngredientReviewViewModel vm) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: IngredientReviewView(viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a status filter narrows the list', (tester) async {
    final vm = IngredientReviewViewModel(
      repository: FakeIngredientRepository(ingredientReviewSample()),
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(tester, vm);

    expect(find.text('vetemjöl'), findsOneWidget);
    expect(find.text('kycklingbröst'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('status-draft')));
    await tester.pumpAndSettle();

    expect(find.text('kycklingbröst'), findsOneWidget);
    expect(find.text('vetemjöl'), findsNothing);
  });

  testWidgets('an empty load shows an error, not a zero count', (tester) async {
    final vm = IngredientReviewViewModel(
      repository: FakeIngredientRepository(const []),
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(tester, vm);

    expect(find.textContaining('Kunde inte ladda'), findsOneWidget);
    expect(find.textContaining('Visar 0'), findsNothing);
  });

  testWidgets('shows when the data was last synced', (tester) async {
    final vm = IngredientReviewViewModel(
      repository: FakeIngredientRepository(ingredientReviewSample()),
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(tester, vm);

    expect(find.textContaining('Senast synkad: 2026-10-'), findsOneWidget);
    expect(find.textContaining('okänt'), findsNothing);
  });

  testWidgets(
    'without tag config the list stays but says allergens are unknown',
    (tester) async {
      final vm = IngredientReviewViewModel(
        repository: FakeIngredientRepository(ingredientReviewSample()),
        tagConfigService: FakeTagConfigService(null),
      );
      await pump(tester, vm);

      expect(find.text('vetemjöl'), findsOneWidget);
      expect(
        find.textContaining('Taggkonfigurationen är inte laddad'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('filter-allergen')), findsNothing);
    },
  );

  testWidgets('the row copy button puts that ingredient on the clipboard', (
    tester,
  ) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final vm = IngredientReviewViewModel(
      repository: FakeIngredientRepository(ingredientReviewSample()),
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(tester, vm);

    final row = find.byKey(const ValueKey('almond'));
    await tester.tap(
      find.descendant(
        of: row,
        matching: find.bySemanticsLabel(RegExp('Kopiera för Claude')),
      ),
    );
    await tester.pump();

    expect(clipboard, contains('Id: almond'));
    expect(clipboard, contains('Ger allergener: nötter'));
  });

  testWidgets('a dropdown picks a value, and "Alla" clears it again', (
    tester,
  ) async {
    final vm = IngredientReviewViewModel(
      repository: FakeIngredientRepository(ingredientReviewSample()),
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(tester, vm);
    final allergen = find.byKey(const ValueKey('filter-allergen'));

    await tester.tap(
      find.descendant(
        of: allergen,
        matching: find.byType(ButleryDropdown<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('gluten').last);
    await tester.pumpAndSettle();

    expect(vm.allergenFilter, 'gluten');
    expect(find.text('vetemjöl'), findsOneWidget);
    expect(find.text('kycklingbröst'), findsNothing);

    await tester.tap(
      find.descendant(
        of: allergen,
        matching: find.byType(ButleryDropdown<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alla').last);
    await tester.pumpAndSettle();

    expect(vm.allergenFilter, isNull);
    expect(find.text('kycklingbröst'), findsOneWidget);
  });

  testWidgets('tapping a row opens that ingredient\'s details', (tester) async {
    final vm = IngredientReviewViewModel(
      repository: FakeIngredientRepository(ingredientReviewSample()),
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(tester, vm);

    await tester.tap(find.text('mandel'));
    await tester.pumpAndSettle();

    expect(find.text('almond'), findsWidgets);
    expect(find.text('tree-nut'), findsOneWidget);
  });
}

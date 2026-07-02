// BUT-1464: rendering coverage for the hidden-recipes hint row and the
// "allergener okända" chip in the generated-menu list, including the
// family-vs-neutral wording split (review M2) and the plural forms.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart'
    show MenuPrefSource;
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/menu/menu_content_widgets.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

class _FakeMenuViewModel extends Mock implements MenuViewModel {}

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  _FakeMenuViewModel vmWith({
    required int hiddenCount,
    required MenuPrefSource prefSource,
    required bool unknownSoft,
    required Recipe recipe,
  }) {
    final vm = _FakeMenuViewModel();
    when(() => vm.hasError).thenReturn(false);
    when(() => vm.hasMenu).thenReturn(true);
    when(() => vm.isGenerating).thenReturn(false);
    when(() => vm.menu).thenReturn({
      'middag': [recipe],
    });
    when(() => vm.totalRecipeCount).thenReturn(1);
    when(() => vm.hiddenByFamilyCount).thenReturn(hiddenCount);
    when(() => vm.hiddenPrefSource).thenReturn(prefSource);
    when(() => vm.isUnknownSoft(any())).thenReturn(unknownSoft);
    return vm;
  }

  Future<void> pumpMenuContent(WidgetTester tester, MenuViewModel vm) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) =>
              MenuContentWidgets.buildMenuContent(context, viewModel: vm),
        ),
      ),
    );
  }

  testWidgets(
    'household filtering renders the family hint (plural) and the '
    'unknown-soft chip',
    (tester) async {
      final vm = vmWith(
        hiddenCount: 2,
        prefSource: MenuPrefSource.household,
        unknownSoft: true,
        recipe: RecipeFactory.build(id: 'r1', title: 'Köttbullar'),
      );

      await pumpMenuContent(tester, vm);

      expect(
        find.text('2 recept dolda på grund av familjens allergier'),
        findsOneWidget,
      );
      expect(find.text('allergener okända'), findsOneWidget);
    },
  );

  testWidgets(
    'family hint uses the singular plural form at count 1',
    (tester) async {
      final vm = vmWith(
        hiddenCount: 1,
        prefSource: MenuPrefSource.present,
        unknownSoft: false,
        recipe: RecipeFactory.build(id: 'r1', title: 'Köttbullar'),
      );

      await pumpMenuContent(tester, vm);

      expect(
        find.text('1 recept dolt på grund av familjens allergier'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'solo-user filtering gets the neutral wording, no family attribution, '
    'and no chip when nothing is unknown-soft',
    (tester) async {
      final vm = vmWith(
        hiddenCount: 2,
        prefSource: MenuPrefSource.singleUser,
        unknownSoft: false,
        recipe: RecipeFactory.build(id: 'r1', title: 'Köttbullar'),
      );

      await pumpMenuContent(tester, vm);

      expect(
        find.text('2 recept dolda på grund av dina allergival'),
        findsOneWidget,
      );
      expect(find.textContaining('familjens allergier'), findsNothing);
      expect(find.text('allergener okända'), findsNothing);
    },
  );

  testWidgets(
    'no hint row at all when nothing was hidden',
    (tester) async {
      final vm = vmWith(
        hiddenCount: 0,
        prefSource: MenuPrefSource.household,
        unknownSoft: false,
        recipe: RecipeFactory.build(id: 'r1', title: 'Köttbullar'),
      );

      await pumpMenuContent(tester, vm);

      expect(find.textContaining('dolda'), findsNothing);
      expect(find.textContaining('dolt'), findsNothing);
    },
  );
}

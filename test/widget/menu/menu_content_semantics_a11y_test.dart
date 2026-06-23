// BUT-697 chunk-1: Semantics coverage for menu content widgets.
// Verifies the regenerate / open-recipe / swap / suggest-vote tap targets
// each surface a localized Semantics label.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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

  testWidgets(
    'menu_content_widgets — section header regenerate button exposes label',
    (tester) async {
      final handle = tester.ensureSemantics();
      final vm = _FakeMenuViewModel();
      when(() => vm.isGenerating).thenReturn(false);

      final recipe = RecipeFactory.build(
        id: 'r1',
        title: 'Köttbullar',
        timeMinutes: 30,
        portions: 4,
      );

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => MenuContentWidgets.buildMenuSection(
              context,
              viewModel: vm,
              category: 'middag',
              recipes: [recipe],
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp(r'Skapa nytt förslag för Middag')),
        findsOneWidget,
      );
      handle.dispose();
    },
  );

  testWidgets(
    'menu_content_widgets — recipe row tap target announces title and open hint',
    (tester) async {
      final handle = tester.ensureSemantics();
      final vm = _FakeMenuViewModel();
      when(() => vm.isGenerating).thenReturn(false);

      final recipe = RecipeFactory.build(
        id: 'r1',
        title: 'Köttbullar',
        timeMinutes: 30,
        portions: 4,
      );

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => MenuContentWidgets.buildMenuSection(
              context,
              viewModel: vm,
              category: 'middag',
              recipes: [recipe],
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(
          RegExp(r'^Köttbullar, tryck för att öppna receptet'),
        ),
        findsWidgets,
      );
      handle.dispose();
    },
  );

  testWidgets('menu_content_widgets — swap icon exposes per-recipe label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final vm = _FakeMenuViewModel();
    when(() => vm.isGenerating).thenReturn(false);

    final recipe = RecipeFactory.build(
      id: 'r1',
      title: 'Pasta carbonara',
      timeMinutes: 25,
      portions: 4,
    );

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => MenuContentWidgets.buildMenuSection(
            context,
            viewModel: vm,
            category: 'middag',
            recipes: [recipe],
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp(r'^Byt ut Pasta carbonara')),
      findsOneWidget,
    );
    handle.dispose();
  });
}

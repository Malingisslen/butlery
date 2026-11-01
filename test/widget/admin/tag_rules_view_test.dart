import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/viewmodels/admin/tag_rules_viewmodel.dart';
import 'package:butlery/views/admin/tag_rules_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';
import '../../test_support/ingredient_review_fixtures.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  Future<void> pump(WidgetTester tester, TagRulesViewModel vm) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: TagRulesView(viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists allergens with their triggers and diets with exclusions', (
    tester,
  ) async {
    final vm = TagRulesViewModel(
      tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
    );
    await pump(tester, vm);

    expect(find.text('gluten'), findsOneWidget);
    expect(find.text('contains-gluten'), findsOneWidget);
    expect(find.text('tree-nut, peanut'), findsOneWidget);
    expect(find.text('vegetarisk'), findsOneWidget);
    expect(find.text('meat, seafood'), findsOneWidget);
  });

  testWidgets('a missing tag config is an error, never empty tables', (
    tester,
  ) async {
    final vm = TagRulesViewModel(tagConfigService: FakeTagConfigService(null));
    await pump(tester, vm);

    expect(find.text('Taggkonfigurationen är inte laddad.'), findsOneWidget);
    expect(find.text('gluten'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_app_bar.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('the add button has the same margin on both sides', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => Scaffold(
            floatingActionButton: ShoppingAppBar.buildFloatingActionButton(
              context,
              () {},
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(
      find.byKey(const ValueKey('test-shopping-list-add')),
    );
    expect(rect.left, AppDimensions.space16);
    expect(360 - rect.right, AppDimensions.space16);
  });

  testWidgets('and when the page is narrower than the screen (rail beside)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Row(
          children: [
            const SizedBox(width: 104),
            Expanded(
              child: Builder(
                builder: (context) => Scaffold(
                  floatingActionButton:
                      ShoppingAppBar.buildFloatingActionButton(context, () {}),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final rect = tester.getRect(
      find.byKey(const ValueKey('test-shopping-list-add')),
    );
    expect(rect.left, 104 + AppDimensions.space16);
    expect(900 - rect.right, AppDimensions.space16);
  });
}

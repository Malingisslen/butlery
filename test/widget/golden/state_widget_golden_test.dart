import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  group('StateWidget Golden Tests', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    testWidgets('empty state matches golden', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: SizedBox(
            width: 375,
            height: 400,
            child: StateWidget.empty(
              icon: Icons.restaurant,
              title: 'Inga recept',
              subtitle: 'Lägg till ditt första recept',
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(SizedBox).first,
        matchesGoldenFile('goldens/state_widget_empty.png'),
      );
    });

    testWidgets('error state matches golden', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: SizedBox(
            width: 375,
            height: 400,
            child: StateWidget.error(
              message: 'Något gick fel',
              onAction: () {},
              actionLabel: 'Försök igen',
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(SizedBox).first,
        matchesGoldenFile('goldens/state_widget_error.png'),
      );
    });

    testWidgets('loading state matches golden', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: SizedBox(
            width: 375,
            height: 400,
            child: StateWidget.loading(),
          ),
        ),
      );

      await expectLater(
        find.byType(SizedBox).first,
        matchesGoldenFile('goldens/state_widget_loading.png'),
      );
    });
  });
}

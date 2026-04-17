import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/state_widget.dart';

import '../../test_support/base_unit_test.dart';
import 'golden_helper.dart';

void main() {
  group('StateWidget Golden Tests', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    butleryGolden(
      'empty state matches golden',
      file: 'goldens/state_widget_empty.png',
      build: () => StateWidget.empty(
        icon: Icons.restaurant,
        title: 'Inga recept',
        subtitle: 'Lägg till ditt första recept',
      ),
    );

    butleryGolden(
      'error state matches golden',
      file: 'goldens/state_widget_error.png',
      build: () => StateWidget.error(
        message: 'Något gick fel',
        onAction: () {},
        actionLabel: 'Försök igen',
      ),
    );

    butleryGolden(
      'loading state matches golden',
      file: 'goldens/state_widget_loading.png',
      build: () => StateWidget.loading(),
    );
  });
}

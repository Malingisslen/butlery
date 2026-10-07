import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

/// BUT-2262: the theme's full-width button minimum crashes in a Row, but an
/// AlertDialog's actions are an OverflowBar, which the recipe-selection and
/// menu-load dialogs rely on to hold a themed FilledButton.
void main() {
  testWidgets('a themed FilledButton lays out in AlertDialog actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: AlertDialog(
          title: const Text('Välj recept'),
          actions: [
            TextButton(onPressed: () {}, child: const Text('Avbryt')),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.check),
              label: const Text('Lägg till'),
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

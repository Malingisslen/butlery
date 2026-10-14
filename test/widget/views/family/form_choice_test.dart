import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/views/family/family_form_parts.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  // The form adds a key on true and removes it on false, so a tap has to
  // report the state the chip is about to take, not the one it shows.
  Future<List<bool>> tapChoice(
    WidgetTester tester, {
    required bool selected,
  }) async {
    final taps = <bool>[];
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: FormChoice(
          label: 'Nötter',
          selected: selected,
          onSelected: taps.add,
        ),
      ),
    );
    await tester.tap(find.text('Nötter'));
    await tester.pump();
    return taps;
  }

  testWidgets('an unselected choice reports true when tapped', (tester) async {
    expect(await tapChoice(tester, selected: false), [true]);
  });

  testWidgets('a selected choice reports false when tapped', (tester) async {
    expect(await tapChoice(tester, selected: true), [false]);
  });
}

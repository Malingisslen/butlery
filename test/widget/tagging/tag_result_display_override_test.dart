// A manual allergen correction is never invisible: the detail view says what
// the person changed and offers a way back to the tagger's own answer.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/widgets/tagging/tag_result_display.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

TagResult _found(TriState gluten) => TagResult(
  tags: const {},
  allergenStatus: {'gluten': gluten},
  dietaryStatus: const {},
  coverage: 1.0,
  generatedAt: DateTime(2026),
  generatorVersion: kTagGeneratorVersion,
);

Future<void> _pump(
  WidgetTester tester, {
  required TagResult tagResult,
  required TagOverrides overrides,
  ValueChanged<String>? onReset,
}) => tester.pumpWidget(
  createLocalizedTestApp(
    child: TagResultDisplay(
      tagResult: tagResult,
      tagOverrides: overrides,
      onResetAllergenOverride: onReset,
      showCoverage: false,
    ),
  ),
);

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  testWidgets('says the person marked ok what the app found', (tester) async {
    await _pump(
      tester,
      tagResult: _found(TriState.contains),
      overrides: const TagOverrides(
        allergenOverrides: {'gluten': TriState.free},
      ),
    );

    expect(
      find.text('Du har markerat gluten som ok. Appen hittade gluten.'),
      findsOneWidget,
    );
  });

  testWidgets('Återställ hands the allergen back to the caller', (
    tester,
  ) async {
    String? reset;
    await _pump(
      tester,
      tagResult: _found(TriState.contains),
      overrides: const TagOverrides(
        allergenOverrides: {'gluten': TriState.free},
      ),
      onReset: (key) => reset = key,
    );

    await tester.tap(find.text('Återställ'));

    expect(reset, 'gluten');
  });

  testWidgets('says the person marked a contains the app did not find', (
    tester,
  ) async {
    await _pump(
      tester,
      tagResult: _found(TriState.free),
      overrides: const TagOverrides(
        allergenOverrides: {'gluten': TriState.contains},
      ),
    );

    expect(
      find.text('Du har markerat att receptet innehåller gluten.'),
      findsOneWidget,
    );
    // No reset callback, no button.
    expect(find.text('Återställ'), findsNothing);
  });

  testWidgets('an override that changes nothing shows no line', (tester) async {
    await _pump(
      tester,
      tagResult: _found(TriState.free),
      overrides: const TagOverrides(
        allergenOverrides: {'gluten': TriState.free},
      ),
    );

    expect(find.textContaining('Du har markerat'), findsNothing);
  });
}

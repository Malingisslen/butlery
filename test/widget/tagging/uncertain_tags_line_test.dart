// The recipe detail names the uncertainty when too few ingredients are known
// for the tags to be sure: "Osäkra taggar, 3 ingredienser okända".

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/widgets/tagging/uncertain_tags_line.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

TagResult _result(double coverage, List<String> unknown) => TagResult(
  tags: const {},
  allergenStatus: const {},
  dietaryStatus: const {},
  coverage: coverage,
  unknownIngredients: unknown,
  generatedAt: DateTime(2026, 1, 1),
);

void main() {
  group('UncertainTagsLine.appliesTo', () {
    test('no tag result means no line', () {
      expect(UncertainTagsLine.appliesTo(null), isFalse);
    });

    test('full coverage means no line', () {
      expect(UncertainTagsLine.appliesTo(_result(1.0, const [])), isFalse);
    });

    test('just below 0.80 with unknown ingredients shows the line', () {
      expect(UncertainTagsLine.appliesTo(_result(0.79, ['x'])), isTrue);
    });

    test('exactly 0.80 with unknown ingredients shows no line', () {
      expect(UncertainTagsLine.appliesTo(_result(0.80, ['x'])), isFalse);
    });

    test('low coverage without any named unknown ingredient shows no line', () {
      expect(UncertainTagsLine.appliesTo(_result(0.5, const [])), isFalse);
    });
  });

  group('UncertainTagsLine text', () {
    testWidgets('names several unknown ingredients in the plural', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: UncertainTagsLine(tagResult: _result(0.4, ['a', 'b', 'c'])),
        ),
      );

      expect(find.text('Osäkra taggar, 3 ingredienser okända'), findsOneWidget);
    });

    testWidgets('names a single unknown ingredient in the singular', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: UncertainTagsLine(tagResult: _result(0.7, ['a'])),
        ),
      );

      expect(find.text('Osäkra taggar, 1 ingrediens okänd'), findsOneWidget);
    });
  });
}

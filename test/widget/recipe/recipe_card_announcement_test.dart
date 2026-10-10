// BUT-2347: the card's value badges name their value once, in the label that
// replaces the visible glyph text, and the card itself is a button that is
// named by its own title rather than by a label restating it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';

import '../../infrastructure/builders/recipe_builder.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';
import '../../test_support/semantics_announcement.dart';

Recipe _recipe() =>
    (RecipeBuilder()
          ..id = 'announce'
          ..title = 'Köttbullar'
          ..rating = 4.5
          ..imageUrls = []
          ..withTagResult(
            TagResult(
              tags: const {},
              allergenStatus: const {},
              dietaryStatus: const {},
              coverage: 0.0,
              generatedAt: DateTime(2026, 1, 1),
              generatorVersion: '1.0',
              hasCoverageAnomaly: false,
            ),
          ))
        .build();

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  testWidgets('each badge on a detailed card is announced once and the card '
      'stays tappable', (tester) async {
    final handle = tester.ensureSemantics();
    var tapped = 0;
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Scaffold(
          body: SingleChildScrollView(
            child: RecipeCard(
              recipe: _recipe(),
              style: RecipeCardStyle.detailed,
              matchPercent: 0.85,
              showAllergenBadges: true,
              userAllergenPrefs: const {'gluten'},
              onTap: (_) => tapped++,
            ),
          ),
        ),
      ),
    );

    final card = find
        .descendant(
          of: find.byType(RecipeCard),
          matching: find.byType(InkWell),
        )
        .first;
    final lines = announcedLines(tester, card);

    expect(lines.where((l) => l.contains('4.5')), ['Betyg: 4.5']);
    expect(lines.where((l) => l.contains('85%')), [
      'Matchar 85% av dina ingredienser',
    ]);
    expect(lines.where((l) => l.contains('komplett')), [
      'Receptet är 65 procent komplett',
    ]);
    expect(lines.where((l) => l.contains('bedömda')), [
      'Allergener är inte bedömda för det här receptet',
    ]);
    expect(lines.where((l) => l.contains('Köttbullar')), ['Köttbullar']);
    expectNothingAnnouncedTwice(tester, card);
    expectActivatable(tester, card);

    tester.semantics.tap(find.semantics.byLabel(RegExp('Köttbullar')));
    expect(tapped, 1);
    handle.dispose();
  });
}

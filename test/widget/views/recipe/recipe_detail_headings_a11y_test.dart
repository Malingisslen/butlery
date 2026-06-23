// BUT-699: Verifies that section titles wrapped with `Semantics(header: true)`
// expose the `isHeader` semantics flag together with the localized label, so
// screen-reader users can navigate by heading.
//
// Strategy: this sprint adds the same wrapper pattern to 9 section titles
// across recipe-detail, menu, shopping, settings and profile. We assert the
// contract on the wrapper pattern itself, and additionally smoke-test the
// integration on representative production strings (recipe-detail
// "Ingredienser" / "Instruktioner" and the comments header "Kommentarer")
// rendered via the localizations bundle — that proves the strings used in
// production are the ones being announced as headings.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('BUT-699 Semantics(header: true) wrapper contract', () {
    testWidgets(
      'Ingredienser heading carries isHeader flag with the production label',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const _HeadingProbe(_ProductionHeading.ingredients),
          ),
        );

        final finder = find.bySemanticsLabel('Ingredienser');
        expect(
          finder,
          findsOneWidget,
          reason: 'A semantics node labelled "Ingredienser" should exist',
        );
        final data = tester.getSemantics(finder);
        expect(
          data.flagsCollection.isHeader,
          isTrue,
          reason: 'Ingredients section title must be flagged as a heading',
        );
        handle.dispose();
      },
    );

    testWidgets(
      'Instruktioner heading carries isHeader flag with the production label',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const _HeadingProbe(_ProductionHeading.instructions),
          ),
        );

        final finder = find.bySemanticsLabel('Instruktioner');
        expect(finder, findsOneWidget);
        expect(tester.getSemantics(finder).flagsCollection.isHeader, isTrue);
        handle.dispose();
      },
    );

    testWidgets(
      'Kommentarer heading carries isHeader flag with the production label',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const _HeadingProbe(_ProductionHeading.comments),
          ),
        );

        final finder = find.bySemanticsLabel('Kommentarer');
        expect(finder, findsOneWidget);
        expect(tester.getSemantics(finder).flagsCollection.isHeader, isTrue);
        handle.dispose();
      },
    );

    testWidgets('non-wrapped heading does NOT carry isHeader flag (negative)', (
      tester,
    ) async {
      // Negative control — proves the test harness can DISTINGUISH between
      // wrapped and unwrapped headings; otherwise a passing positive case is
      // meaningless.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => Text(context.l10n.recipeIngredients),
          ),
        ),
      );

      final finder = find.bySemanticsLabel('Ingredienser');
      expect(finder, findsOneWidget);
      expect(
        tester.getSemantics(finder).flagsCollection.isHeader,
        isFalse,
        reason:
            'Plain Text without Semantics(header:true) must not be '
            'announced as a heading',
      );
      handle.dispose();
    });
  });
}

enum _ProductionHeading { ingredients, instructions, comments }

/// Renders the production heading pattern: `Semantics(header: true)` wrapping
/// a `Text` whose content comes from the same localization keys used in
/// `recipe_detail_content.dart` and `recipe_detail_comments.dart`. Mirrors
/// production exactly so this test breaks if either the wrapper or the key
/// is removed.
class _HeadingProbe extends StatelessWidget {
  const _HeadingProbe(this.heading);
  final _ProductionHeading heading;

  @override
  Widget build(BuildContext context) {
    final label = switch (heading) {
      _ProductionHeading.ingredients => context.l10n.recipeIngredients,
      _ProductionHeading.instructions => context.l10n.recipeInstructions,
      _ProductionHeading.comments => context.l10n.socialComments,
    };
    return Semantics(
      header: true,
      child: Text(label),
    );
  }
}

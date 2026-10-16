// At 200 % text the shared components keep their words whole: they wrap
// between words, stack, scroll sideways or grow, and never overflow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';
import 'package:butlery/widgets/common/navigation/underline_tabs.dart';
import 'package:butlery/widgets/common/stat_row.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/word_break_finder.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget Function(BuildContext) build, {
    double scale = 2,
    double width = 360,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Builder(builder: build),
          ),
        ),
      ),
    );
  }

  testWidgets('StatRow stacks its figures when a word would not fit', (
    tester,
  ) async {
    await pump(
      tester,
      (_) => const StatRow(
        items: [
          StatRowItem(value: '45', label: 'Tillagning'),
          StatRowItem(value: '4', label: 'Portioner'),
          StatRowItem(value: '3,5', label: 'Betyg'),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(findMidWordBreaks(tester), isEmpty);
    expect(
      tester.getTopLeft(find.text('4')).dy,
      greaterThan(tester.getTopLeft(find.text('45')).dy),
      reason: 'stacked, not side by side',
    );
  });

  testWidgets('StatRow keeps its figures side by side at normal text', (
    tester,
  ) async {
    await pump(
      tester,
      (_) => const StatRow(
        items: [
          StatRowItem(value: '45', label: 'Tillagning'),
          StatRowItem(value: '4', label: 'Portioner'),
        ],
      ),
      scale: 1,
    );

    expect(
      tester.getTopLeft(find.text('4')).dy,
      tester.getTopLeft(find.text('45')).dy,
    );
  });

  testWidgets('UnderlineTabs scroll sideways instead of breaking a word', (
    tester,
  ) async {
    await pump(
      tester,
      (_) => UnderlineTabs<int>(
        values: const [0, 1],
        labelOf: (v) => v == 0 ? 'Alla recept' : 'Kokböcker',
        selected: 0,
        onChanged: (_) {},
      ),
    );

    expect(tester.takeException(), isNull);
    expect(findMidWordBreaks(tester), isEmpty);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('UnderlineTabs share the width at normal text', (tester) async {
    await pump(
      tester,
      (_) => UnderlineTabs<int>(
        values: const [0, 1],
        labelOf: (v) => v == 0 ? 'Alla recept' : 'Kokböcker',
        selected: 0,
        onChanged: (_) {},
      ),
      scale: 1,
    );

    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  testWidgets('WholeWordText shrinks a word that is wider than its box', (
    tester,
  ) async {
    await pump(
      tester,
      (_) => const SizedBox(
        width: 120,
        child: WholeWordText(
          'Kokböcker',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(findMidWordBreaks(tester), isEmpty);
  });

  testWidgets('a button label wider than 200 stays whole at 200 % text', (
    tester,
  ) async {
    await pump(
      tester,
      (context) => Center(
        child: ActionButtons.primaryButton(
          context,
          label: 'Förfrågan',
          onPressed: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(findMidWordBreaks(tester), isEmpty);
  });

  testWidgets('the large button grows past its height with the text', (
    tester,
  ) async {
    await pump(
      tester,
      (context) => Center(
        child: SizedBox(
          width: 140,
          child: ActionButtons.largeButton(
            context,
            label: 'Skapa en ny veckomeny åt hela familjen',
            icon: Icons.add,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byWidgetPredicate((w) => w is ElevatedButton)).height,
      greaterThan(100), // the default floor of largeButton
    );
  });

  testWidgets('InlineError puts its action under the message at 200 % text', (
    tester,
  ) async {
    await pump(
      tester,
      (_) => InlineError(
        what: 'Recepten med taggen gick inte att hämta.',
        actionLabel: 'Försök igen',
        onAction: () {},
      ),
    );

    expect(tester.takeException(), isNull);
    expect(findMidWordBreaks(tester), isEmpty);
    expect(
      tester.getTopLeft(find.byKey(InlineError.actionKey)).dy,
      greaterThan(
        tester
                .getBottomLeft(
                  find.text('Recepten med taggen gick inte att hämta.'),
                )
                .dy -
            1,
      ),
      reason: 'stacked below the message, not beside it',
    );
  });

  testWidgets(
    'InlineError keeps its action beside the message at normal text',
    (
      tester,
    ) async {
      await pump(
        tester,
        (_) => InlineError(
          what: 'Recepten med taggen gick inte att hämta.',
          actionLabel: 'Försök igen',
          onAction: () {},
        ),
        scale: 1,
        width: 600,
      );

      expect(
        tester.getTopLeft(find.byKey(InlineError.actionKey)).dx,
        greaterThan(
          tester
                  .getTopRight(
                    find.text('Recepten med taggen gick inte att hämta.'),
                  )
                  .dx -
              1,
        ),
      );
    },
  );
}

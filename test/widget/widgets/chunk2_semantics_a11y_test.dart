// BUT-697 chunk-2: Semantics coverage for the chunk-2 widget sweep.
// Asserts that every tap target wrapped in this sprint exposes a localized
// Semantics label discoverable via `find.bySemanticsLabel`.
//
// Like chunk-1, descendant Text labels merge with the wrapper label, so
// RegExp prefix matchers are used so the assertion isn't coupled to
// neighbouring text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test_support/semantics_announcement.dart';
import 'package:butlery/models/realtime/menu_slot_vote.dart';
import 'package:butlery/widgets/menu/menu_vote_card.dart';
import 'package:butlery/widgets/menu/parsed_extraction_chips.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/widgets/recipe/recipe_shelf.dart';
import 'package:butlery/theme/app_theme.dart';
import '../../infrastructure/builders/recipe_builder.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/base_widget_test.dart';
import '../../infrastructure/helpers/ink_fill.dart';

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  MenuSlotVote buildVote({Map<String, String> votes = const {}}) {
    return MenuSlotVote(
      id: 'v1',
      category: 'middag',
      slotIndex: 0,
      starterId: 'me',
      alternatives: const [
        VoteOption(id: 'a1', dish: {'id': 'r1', 'title': 'Pannkakor'}),
        VoteOption(id: 'a2', dish: {'id': 'r2', 'title': 'Pasta'}),
      ],
      votes: votes,
      deadline: DateTime.now().add(const Duration(hours: 24)),
      createdAt: DateTime.now(),
    );
  }

  group('BUT-697 chunk-2 widget Semantics labels', () {
    testWidgets('recipe_shelf — shelf card exposes recipe-open label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final recipe = (RecipeBuilder()..title = 'Pannkakor').build();

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: SizedBox(
            height: 200,
            child: RecipeShelf(
              title: 'Hyllan',
              recipes: [recipe],
              onRecipeTap: (_) {},
            ),
          ),
        ),
      );

      final opener = find.bySemanticsLabel(RegExp(r'^Öppna recept'));
      expect(opener, findsOneWidget);
      expectNothingAnnouncedTwice(tester, opener);
      handle.dispose();
    });

    testWidgets('menu_vote_card — unselected option exposes vote label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: MenuVoteCard(
            vote: buildVote(),
            currentUserId: 'me',
            onVote: (_) {},
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp(r'Rösta på Pannkakor')),
        findsWidgets,
      );
      handle.dispose();
    });

    // BUT-2205: the option's own fill used to sit above the ink layer, so a
    // pressed option showed nothing.
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      testWidgets('menu_vote_card — a pressed option shows surface.raised '
          '(${theme.brightness.name})', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Theme(
              data: theme,
              child: MenuVoteCard(
                vote: buildVote(),
                currentUserId: 'me',
                onVote: (_) {},
              ),
            ),
          ),
        );
        final option = find.text('Pannkakor');
        expect(pressIsCovered(tester, option), isFalse);
        expect(borderIsAbovePress(tester, option), isTrue);
        final gesture = await holdPress(tester, option);
        expect(
          paintsInkFill(
            tester,
            option,
            theme.colorScheme.surfaceContainerHighest,
          ),
          isTrue,
        );
        await gesture.cancel();
      });
    }

    testWidgets('menu_vote_card — selected option exposes selected label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: MenuVoteCard(
            vote: buildVote(votes: const {'me': 'a1'}),
            currentUserId: 'me',
            onVote: (_) {},
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp(r'Pannkakor, din röst\.')),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets(
      'parsed_extraction_chips — refine prompt exposes a button label',
      (tester) async {
        final handle = tester.ensureSemantics();
        // notUnderstood populated => trace.hasGaps == true => link renders.
        const parsed = ParsedMenuRequest(
          slotRequests: [],
          globalAllergenAvoid: {},
          globalDietaryRequire: {},
          dayPins: [],
          trace: ExtractionTrace(notUnderstood: ['fancy']),
          rawPrompt: 'something fancy',
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ParsedExtractionChips(
              parsed: parsed,
              onRefinePrompt: () {},
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(RegExp(r'Förbättra menyprompten')),
          findsWidgets,
        );
        handle.dispose();
      },
    );
  });
}

// BUT-697 chunk-2: Semantics coverage for the chunk-2 widget sweep.
// Asserts that every tap target wrapped in this sprint exposes a localized
// Semantics label discoverable via `find.bySemanticsLabel`.
//
// Like chunk-1, descendant Text labels merge with the wrapper label, so
// RegExp prefix matchers are used so the assertion isn't coupled to
// neighbouring text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/realtime/menu_slot_vote.dart';
import 'package:butlery/widgets/menu/menu_vote_card.dart';
import 'package:butlery/widgets/menu/parsed_extraction_chips.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/widgets/recipe/recipe_shelf.dart';
import '../../infrastructure/builders/recipe_builder.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

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
      menuId: 'm1',
      category: 'middag',
      slotIndex: 0,
      alternatives: const [
        VoteOption(
          id: 'a1',
          recipeId: 'r1',
          recipeName: 'Pannkakor',
          suggestedByUserId: 'me',
        ),
        VoteOption(
          id: 'a2',
          recipeId: 'r2',
          recipeName: 'Pasta',
          suggestedByUserId: 'me',
        ),
      ],
      votes: votes,
      deadline: DateTime.now().add(const Duration(hours: 24)),
      createdByUserId: 'me',
      createdAt: DateTime.now(),
    );
  }

  group('BUT-697 chunk-2 widget Semantics labels', () {
    testWidgets('recipe_shelf — shelf card exposes recipe-open label',
        (tester) async {
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

      expect(
        find.bySemanticsLabel(RegExp(r'^Pannkakor, tryck för att öppna')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('menu_vote_card — unselected option exposes vote label',
        (tester) async {
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

    testWidgets('menu_vote_card — selected option exposes selected label',
        (tester) async {
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
        find.bySemanticsLabel(RegExp(r'Pannkakor, vald')),
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
    });
  });
}

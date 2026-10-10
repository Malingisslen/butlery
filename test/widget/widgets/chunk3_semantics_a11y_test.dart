// BUT-697 chunk-3: Semantics coverage for the chunk-3 widget sweep.
// Asserts that every tap target wrapped in this sprint exposes a localized
// Semantics label discoverable via `find.bySemanticsLabel`.
//
// Like chunk-1/-2, descendant Text labels merge with the wrapper label, so
// RegExp prefix matchers are used so the assertion isn't coupled to
// neighbouring text.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/cooking/ingredient_substitution.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/recipe/heirloom_metadata.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/input/ingredient_suggestion_list.dart';
import 'package:butlery/widgets/common/search_filter/quick_filter_chips.dart';
import 'package:butlery/widgets/common/share_dialog/share_target_selection_enhanced.dart';
import 'package:butlery/widgets/cooking/substitution_bottom_sheet.dart';
import 'package:butlery/widgets/recipe/heirloom_section.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/base_widget_test.dart';
import '../../test_support/semantics_announcement.dart';

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('BUT-697 chunk-3 widget Semantics labels', () {
    testWidgets(
      'ingredient_suggestion_list — suggestion row exposes add-ingredient label',
      (tester) async {
        final handle = tester.ensureSemantics();
        const ingredient = IngredientData(
          id: 'ing_1',
          swedish: 'Mjölk',
          english: 'Milk',
          group: 'mejeri',
          properties: {'dairy'},
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: IngredientSuggestionList(
              results: const [ingredient],
              onTap: (_) {},
            ),
          ),
        );

        final row = find.bySemanticsLabel(RegExp(r'^Lägg till'));
        expect(row, findsOneWidget);
        expect(announcedLines(tester, row), contains('Mjölk'));
        expectNothingAnnouncedTwice(tester, row);
        expectActivatable(tester, row);
        handle.dispose();
      },
    );

    testWidgets(
      'quick_filter_chips — unselected chip exposes filter-by label',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: QuickFilterChips(
              options: const [QuickFilterOption(id: 'fav', label: 'Favoriter')],
              selectedIds: const {},
              onFilterToggle: (_) {},
              showAllOption: false,
            ),
          ),
        );

        final chip = find.bySemanticsLabel(RegExp(r'^Filtrera\nFavoriter'));
        expect(chip, findsOneWidget);
        expectActivatable(tester, chip);
        expectNothingAnnouncedTwice(tester, chip);
        handle.dispose();
      },
    );

    testWidgets(
      'quick_filter_chips — selected chip is flagged selected',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: QuickFilterChips(
              options: const [QuickFilterOption(id: 'fav', label: 'Favoriter')],
              selectedIds: const {'fav'},
              onFilterToggle: (_) {},
              showAllOption: false,
            ),
          ),
        );

        final chip = find.bySemanticsLabel(RegExp(r'^Filtrera\nFavoriter'));
        expect(chip, findsOneWidget);
        expect(
          announcedLines(tester, chip),
          ['Filtrera', 'Favoriter'],
          reason: 'the selected state is a flag, not words',
        );
        expect(
          tester
              .getSemantics(chip)
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          ui.Tristate.isTrue,
        );
        expectNothingAnnouncedTwice(tester, chip);
        handle.dispose();
      },
    );

    testWidgets('heirloom_section — overlay exposes open-fullscreen label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final heirloom = HeirloomMetadata(
        sourceImageUrl: 'https://example.invalid/heirloom.jpg',
        addedAt: DateTime(2026, 1, 1),
        addedByUserId: 'user_1',
      );

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: SizedBox(
            height: 400,
            width: 300,
            child: HeirloomSection(heirloom: heirloom),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp(r'Öppna originalskanning i fullskärm')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets(
      'substitution_bottom_sheet — replace button exposes substitute label',
      (tester) async {
        final handle = tester.ensureSemantics();
        const suggestion = IngredientSubstitution(name: 'yoghurt', ratio: 1.0);

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const SubstitutionBottomSheet(
              ingredientName: 'crème fraîche',
              suggestions: [suggestion],
            ),
          ),
        );

        final replace = find.bySemanticsLabel(RegExp(r'Ersättare: yoghurt'));
        expect(replace, findsOneWidget);
        expectNothingAnnouncedTwice(tester, replace);
        expectActivatable(tester, replace);
        handle.dispose();
      },
    );

    testWidgets(
      'share_target_selection_enhanced — tab buttons expose switch label',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (ctx) => ShareTargetSelectionEnhanced.build(
                ctx,
                ShareTargetType.friends,
                const <UserProfile>[],
                const <FriendCategory>[],
                const {},
                const {},
                '',
                (_) {},
                (_) {},
                (_) {},
                (_) {},
              ),
            ),
          ),
        );

        // Tab labels render their visible text inside the Semantics wrapper.
        // Both "Vänner" and "Grupper" tabs should expose a switch label.
        final tab = find.bySemanticsLabel(RegExp(r'^Visa\nVänner'));
        expect(tab, findsOneWidget);
        expectNothingAnnouncedTwice(tester, tab);
        expectActivatable(tester, tab);
        handle.dispose();
      },
    );
  });
}

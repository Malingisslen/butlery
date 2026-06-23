// BUT-697 chunk-3: Semantics coverage for the chunk-3 widget sweep.
// Asserts that every tap target wrapped in this sprint exposes a localized
// Semantics label discoverable via `find.bySemanticsLabel`.
//
// Like chunk-1/-2, descendant Text labels merge with the wrapper label, so
// RegExp prefix matchers are used so the assertion isn't coupled to
// neighbouring text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/cooking/ingredient_substitution.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/recipe/heirloom_metadata.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/widgets/common/input/ingredient_suggestion_list.dart';
import 'package:butlery/widgets/common/input/shopping_list_card.dart'
    as input_card;
import 'package:butlery/widgets/common/search_filter/quick_filter_chips.dart';
import 'package:butlery/widgets/common/share_dialog/share_target_selection_enhanced.dart';
import 'package:butlery/widgets/cooking/substitution_bottom_sheet.dart';
import 'package:butlery/widgets/recipe/heirloom_section.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

class _MockShoppingViewModel extends Mock implements UnifiedShoppingViewModel {}

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

        expect(
          find.bySemanticsLabel(RegExp(r'^Lägg till Mjölk')),
          findsOneWidget,
        );
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
              options: const [
                QuickFilterOption(id: 'fav', label: 'Favoriter'),
              ],
              selectedIds: const {},
              onFilterToggle: (_) {},
              showAllOption: false,
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(RegExp(r'Filtrera på Favoriter')),
          findsWidgets,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'quick_filter_chips — selected chip exposes selected-filter label',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: QuickFilterChips(
              options: const [
                QuickFilterOption(id: 'fav', label: 'Favoriter'),
              ],
              selectedIds: const {'fav'},
              onFilterToggle: (_) {},
              showAllOption: false,
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(RegExp(r'Favoriter, valt filter')),
          findsWidgets,
        );
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
        find.bySemanticsLabel(
          RegExp(r'Öppna originalskanning i fullskärm'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets(
      'substitution_bottom_sheet — replace button exposes substitute label',
      (tester) async {
        final handle = tester.ensureSemantics();
        const suggestion = IngredientSubstitution(
          name: 'yoghurt',
          ratio: 1.0,
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const SubstitutionBottomSheet(
              ingredientName: 'crème fraîche',
              suggestions: [suggestion],
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(RegExp(r'Byt ut mot yoghurt i receptet')),
          findsOneWidget,
        );
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
        expect(
          find.bySemanticsLabel(RegExp(r'Visa ')),
          findsWidgets,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'input/shopping_list_card — list card exposes shopping-list label',
      (tester) async {
        final handle = tester.ensureSemantics();
        final mockVm = _MockShoppingViewModel();
        final list = UnifiedShoppingList(
          id: 'list_1',
          ownerId: 'user_1',
          ownerDisplayName: 'Test',
          name: 'Veckans inköp',
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: input_card.ShoppingListCard(
              list: list,
              viewModel: mockVm,
              isSelected: false,
              showActions: false,
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(RegExp(r'Inköpslista: Veckans inköp')),
          findsOneWidget,
        );
        handle.dispose();
      },
    );
  });
}

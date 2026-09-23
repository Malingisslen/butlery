/// P4-T6 (P4-SWEEP-VIEWS): view foregrounds read in dark mode.
///
/// ColorScheme.primary is surface.ink #24382C in both schemes
/// (lib/theme/app_colors.dart), so a view that drew text, a glyph or a line
/// in cs.primary drew ink on the dark page #17251D (tokens.json:104-107).
/// The foreground is text.primary, onSurface: #24382C light, #F5F4ED dark
/// (tokens.json:54-57). Links are text.link, #8A5212 light and #DCA968 dark
/// (tokens.json:228-232).
///
/// One representative per view family here (social, legal, pantry,
/// shopping, messaging, week menu); recipes, import, settings and auth carry
/// their dark case in their own view test files.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu/menu_placement_viewmodel.dart';
import 'package:butlery/viewmodels/pantry/pantry_selection_manager.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/legal/markdown_body.dart';
import 'package:butlery/views/menu_placement/placement_widgets.dart';
import 'package:butlery/views/messaging/chat_view/chat_input_section.dart';
import 'package:butlery/views/pantry/pantry_item_card.dart';
import 'package:butlery/views/social/friends_list/friends_empty_state.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_item_tiles.dart';

class _MockPantryViewModel extends Mock implements PantryViewModel {}

class _MockPlacementViewModel extends Mock implements MenuPlacementViewModel {}

class _NoopUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async => true;
}

final _modes = <(String, ThemeData)>[
  ('light', AppTheme.lightTheme),
  ('dark', AppTheme.darkTheme),
];

Widget _app(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

/// text.primary for [theme]: ink on light, paper on dark.
Color _textPrimary(ThemeData theme) => theme.colorScheme.onSurface;

void main() {
  setUpAll(() {
    registerFallbackValue(DayOfWeek.mon);
    registerFallbackValue(MealSlot.ovrigt);
  });

  test('the premise: cs.primary is ink in both schemes, onSurface is not', () {
    expect(
      AppTheme.darkTheme.colorScheme.primary,
      AppTheme.lightTheme.colorScheme.primary,
    );
    expect(
      AppTheme.darkTheme.colorScheme.onSurface,
      isNot(AppTheme.darkTheme.colorScheme.primary),
    );
    // Light mode is unchanged by the sweep: text.primary is the same ink.
    expect(
      AppTheme.lightTheme.colorScheme.onSurface,
      AppTheme.lightTheme.colorScheme.primary,
    );
  });

  for (final (mode, theme) in _modes) {
    group('$mode mode', () {
      testWidgets('social: the empty friends headline is text.primary', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            theme,
            FriendsEmptyState(onInvite: () {}, onFindByUsername: () {}),
          ),
        );
        final title = tester.widget<Text>(
          find.text('Laga tillsammans med vänner'),
        );
        expect(title.style?.color, _textPrimary(theme));
      });

      testWidgets('legal: a link in the policy text is text.link', (
        tester,
      ) async {
        final original = UrlLauncherPlatform.instance;
        UrlLauncherPlatform.instance = _NoopUrlLauncher();
        addTearDown(() => UrlLauncherPlatform.instance = original);

        await tester.pumpWidget(
          _app(
            theme,
            const SingleChildScrollView(
              child: MarkdownBody(data: 'Läs [villkoren](https://x.se).'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final link = tester.widget<Text>(find.text('villkoren'));
        // The literal text.link values (tokens.json:228-232), not a theme
        // member: a member comparison would pass with a wrong dark value.
        final linkColour = mode == 'light'
            ? const Color(0xFF8A5212)
            : const Color(0xFFDCA968);
        expect(link.style?.color, linkColour);
        expect(link.style?.color, isNot(theme.colorScheme.primary));
      });

      testWidgets('pantry: a chosen card shows its mark in text.primary', (
        tester,
      ) async {
        final vm = _MockPantryViewModel();
        final selection = PantrySelectionManager()..enterSelectionMode('p_1');
        final item = PantryItem(
          id: 'p_1',
          ingredientName: 'Mjölk',
          quantity: 1,
          unit: 'l',
          location: PantryLocation.fridge,
          addedAt: DateTime(2026, 1, 1),
        );
        await tester.pumpWidget(
          _app(
            theme,
            MultiProvider(
              providers: [
                ChangeNotifierProvider<PantryViewModel>.value(value: vm),
                ChangeNotifierProvider<PantrySelectionManager>.value(
                  value: selection,
                ),
              ],
              child: ListView(children: [PantryItemCard(item: item)]),
            ),
          ),
        );
        final mark = tester.widget<Icon>(find.byIcon(Icons.check_circle));
        expect(mark.color, _textPrimary(theme));
      });

      testWidgets('shopping: an unticked box has a text.primary edge', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            theme,
            ShoppingItemTile(
              item: UnifiedShoppingItem(
                id: 's-1',
                name: 'Mjölk',
                amount: 1,
                unit: 'l',
                category: 'Mejeri',
                bought: false,
              ),
              isCompleted: false,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final box = tester.widget<AnimatedContainer>(
          find.byWidgetPredicate(
            (w) =>
                w is AnimatedContainer &&
                w.constraints ==
                    const BoxConstraints.tightFor(width: 22, height: 22),
          ),
        );
        final border = (box.decoration! as BoxDecoration).border! as Border;
        expect(border.top.color, _textPrimary(theme));
      });

      testWidgets('messaging: the send glyph is text.primary when typing', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            theme,
            ChatInputSection(
              conversationId: 'conv-1',
              onSendMessage:
                  (String _, {MessageType type = MessageType.text}) {},
              onAttachment: (String _) {},
            ),
          ),
        );
        await tester.enterText(find.byType(TextField).first, 'hej');
        await tester.pump();
        final send = tester.widget<Icon>(find.byIcon(Icons.send));
        expect(send.color, _textPrimary(theme));
      });

      testWidgets('week menu: a new Övrigt entry has a text.primary edge', (
        tester,
      ) async {
        final now = DateTime(2026, 4, 1, 12);
        const entry = WeeklyMenuPlanEntry(
          id: 'e-1',
          day: DayOfWeek.mon,
          slot: MealSlot.ovrigt,
          recipeId: 'r-1',
          recipeTitle: 'Pannkakor',
        );
        final vm = _MockPlacementViewModel();
        when(() => vm.plan).thenReturn(
          WeeklyMenuPlan(
            id: 'w-1',
            userId: 'u-1',
            weekStartDate: DateTime(2026, 4, 6),
            entries: const [entry],
            createdAt: now,
            updatedAt: now,
          ),
        );
        when(() => vm.isEligible(any(), any())).thenReturn(false);
        when(() => vm.selectedItem).thenReturn(null);
        when(() => vm.isSessionEntry(any())).thenReturn(true);

        await tester.pumpWidget(
          _app(theme, SingleChildScrollView(child: PlacementGrid(vm: vm))),
        );
        final chip = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('pannkakor'),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Container &&
                      w.decoration is BoxDecoration &&
                      (w.decoration! as BoxDecoration).border is Border,
                ),
              )
              .first,
        );
        final border = (chip.decoration! as BoxDecoration).border! as Border;
        expect(border.left.color, _textPrimary(theme));
      });
    });
  }
}

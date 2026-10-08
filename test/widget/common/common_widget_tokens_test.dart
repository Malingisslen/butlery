// BUT-2183 5l: the shared widgets under lib/widgets/common leave the old
// opacity steps. Status chips and notices are the mode's surface tint with no
// border (B83-2) and the matching on-colour for glyph and text; neutral chips
// are the raised surface with no border; the selected toggle is the raised
// surface with a 1.5 px text.primary border (B83-1). Each test runs in both
// modes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/content_cards/menu_card.dart';
import 'package:butlery/widgets/common/content_cards/shopping_list_card.dart';
import 'package:butlery/widgets/common/emoji_reaction_display.dart';
import 'package:butlery/widgets/common/filter_status_chip.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/admin_badge.dart';
import 'package:butlery/widgets/common/indicators/emoji_avatar.dart';
import 'package:butlery/widgets/common/indicators/realtime_status_widgets.dart';
import 'package:butlery/widgets/common/indicators/status_indicator.dart';
import 'package:butlery/widgets/common/input/portion_scaler_ui.dart';

import '../../infrastructure/factories/recipe_factory.dart';

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme,
  Widget child,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: const Locale('sv'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
  await tester.pump();
}

/// The nearest Container above [of] that paints a BoxDecoration.
BoxDecoration _decorationAbove(WidgetTester tester, Finder of) {
  final container = find
      .ancestor(
        of: of,
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration,
        ),
      )
      .first;
  return tester.widget<Container>(container).decoration! as BoxDecoration;
}

Color? _glyphColor(WidgetTester tester, Finder glyph) =>
    tester.widget<Icon>(glyph).color;

Color? _textColor(WidgetTester tester, Finder text) =>
    tester.widget<Text>(text).style?.color;

/// The colour of the label beside [glyph]: the first Text in the nearest Row
/// that holds the glyph.
Color? _labelColorBeside(WidgetTester tester, Finder glyph) {
  final row = find.ancestor(of: glyph, matching: find.byType(Row)).first;
  final label = find.descendant(of: row, matching: find.byType(Text)).first;
  return tester.widget<Text>(label).style?.color;
}

UnifiedShoppingList _list({
  required bool allBought,
  ListType type = ListType.personal,
}) => UnifiedShoppingList(
  id: 'list1',
  name: 'Veckans inköp',
  ownerId: 'u1',
  ownerDisplayName: 'Anna',
  items: [
    UnifiedShoppingItem(
      id: 'i1',
      name: 'Mjölk',
      amount: 1,
      unit: 'liter',
      category: ShoppingCategory.dairy,
      bought: true,
    ),
    UnifiedShoppingItem(
      id: 'i2',
      name: 'Bröd',
      amount: 1,
      unit: 'st',
      category: ShoppingCategory.breadGrain,
      bought: allBought,
    ),
  ],
  type: type,
  memberPermissions: type == ListType.collaborative
      ? {'u2': SharedListPermission.edit}
      : const {},
);

SharedMenu _sharedMenu() => SharedMenu(
  id: 'm1',
  sharedByUserId: 'u1',
  sharedByDisplayName: 'Anna',
  menuTitle: 'Veckomeny',
  menuSnapshot: <String, List<Recipe>>{
    'Middag': [
      RecipeFactory.build(
        id: 'r1',
        title: 'Köttbullar',
        imageUrls: const [],
        personalTagIds: const [],
      ),
    ],
  },
  activeCollaboratorCount: 2,
);

void main() {
  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;
    final modeColors = ModeColors.of(theme.brightness);

    group('sharing chip on the menu and list cards, $mode', () {
      testWidgets('menu card: raised fill, no border, link-text label', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          MenuCard(menu: _sharedMenu(), showSharingStatus: true),
        );

        final glyph = find.byIcon(ButleryIcons.users);
        expect(glyph, findsOneWidget);
        final deco = _decorationAbove(tester, glyph);
        expect(deco.color, cs.surfaceContainerHighest);
        expect(deco.border, isNull);
        expect(_glyphColor(tester, glyph), cs.onSurface);
        expect(
          _labelColorBeside(tester, glyph),
          modeColors.textLink,
        );
      });

      testWidgets('list card: raised fill, no border, link-text label', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          ShoppingListCard(
            shoppingList: _list(allBought: false, type: ListType.collaborative),
            showSharingStatus: true,
          ),
        );

        final glyph = find.byIcon(ButleryIcons.users);
        expect(glyph, findsOneWidget);
        final deco = _decorationAbove(tester, glyph);
        expect(deco.color, cs.surfaceContainerHighest);
        expect(deco.border, isNull);
        expect(_glyphColor(tester, glyph), cs.onSurface);
        expect(
          _labelColorBeside(tester, glyph),
          modeColors.textLink,
        );
      });
    });

    group('shopping list completion chip, $mode', () {
      testWidgets('complete is the success tint with onSuccessContainer', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          ShoppingListCard(
            shoppingList: _list(allBought: true),
            style: ShoppingListCardStyle.compact,
          ),
        );

        final glyph = find.byIcon(ButleryIcons.circleCheck);
        final deco = _decorationAbove(tester, glyph);
        expect(deco.color, modeColors.surfaceTintSuccess);
        expect(deco.border, isNull);
        expect(_glyphColor(tester, glyph), modeColors.onSuccessContainer);
        expect(_labelColorBeside(tester, glyph), modeColors.onSuccessContainer);
      });

      testWidgets('in progress is the warning tint with textWarning', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          ShoppingListCard(
            shoppingList: _list(allBought: false),
            style: ShoppingListCardStyle.compact,
          ),
        );

        final glyph = find.byIcon(ButleryIcons.hourglass);
        final deco = _decorationAbove(tester, glyph);
        final warningText = AppModeColors.textWarning(theme.brightness);
        expect(deco.color, modeColors.surfaceTintWarning);
        expect(deco.border, isNull);
        expect(_glyphColor(tester, glyph), warningText);
        expect(_labelColorBeside(tester, glyph), warningText);
      });
    });

    group('reaction badge, $mode', () {
      testWidgets('yours is raised with a text.primary border; others are '
          'opaque surface with an outlineVariant border', (tester) async {
        await _pump(
          tester,
          theme,
          EmojiReactionDisplay(
            reactions: const {
              'thumbs_up': ['me'],
              'heart': ['other'],
            },
            currentUserId: 'me',
            onReactionTap: (_) {},
          ),
        );

        final badges = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(EmojiReactionDisplay),
                matching: find.byWidgetPredicate(
                  (w) => w is Container && w.decoration is BoxDecoration,
                ),
              ),
            )
            .map((c) => c.decoration! as BoxDecoration)
            .toList();
        expect(badges, hasLength(2));

        final yours = badges.firstWhere(
          (d) => d.color == cs.surfaceContainerHighest,
        );
        expect((yours.border! as Border).top.color, cs.onSurface);

        final others = badges.firstWhere((d) => d != yours);
        expect(others.color, cs.surface);
        expect(others.color!.a, 1.0);
        expect((others.border! as Border).top.color, cs.outlineVariant);
      });
    });

    group('neutral chips, $mode', () {
      testWidgets('filter status chip is raised with no border', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          const FilterStatusChip(filterParts: ['Vegetarisk'], selectedCount: 2),
        );

        final deco = _decorationAbove(tester, find.text('2 valda'));
        expect(deco.color, cs.surfaceContainerHighest);
        expect(deco.border, isNull);
        expect(
          _textColor(tester, find.text('Filter: Vegetarisk')),
          cs.onSecondaryContainer,
        );
        expect(_textColor(tester, find.text('2 valda')), cs.onSurface);
        expect(
          _glyphColor(tester, find.byIcon(ButleryIcons.filter)),
          cs.onSurfaceVariant,
        );
      });

      testWidgets(
        'admin badge is surface.base with text.primary glyph and text',
        (
          tester,
        ) async {
          await _pump(tester, theme, const AdminBadge(label: 'Admin'));

          final deco = _decorationAbove(tester, find.text('Admin'));
          expect(deco.color, cs.surface);
          expect(deco.border, isNull);
          expect(_textColor(tester, find.text('Admin')), cs.onSurface);
          expect(
            _glyphColor(tester, find.byIcon(ButleryIcons.crown)),
            cs.onSurface,
          );
        },
      );

      testWidgets('emoji avatar defaults to the raised surface', (
        tester,
      ) async {
        await _pump(tester, theme, const EmojiAvatar(emoji: '😀'));

        final deco = _decorationAbove(tester, find.text('😀'));
        expect(deco.color, cs.surfaceContainerHighest);
      });

      testWidgets('status indicator is raised and keeps the caller glyph', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          StatusIndicator(
            icon: ButleryIcons.circleCheck,
            color: modeColors.success,
          ),
        );

        final glyph = find.byIcon(ButleryIcons.circleCheck);
        final deco = _decorationAbove(tester, glyph);
        expect(deco.color, cs.surfaceContainerHighest);
        expect(_glyphColor(tester, glyph), modeColors.success);
      });
    });

    group('realtime offline banner, $mode', () {
      testWidgets('is the danger tint with the title in onErrorContainer', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          const RealtimeStatusBanner(
            isOnline: false,
            statusDescription: 'Ingen anslutning',
            statusEmoji: '🔴',
          ),
        );

        final banner = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('Ingen anslutning'),
                matching: find.byWidgetPredicate(
                  (w) => w is Container && w.color != null,
                ),
              )
              .first,
        );
        expect(banner.color, modeColors.surfaceTintDanger);

        final title = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(RealtimeStatusBanner),
                matching: find.byType(Text),
              ),
            )
            .firstWhere(
              (t) => t.data != '🔴' && t.data != 'Ingen anslutning',
            );
        expect(title.style?.color, cs.onErrorContainer);
      });
    });

    group('unit-conversion toggle, $mode', () {
      Future<ButtonStyle> pumpToggle(
        WidgetTester tester, {
        required bool convertToSwedish,
      }) async {
        await _pump(
          tester,
          theme,
          Builder(
            builder: (context) => PortionScalerUI.buildScaler(
              context: context,
              currentPortions: 4,
              originalPortions: 4,
              convertToSwedish: convertToSwedish,
              hasAmericanUnits: true,
              minPortions: 1,
              maxPortions: 20,
              scaleAnimation: const AlwaysStoppedAnimation(1),
              onUpdatePortions: (_) {},
              onToggleUnitConversion: () {},
            ),
          ),
        );
        return tester
            .widget<OutlinedButton>(find.byType(OutlinedButton))
            .style!;
      }

      testWidgets('selected is raised with a 1.5 px text.primary border', (
        tester,
      ) async {
        final style = await pumpToggle(tester, convertToSwedish: true);

        expect(style.backgroundColor!.resolve({}), cs.surfaceContainerHighest);
        final side = style.side!.resolve({})!;
        expect(side.color, cs.onSurface);
        expect(side.width, 1.5);
      });

      testWidgets('unselected has no fill and a 1 px outline border', (
        tester,
      ) async {
        final style = await pumpToggle(tester, convertToSwedish: false);

        expect(style.backgroundColor, isNull);
        final side = style.side!.resolve({})!;
        expect(side.color, cs.outline);
        expect(side.width, 1);
      });
    });
  }
}

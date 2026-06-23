/// BUT-1358: pin that ShoppingListCard mounts a HoverableCard ancestor whose
/// rest decoration reproduces the previous Material(elevation: 4) appearance
/// (surface fill + square corners + an elevation shadow) and whose hover
/// variant only deepens that shadow.
///
/// Intent: BUT-1358 replaced the elevated Material with a HoverableCard so the
/// card gains a web/desktop hover affordance without changing its rest look.
/// This render test guards against a refactor dropping the wrapper or altering
/// the rest fill/corner tokens, and confirms a non-tappable card defers the
/// cursor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/content_cards/shopping_list_card.dart';
import 'package:butlery/widgets/common/hoverable_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

UnifiedShoppingList _list() => UnifiedShoppingList(
      id: 'list1',
      name: 'Veckans inköp',
      ownerId: 'u1',
      ownerDisplayName: 'Anna',
      items: const <UnifiedShoppingItem>[],
      type: ListType.personal,
    );

void main() {
  group('ShoppingListCard mounts HoverableCard (BUT-1358)', () {
    testWidgets('renders a HoverableCard ancestor', (tester) async {
      await tester.pumpWidget(_wrap(
        ShoppingListCard(shoppingList: _list(), onTap: () {}),
      ));

      expect(
        find.descendant(
          of: find.byType(ShoppingListCard),
          matching: find.byType(HoverableCard),
        ),
        findsOneWidget,
      );
    });

    testWidgets('rest decoration uses surface fill + square corners + shadow',
        (tester) async {
      late ColorScheme cs;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          cs = Theme.of(context).colorScheme;
          return ShoppingListCard(shoppingList: _list(), onTap: () {});
        }),
      ));

      final hoverable = tester.widget<HoverableCard>(
        find.descendant(
          of: find.byType(ShoppingListCard),
          matching: find.byType(HoverableCard),
        ),
      );

      final rest = hoverable.restDecoration as BoxDecoration;
      expect(rest.color, cs.surface,
          reason: 'Shopping list card fill must use the surface token.');
      expect(
        rest.borderRadius,
        BorderRadius.circular(AppDimensions.borderRadiusM),
      );
      expect(rest.boxShadow, isNotNull,
          reason: 'Rest reproduces the old Material elevation as a shadow.');
    });

    testWidgets('hover variant keeps fill + corners, only deepens shadow',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ShoppingListCard(shoppingList: _list(), onTap: () {}),
      ));

      final hoverable = tester.widget<HoverableCard>(
        find.descendant(
          of: find.byType(ShoppingListCard),
          matching: find.byType(HoverableCard),
        ),
      );

      final rest = hoverable.restDecoration as BoxDecoration;
      final hover = hoverable.hoverDecoration as BoxDecoration;

      expect(hover.color, equals(rest.color));
      expect(hover.borderRadius, equals(rest.borderRadius));
      expect(hover.boxShadow, isNotNull);
      expect(hover.boxShadow, isNot(equals(rest.boxShadow)),
          reason: 'Hover must deepen the shadow beyond the rest elevation.');
    });

    testWidgets('non-tappable card defers the cursor', (tester) async {
      MouseCursor cursorOf() {
        final mouseRegion = tester.widget<MouseRegion>(
          find
              .descendant(
                of: find.byType(HoverableCard),
                matching: find.byType(MouseRegion),
              )
              .first,
        );
        return mouseRegion.cursor;
      }

      await tester.pumpWidget(_wrap(
        ShoppingListCard(shoppingList: _list(), onTap: () {}),
      ));
      expect(cursorOf(), SystemMouseCursors.click,
          reason: 'A card with an onTap must show the click cursor.');

      await tester.pumpWidget(_wrap(
        ShoppingListCard(shoppingList: _list()),
      ));
      expect(cursorOf(), MouseCursor.defer,
          reason: 'A card with no onTap should not imply clickability.');
    });
  });
}

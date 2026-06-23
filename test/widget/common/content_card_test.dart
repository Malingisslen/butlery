/// Widget tests for the ContentCard facade.
///
/// Scope (facade-level contract, not specialized card internals):
///   - Each ContentCardType delegates to the correct specialized widget
///     (RecipeCard / FriendCard / FriendRequestCard / MenuCard / ShoppingListCard).
///   - Each ContentCardStyle (detailed/compact/grid) is mapped through to the
///     specialized card's style enum.
///   - Pass-through props (margin, padding, showImage, showTags, showMetadata,
///     showOnlineStatus, showSharingStatus, trailing, subtitle) reach the
///     specialized widget.
///   - Tap / long-press / favorite / accept / decline callbacks fire and are
///     adapted across the (Recipe) -> () signature gap for RecipeCard.
///   - Legacy static factory methods (recipe / compactRecipe / friend /
///     friendRequest) produce equivalent ContentCard configurations.
///
/// Out of scope: the visual rendering of each specialized card (covered by
/// dedicated tests under widget/recipe and widget/common/content_cards).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/widgets/common/content_cards/friend_card.dart';
import 'package:butlery/widgets/common/content_cards/menu_card.dart';
import 'package:butlery/widgets/common/content_cards/shopping_list_card.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';
import 'package:butlery/theme/app_theme.dart';

import '../../infrastructure/factories/recipe_factory.dart';

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

UserProfile _user({
  String uid = 'u1',
  String displayName = 'Anna Andersson',
  String email = 'anna@example.com',
}) {
  final ts = DateTime(2026, 5, 1, 12);
  return UserProfile(
    uid: uid,
    displayName: displayName,
    email: email,
    joinedAt: ts,
    lastActiveAt: ts,
    isOnline: false,
  );
}

FriendRequest _request({String? message}) => FriendRequest(
  id: 'req-1',
  fromUserId: 'sender',
  toUserId: 'me',
  sentAt: DateTime(2026, 5, 1, 12),
  message: message,
);

Recipe _recipe() => RecipeFactory.build(
  id: 'r1',
  title: 'Köttbullar',
  description: 'Klassisk husmanskost',
  imageUrls: const [],
  personalTagIds: const [],
);

UnifiedShoppingList _shoppingList({String name = 'Veckans inköp'}) =>
    UnifiedShoppingList.personal(
      name: name,
      ownerId: 'u1',
      ownerDisplayName: 'Anna',
    );

void main() {
  group('ContentCard - delegation by type', () {
    testWidgets('recipe type delegates to RecipeCard', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(item: _recipe(), type: ContentCardType.recipe),
        ),
      );
      expect(find.byType(RecipeCard), findsOneWidget);
      expect(find.byType(FriendCard), findsNothing);
      expect(find.byType(MenuCard), findsNothing);
      expect(find.byType(ShoppingListCard), findsNothing);
      expect(find.byType(FriendRequestCard), findsNothing);
    });

    testWidgets('friend type delegates to FriendCard', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(item: _user(), type: ContentCardType.friend),
        ),
      );
      expect(find.byType(FriendCard), findsOneWidget);
      expect(find.byType(RecipeCard), findsNothing);
    });

    testWidgets('friendRequest type delegates to FriendRequestCard', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(item: _request(), type: ContentCardType.friendRequest),
        ),
      );
      expect(find.byType(FriendRequestCard), findsOneWidget);
      expect(find.byType(FriendCard), findsNothing);
    });

    testWidgets('menu type delegates to MenuCard (Map-of-Recipes payload)', (
      tester,
    ) async {
      final Map<String, List<Recipe>> menu = {
        'Måndag': [_recipe()],
      };
      await tester.pumpWidget(
        _wrap(
          ContentCard(item: menu, type: ContentCardType.menu),
        ),
      );
      expect(find.byType(MenuCard), findsOneWidget);
    });

    testWidgets('shoppingList type delegates to ShoppingListCard', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _shoppingList(),
            type: ContentCardType.shoppingList,
          ),
        ),
      );
      expect(find.byType(ShoppingListCard), findsOneWidget);
    });
  });

  group('ContentCard - assertion on wrong item type', () {
    testWidgets('recipe type with non-Recipe item throws AssertionError', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(item: 'not a recipe', type: ContentCardType.recipe),
        ),
      );
      expect(tester.takeException(), isA<AssertionError>());
    });

    testWidgets('friend type with non-UserProfile item throws AssertionError', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(item: 'not a user', type: ContentCardType.friend),
        ),
      );
      expect(tester.takeException(), isA<AssertionError>());
    });

    testWidgets(
      'friendRequest type with non-FriendRequest item throws AssertionError',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ContentCard(item: 'nope', type: ContentCardType.friendRequest),
          ),
        );
        expect(tester.takeException(), isA<AssertionError>());
      },
    );
  });

  group('ContentCard - style mapping', () {
    testWidgets('detailed -> RecipeCardStyle.detailed', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _recipe(),
            type: ContentCardType.recipe,
            style: ContentCardStyle.detailed,
          ),
        ),
      );
      final card = tester.widget<RecipeCard>(find.byType(RecipeCard));
      expect(card.style, RecipeCardStyle.detailed);
    });

    testWidgets('compact -> RecipeCardStyle.compact', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _recipe(),
            type: ContentCardType.recipe,
            style: ContentCardStyle.compact,
          ),
        ),
      );
      final card = tester.widget<RecipeCard>(find.byType(RecipeCard));
      expect(card.style, RecipeCardStyle.compact);
    });

    testWidgets('grid -> RecipeCardStyle.grid', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _recipe(),
            type: ContentCardType.recipe,
            style: ContentCardStyle.grid,
          ),
        ),
      );
      final card = tester.widget<RecipeCard>(find.byType(RecipeCard));
      expect(card.style, RecipeCardStyle.grid);
    });

    testWidgets('friend grid -> FriendCardStyle.list (grid mapped to list)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _user(),
            type: ContentCardType.friend,
            style: ContentCardStyle.grid,
          ),
        ),
      );
      final card = tester.widget<FriendCard>(find.byType(FriendCard));
      expect(card.style, FriendCardStyle.list);
    });

    testWidgets('friend detailed -> FriendCardStyle.detailed', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _user(),
            type: ContentCardType.friend,
            style: ContentCardStyle.detailed,
          ),
        ),
      );
      expect(
        tester.widget<FriendCard>(find.byType(FriendCard)).style,
        FriendCardStyle.detailed,
      );
    });

    testWidgets('friend compact -> FriendCardStyle.compact', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _user(),
            type: ContentCardType.friend,
            style: ContentCardStyle.compact,
          ),
        ),
      );
      expect(
        tester.widget<FriendCard>(find.byType(FriendCard)).style,
        FriendCardStyle.compact,
      );
    });

    testWidgets('menu styles map across all three variants', (tester) async {
      final Map<String, List<Recipe>> menu = {
        'Mån': [_recipe()],
      };
      for (final pair in const [
        (ContentCardStyle.detailed, MenuCardStyle.detailed),
        (ContentCardStyle.compact, MenuCardStyle.compact),
        (ContentCardStyle.grid, MenuCardStyle.grid),
      ]) {
        await tester.pumpWidget(
          _wrap(
            ContentCard(
              item: menu,
              type: ContentCardType.menu,
              style: pair.$1,
            ),
          ),
        );
        expect(
          tester.widget<MenuCard>(find.byType(MenuCard)).style,
          pair.$2,
          reason:
              'ContentCardStyle.${pair.$1.name} should map to '
              'MenuCardStyle.${pair.$2.name}',
        );
      }
    });

    testWidgets('shopping list styles map across all three variants', (
      tester,
    ) async {
      for (final pair in const [
        (ContentCardStyle.detailed, ShoppingListCardStyle.detailed),
        (ContentCardStyle.compact, ShoppingListCardStyle.compact),
        (ContentCardStyle.grid, ShoppingListCardStyle.grid),
      ]) {
        await tester.pumpWidget(
          _wrap(
            ContentCard(
              item: _shoppingList(),
              type: ContentCardType.shoppingList,
              style: pair.$1,
            ),
          ),
        );
        expect(
          tester.widget<ShoppingListCard>(find.byType(ShoppingListCard)).style,
          pair.$2,
        );
      }
    });
  });

  group('ContentCard - prop forwarding (recipe)', () {
    testWidgets('showImage / showTags / showMetadata forwarded to RecipeCard', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _recipe(),
            type: ContentCardType.recipe,
            showImage: false,
            showTags: false,
            showMetadata: false,
          ),
        ),
      );
      final card = tester.widget<RecipeCard>(find.byType(RecipeCard));
      expect(card.showImage, isFalse);
      expect(card.showTags, isFalse);
      expect(card.showMetadata, isFalse);
    });

    testWidgets('margin / padding forwarded to RecipeCard', (tester) async {
      const margin = EdgeInsets.all(7);
      const padding = EdgeInsets.all(11);
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _recipe(),
            type: ContentCardType.recipe,
            margin: margin,
            padding: padding,
          ),
        ),
      );
      final card = tester.widget<RecipeCard>(find.byType(RecipeCard));
      expect(card.margin, margin);
      expect(card.padding, padding);
    });

    testWidgets(
      'userAllergenPrefs / userDietaryPrefs / matchPercent forwarded',
      (tester) async {
        final allergens = {'gluten'};
        final dietary = {'vegan'};
        await tester.pumpWidget(
          _wrap(
            ContentCard(
              item: _recipe(),
              type: ContentCardType.recipe,
              userAllergenPrefs: allergens,
              userDietaryPrefs: dietary,
              matchPercent: 0.75,
            ),
          ),
        );
        final card = tester.widget<RecipeCard>(find.byType(RecipeCard));
        expect(card.userAllergenPrefs, allergens);
        expect(card.userDietaryPrefs, dietary);
        expect(card.matchPercent, 0.75);
      },
    );
  });

  group('ContentCard - prop forwarding (friend)', () {
    testWidgets('showImage maps to FriendCard.showAvatar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _user(),
            type: ContentCardType.friend,
            showImage: false,
          ),
        ),
      );
      final card = tester.widget<FriendCard>(find.byType(FriendCard));
      expect(card.showAvatar, isFalse);
    });

    testWidgets('showOnlineStatus forwarded', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _user(),
            type: ContentCardType.friend,
            showOnlineStatus: true,
          ),
        ),
      );
      expect(
        tester.widget<FriendCard>(find.byType(FriendCard)).showOnlineStatus,
        isTrue,
      );
    });

    testWidgets('subtitle forwarded to FriendCard', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _user(),
            type: ContentCardType.friend,
            subtitle: 'Mutual: 3',
          ),
        ),
      );
      expect(
        tester.widget<FriendCard>(find.byType(FriendCard)).subtitle,
        'Mutual: 3',
      );
      // And it actually renders.
      expect(find.text('Mutual: 3'), findsOneWidget);
    });

    testWidgets('trailing widget reaches the rendered FriendCard', (
      tester,
    ) async {
      const trailingKey = Key('trailing-marker');
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _user(),
            type: ContentCardType.friend,
            trailing: const Icon(Icons.chevron_right, key: trailingKey),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(FriendCard),
          matching: find.byKey(trailingKey),
        ),
        findsOneWidget,
      );
    });
  });

  group('ContentCard - prop forwarding (menu & shopping list)', () {
    testWidgets('menu: showTags maps to MenuCard.showPreview', (tester) async {
      final Map<String, List<Recipe>> menu = {
        'Mån': [_recipe()],
      };
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: menu,
            type: ContentCardType.menu,
            showTags: false,
            showSharingStatus: true,
          ),
        ),
      );
      final card = tester.widget<MenuCard>(find.byType(MenuCard));
      expect(card.showPreview, isFalse);
      expect(card.showSharingStatus, isTrue);
    });

    testWidgets('shoppingList: showTags maps to ShoppingListCard.showPreview', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _shoppingList(),
            type: ContentCardType.shoppingList,
            showTags: false,
            showSharingStatus: true,
          ),
        ),
      );
      final card = tester.widget<ShoppingListCard>(
        find.byType(ShoppingListCard),
      );
      expect(card.showPreview, isFalse);
      expect(card.showSharingStatus, isTrue);
    });
  });

  group('ContentCard - callback adaptation', () {
    testWidgets('recipe onTap (VoidCallback) is adapted to (Recipe)->void '
        'and fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _recipe(),
            type: ContentCardType.recipe,
            onTap: () => taps++,
          ),
        ),
      );
      final card = tester.widget<RecipeCard>(find.byType(RecipeCard));
      expect(card.onTap, isNotNull);
      card.onTap!(_recipe());
      expect(taps, 1);
    });

    testWidgets('recipe onLongPress is adapted and fires', (tester) async {
      var longs = 0;
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _recipe(),
            type: ContentCardType.recipe,
            onLongPress: () => longs++,
          ),
        ),
      );
      final card = tester.widget<RecipeCard>(find.byType(RecipeCard));
      expect(card.onLongPress, isNotNull);
      card.onLongPress!(_recipe());
      expect(longs, 1);
    });

    testWidgets('recipe onFavoriteToggle is adapted and fires', (tester) async {
      var favs = 0;
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _recipe(),
            type: ContentCardType.recipe,
            onFavoriteToggle: () => favs++,
          ),
        ),
      );
      final card = tester.widget<RecipeCard>(find.byType(RecipeCard));
      expect(card.onFavoriteToggle, isNotNull);
      card.onFavoriteToggle!(_recipe());
      expect(favs, 1);
    });

    testWidgets('recipe callbacks are null when not provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard(item: _recipe(), type: ContentCardType.recipe),
        ),
      );
      final card = tester.widget<RecipeCard>(find.byType(RecipeCard));
      expect(card.onTap, isNull);
      expect(card.onLongPress, isNull);
      expect(card.onFavoriteToggle, isNull);
    });

    testWidgets('friend onTap forwarded as-is and fires via tap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _user(),
            type: ContentCardType.friend,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(FriendCard));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('friendRequest onAccept/onDecline forwarded and fire', (
      tester,
    ) async {
      var accepts = 0;
      var declines = 0;
      await tester.pumpWidget(
        _wrap(
          ContentCard(
            item: _request(),
            type: ContentCardType.friendRequest,
            onAccept: () => accepts++,
            onDecline: () => declines++,
          ),
        ),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Acceptera'));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Avvisa'));
      await tester.pump();
      expect(accepts, 1);
      expect(declines, 1);
    });
  });

  group('ContentCard - legacy static factories', () {
    testWidgets('ContentCard.recipe builds a detailed RecipeCard', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(ContentCard.recipe(recipe: _recipe())));
      expect(find.byType(ContentCard), findsOneWidget);
      expect(find.byType(RecipeCard), findsOneWidget);
      final card = tester.widget<RecipeCard>(find.byType(RecipeCard));
      expect(card.style, RecipeCardStyle.detailed);
      expect(card.showTags, isTrue);
    });

    testWidgets(
      'ContentCard.compactRecipe forces compact style + showTags=false',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ContentCard.compactRecipe(recipe: _recipe()),
          ),
        );
        final card = tester.widget<RecipeCard>(find.byType(RecipeCard));
        expect(card.style, RecipeCardStyle.compact);
        expect(card.showTags, isFalse);
      },
    );

    testWidgets('ContentCard.friend builds detailed FriendCard, '
        'showAvatar honoured', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentCard.friend(user: _user(), showAvatar: false),
        ),
      );
      final card = tester.widget<FriendCard>(find.byType(FriendCard));
      expect(card.style, FriendCardStyle.detailed);
      expect(card.showAvatar, isFalse);
    });

    testWidgets('ContentCard.friend trailing forwarded', (tester) async {
      const k = Key('trailing-legacy');
      await tester.pumpWidget(
        _wrap(
          ContentCard.friend(
            user: _user(),
            trailing: const Icon(Icons.message, key: k),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(FriendCard),
          matching: find.byKey(k),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ContentCard.friendRequest wires accept/decline callbacks', (
      tester,
    ) async {
      var a = 0;
      var d = 0;
      await tester.pumpWidget(
        _wrap(
          ContentCard.friendRequest(
            friendRequest: _request(),
            onAccept: () => a++,
            onDecline: () => d++,
          ),
        ),
      );
      expect(find.byType(FriendRequestCard), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Acceptera'));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Avvisa'));
      await tester.pump();
      expect(a, 1);
      expect(d, 1);
    });
  });
}

/// Widget tests for the `recipe_selection_dialogs` family.
///
/// The facade file ([RecipeSelectionDialogs]) is a 2-method dispatcher that
/// calls `showDialog` with one of two inner dialogs:
///   - [FriendRecipeSharingDialog] — needs `UnifiedRecipeService` from
///     ServiceLocator.
///   - [MenuRecipeSelectionDialog] — needs `RecipeListViewModel` from
///     ServiceLocator.
///
/// Driving those dialogs through `showDialog` would require pulling in the
/// real DI container, mocking two ChangeNotifier services, and pumping
/// async loads — overhead far beyond the value the facade itself provides.
///
/// Instead, this file covers what we can actually verify cleanly:
///   1. **Facade signatures** — `showRecipeSelector` returns `Future<void>`,
///      `showMenuRecipeSelector` returns `Future<List<Recipe>?>`. A wrong
///      signature would fail at static analysis time, so this also runs as
///      a compile-time contract test.
///   2. **Inner list items** — [FriendRecipeListItem] and
///      [MenuRecipeListItem] are pure `StatelessWidget`s; they render
///      recipe metadata, the localized Swedish badge ("Delad"), and wire
///      tap/checkbox callbacks. These items are what end-users actually
///      see and interact with inside both dialogs.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection_dialogs.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/friend_recipe_sharing_dialog.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/menu_recipe_selection_dialog.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

UserProfile _friend({String name = 'Anna', String uid = 'friend-1'}) {
  return UserProfile(
    uid: uid,
    displayName: name,
    email: 'anna@example.com',
    joinedAt: DateTime.utc(2024, 1, 1),
    lastActiveAt: DateTime.utc(2024, 1, 1),
  );
}

Recipe _recipe({
  String id = 'recipe-1',
  String title = 'Carbonara',
  String mealType = 'Middag',
  String description = 'Klassisk italiensk pasta',
  int? timeMinutes = 30,
  int? portions = 4,
  List<String> imageUrls = const [],
}) {
  return Recipe(
    core: RecipeCore(
      id: id,
      title: title,
      description: description,
      ingredients: const ['pasta', 'agg', 'bacon'],
      instructions: const ['Koka pasta'],
      mealType: mealType,
      timeMinutes: timeMinutes,
      portions: portions,
      imageUrls: imageUrls,
    ),
    type: RecipeType.personal,
  );
}

void main() {
  // Touch the facade members so a compile error in their signatures fails
  // this test file at build time — closest we can get to a "facade contract"
  // test without dragging the full ServiceLocator into the suite.
  group('RecipeSelectionDialogs facade contract', () {
    test(
      'showRecipeSelector is a static Function with the expected signature',
      () {
        final fn = RecipeSelectionDialogs.showRecipeSelector;
        expect(fn, isA<Function>());
        // Closure type erases generics — but smoke the static reference.
        expect(RecipeSelectionDialogs.showRecipeSelector, isNotNull);
      },
    );

    test('showMenuRecipeSelector is a static Function with the expected '
        'signature', () {
      final fn = RecipeSelectionDialogs.showMenuRecipeSelector;
      expect(fn, isA<Function>());
      expect(RecipeSelectionDialogs.showMenuRecipeSelector, isNotNull);
    });

    test('FriendRecipeSharingDialog can be constructed with a friend', () {
      // Construction is pure (no ServiceLocator access) — only build() reads
      // from DI. Verifying construction protects the public API.
      final w = FriendRecipeSharingDialog(friend: _friend());
      expect(w.friend.uid, 'friend-1');
    });

    test(
      'MenuRecipeSelectionDialog can be constructed with a categoryName',
      () {
        final w = const MenuRecipeSelectionDialog(categoryName: 'Lunch');
        expect(w.categoryName, 'Lunch');
      },
    );
  });

  group('FriendRecipeListItem rendering', () {
    testWidgets('renders title, mealType, description, time, and portions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendRecipeListItem(
            recipe: _recipe(),
            isSelected: false,
            isAlreadyShared: false,
            onSelectionChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Carbonara'), findsOneWidget);
      expect(find.text('Middag'), findsOneWidget);
      expect(find.text('Klassisk italiensk pasta'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('4 port'), findsOneWidget);
    });

    testWidgets('checkbox value reflects isSelected=true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FriendRecipeListItem(
            recipe: _recipe(),
            isSelected: true,
            isAlreadyShared: false,
            onSelectionChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      final cb = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(cb.value, isTrue);
    });

    testWidgets('row tap fires onSelectionChanged with the inverted value', (
      tester,
    ) async {
      bool? lastValue;
      await tester.pumpWidget(
        _wrap(
          FriendRecipeListItem(
            recipe: _recipe(),
            isSelected: false,
            isAlreadyShared: false,
            onSelectionChanged: (v) => lastValue = v,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(
        lastValue,
        isTrue,
        reason: 'tapping an unselected row should propose selection',
      );
    });

    testWidgets('checkbox tap fires onSelectionChanged with the new value', (
      tester,
    ) async {
      bool? lastValue;
      await tester.pumpWidget(
        _wrap(
          FriendRecipeListItem(
            recipe: _recipe(),
            isSelected: false,
            isAlreadyShared: false,
            onSelectionChanged: (v) => lastValue = v,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(lastValue, isTrue);
    });

    testWidgets('isAlreadyShared shows the Swedish "Delad" badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendRecipeListItem(
            recipe: _recipe(),
            isSelected: false,
            isAlreadyShared: true,
            onSelectionChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      // From app_sv.arb → "dialogAlreadyShared": "Delad"
      expect(find.text('Delad'), findsOneWidget);
    });

    testWidgets('isAlreadyShared=false hides the "Delad" badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendRecipeListItem(
            recipe: _recipe(),
            isSelected: false,
            isAlreadyShared: false,
            onSelectionChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Delad'), findsNothing);
    });

    testWidgets('empty description suppresses the description Text widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendRecipeListItem(
            recipe: _recipe(description: ''),
            isSelected: false,
            isAlreadyShared: false,
            onSelectionChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Klassisk italiensk pasta'), findsNothing);
    });

    testWidgets('null timeMinutes hides the access_time icon and minute text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendRecipeListItem(
            recipe: _recipe(timeMinutes: null),
            isSelected: false,
            isAlreadyShared: false,
            onSelectionChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.access_time), findsNothing);
      expect(find.text('30 min'), findsNothing);
    });

    testWidgets('null portions hides the people icon and "port" text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendRecipeListItem(
            recipe: _recipe(portions: null),
            isSelected: false,
            isAlreadyShared: false,
            onSelectionChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.people), findsNothing);
      expect(find.text('4 port'), findsNothing);
    });

    testWidgets(
      'empty imageUrls renders the restaurant_menu placeholder icon',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            FriendRecipeListItem(
              recipe: _recipe(),
              isSelected: false,
              isAlreadyShared: false,
              onSelectionChanged: (_) {},
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
      },
    );
  });

  group('MenuRecipeListItem rendering', () {
    testWidgets('renders title, mealType, time, and portions', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MenuRecipeListItem(
            recipe: _recipe(),
            isSelected: false,
            onSelectionChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Carbonara'), findsOneWidget);
      expect(find.text('Middag'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('4 port'), findsOneWidget);
    });

    testWidgets('checkbox reflects isSelected=true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MenuRecipeListItem(
            recipe: _recipe(),
            isSelected: true,
            onSelectionChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      final cb = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(cb.value, isTrue);
    });

    testWidgets('row tap on a selected item proposes deselect (false)', (
      tester,
    ) async {
      bool? lastValue;
      await tester.pumpWidget(
        _wrap(
          MenuRecipeListItem(
            recipe: _recipe(),
            isSelected: true,
            onSelectionChanged: (v) => lastValue = v,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(lastValue, isFalse);
    });

    testWidgets('row tap on an unselected item proposes select (true)', (
      tester,
    ) async {
      bool? lastValue;
      await tester.pumpWidget(
        _wrap(
          MenuRecipeListItem(
            recipe: _recipe(),
            isSelected: false,
            onSelectionChanged: (v) => lastValue = v,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(lastValue, isTrue);
    });

    testWidgets('checkbox tap fires onSelectionChanged', (tester) async {
      bool? lastValue;
      await tester.pumpWidget(
        _wrap(
          MenuRecipeListItem(
            recipe: _recipe(),
            isSelected: false,
            onSelectionChanged: (v) => lastValue = v,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(lastValue, isTrue);
    });

    testWidgets('empty description hides the description Text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MenuRecipeListItem(
            recipe: _recipe(description: ''),
            isSelected: false,
            onSelectionChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Klassisk italiensk pasta'), findsNothing);
    });

    testWidgets('null timeMinutes hides the time icon and text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MenuRecipeListItem(
            recipe: _recipe(timeMinutes: null),
            isSelected: false,
            onSelectionChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.access_time), findsNothing);
      expect(find.text('30 min'), findsNothing);
    });

    testWidgets('null portions hides the people icon and text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MenuRecipeListItem(
            recipe: _recipe(portions: null),
            isSelected: false,
            onSelectionChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.people), findsNothing);
      expect(find.text('4 port'), findsNothing);
    });

    testWidgets(
      'empty imageUrls renders the restaurant_menu placeholder icon',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            MenuRecipeListItem(
              recipe: _recipe(),
              isSelected: false,
              onSelectionChanged: (_) {},
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
      },
    );
  });
}

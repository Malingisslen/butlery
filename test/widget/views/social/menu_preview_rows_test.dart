/// The shared menu's dishes as the approved picture draws them
/// (103-menu-preview): one row per dish, the category on its first row,
/// the name in bold and the time at the end.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/shared_content/menu_dish_credit_viewmodel.dart';
import 'package:butlery/views/social/menu_preview/menu_preview_dishes.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _NoProfiles extends Fake implements UserService {
  @override
  Future<ProfileBatchLookup> getUserProfiles(List<String> userIds) async =>
      const ProfileBatchLookup(
        profiles: [],
        missingIds: {},
        unavailableIds: {},
      );
}

Recipe _dish(String id, String title, {int? minutes}) => Recipe(
  core: RecipeCore(
    id: id,
    title: title,
    description: '',
    ingredients: const [],
    instructions: const [],
    imageUrls: const [],
    mealType: 'Middag',
    timeMinutes: minutes,
  ),
  type: RecipeType.personal,
);

void main() {
  late SharedMenu menu;
  late MenuDishCreditViewModel credits;

  setUp(() {
    menu = SharedMenu(
      id: 'menu-1',
      sharedByUserId: 'sharer',
      sharedByDisplayName: 'Erik',
      menuTitle: 'Snabb vardag',
      menuSnapshot: {
        'Lunch': [_dish('a', 'Halloumibowl', minutes: 25)],
        'Middag': [
          _dish('b', 'Kycklinggryta', minutes: 35),
          _dish('c', 'Fiskgratäng'),
        ],
      },
    );
    credits = MenuDishCreditViewModel(
      menu: menu,
      userService: _NoProfiles(),
      blockedUserIds: () => const {},
      viewerId: 'viewer',
    );
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    createLocalizedTestApp(
      wrapInScaffold: false,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [MenuPreviewDishes(sharedMenu: menu, credits: credits)],
        ),
      ),
    ),
  );

  testWidgets('a category is named once, on its first dish', (tester) async {
    await pump(tester);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Middag'), findsOneWidget);
    expect(find.text('Kycklinggryta'), findsOneWidget);
    expect(find.text('Fiskgratäng'), findsOneWidget);
  });

  testWidgets('a dish shows its time, and none when it has none', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('25 min'), findsOneWidget);
    expect(find.text('35 min'), findsOneWidget);
    expect(find.textContaining('min'), findsNWidgets(2));
  });

  testWidgets('every row is at least 48 dp tall', (tester) async {
    await pump(tester);
    for (final title in ['Halloumibowl', 'Kycklinggryta', 'Fiskgratäng']) {
      final ink = find.ancestor(
        of: find.text(title),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(ink.first).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('a row opens the recipe', (tester) async {
    Object? opened;
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Scaffold(
          body: CustomScrollView(
            slivers: [MenuPreviewDishes(sharedMenu: menu, credits: credits)],
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == '/receptDetalj') opened = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('RECEPT')),
          );
        },
      ),
    );
    await tester.tap(find.text('Kycklinggryta'));
    await tester.pumpAndSettle();
    expect((opened as Recipe).id, 'b');
  });
}

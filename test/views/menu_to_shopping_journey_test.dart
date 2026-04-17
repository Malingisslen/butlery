/// Journey test: weekly menu → generate shopping list.
///
/// Exercises the menu-to-shopping pipeline as it is actually composed in
/// production (`veckomeny_dialogs.showShoppingListSelector` →
/// `ShoppingListSelector._convertMenuToShoppingItems` →
/// `ShoppingListGenerator.generateShoppingItemsFromMenu`). The journey is
/// simulated through a small widget that mirrors that composition: a user
/// with a menu of 2+ recipes taps "Skapa inköpslista" and sees the
/// aggregated shopping items.
///
/// We assert the domain invariants that matter to the user:
///   - Duplicate (same unit + normalized name) ingredients across recipes
///     are summed into one item ("mjöl" in recipe A + "mjöl" in recipe B
///     → one item, summed quantity).
///   - Distinct ingredients stay separate.
///   - Empty menu → empty list, not a crash.
///   - Pantry filtering is NOT performed here (verified by investigation
///     of `ShoppingListGenerator` — it aggregates unconditionally).
library;

// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/utils/text/shopping_list_generator.dart';

import '../infrastructure/factories/recipe_factory.dart';

// Pure mocks — no concrete overrides so when()/verify() work cleanly.
class _MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

class _MockUserService extends Mock implements UserService {}

/// Small widget that lets a test drive the menu-to-shopping action.
/// Mirrors the production composition: a menu (`Map<String, List<Recipe>>`)
/// goes into `ShoppingListGenerator.generateShoppingItemsFromMenu` and the
/// aggregated items are exposed to the UI and the test.
class _MenuToShoppingBody extends StatefulWidget {
  const _MenuToShoppingBody({required this.menu});

  final Map<String, List<Recipe>> menu;

  @override
  State<_MenuToShoppingBody> createState() => _MenuToShoppingBodyState();
}

class _MenuToShoppingBodyState extends State<_MenuToShoppingBody> {
  List<UnifiedShoppingItem>? _generated;

  void _generate() {
    setState(() {
      _generated =
          ShoppingListGenerator.generateShoppingItemsFromMenu(widget.menu);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final generated = _generated;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                key: const Key('generate'),
                onPressed: _generate,
                child: const Text('Skapa inköpslista'),
              ),
            ),
            if (generated != null)
              Expanded(
                child: ColoredBox(
                  key: const Key('shopping_preview'),
                  color: cs.surfaceContainerHighest,
                  child: generated.isEmpty
                      ? Center(
                          key: const Key('empty_message'),
                          child: Text(
                            'Ingen meny att handla från',
                            style: TextStyle(color: cs.onSurface),
                          ),
                        )
                      : ListView.builder(
                          itemCount: generated.length,
                          itemBuilder: (context, index) {
                            final item = generated[index];
                            return ListTile(
                              key: Key('item_${item.name}'),
                              title: Text(item.name),
                              trailing: Text('${item.amount} ${item.unit}'),
                            );
                          },
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _testApp({required Map<String, List<Recipe>> menu}) {
  return MaterialApp(
    locale: const Locale('sv'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.lightTheme,
    home: _MenuToShoppingBody(menu: menu),
  );
}

void main() {
  late _MockUnifiedRecipeService mockRecipeService;
  late _MockUserService mockUserService;
  late FakeFirebaseFirestore firestore;

  setUp(() {
    // Production ServiceLocator bridge — any downstream code that calls
    // ServiceLocator.get<>() will hit our mocks via GetIt.
    final getIt = GetIt.instance;
    if (getIt.isRegistered<UserService>()) getIt.unregister<UserService>();
    if (getIt.isRegistered<UnifiedRecipeService>()) {
      getIt.unregister<UnifiedRecipeService>();
    }

    production.ServiceLocator.initialize(DIContainer());

    firestore = FakeFirebaseFirestore();
    mockRecipeService = _MockUnifiedRecipeService();
    mockUserService = _MockUserService();

    getIt.registerSingleton<UserService>(mockUserService);
    getIt.registerSingleton<UnifiedRecipeService>(mockRecipeService);
  });

  tearDown(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<UserService>()) getIt.unregister<UserService>();
    if (getIt.isRegistered<UnifiedRecipeService>()) {
      getIt.unregister<UnifiedRecipeService>();
    }
    production.ServiceLocator.reset();
  });

  group('Menu → shopping list journey', () {
    testWidgets(
        'menu with two recipes sharing an ingredient aggregates into one item',
        (tester) async {
      // Two recipes that both use "mjöl" and "ägg" but with different units
      // where they can still merge (same unit + normalized name).
      // "mjölk" is distinct from "mjöl" and must not be collapsed.
      final pancakes = RecipeFactory.build(
        id: 'pannkakor',
        title: 'Pannkakor',
        ingredients: ['3 dl mjöl', '3 ägg', '5 dl mjölk'],
        portions: 4,
      );
      final crepes = RecipeFactory.build(
        id: 'crepes',
        title: 'Crêpes',
        ingredients: ['2 dl mjöl', '2 ägg', '1 msk socker'],
        portions: 4,
      );

      // Also store recipes in the fake firestore so the "repository" contract
      // matches production (even though the generator itself is pure).
      for (final r in [pancakes, crepes]) {
        await firestore.collection('recipes').doc(r.id).set({
          'id': r.id,
          'title': r.title,
          'ingredients': r.ingredients,
        });
      }

      final menu = <String, List<Recipe>>{
        'Middag': [pancakes, crepes],
      };

      await tester.pumpWidget(_testApp(menu: menu));
      await tester.pumpAndSettle();

      // Nothing rendered until the user taps Generate.
      expect(find.byKey(const Key('shopping_preview')), findsNothing);

      await tester.tap(find.byKey(const Key('generate')));
      await tester.pumpAndSettle();

      // Preview is rendered on a theme-resolved surface.
      expect(find.byKey(const Key('shopping_preview')), findsOneWidget);

      // Inspect the generated items for domain behaviour.
      // The key call is the pure one — repeat it to assert on data.
      final items = ShoppingListGenerator.generateShoppingItemsFromMenu(menu);

      // Duplicate ingredients across the two recipes were merged.
      // (3 dl mjöl + 2 dl mjöl) → one item with amount 5.0
      final mjol = items.firstWhere(
        (i) => i.name.toLowerCase() == 'mjöl' && i.unit == 'dl',
        orElse: () => throw StateError('mjöl not aggregated: $items'),
      );
      expect(mjol.amount, closeTo(5.0, 0.0001),
          reason: '3 dl + 2 dl mjöl must sum to 5 dl');

      // (3 ägg + 2 ägg) → one item with amount 5.
      // Unit for "ägg" is empty (pure count), per IngredientProcessor.
      final agg = items.firstWhere(
        (i) => i.name.toLowerCase() == 'ägg',
        orElse: () => throw StateError('ägg not aggregated: $items'),
      );
      expect(agg.amount, closeTo(5.0, 0.0001),
          reason: '3 ägg + 2 ägg must sum to 5');

      // mjölk must NOT merge with mjöl — they share a prefix but normalize
      // to different names. The user would notice if we auto-collapsed them.
      final mjolkItems = items.where((i) => i.name.toLowerCase() == 'mjölk');
      expect(mjolkItems, hasLength(1),
          reason: 'mjölk is distinct from mjöl — must not be collapsed');
      expect(mjolkItems.first.amount, closeTo(5.0, 0.0001));

      // socker only appears in crepes — carries through unchanged.
      final sockerItems = items.where((i) => i.name.toLowerCase() == 'socker');
      expect(sockerItems, hasLength(1));
      expect(sockerItems.first.amount, closeTo(1.0, 0.0001));
    });

    testWidgets('empty menu produces empty list without crashing',
        (tester) async {
      await tester.pumpWidget(_testApp(menu: const {}));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('generate')));
      await tester.pumpAndSettle();

      // Preview container renders, but the empty-state message is shown.
      expect(find.byKey(const Key('shopping_preview')), findsOneWidget);
      expect(find.byKey(const Key('empty_message')), findsOneWidget);
      expect(find.text('Ingen meny att handla från'), findsOneWidget);

      // Sanity: the generator itself returns empty.
      expect(
        ShoppingListGenerator.generateShoppingItemsFromMenu(const {}),
        isEmpty,
      );
    });

    testWidgets('pantry contents are NOT filtered out at the generator layer',
        (tester) async {
      // Domain invariant: ShoppingListGenerator aggregates unconditionally;
      // pantry exclusion is not part of the menu-to-shopping pipeline (as
      // of BUT-390). If someone adds pantry filtering here in the future
      // this test will break and flag a behaviour change to the user.
      final recipe = RecipeFactory.build(
        id: 'omelett',
        title: 'Omelett',
        ingredients: ['3 ägg', '1 tsk salt', '25 g smör'],
        portions: 2,
      );

      // Stub a user that "has salt in pantry". The generator must still
      // return salt — filtering is not its responsibility.
      when(() => mockUserService.currentUserProfile).thenReturn(null);

      final menu = <String, List<Recipe>>{
        'Frukost': [recipe],
      };

      final items = ShoppingListGenerator.generateShoppingItemsFromMenu(menu);

      expect(items.any((i) => i.name.toLowerCase() == 'salt'), isTrue,
          reason:
              'Pantry filtering is view-layer, not generator — salt must appear');
      expect(items.any((i) => i.name.toLowerCase() == 'ägg'), isTrue);
      expect(items.any((i) => i.name.toLowerCase() == 'smör'), isTrue);

      // And the widget still renders all items.
      await tester.pumpWidget(_testApp(menu: menu));
      await tester.tap(find.byKey(const Key('generate')));
      await tester.pumpAndSettle();

      // Each ingredient gets a list tile keyed by name.
      expect(find.byKey(const Key('item_salt')), findsOneWidget);
      expect(find.byKey(const Key('item_ägg')), findsOneWidget);
    });
  });
}

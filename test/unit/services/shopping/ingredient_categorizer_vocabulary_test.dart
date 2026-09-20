// BUT-1890: the shopping dialog used to carry its own category map with a much
// larger Swedish vocabulary than `IngredientCategorizer`. Routing the dialog at
// the engine without moving that vocabulary first would have dropped the
// suggestion for 78 of the map's 139 words (measured 2026-09-20 by running both
// engines over every word). This file binds the vocabulary that moved across, so
// deleting a keyword or re-pointing a bucket reddens here rather than silently
// in the UI.
//
// The second group is the one that earns its keep. Every word below it is short
// enough, or Swedish enough, to ride inside an unrelated grocery — that is the
// exact failure the old map shipped ('te' inside "diskborste" filed a dishbrush
// under drinks). Each case names the collision it rules out.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/shopping/ingredient_categorizer.dart';

void main() {
  void expectCategory(Map<String, String> cases) {
    cases.forEach((name, expected) {
      test('"$name" categorises as $expected', () {
        expect(IngredientCategorizer.categorize(name), expected);
      });
    });
  }

  group('vocabulary carried over from the shopping dialog', () {
    group('dairy — none of these contains "ost"', () {
      expectCategory({
        'Crème fraiche': ShoppingCategory.dairy,
        'Kvarg': ShoppingCategory.dairy,
        'Keso': ShoppingCategory.dairy,
        'Parmesan': ShoppingCategory.dairy,
        'Mozzarella': ShoppingCategory.dairy,
        'Cheddar': ShoppingCategory.dairy,
        'Brie': ShoppingCategory.dairy,
        'Cream cheese': ShoppingCategory.dairy,
        'Crème fraîche': ShoppingCategory.dairy,
        'Ricotta': ShoppingCategory.dairy,
        'Mascarpone': ShoppingCategory.dairy,
        'Feta': ShoppingCategory.dairy,
      });
    });

    group('meat and fish', () {
      expectCategory({
        'Lamm': ShoppingCategory.meat,
        'Kalkon': ShoppingCategory.meat,
        'Anka': ShoppingCategory.meat,
        'Entrecote': ShoppingCategory.meat,
        'Kotlett': ShoppingCategory.meat,
        'Musslor': ShoppingCategory.fish,
        'Mussla': ShoppingCategory.fish,
        'Krabba': ShoppingCategory.fish,
        'Krabbor': ShoppingCategory.fish,
        'Entrecôte': ShoppingCategory.meat,
        'Hummer': ShoppingCategory.fish,
      });
    });

    group('bread', () {
      expectCategory({
        'Limpa': ShoppingCategory.breadGrain,
        'Fralla': ShoppingCategory.breadGrain,
        'Bulle': ShoppingCategory.breadGrain,
        'Croissant': ShoppingCategory.breadGrain,
        'Bagel': ShoppingCategory.breadGrain,
        'Tortilla': ShoppingCategory.breadGrain,
        'Kanelbullar': ShoppingCategory.breadGrain,
        'Frallor': ShoppingCategory.breadGrain,
        'Knäckebröd': ShoppingCategory.breadGrain,
        'Pitabröd': ShoppingCategory.breadGrain,
      });
    });

    group('fruit and veg', () {
      expectCategory({
        'Mango': ShoppingCategory.fruit,
        'Ananas': ShoppingCategory.fruit,
        'Persika': ShoppingCategory.fruit,
        'Plommon': ShoppingCategory.fruit,
        'Kiwi': ShoppingCategory.fruit,
        'Avokado': ShoppingCategory.fruit,
        'Druvor': ShoppingCategory.fruit,
        'Aubergine': ShoppingCategory.veg,
        'Champinjoner': ShoppingCategory.veg,
        'Svamp': ShoppingCategory.veg,
        'Selleri': ShoppingCategory.veg,
        'Rödbetor': ShoppingCategory.veg,
        'Vitkål': ShoppingCategory.veg,
        'Rödkål': ShoppingCategory.veg,
      });
    });

    group('dry goods and pantry', () {
      expectCategory({
        'Spaghetti': ShoppingCategory.dryGoods,
        'Nudlar': ShoppingCategory.dryGoods,
        'Flingor': ShoppingCategory.dryGoods,
        'Linser': ShoppingCategory.dryGoods,
        'Kikärtor': ShoppingCategory.dryGoods,
        'Kikärter': ShoppingCategory.dryGoods,
        'Ketchup': ShoppingCategory.pantry,
        'Senap': ShoppingCategory.pantry,
        'Majonnäs': ShoppingCategory.pantry,
        'Soja': ShoppingCategory.pantry,
        'Vinäger': ShoppingCategory.pantry,
        'Honung': ShoppingCategory.pantry,
        'Sylt': ShoppingCategory.pantry,
        'Buljong': ShoppingCategory.pantry,
        'Fond': ShoppingCategory.pantry,
      });
    });

    group('the three aisles the engine had no rule for at all', () {
      expectCategory({
        'Glass': ShoppingCategory.frozen,
        'Fryst': ShoppingCategory.frozen,
        'Frysta': ShoppingCategory.frozen,
        'Fryspizza': ShoppingCategory.frozen,
        'Frysvaror': ShoppingCategory.frozen,
        'Chips': ShoppingCategory.snacks,
        'Nötter': ShoppingCategory.snacks,
        'Popcorn': ShoppingCategory.snacks,
        'Godis': ShoppingCategory.snacks,
        'Choklad': ShoppingCategory.snacks,
        'Kex': ShoppingCategory.snacks,
        'Kakor': ShoppingCategory.snacks,
        'Juice': ShoppingCategory.drinks,
        'Läsk': ShoppingCategory.drinks,
        'Mineralvatten': ShoppingCategory.drinks,
        'Kaffe': ShoppingCategory.drinks,
        'Cider': ShoppingCategory.drinks,
        'Smoothie': ShoppingCategory.drinks,
        'Te': ShoppingCategory.drinks,
      });
    });
  });

  group('the collisions each new rule had to be bounded against', () {
    // Left of the arrow is the word that must NOT be claimed; each expectation
    // is the answer the engine gives instead.
    expectCategory({
      // 'te' — the defect the old map shipped.
      'Diskborste': ShoppingCategory.other,
      // 'öl' rides inside 'bröllop'. 'Mjöl' below is answered by the dry-goods
      // rule far above the drinks rule, so it pins that keyword, not the
      // boundary.
      'Bröllopstårta': ShoppingCategory.other,
      'Mjöl': ShoppingCategory.dryGoods,
      'Vetemjöl': ShoppingCategory.dryGoods,
      'Starköl': ShoppingCategory.drinks,
      'Lättöl': ShoppingCategory.drinks,
      'Folköl': ShoppingCategory.drinks,
      'Mellanöl': ShoppingCategory.drinks,
      'Öl': ShoppingCategory.drinks,
      // 'Vinbär' is what pins the REJECTING half of the trailing boundary: it
      // reaches the drinks rule, and becomes a drink the moment the boundary
      // goes. 'Cidervinäger' is answered by the pantry rule above it and pins
      // nothing about 'vin'.
      'Vinbär': ShoppingCategory.other,
      'Rödvin': ShoppingCategory.drinks,
      'Vitvin': ShoppingCategory.drinks,
      'Cidervinäger': ShoppingCategory.pantry,
      // 'kål' rides the tail of 'skål'.
      'Skål': ShoppingCategory.other,
      'Tvättskål': ShoppingCategory.other,
      // 'mango' rides inside 'mangold', which is chard.
      'Mangold': ShoppingCategory.veg,
      // 'vatten' would claim a melon.
      'Vattenmelon': ShoppingCategory.fruit,
      // 'druv' would claim glucose.
      'Druvsocker': ShoppingCategory.dryGoods,
      // The pantry block sits after canned and after fruit, which is what
      // keeps a tin of soya beans a tin and a honeydew a melon.
      'Sojabönor': ShoppingCategory.canned,
      'Honungsmelon': ShoppingCategory.fruit,
      // 'anka' rides inside 'planka'.
      'Planka': ShoppingCategory.other,
      // The bread rules straddle meat and fish deliberately: a head-noun rule
      // above them so 'korv' cannot claim a hot-dog roll, and the loaf-and-bun
      // rule below them so 'kött' and 'fisk' keep theirs.
      'Korvbröd': ShoppingCategory.breadGrain,
      'Kaffebröd': ShoppingCategory.breadGrain,
      'Köttlimpa': ShoppingCategory.meat,
      'Leverlimpa': ShoppingCategory.other,
      'Köttbulle': ShoppingCategory.meat,
      'Fiskbulle': ShoppingCategory.fish,
      // A loan letter is not a word boundary: without the extra letter class
      // the bounded 'te' fires inside "cô-te" and this is a drink. It has to be
      // a cut the meat rule does NOT name — 'Entrecôte' is answered by its own
      // keyword long before the drinks rule, so it pins the keyword, not the
      // boundary.
      'Côte de boeuf': ShoppingCategory.other,
      'Entrecôte 500 g': ShoppingCategory.meat,
      // 'vin' is bounded on the RIGHT only, so the wines whose first element
      // ends in 's' survive. `_porkPattern` reaches only word-initial `svin`,
      // which is why wild boar is a keyword of its own rather than a boundary:
      // `vildsvin` and `bordsvin` are the same shape, so no boundary separates
      // them. 'Bordsvin' is the control that the wine did not regress.
      'Bordsvin': ShoppingCategory.drinks,
      'Husvin': ShoppingCategory.drinks,
      'Svin': ShoppingCategory.meat,
      'Svinkotlett': ShoppingCategory.meat,
      'Vildsvin': ShoppingCategory.meat,
      'Vildsvinsfärs': ShoppingCategory.meat,
      // Head nouns: the fruit and veg rules would otherwise claim the first
      // element of each of these, and the jam rule yields to a pickled onion.
      'Apelsinjuice': ShoppingCategory.drinks,
      'Tomatjuice': ShoppingCategory.drinks,
      'Potatischips': ShoppingCategory.snacks,
      'Tortillachips': ShoppingCategory.snacks,
      'Jordgubbssylt': ShoppingCategory.pantry,
      'Hallonsylt': ShoppingCategory.pantry,
      'Syltlök': ShoppingCategory.veg,
      // The bun and loaf stems sit below meat, fish, fruit and veg, so a
      // patty named after what it is made of keeps that answer.
      'Köttbullar': ShoppingCategory.meat,
      'Fiskbullar': ShoppingCategory.fish,
      'Potatisbullar': ShoppingCategory.veg,
      // 'nötter' reaches snacks only because the beef pattern refuses the nut
      // plural outright — and 'nötfärs' proves the beef rule still fires.
      'Nötfärs': ShoppingCategory.meat,
      'Nötkärnor': ShoppingCategory.other,
      // The two words the migration deliberately gives up on: 'lax filé' is
      // fish and 'fläskfilé' is meat, and a hamburger is meat while a
      // hamburgerbröd is bread. Both leave the field blank.
      'Filé': ShoppingCategory.other,
      'Hamburger': ShoppingCategory.other,
      // The answers BUT-1890 exists to make right, re-pinned at the engine.
      'Rostbiff': ShoppingCategory.meat,
      'Kokosmjölk': ShoppingCategory.canned,
      'Vitlökspulver': ShoppingCategory.veg,
    });
  });
}

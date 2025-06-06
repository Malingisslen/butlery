// lib/services/shopping_list_service.dart

import '../models/shopping_item.dart';
import '../models/recipe.dart';
import '../utils/text_utils.dart';

/// Service som från en veckomeny (måltidstyp → lista recept)
/// bygger en samman­slagen inköpslista (ShoppingItem per ingrediens).
class ShoppingListService {
  /// Tar en meny där nyckeln är måltidstyp och värdet är listor av recept,
  /// och returnerar en summerad lista av ShoppingItem.
  List<ShoppingItem> createShoppingListFromMenu(
    Map<String, List<Recipe>> menuMap,
  ) {
    final Map<String, ShoppingItem> aggregated = {};

    for (var recipes in menuMap.values) {
      for (var recipe in recipes) {
        for (var raw in recipe.ingredients) {
          final parsed = IngredientParser.parseIngredient(raw);

          // Normalisera ingrediensnamnet till singular för bättre gruppering
          final normalizedName = SwedishPluralization.normalizeToSingular(
            parsed.name,
          );

          // Skapa smart nyckel som slår ihop samma ingredienser
          final key = _createSmartKey(parsed.unit, normalizedName);

          if (aggregated.containsKey(key)) {
            // Summera mängden och välj den mest specifika enheten
            final existing = aggregated[key]!;
            existing.amount += parsed.quantity;

            // Föredra specifika enheter (burk, påse) framför generiska
            if (parsed.unit.isNotEmpty && _isCountableUnit(parsed.unit)) {
              existing.unit = parsed.unit;
            }
          } else {
            // Skapa ny ShoppingItem
            aggregated[key] = ShoppingItem(
              name: normalizedName,
              amount: parsed.quantity,
              unit: parsed.unit,
            );
          }
        }
      }
    }

    // Konvertera ShoppingItem till String för visning med smart formatering
    final displayList = <String>[];
    final sortedItems =
        aggregated.values.toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    for (var item in sortedItems) {
      final amountStr = toSwedishHalfFraction(item.amount);

      String formattedItem;
      if (item.unit.isNotEmpty) {
        // Med enhet: "2 dl mjölk", "1 msk salt", "1 burk krossade tomater"
        if (item.amount == 1.0 && _isCountableUnit(item.unit)) {
          // För räknebara enheter som "burk", visa alltid kvantiteten
          formattedItem = '$amountStr ${item.unit} ${item.name}';
        } else if (_isCountableUnit(item.unit)) {
          // Pluralisera enheten för räknebara enheter
          final pluralUnit = _pluralizeUnit(item.unit, item.amount);
          formattedItem = '$amountStr $pluralUnit ${item.name}';
        } else {
          // För måttenheter som "dl", "g" etc.
          formattedItem = '$amountStr ${item.unit} ${item.name}';
        }
      } else {
        // Utan enhet - kolla om det är räknebart
        if (_isCountable(item.name)) {
          // Räknebara: hantera specialfall först
          if (item.name.toLowerCase().contains('platt')) {
            // Speciellt för lasagneplattor - visa alltid plural
            final pluralName = item.name.replaceAll(
              RegExp(r'platt$', caseSensitive: false),
              'plattor',
            );
            formattedItem = '$amountStr $pluralName';
          } else if (item.amount == 1.0) {
            formattedItem = '$amountStr ${item.name}';
          } else {
            final pluralName = SwedishPluralization.pluralize(
              item.name,
              item.amount,
            );
            formattedItem = '$amountStr $pluralName';
          }
        } else {
          // Orräknebara: bara "salt", "mjöl" etc.
          if (item.amount == 1.0) {
            formattedItem = item.name;
          } else {
            // Om mer än 1 av något orräknebart, visa ändå mängden
            formattedItem = '$amountStr ${item.name}';
          }
        }
      }

      displayList.add(formattedItem);
    }

    // Konvertera tillbaka till ShoppingItem för kompatibilitet
    final result = <ShoppingItem>[];
    for (int i = 0; i < displayList.length; i++) {
      result.add(
        ShoppingItem(
          name: displayList[i],
          amount: 1.0, // Dummy värde eftersom vi använder formaterad sträng
          unit: '',
          bought: false,
        ),
      );
    }

    return result;
  }

  /// Kontrollerar om en enhet är räknebart (burk, påse) eller ett mått (dl, g)
  bool _isCountableUnit(String unit) {
    final countableUnits = {
      'burk',
      'burkar',
      'påse',
      'påsar',
      'förpackning',
      'förpackningar',
      'flaska',
      'flaskor',
      'ask',
      'askar',
      'paket',
      'st',
      'bit',
      'bitar',
      'skiva',
      'skivor',
      'knippe',
      'blad',
      'kvist',
      'tube',
      'tub',
    };
    return countableUnits.contains(unit.toLowerCase());
  }

  /// Pluraliserar enheter
  String _pluralizeUnit(String unit, double amount) {
    if (amount == 1.0) return unit;

    final unitPlurals = {
      'burk': 'burkar',
      'påse': 'påsar',
      'förpackning': 'förpackningar',
      'flaska': 'flaskor',
      'ask': 'askar',
      'bit': 'bitar',
      'skiva': 'skivor',
      'tube': 'tuber',
      'tub': 'tuber',
    };

    return unitPlurals[unit.toLowerCase()] ?? '${unit}ar';
  }

  /// Kontrollerar om en ingrediens är räknebart (diskret) eller orräknebart (kontinuerligt)
  bool _isCountable(String name) {
    // Specialfall för sammansatta namn som alltid ska ha plural
    final lowerName = name.toLowerCase();
    if (lowerName.contains('krossade') ||
        lowerName.contains('hackade') ||
        lowerName.contains('skivade') ||
        lowerName.contains('platt')) {
      return true; // Dessa ska ha plural: "krossade tomater", "lasagneplattor"
    }

    final uncountable = {
      // Kryddor och smaker
      'salt', 'peppar', 'socker', 'vaniljsocker', 'bakpulver', 'natron',
      'kanel', 'kardemumma', 'ingefära', 'vitlökspulver', 'paprikapulver',
      'curry', 'oregano', 'basilika', 'timjan', 'rosmarin', 'dill', 'persilja',
      'chili', 'chilipulver', 'cayennepeppar', 'svartpeppar', 'vitpeppar',

      // Vätskor (när de inte har enhet)
      'olja', 'olivolja', 'rapsolja', 'kokosolja', 'smör', 'margarin',
      'grädde', 'mjölk', 'vatten', 'buljong', 'fond', 'vin', 'vinäger',
      'balsamvinäger', 'äppelcidervinäger', 'soja', 'sojasås', 'fiskesås',
      'worcestershiresås', 'tabasco', 'sriracha',

      // Torrvaror
      'mjöl', 'vetemjöl', 'rågmjöl', 'mandelmjöl', 'kokosmjöl', 'majsmjöl',
      'ris', 'jasminris', 'basmataris', 'risotto', 'pasta', 'couscous',
      'bulgur', 'quinoa', 'havregryn', 'müsli', 'cornflakes', 'granola',

      // Kött och fisk (när de inte har enhet)
      'kött', 'fläsk', 'nötkött', 'kalvkött', 'lamm', 'kyckling', 'kalkonfärs',
      'fisk', 'lax', 'torsk', 'makrill', 'tonfisk', 'räkor', 'musslor',
      'köttfärs', 'nötfärs', 'blandfärs', 'fläskfärs', 'kycklingfärs',

      // Mejeriprodukter
      'ost', 'parmesan', 'mozzarella', 'fetaost', 'ricotta', 'mascarpone',
      'crème fraiche', 'yoghurt', 'filmjölk', 'kefir',

      // Sötningsmedel och sylt
      'honung', 'sirap', 'lönnsirap', 'agavesirap', 'strösocker', 'florsocker',
      'muscovadosocker', 'kokossocker', 'stevia', 'sylt', 'marmelad', 'gelé',

      // Bröd och bakverk
      'bröd', 'knäckebröd', 'tunnbröd', 'pitabröd', 'tortilla', 'bagel',

      // Nötter och frön (när de inte räknas styckvis)
      'mandel', 'hasselnöt', 'valnöt', 'cashew', 'pistasch', 'pinje',
      'sesam', 'solrosfrön', 'pumpafrön', 'chiafrön', 'linfrö',

      // Bönor och linser (när de inte räknas styckvis)
      'linser', 'röda linser', 'gröna linser', 'belugalinser',
      'kidneybönor', 'svarta bönor', 'vita bönor', 'kikärtor',

      // Övrigt
      'kakao', 'kaffe', 'te', 'matcha', 'vanilj', 'vaniljextrakt',
      'kokosmjölk', 'mandelmjölk', 'havremjölk', 'sojamjölk',
    };

    return !uncountable.contains(name.toLowerCase().trim());
  }

  /// Hjälpmetod för att generera en textrepresentation av inköpslistan
  String generateShoppingListText(List<ShoppingItem> items) {
    final buffer = StringBuffer();
    buffer.writeln('Inköpslista:');
    buffer.writeln();

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final checkbox = item.bought ? '☑' : '☐';
      buffer.writeln('$checkbox ${item.name}');
    }

    return buffer.toString();
  }

  /// Hjälpmetod för att räkna statistik över inköpslistan
  Map<String, int> getShoppingListStats(List<ShoppingItem> items) {
    final total = items.length;
    final bought = items.where((item) => item.bought).length;
    final remaining = total - bought;

    return {
      'total': total,
      'bought': bought,
      'remaining': remaining,
      'completionPercentage': total > 0 ? (bought / total * 100).round() : 0,
    };
  }

  /// Markerar en vara som köpt/ej köpt
  void toggleItemBought(List<ShoppingItem> items, int index) {
    if (index >= 0 && index < items.length) {
      items[index].bought = !items[index].bought;
    }
  }

  /// Rensar alla checkade artiklar från listan
  List<ShoppingItem> clearBoughtItems(List<ShoppingItem> items) {
    return items.where((item) => !item.bought).toList();
  }

  /// Sorterar listan - köpta sist
  List<ShoppingItem> sortShoppingList(List<ShoppingItem> items) {
    items.sort((a, b) {
      // Först sorterar vi på köpt-status (false först)
      if (a.bought != b.bought) {
        return a.bought.toString().compareTo(b.bought.toString());
      }
      // Sedan alfabetiskt på namn
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  /// Skapar smart nyckel som slår ihop samma ingredienser
  String _createSmartKey(String unit, String name) {
    // Specialfall för ingredienser som ofta förekommer både med och utan enhet
    final commonIngredients = {
      'tomatsås': 'tomatsås',
      'krossade tomater': 'krossade tomater',
      'tomatpuré': 'tomatpuré',
      'kokosmjölk': 'kokosmjölk',
      'bönor': 'bönor',
      'linser': 'linser',
      'majs': 'majs',
      'ärtor': 'ärtor',
      'champinjoner': 'champinjoner',
      'oliver': 'oliver',
      'kapris': 'kapris',
    };

    // Om ingrediensen är vanlig och enheten är räknebart (burk, påse)
    // använd bara ingrediensnamnet som nyckel
    if (commonIngredients.containsKey(name.toLowerCase()) &&
        (unit.isEmpty || _isCountableUnit(unit))) {
      return name.toLowerCase();
    }

    // För andra fall, använd standard nyckel
    return unit.isEmpty ? name : '$unit|$name';
  }
}

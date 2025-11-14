/// Test fixtures and data for import integration tests
///
/// This file contains:
/// - Sample HTML responses (JSON-LD, microdata, plain HTML)
/// - Swedish recipe text samples
/// - CSV test data
/// - Sample image bytes for OCR testing
/// - Helper functions for creating test data

import 'dart:typed_data';

/// Sample HTML responses for URL import testing
class ImportHTMLFixtures {
  /// HTML with schema.org Recipe in JSON-LD format (modern standard)
  static const String jsonLdRecipeHtml = '''
<!DOCTYPE html>
<html>
<head>
  <title>Köttbullar med gräddsås - Butlery Test</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Köttbullar med gräddsås",
    "image": "https://example.com/images/kottbullar.jpg",
    "author": {
      "@type": "Person",
      "name": "Chef Anna"
    },
    "datePublished": "2025-01-15",
    "description": "Klassiska svenska köttbullar med krämig gräddsås",
    "prepTime": "PT15M",
    "cookTime": "PT25M",
    "totalTime": "PT40M",
    "recipeYield": "4 portioner",
    "recipeCategory": "Huvudrätt",
    "recipeCuisine": "Svensk",
    "keywords": "köttbullar, gräddsås, svensk mat, middag",
    "recipeIngredient": [
      "500 g köttfärs",
      "1 ägg",
      "2 dl ströbröd",
      "1 dl mjölk",
      "1 gul lök, finhackad",
      "2 msk smör till stekning",
      "Salt och peppar",
      "För gräddsås:",
      "3 dl grädde",
      "2 msk soja",
      "1 msk gelé",
      "Salt och peppar"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Blanda köttfärs, ägg, ströbröd, mjölk, hackad lök, salt och peppar i en skål."
      },
      {
        "@type": "HowToStep",
        "text": "Rör om ordentligt och låt smeten svälla i 10 minuter."
      },
      {
        "@type": "HowToStep",
        "text": "Forma till bullar (ca 20-25 st) med våta händer."
      },
      {
        "@type": "HowToStep",
        "text": "Stek bullarna i smör på medelhög värme tills de är genomstekta, ca 10 minuter."
      },
      {
        "@type": "HowToStep",
        "text": "För gräddsåsen: Häll grädde, soja och gelé i stekpannan. Koka upp och smaka av med salt och peppar."
      },
      {
        "@type": "HowToStep",
        "text": "Servera köttbullarna med gräddsås, potatismos och lingonsylt."
      }
    ],
    "nutrition": {
      "@type": "NutritionInformation",
      "calories": "520 kcal",
      "proteinContent": "28 g",
      "fatContent": "35 g"
    }
  }
  </script>
</head>
<body>
  <h1>Köttbullar med gräddsås</h1>
  <p>Klassiska svenska köttbullar med krämig gräddsås</p>
</body>
</html>
''';

  /// HTML with microdata (legacy format, still used by some sites)
  static const String microdataRecipeHtml = '''
<!DOCTYPE html>
<html>
<body itemscope itemtype="http://schema.org/Recipe">
  <h1 itemprop="name">Pannkakor</h1>
  <img itemprop="image" src="https://example.com/pannkakor.jpg" />
  <p itemprop="description">Klassiska svenska pannkakor</p>

  <div itemprop="author" itemscope itemtype="http://schema.org/Person">
    <span itemprop="name">Chef Erik</span>
  </div>

  <p>Tid: <time itemprop="totalTime" datetime="PT20M">20 minuter</time></p>
  <p>Portioner: <span itemprop="recipeYield">4</span></p>

  <h2>Ingredienser:</h2>
  <ul>
    <li itemprop="recipeIngredient">3 dl mjöl</li>
    <li itemprop="recipeIngredient">6 dl mjölk</li>
    <li itemprop="recipeIngredient">3 ägg</li>
    <li itemprop="recipeIngredient">1 nypa salt</li>
    <li itemprop="recipeIngredient">2 msk smör till stekning</li>
  </ul>

  <h2>Instruktioner:</h2>
  <div itemprop="recipeInstructions">
    <p>1. Vispa ihop mjöl och hälften av mjölken till en slät smet.</p>
    <p>2. Tillsätt resten av mjölken, äggen och saltet. Vispa till en jämn smet.</p>
    <p>3. Låt smeten svälla i 30 minuter.</p>
    <p>4. Stek tunna pannkakor i smör på medelvärme tills de är gyllenbruna på båda sidor.</p>
    <p>5. Servera med sylt och grädde.</p>
  </div>
</body>
</html>
''';

  /// Plain HTML without structured data (requires text extraction fallback)
  static const String plainHtmlRecipe = '''
<!DOCTYPE html>
<html>
<head><title>Laxpasta - Recept</title></head>
<body>
  <div class="recipe-container">
    <h1 class="recipe-title">Laxpasta med dillsås</h1>
    <p class="recipe-meta">Tid: 25 minuter | Portioner: 4 | Svårighet: Lätt</p>

    <div class="ingredients-section">
      <h2>Ingredienser</h2>
      <ul class="ingredients-list">
        <li>400 g pasta (gärna penne eller farfalle)</li>
        <li>300 g rökt lax i tärningar</li>
        <li>2 dl grädde</li>
        <li>1 dl crème fraiche</li>
        <li>1 citron (saft och skal)</li>
        <li>1 kruka färsk dill, hackad</li>
        <li>Salt och peppar</li>
      </ul>
    </div>

    <div class="instructions-section">
      <h2>Gör så här</h2>
      <ol class="instructions-list">
        <li>Koka pastan enligt anvisning på förpackningen.</li>
        <li>Värm grädde och crème fraiche i en stekpanna.</li>
        <li>Tillsätt lax, citronsaft, citronzest och dill. Värm försiktigt.</li>
        <li>Häll av pastan och blanda med såsen.</li>
        <li>Smaka av med salt och peppar. Servera genast!</li>
      </ol>
    </div>

    <div class="tips-section">
      <h3>Tips</h3>
      <p>Servera med riven parmesan och extra dill. God med ett glas vitt vin!</p>
    </div>
  </div>
</body>
</html>
''';

  /// HTML that returns 404
  static const String notFoundHtml = '''
<!DOCTYPE html>
<html>
<head><title>404 - Sidan hittades inte</title></head>
<body>
  <h1>404 - Sidan hittades inte</h1>
  <p>Receptet du söker finns inte längre.</p>
</body>
</html>
''';
}

/// Sample recipe text for text import testing
class ImportTextFixtures {
  /// Well-structured Swedish recipe text
  static const String wellStructuredRecipe = '''
Köttbullar med gräddsås

Portioner: 4
Tid: 40 minuter
Typ: Huvudrätt

INGREDIENSER:
500 g köttfärs
1 ägg
2 dl ströbröd
1 dl mjölk
1 gul lök, finhackad
2 msk smör till stekning
Salt och peppar

För gräddsås:
3 dl grädde
2 msk soja
1 msk gelé
Salt och peppar

INSTRUKTIONER:
1. Blanda köttfärs, ägg, ströbröd, mjölk, hackad lök, salt och peppar i en skål.
2. Rör om ordentligt och låt smeten svälla i 10 minuter.
3. Forma till bullar (ca 20-25 st) med våta händer.
4. Stek bullarna i smör på medelhög värme tills de är genomstekta, ca 10 minuter.
5. För gräddsåsen: Häll grädde, soja och gelé i stekpannan. Koka upp och smaka av.
6. Servera köttbullarna med gräddsås, potatismos och lingonsylt.

Tips: Låt smeten svälla ordentligt för saftigare bullar!
''';

  /// Social media formatted text (emojis, hashtags, etc.)
  static const String socialMediaRecipe = '''
🍝 BÄSTA CARBONARAN!!! 🇮🇹✨

Omg grabbar, ni MÅSTE testa detta recept!!! 😍😍😍

Ingredienser 📝:
- 400g spagetti 🍝
- 150g bacon (skivad) 🥓
- 3 ägg + 1 äggula 🥚
- 100g parmesanost, riven 🧀
- Salt & peppar ⚫⚪
- (Vitlök om du vill 🧄)

Så gör du 👨‍🍳:
1️⃣ Koka pasta enligt förpackningen!!!
2️⃣ Stek bacon tills KRISPY 🔥
3️⃣ Vispa ägg + ost i en skål
4️⃣ Häll av pastan (spara lite vatten!!!)
5️⃣ Blanda pasta + bacon + äggblandning OFF HEAT!!!
6️⃣ Tillsätt lite pastatten om det blir för torrt

Servera direkt!!!! 🤤🤤🤤

#carbonara #pasta #italienskt #middag #gott #mat #foodie #cooking #homemade #recipe #yummy
''';

  /// Poorly structured text (missing sections, hard to parse)
  static const String poorlyStructuredRecipe = '''
min mammas pannkakor

mjöl ägg mjölk och lite salt
vispa ihop allt och stek i smör
servera med sylt
ca 4 portioner tar typ 20 min
''';

  /// Recipe with measurements that need preprocessing
  static const String recipeWithApproximations = '''
Morotssoppa

Ingredienser (ca 4 portioner):
- ca 500 g morötter
- 1-2 gula lökar
- 1 liter buljong (ev vegetabilisk)
- 2-3 msk olivolja
- 1 tsk spiskummin (valfritt)
- salt & peppar efter smak

Gör så här:
Skala och hacka morötter och lök. Fräs i oljan. Häll på buljong och koka mjukt. Mixa slätt. Smaka av.
''';
}

/// Sample CSV data for file import testing
class ImportCSVFixtures {
  /// CSV with Swedish headers and multiple recipes
  static const String multipleRecipesCSV = '''Titel,Ingredienser,Instruktioner,Portioner,Tid,Typ
"Köttbullar","500g köttfärs;1 ägg;2dl ströbröd;1dl mjölk","Blanda allt. Forma bullar. Stek i smör.",4,40,Huvudrätt
"Pannkakor","3dl mjöl;6dl mjölk;3 ägg;1 nypa salt","Vispa ihop. Stek tunna pannkakor.",4,20,Frukost
"Laxsoppa","400g lax;1l fiskbuljong;2dl grädde;dill","Koka lax i buljong. Tillsätt grädde. Garnera med dill.",4,30,Soppa
"Caesar sallad","1 romansallad;kyckling;krutonger;parmesanost;caesardressing","Riv salladen. Toppa med övriga ingredienser.",2,15,Sallad
"Tomatsoppa","1kg tomater;2 vitlöksklyftor;1l grönsaksbuljong;basilika","Koka tomater i buljong. Mixa slätt. Smaka av med basilika.",4,25,Soppa
"Köttfärssås","500g köttfärs;1 burk krossade tomater;2 vitlöksklyftor;örter","Bryn köttfärsen. Tillsätt tomater och vitlök. Koka 20 min.",4,30,Såser
"Äggröra","6 ägg;1dl mjölk;smör;salt","Vispa ägg och mjölk. Stek i smör på låg värme.",2,10,Frukost
"Fiskgratäng","600g fisk;2dl grädde;1dl riven ost;dill","Lägg fisken i form. Häll över grädde. Toppa med ost. Grädda 25 min på 200°C.",4,35,Fisk
"Pastasallad","400g pasta;1 burk tonfisk;tomat;gurka;majonnäs","Koka pasta. Blanda med övriga ingredienser.",4,20,Sallad
"Chokladbollar","2dl havregryn;1dl socker;3msk kakao;100g smör;3msk kallt kaffe","Blanda allt. Rulla bollar. Ät direkt eller kyl.",30,15,Efterrätt
''';

  /// CSV with English headers
  static const String englishHeadersCSV = '''Title,Ingredients,Instructions,Servings,Time,Type
"Meatballs","500g ground beef;1 egg;2dl breadcrumbs","Mix all. Form balls. Fry in butter.",4,40,Main
"Pancakes","3dl flour;6dl milk;3 eggs","Whisk together. Fry thin pancakes.",4,20,Breakfast
''';

  /// Malformed CSV (missing columns)
  static const String malformedCSV = '''Titel,Ingredienser,Instruktioner
"Köttbullar","500g köttfärs;1 ägg"
"Pannkakor"
''';
}

/// Sample image bytes for OCR testing
class ImportImageFixtures {
  /// Valid PNG image (minimal header + data for recipe photo)
  static Uint8List get validRecipeImagePNG => Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        ...List.generate(500 * 1024, (i) => i % 256), // 500KB simulated image
      ]);

  /// Valid JPEG image
  static Uint8List get validRecipeImageJPEG => Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, // JPEG signature
        ...List.generate(300 * 1024, (i) => i % 256), // 300KB simulated image
      ]);

  /// Poor quality image (too small)
  static Uint8List get poorQualityImage => Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        ...List.generate(20 * 1024, (i) => i % 256), // 20KB (poor quality)
      ]);
}

/// Expected OCR text extraction results
class ImportOCRFixtures {
  /// High confidence OCR result (Swedish recipe from photo)
  static const String highConfidenceSwedishRecipe = '''
Köttbullar med gräddsås

Ingredienser:
500 g köttfärs
1 ägg
2 dl ströbröd
1 dl mjölk
1 gul lök, finhackad
Salt och peppar

Instruktioner:
1. Blanda alla ingredienser
2. Forma till bullar
3. Stek i smör tills genomstekta
4. Servera med gräddsås

Portioner: 4
Tid: 30 minuter
''';

  /// Low confidence OCR result (poor image quality)
  static const String lowConfidenceOCRText = '''
K0ttbull4r

Ingr3di3ns3r:
500g k0ttf4rs
1 4gg
2dl str0br0d

1nstruktion3r:
Bl4nda 4llt
St3k i sm0r
''';

  /// OCR result with measurement variations
  static const String ocrWithMeasurements = '''
Morotssoppa

ca 500 g morötter
1-2 gula lökar
1 liter buljong
2-3 msk olivolja
salt & peppar efter smak

Skala och hacka morötter och lök.
Fräs i oljan. Häll på buljong.
Koka mjukt. Mixa slätt.
''';
}

/// Helper functions for creating test data
class ImportTestHelpers {
  /// Create a mock ImportResult for testing
  static Map<String, dynamic> createMockImportResult({
    required String title,
    required String ingredients,
    required String instructions,
    int portions = 4,
    int timeMinutes = 30,
    String? mealType,
  }) {
    return {
      'title': title,
      'ingredients': ingredients,
      'instructions': instructions,
      'portions': portions,
      'timeMinutes': timeMinutes,
      'mealType': mealType ?? 'Huvudrätt',
    };
  }

  /// Generate fake image bytes of specified size
  static Uint8List generateFakeImage({
    required int sizeKB,
    bool isPNG = true,
  }) {
    final signature = isPNG
        ? [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        : [0xFF, 0xD8, 0xFF, 0xE0];

    return Uint8List.fromList([
      ...signature,
      ...List.generate(sizeKB * 1024, (i) => i % 256),
    ]);
  }

  /// Parse CSV content for testing
  static List<Map<String, String>> parseCSV(String csvContent) {
    final lines = csvContent.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final headers = lines[0].split(',').map((h) => h.trim().replaceAll('"', '')).toList();
    final rows = <Map<String, String>>[];

    for (var i = 1; i < lines.length; i++) {
      final values = lines[i].split(',').map((v) => v.trim().replaceAll('"', '')).toList();
      if (values.length == headers.length) {
        final row = <String, String>{};
        for (var j = 0; j < headers.length; j++) {
          row[headers[j]] = values[j];
        }
        rows.add(row);
      }
    }

    return rows;
  }
}

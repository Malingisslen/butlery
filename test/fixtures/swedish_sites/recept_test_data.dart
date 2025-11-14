/// Test fixtures for Recept.se recipe parsing
///
/// Contains representative HTML from Recept.se recipes with:
/// - Schema.org JSON-LD markup
/// - Swedish recipe content
/// - Recept-specific fields (category, cuisine, serving suggestions)
/// - Mix of traditional and modern recipes

class ReceptTestFixtures {
  /// Complete Recept recipe with full JSON-LD
  ///
  /// Based on classic Swedish cinnamon buns
  static const String kanelbullarComplete = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Kanelbullar - Recept.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Klassiska kanelbullar",
    "description": "Traditionella svenska kanelbullar med kardemumma och kanel.",
    "image": "https://img.recept.se/media/kanelbullar-123456.jpg",
    "author": {
      "@type": "Person",
      "name": "Recept.se"
    },
    "datePublished": "2024-01-15",
    "prepTime": "PT30M",
    "cookTime": "PT15M",
    "totalTime": "PT45M",
    "recipeYield": "25 bullar",
    "recipeCategory": "Fika",
    "recipeCuisine": "Svensk",
    "keywords": "kanelbullar, fika, bröd",
    "recipeIngredient": [
      "5 dl mjölk",
      "50 g jäst",
      "1 ägg",
      "1 dl socker",
      "1 tsk kardemumma",
      "12 dl vetemjöl",
      "100 g smör till fyllning",
      "2 msk kanel",
      "1 dl pärlsocker"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Värm mjölken till 37 grader och lös upp jästen."
      },
      {
        "@type": "HowToStep",
        "text": "Blanda i ägg, socker, kardemumma och mjöl."
      },
      {
        "@type": "HowToStep",
        "text": "Kavla ut degen och bred på fyllning."
      },
      {
        "@type": "HowToStep",
        "text": "Rulla ihop och skär i bitar. Grädda i 225°C i 10-15 min."
      }
    ]
  }
  </script>
</head>
<body>
  <article class="recipe-content">
    <div class="recipe-meta">
      <span class="recipe-difficulty">Medel</span>
      <span class="recipe-category">Fika</span>
      <span class="recipe-cuisine">Svensk</span>
    </div>
    <div class="recipe-tips">
      <p>Tips: Låt degen jäsa dubbelt så stor för luftigare bullar.</p>
    </div>
    <div class="serving-suggestions">
      <p>Servera med kaffe eller mjölk.</p>
    </div>
  </article>
</body>
</html>
''';

  /// Recipe with Swedish characters
  static const String recipeWithSwedishChars = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Älggryta - Recept.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Älggryta med svamp och lingon",
    "description": "Klassisk svensk höstgryta med älgkött och skogschampinjoner.",
    "totalTime": "PT2H30M",
    "recipeYield": "6 portioner",
    "recipeCuisine": "Svensk",
    "recipeCategory": "Middag",
    "recipeIngredient": [
      "800 g älgkött i tärningar",
      "300 g svamp (kantareller eller skogschampinjoner)",
      "2 dl grädde",
      "2 msk lingonsylt",
      "Salt och peppar"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Bryn älgköttet i smör."
      },
      {
        "@type": "HowToStep",
        "text": "Tillsätt svamp och låt puttra i 2 timmar."
      },
      {
        "@type": "HowToStep",
        "text": "Rör ner grädde och lingonsylt."
      }
    ]
  }
  </script>
</head>
<body>
  <div class="recipe-difficulty">Medel</div>
  <div class="recipe-category">Middag</div>
</body>
</html>
''';

  /// Recipe with category and cuisine
  static const String recipeWithCategoryAndCuisine = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Pasta Carbonara - Recept.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Klassisk Pasta Carbonara",
    "description": "Italiensk pasta med ägg, bacon och parmesan.",
    "totalTime": "PT20M",
    "recipeYield": "4 portioner",
    "recipeCategory": "Middag",
    "recipeCuisine": "Italiensk",
    "recipeIngredient": [
      "400 g spaghetti",
      "200 g bacon",
      "3 ägg",
      "100 g parmesan",
      "Salt och svartpeppar"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Koka pastan enligt förpackningen."
      },
      {
        "@type": "HowToStep",
        "text": "Stek bacon tills knaprig."
      },
      {
        "@type": "HowToStep",
        "text": "Blanda ägg och parmesan, rör ner i pastan."
      }
    ]
  }
  </script>
</head>
<body>
  <div class="recipe-category">Middag</div>
  <div class="recipe-cuisine">Italiensk</div>
  <div class="recipe-difficulty">Enkel</div>
</body>
</html>
''';

  /// Recipe without JSON-LD (tests CSS fallback)
  static const String recipeWithoutJsonLd = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Pannkakor - Recept.se</title>
</head>
<body>
  <article class="recipe-content">
    <h1 class="recipe-title">Klassiska svenska pannkakor</h1>
    <div class="recipe-description">
      Tunna och luftiga pannkakor perfekta till frukost eller middag.
    </div>
    <div class="recipe-meta">
      <span class="recipe-portions">10 pannkakor</span>
      <span class="recipe-time">30 minuter</span>
      <span class="recipe-difficulty">Enkel</span>
      <span class="recipe-category">Frukost</span>
    </div>
    <div class="ingredient-list">
      <ul>
        <li>3 ägg</li>
        <li>6 dl mjölk</li>
        <li>3 dl vetemjöl</li>
        <li>½ tsk salt</li>
        <li>Smör till stekning</li>
      </ul>
    </div>
    <div class="recipe-instructions">
      <ol>
        <li>Vispa ihop ägg och mjölk.</li>
        <li>Rör ner mjöl och salt till en slät smet.</li>
        <li>Stek tunna pannkakor i smör.</li>
        <li>Servera med sylt och grädde.</li>
      </ol>
    </div>
    <div class="serving-suggestions">
      <p>Servera med jordgubbssylt och vispad grädde.</p>
    </div>
  </article>
</body>
</html>
''';

  /// Recipe with malformed JSON (tests error recovery)
  static const String recipeWithMalformedJson = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Köttfärssås - Recept.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Köttfärssås",
    "recipeIngredient": [
      "500 g köttfärs",
      "1 burk krossade tomater"
      // Missing comma - JSON parse error
      "1 gul lök"
    ],
  </script>
</head>
<body>
  <h1>Köttfärssås</h1>
  <div class="ingredient-list">
    <ul>
      <li>500 g köttfärs</li>
      <li>1 burk krossade tomater</li>
      <li>1 gul lök</li>
      <li>2 vitlöksklyftor</li>
      <li>Basilika och oregano</li>
    </ul>
  </div>
  <div class="recipe-steps">
    <ol>
      <li>Bryn färsen med lök och vitlök.</li>
      <li>Tillsätt tomater och kryddor.</li>
      <li>Låt puttra i 30 minuter.</li>
    </ol>
  </div>
  <div class="recipe-difficulty">Enkel</div>
  <div class="recipe-category">Middag</div>
</body>
</html>
''';

  /// Recipe with minimal data (quality check)
  static const String recipeMinimalData = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Toast - Recept.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Rostat bröd",
    "recipeIngredient": [
      "2 skivor bröd"
    ]
  }
  </script>
</head>
<body></body>
</html>
''';

  /// Recipe with complete metadata (high quality)
  static const String recipeCompleteMetadata = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Grillad lax - Recept.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Grillad lax med citron och dill",
    "description": "Saftig grillad lax med fräsch citron- och dillsmak.",
    "image": "https://img.recept.se/media/lax.jpg",
    "author": {
      "@type": "Person",
      "name": "Recept.se"
    },
    "prepTime": "PT10M",
    "cookTime": "PT15M",
    "totalTime": "PT25M",
    "recipeYield": "4 portioner",
    "recipeCategory": "Middag",
    "recipeCuisine": "Svensk",
    "keywords": "lax, fisk, grill, sommar",
    "recipeIngredient": [
      "4 laxfiléer à 150 g",
      "2 citroner",
      "1 dl färsk dill",
      "2 msk olivolja",
      "Salt och peppar",
      "1 vitlöksklyfta"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Marinera laxen med olivolja, citron och dill i 15 min."
      },
      {
        "@type": "HowToStep",
        "text": "Grilla laxen i 5-7 minuter per sida."
      },
      {
        "@type": "HowToStep",
        "text": "Servera med resten av citronen och färsk dill."
      }
    ]
  }
  </script>
</head>
<body>
  <div class="recipe-difficulty">Enkel</div>
  <div class="recipe-category">Middag</div>
  <div class="recipe-cuisine">Svensk</div>
  <div class="recipe-tips">Tips: Använd färsk lax för bästa smak.</div>
  <div class="serving-suggestions">Servera med kokt potatis och en grön sallad.</div>
</body>
</html>
''';

  /// Recipe with Recept-specific formatting quirks
  static const String recipeWithReceptQuirks = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Potatismos - Recept.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Krämigt potatismos",
    "recipeYield": "cirka 4 portioner",
    "recipeIngredient": [
      "ca 800 g potatis",
      "cirka 2 dl mjölk  ",
      "  100 g smör",
      "Salt och vitpeppar  "
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "  Koka potatisen mjuk.  "
      },
      {
        "@type": "HowToStep",
        "text": "Mosa med mjölk och smör till krämig konsistens.  "
      }
    ]
  }
  </script>
</head>
<body>
  <div class="recipe-difficulty">Enkel</div>
</body>
</html>
''';
}

/// Test fixtures for Köket.se recipe parsing
///
/// Every fixture in this file is FABRICATED from the schema.org Recipe
/// standard, and stays that way. TV4's terms bar copying the material,
/// making any part of the service available to the public, and any use
/// beyond private use; the terms close with "Do not mine us". Nothing here
/// has any contact with a TV4 property, and no capture from köket.se may be
/// added. See ADR-0012's superseding section — and note that köket.se's
/// robots.txt is fully permissive, so robots.txt alone would tell you the
/// opposite of the truth here.
///
/// The consequence is a real limitation, written down rather than hidden:
/// these fixtures agree with the parser by construction, so they cannot show
/// that it handles what köket.se actually serves. Compare
/// `real_structure_test.dart`, where captured arla.se markup turned out to
/// disagree with the parser (BUT-2020).
///
/// Contains representative HTML from Köket.se recipes with:
/// - Schema.org JSON-LD markup
/// - Swedish recipe content
/// - Köket-specific fields (ratings, author, seasonal tags)
/// - Mix of professional and user-generated content

class KoketTestFixtures {
  /// Professional Köket recipe with complete JSON-LD
  ///
  /// Based on classic Swedish meatballs recipe
  static const String kottbullarProfessional = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Klassiska köttbullar - Köket.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Klassiska svenska köttbullar",
    "description": "Perfekta köttbullar gjorda på nötfärs med traditionell svensk smak.",
    "image": "https://img.koket.se/media/kottbullar-123456.jpg",
    "author": {
      "@type": "Person",
      "name": "Kökets Kockar"
    },
    "aggregateRating": {
      "@type": "AggregateRating",
      "ratingValue": "4.8",
      "reviewCount": "256"
    },
    "datePublished": "2024-01-15",
    "prepTime": "PT20M",
    "cookTime": "PT25M",
    "totalTime": "PT45M",
    "recipeYield": "4 portioner",
    "recipeCategory": "Huvudrätt",
    "recipeCuisine": "Svensk",
    "keywords": "köttbullar, middag, svensk mat",
    "recipeIngredient": [
      "500 g nötfärs",
      "1 ägg",
      "2 dl ströbröd",
      "1 dl mjölk",
      "1 gul lök",
      "1 tsk salt",
      "½ tsk peppar"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Blanda alla ingredienser till en smet."
      },
      {
        "@type": "HowToStep",
        "text": "Forma till bullar och stek i smör."
      },
      {
        "@type": "HowToStep",
        "text": "Servera med potatis och lingonsylt."
      }
    ]
  }
  </script>
</head>
<body>
  <article class="recipe-content">
    <div class="recipe-meta">
      <span class="recipe-difficulty">Enkel</span>
      <span class="recipe-rating">4.8 / 5 (256 betyg)</span>
      <span class="recipe-author">Kökets Kockar</span>
    </div>
    <div class="recipe-tips">
      <p>Tips: Låt smeten svälla i kylskåpet för saftigare resultat.</p>
    </div>
  </article>
</body>
</html>
''';

  /// User-generated recipe with variable quality
  static const String userGeneratedRecipe = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Mormors pannkakor - Köket.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Mormors bästa pannkakor",
    "description": "Klassiska pannkakor precis som mormor brukade göra dem!",
    "author": {
      "@type": "Person",
      "name": "Anna Svensson"
    },
    "aggregateRating": {
      "@type": "AggregateRating",
      "ratingValue": "4.2",
      "reviewCount": "48"
    },
    "totalTime": "PT30M",
    "recipeYield": "ca 12 pannkakor",
    "recipeIngredient": [
      "3 ägg",
      "6 dl mjölk",
      "3 dl vetemjöl",
      "½ tsk salt"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Vispa ihop ägg och mjölk."
      },
      {
        "@type": "HowToStep",
        "text": "Rör ner mjöl och salt."
      },
      {
        "@type": "HowToStep",
        "text": "Stek tunna pannkakor i smör."
      }
    ]
  }
  </script>
</head>
<body>
  <div class="recipe-author">Anna Svensson</div>
  <div class="recipe-rating">4.2 / 5 (48 betyg)</div>
  <div class="user-tips">
    <p>Tips från användare: Lägg till lite socker i smeten för extra goda pannkakor!</p>
  </div>
</body>
</html>
''';

  /// Recipe with seasonal/holiday tags
  static const String seasonalRecipe = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Julskinka - Köket.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Klassisk julskinka",
    "description": "Traditionell svensk julskinka perfekt till julbordet.",
    "totalTime": "PT4H",
    "recipeYield": "12 portioner",
    "keywords": "jul, julskinka, julbord, högtid",
    "recipeIngredient": [
      "1 rökt skinka ca 3 kg",
      "Senap",
      "Äggula",
      "Ströbröd"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Koka skinkan enligt anvisning."
      },
      {
        "@type": "HowToStep",
        "text": "Pensla med senap och äggula."
      },
      {
        "@type": "HowToStep",
        "text": "Gratinera i ugnen."
      }
    ]
  }
  </script>
</head>
<body>
  <div class="recipe-tags">
    <span>jul</span>
    <span>högtid</span>
    <span>vinter</span>
  </div>
</body>
</html>
''';

  /// Recipe without JSON-LD (tests CSS fallback)
  static const String recipeWithoutJsonLd = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Kladdkaka - Köket.se</title>
</head>
<body>
  <article class="recipe-content">
    <h1 class="recipe-title">Saftig kladdkaka</h1>
    <div class="recipe-description">
      En kladdig och god chokladkaka.
    </div>
    <div class="recipe-meta">
      <span class="recipe-portions">8 bitar</span>
      <span class="recipe-time">40 minuter</span>
      <span class="recipe-difficulty">Enkel</span>
    </div>
    <div class="ingredient-list">
      <ul>
        <li>2 ägg</li>
        <li>3 dl socker</li>
        <li>100 g smör</li>
        <li>1½ dl vetemjöl</li>
        <li>4 msk kakao</li>
      </ul>
    </div>
    <div class="recipe-instructions">
      <ol>
        <li>Vispa ägg och socker pösigt.</li>
        <li>Smält smöret och rör ner det.</li>
        <li>Blanda i mjöl och kakao.</li>
        <li>Grädda i 175°C i 15 minuter.</li>
      </ol>
    </div>
    <div class="recipe-image">
      <img src="https://img.koket.se/media/kladdkaka.jpg" alt="Kladdkaka">
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
  <title>Lasagne - Köket.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Italiensk lasagne",
    "recipeIngredient": [
      "500 g köttfärs",
      "1 burk tomater"
      // Missing comma - JSON parse error
      "Lasagneplattor"
    ],
  </script>
</head>
<body>
  <h1>Italiensk lasagne</h1>
  <div class="ingredient-list">
    <ul>
      <li>500 g köttfärs</li>
      <li>1 burk tomater</li>
      <li>Lasagneplattor</li>
      <li>Bechamelsås</li>
      <li>Riven ost</li>
    </ul>
  </div>
  <div class="recipe-steps">
    <ol>
      <li>Bryn färsen med tomater.</li>
      <li>Varva köttfärssås, plattor och bechamelsås.</li>
      <li>Gratinera med ost i ugnen.</li>
    </ol>
  </div>
</body>
</html>
''';

  /// Recipe with Swedish characters
  static const String recipeWithSwedishChars = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Ärtsoppa - Köket.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Ärtsoppa med fläsk",
    "description": "Klassisk torsdagsmiddag med ärtsoppa och pannkakor till efterrätt.",
    "totalTime": "PT2H",
    "recipeYield": "6 portioner",
    "recipeIngredient": [
      "500 g gula ärtor",
      "2 rökta fläskben",
      "2 lökar",
      "Timjan",
      "Salt och peppar"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Blötlägg ärtorna över natten."
      },
      {
        "@type": "HowToStep",
        "text": "Koka ärtor med fläsket i 2 timmar."
      }
    ]
  }
  </script>
</head>
<body>
  <h1>Ärtsoppa med fläsk</h1>
</body>
</html>
''';

  /// Recipe with minimal data (quality check)
  static const String recipeMinimalData = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Enkel smörgås - Köket.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Smörgås",
    "recipeIngredient": [
      "2 skivor bröd",
      "Smör"
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
  <title>Laxpasta - Köket.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Krämig laxpasta",
    "description": "Lyxig pastarätt med lax och spenat i gräddesås.",
    "image": "https://img.koket.se/media/laxpasta.jpg",
    "author": {
      "@type": "Person",
      "name": "Kökets Kockar"
    },
    "aggregateRating": {
      "@type": "AggregateRating",
      "ratingValue": "4.9",
      "reviewCount": "324"
    },
    "prepTime": "PT10M",
    "cookTime": "PT15M",
    "totalTime": "PT25M",
    "recipeYield": "4 portioner",
    "recipeCategory": "Middag",
    "keywords": "pasta, lax, snabbt, middag",
    "recipeIngredient": [
      "400 g pasta",
      "300 g laxfilé",
      "3 dl grädde",
      "100 g spenat",
      "1 vitlöksklyfta",
      "Salt och peppar"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Koka pastan enligt förpackningen."
      },
      {
        "@type": "HowToStep",
        "text": "Stek laxen i smör med vitlök."
      },
      {
        "@type": "HowToStep",
        "text": "Tillsätt grädde och spenat."
      },
      {
        "@type": "HowToStep",
        "text": "Blanda med pastan och smaka av."
      }
    ]
  }
  </script>
</head>
<body>
  <div class="recipe-difficulty">Enkel</div>
  <div class="recipe-rating">4.9 / 5 (324 betyg)</div>
  <div class="recipe-author">Kökets Kockar</div>
  <div class="recipe-tips">Tips: Använd färsk lax för bästa smak.</div>
</body>
</html>
''';

  /// Recipe with Köket-specific formatting quirks
  static const String recipeWithKoketQuirks = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Tacos - Köket.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Snabba tacos",
    "recipeYield": "cirka 4 portioner",
    "recipeIngredient": [
      "ca 500 g köttfärs",
      "cirka 1 dl vatten",
      "1 påse tacokrydda  ",
      "  8 tortillabröd",
      "Tillbehör  "
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "  Bryn färsen i en panna.  "
      },
      {
        "@type": "HowToStep",
        "text": "Tillsätt vatten och krydda. Låt sjuda.  "
      }
    ]
  }
  </script>
</head>
<body></body>
</html>
''';

  /// Recipe with high rating
  static const String recipeWithHighRating = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Prinsesstårta - Köket.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Klassisk prinsesstårta",
    "description": "Traditionell svensk prinsesstårta med grön marsipan.",
    "author": {
      "@type": "Person",
      "name": "Matilda Eriksson"
    },
    "aggregateRating": {
      "@type": "AggregateRating",
      "ratingValue": "5.0",
      "reviewCount": "89"
    },
    "totalTime": "PT2H",
    "recipeYield": "8 portioner",
    "recipeIngredient": [
      "4 ägg",
      "2 dl socker",
      "1 dl vetemjöl",
      "1 tsk bakpulver",
      "5 dl vispgrädde",
      "Vaniljkräm",
      "Grön marsipan"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Grädda sockerkakskakor."
      },
      {
        "@type": "HowToStep",
        "text": "Fyll med vaniljkräm och grädde."
      },
      {
        "@type": "HowToStep",
        "text": "Täck med grön marsipan."
      }
    ]
  }
  </script>
</head>
<body>
  <div class="koket-rating">5.0 / 5 (89 recensioner)</div>
  <div class="recipe-author">Matilda Eriksson</div>
  <div class="recipe-difficulty">Avancerad</div>
</body>
</html>
''';
}

/// Test fixtures for ICA.se recipe parsing
///
/// Contains representative HTML from ICA.se recipes with:
/// - Schema.org JSON-LD markup
/// - Swedish recipe content
/// - ICA-specific fields (difficulty, tips)
/// - Various recipe types and edge cases

class IcaTestFixtures {
  /// Standard ICA.se recipe with complete JSON-LD
  ///
  /// Based on classic Swedish meatballs recipe
  static const String kottbullarComplete = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Klassiska köttbullar - ICA.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Klassiska köttbullar med gräddsås",
    "description": "Saftig köttbullar gjorda på nötfärs med en krämig gräddsås. Ett klassiskt svenskt recept som hela familjen älskar.",
    "image": "https://assets.icanet.se/image/upload/q_auto,f_auto/kottbullar-med-graddsas-123456.jpg",
    "author": {
      "@type": "Person",
      "name": "ICA Köket"
    },
    "datePublished": "2024-01-15",
    "prepTime": "PT20M",
    "cookTime": "PT25M",
    "totalTime": "PT45M",
    "recipeYield": "4 portioner",
    "recipeCategory": "Huvudrätt",
    "recipeCuisine": "Svensk",
    "keywords": "köttbullar, gräddsås, svensk mat, middag, nötfärs",
    "recipeIngredient": [
      "500 g nötfärs",
      "1 ägg",
      "2 dl ströbröd",
      "1 dl mjölk",
      "1 gul lök, finhackad",
      "1 tsk salt",
      "½ tsk peppar",
      "2 msk smör till stekning",
      "För gräddsås:",
      "3 dl grädde",
      "2 msk soja",
      "1 msk gelé",
      "Salt och peppar"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Blanda köttfärs, ägg, ströbröd, mjölk, hackad lök, salt och peppar i en skål. Arbeta samman till en smet."
      },
      {
        "@type": "HowToStep",
        "text": "Låt smeten svälla i kylskåpet i ca 10 minuter."
      },
      {
        "@type": "HowToStep",
        "text": "Forma smeten till ca 20 bullar med våta händer."
      },
      {
        "@type": "HowToStep",
        "text": "Stek bullarna i smör på medelhög värme tills de är genomstekta, ca 10-12 minuter. Vänd dem försiktigt under stekningen."
      },
      {
        "@type": "HowToStep",
        "text": "Ta upp bullarna ur pannan. Häll grädde, soja och gelé i samma panna. Koka upp och smaka av med salt och peppar."
      },
      {
        "@type": "HowToStep",
        "text": "Servera köttbullarna med gräddsås, kokt potatis och lingonsylt."
      }
    ]
  }
  </script>
</head>
<body>
  <article class="recipe-content">
    <div class="recipe-meta">
      <span class="recipe-difficulty">Enkel</span>
    </div>
    <div class="recipe-tips">
      <p>Tips: Låt smeten svälla ordentligt i kylskåpet, det gör bullarna saftigare och lättare att forma.</p>
    </div>
  </article>
</body>
</html>
''';

  /// ICA recipe with difficulty and equipment
  static const String pannkakorWithExtras = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Fluffiga pannkakor - ICA.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Fluffiga amerikanska pannkakor",
    "description": "Tjocka och fluffiga pannkakor som smakar som på restaurang.",
    "image": "https://assets.icanet.se/image/upload/q_auto,f_auto/pannkakor.jpg",
    "totalTime": "PT30M",
    "recipeYield": "ca 12 pannkakor",
    "recipeCategory": "Frukost",
    "recipeIngredient": [
      "3 dl vetemjöl",
      "2 tsk bakpulver",
      "½ tsk salt",
      "3 msk socker",
      "2 ägg",
      "3 dl mjölk",
      "3 msk smält smör"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Blanda mjöl, bakpulver, salt och socker i en skål."
      },
      {
        "@type": "HowToStep",
        "text": "Vispa ihop ägg, mjölk och smält smör i en annan skål."
      },
      {
        "@type": "HowToStep",
        "text": "Häll de våta ingredienserna i de torra och blanda försiktigt. Smeten ska vara lite klumpig."
      },
      {
        "@type": "HowToStep",
        "text": "Stek pannkakor i smör tills de är gyllene på båda sidor."
      }
    ]
  }
  </script>
</head>
<body>
  <div class="recipe-difficulty">Medel</div>
  <div class="equipment-list">
    <ul>
      <li>Vissp</li>
      <li>Stekpanna</li>
      <li>Spatel</li>
    </ul>
  </div>
  <div class="cooking-tips">
    <p>För extra fluffiga pannkakor, låt smeten vila i 5-10 minuter innan stekning.</p>
  </div>
</body>
</html>
''';

  /// Recipe without JSON-LD (tests CSS fallback)
  static const String recipeWithoutJsonLd = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Kladdkaka - ICA.se</title>
</head>
<body>
  <article class="recipe-content">
    <h1 class="recipe-title">Klassisk kladdkaka</h1>
    <div class="recipe-description">
      En saftig och kladdig chokladkaka som är perfekt till fikat.
    </div>
    <div class="recipe-meta">
      <span class="recipe-portions">8 bitar</span>
      <span class="recipe-time">30 minuter</span>
    </div>
    <div class="ingredient-list">
      <ul>
        <li>2 ägg</li>
        <li>3 dl socker</li>
        <li>1½ dl vetemjöl</li>
        <li>4 msk kakao</li>
        <li>1 tsk vaniljsocker</li>
        <li>100 g smör</li>
      </ul>
    </div>
    <div class="recipe-instructions">
      <ol>
        <li>Sätt ugnen på 175°C. Smörj och bröa en form (ca 20 cm).</li>
        <li>Vispa ägg och socker pösigt.</li>
        <li>Blanda mjöl, kakao och vaniljsocker. Rör ner i äggsmeten.</li>
        <li>Smält smöret och rör ner det.</li>
        <li>Häll smeten i formen och grädda i mitten av ugnen i ca 15 minuter. Kakan ska vara kladdig i mitten.</li>
      </ol>
    </div>
    <div class="recipe-image">
      <img src="https://assets.icanet.se/image/upload/kladdkaka.jpg" alt="Kladdkaka">
    </div>
  </article>
</body>
</html>
''';

  /// Recipe with malformed JSON-LD (tests error recovery)
  static const String recipeWithMalformedJson = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Lasagne - ICA.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Lasagne al forno",
    "recipeIngredient": [
      "500 g nötfärs",
      "1 burk krossade tomater"
      // Missing comma - will cause JSON parse error
      "2 vitlöksklyftor"
    ],
  </script>
</head>
<body>
  <h1>Lasagne al forno</h1>
  <div class="ingredient-list">
    <ul>
      <li>500 g nötfärs</li>
      <li>1 burk krossade tomater</li>
      <li>2 vitlöksklyftor, hackade</li>
      <li>Lasagneplattor</li>
      <li>Bechamelsås</li>
    </ul>
  </div>
  <div class="recipe-steps">
    <ol>
      <li>Bryn färsen och tillsätt tomater och vitlök.</li>
      <li>Varva köttfärssås, lasagneplattor och bechamelsås i en ugnsform.</li>
      <li>Gratinera i ugnen på 200°C i 40 minuter.</li>
    </ol>
  </div>
</body>
</html>
''';

  /// Recipe with Swedish characters (Å, Ä, Ö)
  static const String recipeWithSwedishChars = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Ärtsoppa - ICA.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Ärtsoppa med fläsk",
    "description": "Klassisk svensk ärtsoppa med rökta fläskben. Perfekt till torsdagsmiddagen!",
    "totalTime": "PT2H30M",
    "recipeYield": "6 portioner",
    "recipeIngredient": [
      "500 g gula ärtor",
      "2 rökta fläskben",
      "2 gula lökar, hackade",
      "1 msk senapsfrön",
      "Salt och peppar"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Blötlägg ärtorna över natten i kallt vatten."
      },
      {
        "@type": "HowToStep",
        "text": "Koka ärtorna med fläskbenen i ca 2 timmar."
      },
      {
        "@type": "HowToStep",
        "text": "Tillsätt lök och senapsfrön. Låt koka ytterligare 30 minuter."
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

  /// Recipe with minimal data (tests quality scoring)
  static const String recipeMinimalData = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Enkelt recept - ICA.se</title>
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

  /// Recipe with complete metadata (tests high quality score)
  static const String recipeCompleteMetadata = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Laxpasta - ICA.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Krämig laxpasta med spenat",
    "description": "En snabb och lyxig pastarätt med lax och spenat i gräddesås.",
    "image": "https://assets.icanet.se/image/upload/laxpasta.jpg",
    "prepTime": "PT10M",
    "cookTime": "PT20M",
    "totalTime": "PT30M",
    "recipeYield": "4 portioner",
    "recipeCategory": "Middag",
    "recipeCuisine": "Italiensk",
    "keywords": "pasta, lax, snabbt, middag",
    "recipeIngredient": [
      "400 g pasta",
      "300 g laxfilé",
      "2 dl grädde",
      "100 g färsk spenat",
      "1 vitlöksklyfta",
      "Salt och peppar"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Koka pastan enligt anvisning på förpackningen."
      },
      {
        "@type": "HowToStep",
        "text": "Skär laxen i bitar och stek i smör tillsammans med hackad vitlök."
      },
      {
        "@type": "HowToStep",
        "text": "Tillsätt grädde och spenat. Låt koka några minuter."
      },
      {
        "@type": "HowToStep",
        "text": "Blanda pastan med såsen. Smaka av med salt och peppar."
      }
    ]
  }
  </script>
</head>
<body>
  <div class="recipe-difficulty">Enkel</div>
  <div class="recipe-tips">Tips: Använd färsk lax för bästa resultat.</div>
</body>
</html>
''';

  /// Recipe with ICA-specific formatting quirks
  static const String recipeWithIcaQuirks = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Tacos - ICA.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Tacos med nötfärs",
    "recipeYield": "ca 4 portioner",
    "recipeIngredient": [
      "ca 500 g nötfärs",
      "cirka 1 dl vatten",
      "1 påse tacokrydda  ",
      "  8 tortillabröd",
      "Valfria tillbehör:  salsa, gräddfil, ost"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "  Bryn färsen i en stekpanna.  "
      },
      {
        "@type": "HowToStep",
        "text": "Tillsätt vatten och tacokrydda. Låt sjuda i ca 5 minuter.  "
      }
    ]
  }
  </script>
</head>
<body></body>
</html>
''';
}

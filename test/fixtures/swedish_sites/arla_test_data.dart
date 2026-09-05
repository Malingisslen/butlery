/// Test fixtures for Arla.se recipe parsing
///
/// Contains representative HTML from Arla.se recipes with:
/// - Schema.org JSON-LD markup
/// - Swedish recipe content
/// - Arla-specific fields (difficulty, tips, nutritional info)
/// - Various recipe types and edge cases

class ArlaTestFixtures {
  /// Standard Arla.se recipe with complete JSON-LD
  ///
  /// Based on classic Swedish chocolate balls recipe
  static const String chokladbollarComplete = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Chokladbollar - Arla.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Chokladbollar",
    "description": "Klassiska chokladbollar med kakao och havregryn. Perfekt till fikat eller som barnkalas.",
    "image": "https://assets.arla.com/image/upload/q_auto,f_auto/chokladbollar-123456.jpg",
    "author": {
      "@type": "Person",
      "name": "Arla Köket"
    },
    "datePublished": "2024-01-20",
    "prepTime": "PT15M",
    "totalTime": "PT15M",
    "recipeYield": "20 bollar",
    "recipeCategory": "Efterrätt",
    "recipeCuisine": "Svensk",
    "keywords": "chokladbollar, kakao, havregryn, fika",
    "recipeIngredient": [
      "100 g smör, rumstempererat",
      "1 dl socker",
      "2 dl havregryn",
      "1-2 msk kallt kaffe",
      "3 msk kakao",
      "1 tsk vaniljsocker",
      "Pärlsocker eller kokos till rullning"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Blanda smör och socker till en krämig smet."
      },
      {
        "@type": "HowToStep",
        "text": "Rör ner havregryn, kakao, vaniljsocker och kallt kaffe."
      },
      {
        "@type": "HowToStep",
        "text": "Ställ smeten kallt i kylen i ca 30 minuter."
      },
      {
        "@type": "HowToStep",
        "text": "Rulla bollar av smeten och vänd i pärlsocker eller kokos."
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
      <p>Tips: Låt smeten kallna ordentligt, då blir det lättare att forma bollarna.</p>
    </div>
    <div class="nutrition-info">
      <p>Per portion: 120 kcal, Protein: 2 g, Fett: 6 g, Kolhydrater: 15 g</p>
    </div>
  </article>
</body>
</html>
''';

  /// Arla recipe with nutritional information
  static const String recipeWithNutrition = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Ostkaka - Arla.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Ostkaka med grädde och sylt",
    "description": "Klassisk svensk ostkaka med grädde och sylt.",
    "totalTime": "PT1H",
    "recipeYield": "8 portioner",
    "recipeIngredient": [
      "1 liter Arla Ko ekologisk mjölk",
      "200 g Arla Köket® quark naturell",
      "3 ägg",
      "1 dl socker",
      "2 msk vetemjöl",
      "1 tsk vaniljsocker"
    ],
    "recipeInstructions": [
      {"@type": "HowToStep", "text": "Värm mjölken till 37°C."},
      {"@type": "HowToStep", "text": "Blanda ägg, socker, mjöl och vaniljsocker."},
      {"@type": "HowToStep", "text": "Tillsätt mjölken och quark. Rör om väl."},
      {"@type": "HowToStep", "text": "Häll smeten i en smord form och grädda i 175°C i ca 45 minuter."}
    ]
  }
  </script>
</head>
<body>
  <div class="arla-nutrition">
    <h3>Näringsvärde per portion</h3>
    <p>Energi: 185 kcal</p>
    <p>Protein: 8 g</p>
    <p>Fett: 7 g</p>
    <p>Kolhydrater: 22 g</p>
  </div>
</body>
</html>
''';

  /// Recipe without JSON-LD (tests CSS fallback)
  static const String recipeWithoutJsonLd = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Pannkakor - Arla.se</title>
</head>
<body>
  <article class="recipe-content">
    <h1 class="recipe-title">Fluffiga pannkakor</h1>
    <div class="recipe-description">
      Lätta och fluffiga pannkakor som barn älskar.
    </div>
    <div class="recipe-meta">
      <span class="recipe-portions">4 portioner</span>
      <span class="recipe-time">20 minuter</span>
    </div>
    <div class="ingredient-list">
      <ul>
        <li>3 ägg</li>
        <li>6 dl Arla Ko® mellanmjölk</li>
        <li>3 dl vetemjöl</li>
        <li>½ tsk salt</li>
        <li>Smör till stekning</li>
      </ul>
    </div>
    <div class="recipe-instructions">
      <ol>
        <li>Vispa ägg och mjölk.</li>
        <li>Rör ner mjöl och salt till en slät smet.</li>
        <li>Låt smeten vila i 10 minuter.</li>
        <li>Stek tunna pannkakor i smör.</li>
      </ol>
    </div>
    <div class="recipe-image">
      <img src="https://assets.arla.com/image/upload/pannkakor.jpg" alt="Pannkakor">
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
  <title>Kladdkaka - Arla.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Kladdkaka med grädde",
    "recipeIngredient": [
      "200 g smör",
      "3 dl socker"
      // Missing comma - will cause JSON parse error
      "3 ägg"
    ],
  </script>
</head>
<body>
  <h1>Kladdkaka med grädde</h1>
  <div class="ingredient-list">
    <ul>
      <li>200 g smör</li>
      <li>3 dl socker</li>
      <li>3 ägg</li>
      <li>1½ dl vetemjöl</li>
      <li>4 msk kakao</li>
    </ul>
  </div>
  <div class="recipe-steps">
    <ol>
      <li>Smält smöret och blanda med socker.</li>
      <li>Rör ner ägg, mjöl och kakao.</li>
      <li>Grädda i 175°C i ca 15 minuter.</li>
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
  <title>Äppelpaj - Arla.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Äppelpaj med vaniljsås",
    "description": "Klassisk äppelpaj med krämig vaniljsås från Arla.",
    "totalTime": "PT1H",
    "recipeYield": "6 portioner",
    "recipeIngredient": [
      "6 stora äpplen",
      "1 dl socker",
      "2 tsk kanel",
      "100 g smör",
      "2 dl vetemjöl",
      "1 dl havregryn",
      "Arla Köket® vaniljsås"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "Skala och skär äpplena i klyftor."
      },
      {
        "@type": "HowToStep",
        "text": "Blanda äpplen med socker och kanel."
      },
      {
        "@type": "HowToStep",
        "text": "Smula smör, mjöl och havregryn till en deg."
      },
      {
        "@type": "HowToStep",
        "text": "Lägg äpplen i en form och strö smuldeg över."
      },
      {
        "@type": "HowToStep",
        "text": "Grädda i 200°C i ca 30 minuter."
      },
      {
        "@type": "HowToStep",
        "text": "Servera med varm vaniljsås."
      }
    ]
  }
  </script>
</head>
<body>
  <h1>Äppelpaj med vaniljsås</h1>
</body>
</html>
''';

  /// Recipe with minimal data (tests quality scoring)
  static const String recipeMinimalData = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Enkelt recept - Arla.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Yoghurt med müsli",
    "recipeIngredient": [
      "2 dl Arla® yoghurt naturell",
      "1 dl müsli"
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
  <title>Laxpasta - Arla.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Krämig laxpasta med spenat",
    "description": "En snabb och lyxig pastarätt med lax och färsk spenat i gräddesås med Arla Köket®.",
    "image": "https://assets.arla.com/image/upload/laxpasta.jpg",
    "prepTime": "PT10M",
    "cookTime": "PT15M",
    "totalTime": "PT25M",
    "recipeYield": "4 portioner",
    "recipeCategory": "Middag",
    "recipeCuisine": "Italiensk",
    "keywords": "pasta, lax, snabbt, middag, spenat",
    "recipeIngredient": [
      "400 g pasta",
      "300 g laxfilé",
      "3 dl Arla Köket® matlagningsgrädde",
      "100 g färsk spenat",
      "1 vitlöksklyfta",
      "Salt och peppar",
      "Citronskal"
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
        "text": "Blanda pastan med såsen. Smaka av med salt, peppar och citronskal."
      }
    ]
  }
  </script>
</head>
<body>
  <div class="recipe-difficulty">Enkel</div>
  <div class="recipe-tips">Tips: Använd färsk lax för bästa resultat. Fryst lax fungerar också men tina den först.</div>
  <div class="nutrition-info">
    <p>Per portion: 520 kcal, Protein: 28 g, Fett: 18 g, Kolhydrater: 62 g</p>
  </div>
</body>
</html>
''';

  /// Recipe with Arla-specific formatting quirks
  static const String recipeWithArlaQuirks = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Lasagne - Arla.se</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Klassisk lasagne",
    "recipeYield": "ca 6 portioner",
    "recipeIngredient": [
      "ca 500 g nötfärs",
      "cirka 1 burk krossade tomater",
      "1 gul lök, hackad  ",
      "  2 vitlöksklyftor, finhackade",
      "Lasagneplattor  ",
      "5 dl Arla Köket® bechamelsås"
    ],
    "recipeInstructions": [
      {
        "@type": "HowToStep",
        "text": "  Bryn färsen i en stekpanna.  "
      },
      {
        "@type": "HowToStep",
        "text": "Tillsätt lök, vitlök och tomater. Låt koka i 10 minuter.  "
      },
      {
        "@type": "HowToStep",
        "text": "  Varva köttfärssås, lasagneplattor och bechamelsås i en ugnsform."
      },
      {
        "@type": "HowToStep",
        "text": "Gratinera i ugnen på 200°C i 30 minuter.  "
      }
    ]
  }
  </script>
</head>
<body></body>
</html>
''';

  /// Arla.se with the REAL page structure, captured 2026-09-05 from
  /// https://www.arla.se/recept/kassler-i-ugn-med-senap-och-tomat/
  ///
  /// Title, description and instruction prose are PLACEHOLDERS. The DOM
  /// structure, the class names, the JSON-LD envelope and the ingredient
  /// lines are what the live page actually serves. See ADR-0012's superseding
  /// section for why the prose is replaced and the ingredient lines are not.
  ///
  /// Three properties of the live page that no hand-authored fixture had:
  /// - the script tag's type attribute is `application/ld&#x2B;json` — the `+`
  ///   arrives HTML-entity-encoded, so anything matching the attribute before
  ///   character references are resolved finds no structured data at all
  /// - the payload is a four-element ARRAY; the Recipe is the third element
  /// - `recipeInstructions` is a list of `HowToSection`, each holding its
  ///   steps in `itemListElement` — there is no top-level `HowToStep`
  ///
  /// Smaller ones, each its own trap: every duration is `PT00M`,
  /// `recipeYield` is abbreviated ("4 port"), nutrition values use Swedish
  /// decimal commas, and the Recipe node carries both `type` and `@type`.
  ///
  /// The DOM fallback is no easier. Ingredients live in a TABLE — name in a
  /// `<th>`, amount in a `<td>` AFTER it, so reading the row left to right
  /// yields "Kassler 400 g" — and each instruction step's text is repeated
  /// inside a `data-model` attribute as HTML-escaped JSON.
  static const String realStructureKassler = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <title>Platshållarrätt två - Recept | Arla</title>
  <script type="application/ld&#x2B;json">
  [
    {"@context":"https://schema.org/","@type":"Organization","name":"Arla","url":"https://www.arla.se/"},
    {"@context":"https://schema.org/","type":"BreadcrumbList","itemListElement":[{"type":"ListItem","position":1,"name":"Arla","item":"https://www.arla.se/","@type":"ListItem"}],"@type":"BreadcrumbList"},
    {
      "@context":"https://schema.org/",
      "type":"Recipe",
      "name":"Platshållarrätt två",
      "headline":"Platshållarrätt två",
      "description":"Platshållartext för beskrivningen. Den ersätter sajtens egen ingress.",
      "image":"https://images.arla.com/recordid/A1EE0261-46C3-4966-A6573D5236DED194/kassler-i-ugn-med-senap-och-tomat.jpg?width=1300&height=525&mode=crop&format=webp",
      "author":{"type":"Person","name":"Platshållarförfattare","@type":"Person"},
      "publisher":{"type":"Organization","name":"Arla","@type":"Organization"},
      "recipeCategory":"Huvudrätt, Lunch, Middag, Varmrätt",
      "recipeCuisine":"",
      "keywords":"Kassler",
      "recipeYield":"4 port",
      "prepTime":"PT00M",
      "cookTime":"PT00M",
      "totalTime":"PT00M",
      "discussionUrl":"https://www.arla.se/recept/kassler-i-ugn-med-senap-och-tomat/",
      "video":null,
      "nutrition":{
        "type":"NutritionInformation",
        "servingSize":"port",
        "calories":"444 kcal",
        "carbohydrateContent":"50,6 g",
        "fatContent":"13,7 g",
        "fiberContent":"3,2 g",
        "proteinContent":"28,8 g",
        "@type":"NutritionInformation"
      },
      "aggregateRating":{"type":"AggregateRating","ratingValue":"3.3","ratingCount":"148","@type":"AggregateRating"},
      "recipeIngredient":[
        "400 g kassler",
        "150 g Arla® Färskost Naturell",
        "1 msk dijonsenap",
        "1 msk flytande honung",
        "2 tomater",
        "1 dl hackad färsk basilika",
        "3 dl råris",
        "65 g salladsmix"
      ],
      "recipeInstructions":[
        {
          "type":"HowToSection",
          "name":"Första instruktionen",
          "itemListElement":[
            {"type":"HowToStep","text":"Platshållarsteg ett.","url":"https://www.arla.se/recept/kassler-i-ugn-med-senap-och-tomat/#step1-1","@type":"HowToStep"},
            {"type":"HowToStep","text":"Platshållarsteg två.","url":"https://www.arla.se/recept/kassler-i-ugn-med-senap-och-tomat/#step1-2","@type":"HowToStep"},
            {"type":"HowToStep","text":"Platshållarsteg tre.","url":"https://www.arla.se/recept/kassler-i-ugn-med-senap-och-tomat/#step1-3","@type":"HowToStep"},
            {"type":"HowToStep","text":"Platshållarsteg fyra.","url":"https://www.arla.se/recept/kassler-i-ugn-med-senap-och-tomat/#step1-4","@type":"HowToStep"}
          ],
          "@type":"HowToSection"
        }
      ],
      "@type":"Recipe"
    },
    {"@context":"http://schema.org","@type":"ItemList","itemListElement":[{"@type":"ListItem","position":1,"url":"/recept/kasslergratang/"}]}
  ]
  </script>
</head>
<body>
  <div class="c-recipe">
    <div class="c-recipe__hero"><div class="c-recipe__hero-wrap js-recipe-hero-wrap">
      <h1 class="c-recipe__title">Platshållarrätt två</h1>
      <p class="c-recipe__description u-m--0 u-mt--s@mobile">Platshållartext för beskrivningen.</p>
    </div></div>
    <div class="c-recipe__content">
      <div class="c-recipe__ingredients-inner-wrap u-hidden@mobile u-mt--m">
        <div class="c-recipe__ingredients-group">
          <table class="">
            <tbody>
              <tr>
                <th class="u-width-70"><div class="u-flex u-flex-align-center"><span class="">Kassler</span></div></th>
                <td class="u-text-align--right">400 g</td>
              </tr>
              <tr>
                <th class="u-width-70"><div class="u-flex u-flex-align-center"><span class="">Arla&#xAE; F&#xE4;rskost Naturell</span></div></th>
                <td class="u-text-align--right">150 g</td>
              </tr>
              <tr>
                <th class="u-width-70"><div class="u-flex u-flex-align-center"><span class="">dijonsenap</span></div></th>
                <td class="u-text-align--right">1 msk</td>
              </tr>
              <tr>
                <th class="u-width-70"><div class="u-flex u-flex-align-center"><span class="">flytande honung</span></div></th>
                <td class="u-text-align--right">1 msk</td>
              </tr>
              <tr>
                <th class="u-width-70"><div class="u-flex u-flex-align-center"><span class="">tomater</span></div></th>
                <td class="u-text-align--right">2 st</td>
              </tr>
              <tr>
                <th class="u-width-70"><div class="u-flex u-flex-align-center"><span class="">hackad f&#xE4;rsk basilika</span></div></th>
                <td class="u-text-align--right">1 dl</td>
              </tr>
              <tr>
                <th class="u-width-70"><div class="u-flex u-flex-align-center"><span class="">r&#xE5;ris</span></div></th>
                <td class="u-text-align--right">3 dl</td>
              </tr>
              <tr>
                <th class="u-width-70"><div class="u-flex u-flex-align-center"><span class="">salladsmix</span></div></th>
                <td class="u-text-align--right">65 g</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      <div class="c-recipe__how-to">
        <div class="c-recipe__instructions-inner u-flex">
          <p class="c-recipe__instructions-label u-flex u-font-size-h4 u-flex-align-center u-m--0">Första instruktionen</p>
        </div>
        <ol class="u-bare-list c-recipe__instructions-steps-list u-ml--m c-recipe__instructions-steps-multi">
          <li class="c-recipe__instructions-step  u-ml--s">
            <span data-vue="RecipeCookingInstructionCheckbox"
                  data-aria-label="Markera instruktionssteg"
                  data-section-index="0"
                  data-item-index="0"
                  data-model="{&quot;text&quot;:&quot;Platsh&#xE5;llarsteg ett.&quot;}">
              Platshållarsteg ett.
            </span>
          </li>
          <li class="c-recipe__instructions-step  u-ml--s">
            <span data-vue="RecipeCookingInstructionCheckbox"
                  data-aria-label="Markera instruktionssteg"
                  data-section-index="0"
                  data-item-index="1"
                  data-model="{&quot;text&quot;:&quot;Platsh&#xE5;llarsteg tv&#xE5;.&quot;}">
              Platshållarsteg två.
            </span>
          </li>
          <li class="c-recipe__instructions-step  u-ml--s">
            <span data-vue="RecipeCookingInstructionCheckbox"
                  data-aria-label="Markera instruktionssteg"
                  data-section-index="0"
                  data-item-index="2"
                  data-model="{&quot;text&quot;:&quot;Platsh&#xE5;llarsteg tre.&quot;}">
              Platshållarsteg tre.
            </span>
          </li>
          <li class="c-recipe__instructions-step  u-ml--s">
            <span data-vue="RecipeCookingInstructionCheckbox"
                  data-aria-label="Markera instruktionssteg"
                  data-section-index="0"
                  data-item-index="3"
                  data-model="{&quot;text&quot;:&quot;Platsh&#xE5;llarsteg fyra.&quot;}">
              Platshållarsteg fyra.
            </span>
          </li>
        </ol>
      </div>
      <div class="c-recipe__nutrition-values u-mt--s u-mb--m u-ml--xs u-mr--xs">
        <div class="c-recipe__nutrition-values-inner">444 kcal</div>
      </div>
    </div>
  </div>
</body>
</html>
''';
}

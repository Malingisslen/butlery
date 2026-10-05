/// A `recipeInstructions` value mixing sections, steps and strings, and the
/// steps each reader that runs it must make of it (BUT-2026).
library;

const instructionShapesJson = '''
[
  {"@type": "HowToSection", "name": "Förberedelser", "itemListElement": [
    {"@type": "HowToStep", "text": "Sätt ugnen på 200 grader."},
    {"@type": "HowToStep", "name": "Skala potatisen."},
    {"@type": "HowToStep", "name": "Namnet läses inte.", "text": "Koka potatisen."},
    {"@type": "HowToStep", "name": "Mosa potatisen."}
  ]},
  {"@type": "HowToSection", "name": "Tom sektion", "text": "Låt vila en stund."},
  {"@type": "HowToSection", "name": "Rubrik utan innehåll"},
  {"@type": ["HowToSection"], "name": "Rubrik typad som lista"},
  {"@type": "https://schema.org/HowToSection", "name": "Rubrik typad som URL"},
  {"@type": "HowToStep", "name": "Inte heller namnet.", "text": {"@value": "Ingen sträng"}},
  {"@type": "HowToSection", "itemListElement": [
    {"@type": "HowToSection", "name": "Inre", "itemListElement": [
      {"@type": "HowToStep", "text": "Grädda i 30 minuter."}
    ]}
  ]},
  "Servera varm."
]
''';

const instructionShapesSteps = [
  'Sätt ugnen på 200 grader.',
  'Skala potatisen.',
  'Koka potatisen.',
  'Mosa potatisen.',
  'Låt vila en stund.',
  'Grädda i 30 minuter.',
  'Servera varm.',
];

/// A page whose only JSON-LD block is a recipe carrying
/// [instructionShapesJson].
const instructionShapesPage =
    '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Sektionerat recept",
    "description": "Stegen ligger i sektioner.",
    "totalTime": "PT30M",
    "recipeYield": "4 portioner",
    "image": "https://example.test/bild.jpg",
    "recipeIngredient": ["400 g kassler", "1 msk senap", "2 tomater"],
    "recipeInstructions": $instructionShapesJson
  }
  </script>
</head>
<body></body>
</html>
''';

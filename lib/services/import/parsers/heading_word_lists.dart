/// Extracted from `RecipeSectionDetector` (BUT-1714) so the heading heuristic's
/// two vocabularies sit together, off the detector's own line budget (it sits
/// just over 500 with an allowlist entry). Behaviour-preserving for
/// [genericBlockMarkers] — the set is moved verbatim.
library;

class HeadingWordLists {
  const HeadingWordLists._();

  /// Generic ingredient/instruction block markers that are NOT component
  /// groups (checked colon-stripped + lowercased). Mirrors the anchored header
  /// regexes the Swedish line classifier used before it delegated to the
  /// detector, so consolidation stays behaviour-equivalent — e.g. "Metod:" /
  /// "Så gör du:" clear the group instead of becoming one. Kept separate from
  /// `isInstructionHeader` (a loose `contains` check with other callers) to
  /// avoid changing multi-recipe splitting behaviour.
  static const genericBlockMarkers = {
    ...ingredientBlockMarkers,
    ...instructionBlockMarkers,
  };

  /// The [genericBlockMarkers] that open the ingredient block.
  static const ingredientBlockMarkers = {
    'ingrediens',
    'ingredienser',
    'ingredienserna',
    'du behöver',
    'detta behövs',
    'det här behöver du',
  };

  /// The [genericBlockMarkers] that open the instructions.
  static const instructionBlockMarkers = {
    'gör så här',
    'så gör du',
    'instruktion',
    'instruktioner',
    'tillagning',
    'tillagningssätt',
    'tillredning',
    'framställning',
    'steg',
    'metod',
  };

  /// Bare Swedish words that ARE the gluten source, in the exact form a lone
  /// ingredient line uses. Compounds ending in "-mjöl" are covered by the
  /// suffix rule in [isBareGlutenWord] rather than enumerated here.
  ///
  /// Deliberately gluten-only, not all fourteen EU allergens: this is the set
  /// where the "heading" reading is implausible (no Swedish recipe groups its
  /// components under "Råg:") while the miss is a coeliac-relevant one.
  static const bareGlutenWords = {
    'mjöl',
    'vete',
    'matvete',
    'råg',
    'korn',
    'havre',
    'havregryn',
    'vetekli',
    'vetegroddar',
    'dinkel',
    'mannagryn',
    'ströbröd',
    'bulgur',
    'couscous',
    'semolina',
    'malt',
    'öl',
  };

  /// True when [label] is a LONE gluten word — the whole label, not a token
  /// inside a phrase. Multi-word labels ("Till degen") are headings and are
  /// left alone; only a bare word can be the ambiguous quantity-less
  /// ingredient row this guards.
  static bool isBareGlutenWord(String label) {
    final word = label.trim().toLowerCase();
    if (word.isEmpty || word.contains(_whitespace)) return false;
    return bareGlutenWords.contains(word) || word.endsWith('mjöl');
  }

  /// Hoisted: [isBareGlutenWord] runs once per line of every imported recipe,
  /// and again per line per block in MultiRecipeSplitter.
  static final _whitespace = RegExp(r'\s');

  /// Whole-line headings after which a web or magazine page stops being the
  /// recipe (BUT-2455). Whole line only: "Kommentar: koka gärna längre" is the
  /// author's own note, and "Se kommentarer i appen" is a step.
  static const recipeEndHeadings = {
    'kommentarer',
    'kommentar',
    'fler recept',
    'liknande recept',
    'du kanske också gillar',
    'om författaren',
    'lämna en kommentar',
    'skriv en kommentar',
  };

  /// Line openings ("Fler recept från oss", "Prenumerera – 3 nummer för 99 kr").
  static const recipeEndLeads = [
    'fler recept',
    'mer från',
    'prenumerera',
    'du kanske också gillar',
    'visa alla',
    'gillade du',
  ];

  /// Whole-line headings of a box that interrupts the page — it can stand
  /// beside the method in a two-column photo, so the method may continue
  /// after it.
  static const recipeBoxHeadings = {
    'näringsvärde',
    'näringsvärden',
    'näringsinnehåll',
    'visste du att',
  };

  static const recipeBoxLeads = ['visste du att'];

  /// The kind of page text [line] opens, or null when it is recipe text.
  static RecipeTrailerKind? recipeTrailerKind(String line) {
    final lower = line.trim().toLowerCase();
    if (lower.isEmpty) return null;
    final heading = lower
        .replaceFirst(_trailingColon, '')
        .replaceFirst(_trailingParenthetical, '')
        .replaceFirst(_perSuffix, '')
        .trim();
    if (recipeEndHeadings.contains(heading)) return RecipeTrailerKind.end;
    if (recipeBoxHeadings.contains(heading)) return RecipeTrailerKind.box;
    if (recipeEndLeads.any((lead) => _opensWith(lower, lead)) ||
        _commentByline.hasMatch(lower) ||
        _socialBar.hasMatch(lower)) {
      return RecipeTrailerKind.end;
    }
    if (recipeBoxLeads.any((lead) => _opensWith(lower, lead)) ||
        _energyRow.hasMatch(lower) ||
        _nutrientRow.hasMatch(lower)) {
      return RecipeTrailerKind.box;
    }
    return null;
  }

  /// Whole lines of web or magazine page around a recipe — buttons, a
  /// breadcrumb, a rating, an issue number, a cookie banner (BUT-2455).
  /// Whole-line only: "Dela degen i 12 bitar" is a step.
  static bool isPageFurniture(String line) {
    final lower = line.trim().toLowerCase();
    return pageFurniture.contains(lower) ||
        _pageButtonRow.hasMatch(lower) ||
        _shareOn.hasMatch(lower) ||
        _breadcrumb.hasMatch(lower) ||
        _rating.hasMatch(lower) ||
        _published.hasMatch(lower) ||
        _issueNumber.hasMatch(lower) ||
        _cookieBanner.hasMatch(lower);
  }

  static const pageFurniture = {
    'hoppa till recept',
    'hoppa till receptet',
    'skriv ut',
    'skriv ut recept',
    'skriv ut receptet',
    'spara',
    'spara recept',
    'spara receptet',
    'dela',
    'dela receptet',
    'annons',
    'annons:',
    'följ',
    'gilla',
  };

  // "Dela   Spara   Skriv ut", "Spara · Skriv ut".
  static final _pageButtonRow = RegExp(
    r'^(?:dela|spara|skriv ut|följ|gilla)'
    r'(?:\s*[·•|]?\s*(?:dela|spara|skriv ut|följ|gilla))+$',
  );

  static final _shareOn = RegExp(r'^dela på [a-z]+$');

  // "Startsida > Recept > Vegetariskt". No digits: "200 grader > låt stå" is
  // a step.
  static final _breadcrumb = RegExp(
    r'^[^>›»\d]{1,30}(?:\s[>›»]\s[^>›»\d]{1,30})+$',
  );

  static final _rating = RegExp(
    r'^(?:[★☆]+\s*(?:\(\d+\))?'
    r'|\d(?:[,.]\d)?\s*av\s*5(?:\s*\(\d+\s*röst(?:er)?\))?'
    r'|\(?\d+\s*röst(?:er)?\)?)$',
  );

  // "Publicerad 2023-11-02 · Uppdaterad 2024-01-15".
  static final _published = RegExp(r'^(?:publicerad|uppdaterad)\s+\d');

  // "Nummer 4 2024".
  static final _issueNumber = RegExp(r'^nummer\s+\d+(?:\s*[/,]?\s*\d{4})?$');

  static final _cookieBanner = RegExp(
    r'^(?:vi använder (?:cookies|kakor) för att .*|(?:godkänn|acceptera) (?:alla )?(?:cookies|kakor))$',
  );

  static bool _opensWith(String lower, String lead) =>
      lower.startsWith(lead) &&
      (lower.length == lead.length || !_letter.hasMatch(lower[lead.length]));

  static final _letter = RegExp('[a-zåäöé0-9]');
  static final _trailingColon = RegExp(r'\s*:$');
  static final _trailingParenthetical = RegExp(r'\s*\([^)]*\)$');
  static final _perSuffix = RegExp(r'\s+per\s+[a-zåäö0-9 ]+$');

  // "Anna skrev: Supergod!" — a reader's comment under the recipe.
  static final _commentByline = RegExp(
    r'^[a-zåäö][a-zåäö0-9_.\-]*(?: [a-zåäö][a-zåäö\-]*)? skrev:',
  );

  // "Gilla · Kommentera · Dela" — a post's action bar. A lone "Dela" is not
  // one.
  static final _socialBar = RegExp(
    r'^(?:gilla|kommentera|dela|spara|svara)'
    r'(?:\s*[·•|]\s*(?:gilla|kommentera|dela|spara|svara))+$',
  );

  // "Per portion: ca 320 kcal".
  static final _energyRow = RegExp(
    r'^(?:per portion\s*:?\s*)?(?:ca\s*)?\d+(?:[,.]\d+)?\s*(?:kcal|kj)$',
  );

  // "Protein 42 g", "Fett: 18 g", "Protein 6 g, Fett 18 g". Salt and sugar do
  // not OPEN a box — "Socker 100 g" can be an ingredient row written name
  // first — but they continue one, because a box runs until the method does.
  static const _nutrient =
      r'(?:energi|kalorier|protein|kolhydrater|mättat fett|fett|kostfiber|'
      r'fiber)';
  static const _amount =
      r'\s*:?\s*(?:ca\s*)?\d+(?:[,.]\d+)?\s*(?:kcal|kj|g|mg)';
  static final _nutrientRow = RegExp(
    '^$_nutrient$_amount'
    r'(?:\s*,\s*[a-zåäö ]+'
    '$_amount)*\$',
  );
}

/// What a page heading after the recipe means for the lines below it.
enum RecipeTrailerKind {
  /// The recipe is over: comments, related recipes, the author's bio.
  end,

  /// A box beside the recipe (nutrition, a fact box): the method may resume.
  box,
}

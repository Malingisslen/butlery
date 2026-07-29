/// Curated word lists that decide whether a colon-terminated line is a
/// component heading or an ingredient.
///
/// Extracted from `RecipeSectionDetector` (BUT-1714) so the heading heuristic's
/// two vocabularies sit together, off the detector's own line budget (it sits
/// just over 500 with an allowlist entry). Behaviour-preserving for
/// [genericBlockMarkers] — the set is moved verbatim.
library;

/// The vocabularies `RecipeSectionDetector.componentSubHeadingLabel` consults.
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
    'ingrediens',
    'ingredienser',
    'ingredienserna',
    'du behöver',
    'detta behövs',
    'det här behöver du',
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
  /// components under "Råg:") while the miss is a coeliac-relevant one. Dairy,
  /// egg and nut words keep the colon-wins contract for now — widening the set
  /// is a separate, evidenced decision, not a sprint-time reflex.
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
}

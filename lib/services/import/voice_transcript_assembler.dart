/// Assembles guided voice-dictation transcripts (title / ingredients /
/// steps — each section is a separate recording, so the split is KNOWN,
/// never guessed) into the canonical Swedish recipe-text shape that
/// [TextImportStrategy]'s rule-based parser is built for. Doing this here
/// is the cost lever of voice import: a well-shaped text parses on the
/// free deterministic tier instead of escalating to the paid LLM.
///
/// Pure functions, zero IO.
library;

/// Boundaries that separate spoken ingredient enumerations:
/// "två deciliter mjölk, tre ägg och en gul lök" → three lines. Split on
/// commas and standalone connectives; quantities/units stay untouched —
/// normalizing "två deciliter" → "2 dl" is the CRF/NER parser's job.
/// The comma alternative refuses digit,digit adjacency: Whisper renders
/// "en och en halv deciliter" as "1,5 dl" (Swedish decimal comma), and
/// splitting inside the number corrupts amounts (review finding #2 —
/// "1,5 dl mjölk" must never become the lines "1" + "5 dl mjölk").
final RegExp _ingredientBoundaryRe = RegExp(
  r'\s*,(?!(?<=\d,)\d)\s*(?:och\s+|samt\s+)?|\s+(?:och|samt)\s+(?=\d|en\s|ett\s|två\s|tre\s|fyra\s|fem\s|sex\s|sju\s|åtta\s|nio\s|tio\s|några\s|lite\s|(?:en\s|ett\s)?(?:halv|kvarts))',
);

/// Sentence boundaries for spoken instructions. Whisper punctuates
/// reliably; each sentence becomes an instruction line so the review
/// screen shows editable steps instead of one text wall.
final RegExp _sentenceSplitRe = RegExp(r'(?<=[.!?])\s+');

/// Splits a spoken ingredient enumeration into one-ingredient-per-line
/// text. Conservative on purpose: only splits where a boundary is followed
/// by a quantity-like token, so "salt och peppar" stays one line while
/// "tre ägg och en gul lök" splits.
List<String> splitSpokenIngredients(String transcript) {
  final cleaned = transcript.trim();
  if (cleaned.isEmpty) return const [];

  // If the speaker (or Whisper) already produced line breaks, trust them.
  if (cleaned.contains('\n')) {
    return [
      for (final line in cleaned.split('\n'))
        if (line.trim().isNotEmpty) _stripTerminalPunctuation(line.trim()),
    ];
  }

  return [
    for (final part in cleaned.split(_ingredientBoundaryRe))
      if (part.trim().isNotEmpty) _stripTerminalPunctuation(part.trim()),
  ];
}

/// Splits spoken instructions into sentence-per-line steps.
List<String> splitSpokenSteps(String transcript) {
  final cleaned = transcript.trim();
  if (cleaned.isEmpty) return const [];
  return [
    for (final s in cleaned.split(_sentenceSplitRe))
      if (s.trim().isNotEmpty) s.trim(),
  ];
}

/// Assembles the three guided-section transcripts into canonical Swedish
/// recipe text ("Ingredienser:" / "Gör så här:" headers — the exact shape
/// the rule-based text parser recognizes without LLM help).
String assembleRecipeText({
  required String title,
  required String ingredientsTranscript,
  required String stepsTranscript,
}) {
  final cleanTitle = _stripTerminalPunctuation(title.trim());
  final ingredients = splitSpokenIngredients(ingredientsTranscript);
  final steps = splitSpokenSteps(stepsTranscript);

  final buffer = StringBuffer()
    ..writeln(cleanTitle)
    ..writeln()
    ..writeln('Ingredienser:');
  for (final line in ingredients) {
    buffer.writeln(line);
  }
  buffer
    ..writeln()
    ..writeln('Gör så här:');
  for (final step in steps) {
    buffer.writeln(step);
  }
  return buffer.toString().trim();
}

String _stripTerminalPunctuation(String s) =>
    s.replaceAll(RegExp(r'[.!?]+$'), '').trim();

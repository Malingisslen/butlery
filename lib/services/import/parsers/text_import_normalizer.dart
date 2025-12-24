/// Text Import Normalizer - Text preprocessing utilities for recipe import.
/// Extracted from text_import_strategy.dart for better organization.

/// Provides text normalization, decimal protection, sentence splitting,
/// and social media cleanup for recipe text parsing.
class TextImportNormalizer {
  // Temporary marker for protected decimals (Unicode BLACK CIRCLE)
  static const _decimalMarker = '⬤';

  /// Protect decimal numbers from being corrupted by sentence splitting.
  /// Example: "0.75 dl" → "0⬤75 dl" (protected)
  static String protectDecimals(String text) {
    return text.replaceAllMapped(
      RegExp(r'(\d)\.(\d)'),
      (m) => '${m.group(1)}$_decimalMarker${m.group(2)}',
    );
  }

  /// Restore protected decimals back to normal.
  /// Example: "0⬤75 dl" → "0.75 dl"
  static String restoreDecimals(String text) {
    return text.replaceAll(_decimalMarker, '.');
  }

  /// Smart sentence splitting that respects decimals and Swedish patterns.
  /// Splits at periods ONLY when followed by sentence boundaries.
  static String smartSentenceSplit(String text) {
    // Step 1: Protect decimals FIRST
    String result = protectDecimals(text);

    // Step 2: Also protect common abbreviations
    result = result.replaceAll('ca.', 'ca⬛');
    result = result.replaceAll('ev.', 'ev⬛');
    result = result.replaceAll('st.', 'st⬛');
    result = result.replaceAll('t.ex.', 't⬛ex⬛');

    // Step 3: Split at period + space + capital letter (new sentence)
    result = result.replaceAllMapped(
      RegExp(r'\.(\s*)([A-ZÅÄÖ])'),
      (m) => '.\n${m.group(2)}',
    );

    // Step 4: Split at period followed immediately by Swedish action verbs
    // These indicate a new instruction is starting
    const actionWords =
        'stek|koka|blanda|rör|häll|lägg|skär|servera|värm|vispa|grädda|fräs|'
        'sjud|tillsätt|smaksätt|strö|vänd|ta|låt|förvärm|sätt|börja|gör|ställ|'
        'skala|hacka|riv|strimla|marinera|krydda|toppa|garnera';
    result = result.replaceAllMapped(
      RegExp('\\.($actionWords)', caseSensitive: false),
      (m) => '.\n${m.group(1)}',
    );

    // Step 5: Restore protected abbreviations
    result = result.replaceAll('ca⬛', 'ca.');
    result = result.replaceAll('ev⬛', 'ev.');
    result = result.replaceAll('st⬛', 'st.');
    result = result.replaceAll('t⬛ex⬛', 't.ex.');

    // Step 6: Restore decimals
    result = restoreDecimals(result);

    return result;
  }

  /// Split concatenated ingredient text that lacks line breaks.
  /// Common in Instagram captions where ingredients run together.
  /// Example: "oystersås2 msk japansk soya1 msk" → "oystersås\n2 msk japansk soya\n1 msk"
  static String splitConcatenatedIngredients(String text) {
    // CRITICAL: Protect decimals before ANY regex processing
    String result = protectDecimals(text);

    // Pattern 1: Split before measurements when preceded by word characters
    // Match: letters followed directly by digit + measurement unit
    // Example: "oystersås2 msk" → "oystersås\n2 msk"
    result = result.replaceAllMapped(
      RegExp(
        '([a-zåäöA-ZÅÄÖ]{2,})(\\d+(?:[⬤,]\\d+)?\\s*(?:dl|cl|ml|msk|tsk|krm|g|kg|hg|st|burk|pkt|påse|bit|skiva|klyfta|klyft)\\b)',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}\n${m.group(2)}',
    );

    // Pattern 2: Split before Swedish recipe section headers
    result = result.replaceAllMapped(
      RegExp(
        r'([a-zåäö])(sås|såsen|biffen|övrigt|marinaden|gräddsåsen|till servering|kycklingen|fisken|köttet|grönsakerna|woka ihop|servera)',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}\n${m.group(2)}\n',
    );

    // Pattern 3: Split before "X portioner" patterns mid-text
    result = result.replaceAllMapped(
      RegExp(r'([a-zåäö]{2,})\s*(\d+\s*portioner?\b)', caseSensitive: false),
      (m) => '${m.group(1)}\n${m.group(2)}',
    );

    // Pattern 3b: Split AFTER "X portioner" when followed by uppercase (section header)
    result = result.replaceAllMapped(
      RegExp(r'(\d+\s*portioner?)\s*([A-ZÅÄÖ])', caseSensitive: false),
      (m) => '${m.group(1)}\n${m.group(2)}',
    );

    // Pattern 4: Split when a digit+unit is immediately followed by another digit
    result = result.replaceAllMapped(
      RegExp(
        r'(\d+\s*(?:dl|cl|ml|msk|tsk|krm|g|kg|hg|st|burk|pkt)\s+[a-zåäöA-ZÅÄÖ]+)(\d+\s*(?:dl|cl|ml|msk|tsk|krm|g|kg|hg|st|burk|pkt)\b)',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}\n${m.group(2)}',
    );

    // Pattern 5: Split ALL CAPS section header from following content
    result = result.replaceAllMapped(
      RegExp(r'([A-ZÅÄÖ]{2,15}(?:\s+[A-ZÅÄÖ]+)?)([A-ZÅÄÖ])([a-zåäö])'),
      (m) => '${m.group(1)}\n${m.group(2)}${m.group(3)}',
    );

    // Restore decimals at the end
    result = restoreDecimals(result);

    return result;
  }

  /// Clean up common social media formatting issues
  static String cleanSocialMediaFormatting(String text) {
    String processed = text;

    // Remove emoji separators but keep recipe emojis
    processed = processed.replaceAll(RegExp(r'[🔥💥✨🌟⭐]+'), '');

    // Clean up excessive punctuation
    processed = processed.replaceAll(RegExp(r'[!]{2,}'), '!');
    processed = processed.replaceAll(RegExp(r'[.]{3,}'), '...');

    // Remove hashtags but keep the content
    processed = processed.replaceAll(RegExp(r'#\w+'), '');

    // Clean up multiple spaces
    processed = processed.replaceAll(RegExp(r' {2,}'), ' ');

    // Remove Instagram/Facebook line separators
    processed =
        processed.replaceAll(RegExp(r'^[-_=]{3,}$', multiLine: true), '');

    return processed;
  }

  /// Main preprocessing entry point.
  /// Combines all normalization steps for recipe text.
  static String preprocessText(String input) {
    String processed = input;

    // Stage 1: Smart sentence splitting with decimal protection
    processed = smartSentenceSplit(processed);

    // Stage 2: Split concatenated ingredients (handles Instagram text without line breaks)
    processed = splitConcatenatedIngredients(processed);

    // Clean up social media formatting
    processed = cleanSocialMediaFormatting(processed);

    // Add line breaks after common ingredient headers
    processed = processed.replaceAllMapped(
      RegExp(
        r'(behöver är|ingredienser|du behöver|ingredients|what you need|shopping list)',
        caseSensitive: false,
      ),
      (match) => '${match.group(0)}\n',
    );

    // Normalize instruction header variants before adding line breaks
    processed = processed.replaceAll(
      RegExp(r'gör\s*så\s*här', caseSensitive: false),
      'gör så här',
    );

    // Add line breaks after instruction headers
    processed = processed.replaceAllMapped(
      RegExp(
        r'(gör så här|gör såhär|instruktion|tillredning|tillagning|steg|instructions|method|directions|preparation)',
        caseSensitive: false,
      ),
      (match) => '${match.group(0)}\n',
    );

    // Add line breaks before common instruction words
    processed = processed.replaceAllMapped(
      RegExp(
        r'(Börja med|Sätt ugnen|Koka|Stek|Blanda|Häll|Lägg|Skär|Servera|Värm|Rör|Start by|Preheat|Cook|Fry|Mix|Pour|Add|Cut|Serve|Heat|Stir)',
        caseSensitive: false,
      ),
      (match) => '\n${match.group(0)}',
    );

    // Fix measurement formatting (e.g., "2dl" -> "2 dl")
    processed = processed.replaceAllMapped(
      RegExp(r'(\d+(?:[,\.]\d+)?)(dl|cl|ml|kg|g|msk|tsk|st|krm)'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    // Normalize line breaks
    processed = processed.replaceAll(RegExp(r'\n+'), '\n');

    return processed.trim();
  }
}

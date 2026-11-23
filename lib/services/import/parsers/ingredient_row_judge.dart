/// Decides from a line's own shape whether it is an ingredient row, a piece of
/// the method, or debris. A cookbook photo reads a narrow ingredient column
/// beside the method text line by line, so a line's position says nothing about
/// what it is; its form does.
library;

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/shopping/ingredient_categorizer.dart';

enum RowVerdict { ingredient, step, noise, undecided }

abstract final class IngredientRowJudge {
  static const _unitAlternatives =
      'kg|hg|dl|di|d/|cl|ml|liter|kilo|l|g|msk|tsk|krm|st|kopp|koppar|burk|'
      'burkar|pkt|paket|påse|påsar|nypa|nypor|knippe|knippa|klyfta|klyftor|'
      'skiva|skivor|bit|bitar|kvist|kvistar|tärning|tärningar|flaska|förp|port';

  static final _unitWord = RegExp('^(?:$_unitAlternatives)\$');

  static const _number =
      r'(?:\d+(?:[.,]\d+)?(?:\s*[–-]\s*\d+(?:[.,]\d+)?)?(?:\s+\d\s*/\s*\d)?|'
      r'\d+\s*/\s*\d+|[½¼¾⅓⅔⅛])';

  static final _amount = RegExp('^(?:ca\\.?\\s*)?$_number');

  static final _amountThenUnit = RegExp(
    '^(?:ca\\.?\\s*)?$_number\\s*(?:\\d\\s*/\\s*\\d\\s*)?'
    '(?:$_unitAlternatives)(?![a-zåäö])',
  );

  // "saft av ½ citron", "finrivet skal och saft av 1 citron".
  static final _zestRow = RegExp(
    r'^(?:[a-zåäö]+\s+){0,3}(?:skal|skalet|saft|saften|skalremsor)'
    r'(?:\s+(?:och|eller|av)\s+[a-zåäö]+)?\s+av\s+(?:ca\s+)?'
    r'(?:\d|[½¼¾?])',
    caseSensitive: false,
  );

  static final _timeOrTemperature = RegExp(
    r'^\d+(?:[.,]\d+)?\s*(?:°|grad|grader|graders|min\w*|minut|minuter|minuterna|sek|sekunder|tim|timm|'
    r'timme|timmar|dygn|dag|dagar|cm|mm|liter\s+vatten)(?![a-zåäö])',
    caseSensitive: false,
  );

  static final _imperativeOpening = RegExp(
    r'^(?:stek|koka|blanda|rör|häll|lägg|skär|servera|värm|vispa|grädda|fräs|'
    r'sjud|tillsätt|smaksätt|strö|vänd|ta|låt|förvärm|sätt|börja|gör|ställ|'
    r'skala|hacka|riv|strimla|marinera|krydda|toppa|garnera|pressa|skölj|'
    r'dela|mixa|pensla|forma|baka|rosta|grilla|fyll|kavla|hetta|skiva|tärna|'
    r'bryn|smaka|mät|arbeta|kärna|rensa|bryt|smula|fördela|mosa|passera|sila|'
    r'tryck|ansa|sänk|lyft|fortsätt|sprid|kör|ringla|skumma|täck|dra|skjut|'
    r'stäng|öppna|tillaga|lös|smörj|bred|klä|rita|doppa|pudra|svep|'
    r'stoppa|trä|rulla|platta|kasta|salta|peppra|späd|reducera|avglasera|'
    r'dekorera|flytta|vänta|förbered|plocka|vik|knåda|jäs|sticka|ös|nyp|'
    r'kyl|frys|tina|placera)'
    r'(?=[\s,.;:])',
    caseSensitive: false,
  );

  // A verb in the middle of the line: only prose carries one.
  static final _innerVerb = RegExp(
    r'(?:^|\s)(?:är|blir|ska|kan|får|måste|bör|kommer|finns|tar|passar|'
    r'behöver|räcker|smakar|låter|gör|rör|lägg|häll|blanda|stek|koka|vänd|'
    r'tillsätt|hacka|skär|vispa|låt|sedan|tills|därefter|samtidigt|medan|'
    r'när|annars|gärna|brukar|räkna|använd|använder|vill)(?=[\s,.;:]|$)',
    caseSensitive: false,
  );

  // Foods and allergen carriers the shopping-aisle rules do not name: herbs,
  // spices, grains, nuts, seeds and the allergen groups. A bare row naming one
  // is kept, because dropping it also drops the allergen it carries.
  static final _foodWord = RegExp(
    'persilja|kärn|fling|dill|gräslök|kanel|ättika|vinäger|sesam|koriander|basilika|'
    'timjan|rosmarin|oregano|krydd|farin|bovete|puff|choklad|kakao|vanilj|'
    'honung|sirap|senap|ketchup|soja|vatten|buljong|fond|nöt|mandel|frö|'
    'kokos|konjak|likör|vin\\b|vete|råg|korn|havre|dinkel|gryn|couscous|'
    'bulgur|selleri|lupin|räk|mussl|kräft|skaldjur|fisk|sill|lax|torsk|'
    'sardell|ansjovis|gelatin|jäst|bakpulver|stärkelse|maizena|arrowrot|tofu|'
    'rädis|ingefära|wasabi|fänkål|rödbet|palsternack|kålrot|purjo|squash|'
    'aubergine|avokado|majs|linser|kikärt|nori|mirin|harissa|curry|chili|'
    'spenat|ruccola|mynta|salvia|kardemumma|muskot|kummin|saffran|vitlök|'
    'tahini|pesto|hummus|tamari|tempeh|seitan|quorn|edamame|miso',
  );

  static final _bulletPrefix = RegExp(r'^[•\-\*·]+\s*');
  static final _whitespace = RegExp(r'\s+');
  static final _letter = RegExp(r'[A-Za-zÅÄÖåäöÉéü]');
  static final _debrisChars = RegExp(r'[{}|\[\]§=<>]');
  static final _anyAmount = RegExp(r'\d|[½¼¾⅓⅔⅛]');
  static final _amountAndOneLetter = RegExp(r'^\S+ [A-Za-zåäö]$');

  /// What [line] is on its own form, whatever block the page put it in.
  /// [RowVerdict.undecided] means no rule here speaks: the caller's own rules
  /// apply.
  static RowVerdict judge(String line) {
    final text = _unwrap(line);
    if (text.isEmpty) return RowVerdict.undecided;
    final words = text.split(_whitespace);
    final letters = _letter.allMatches(text).length;
    final hasAmount = _amount.hasMatch(text);

    if (letters <= 2 && !hasAmount) return RowVerdict.noise;
    // "1 r", "2 n", "1 t": an amount and one stray letter.
    if (hasAmount && _amountAndOneLetter.hasMatch(text)) {
      return RowVerdict.noise;
    }
    final unitRow = _hasAmountAndUnit(text, words);
    if (_debrisChars.hasMatch(text) && !unitRow && !_anyAmount.hasMatch(text)) {
      return RowVerdict.noise;
    }

    final opensImperative = _imperativeOpening.hasMatch(text);
    final endsSentence = text.endsWith('.') || text.endsWith('!');

    if (hasAmount && _timeOrTemperature.hasMatch(text)) return RowVerdict.step;

    if (unitRow &&
        words.length <= 9 &&
        !opensImperative &&
        !(endsSentence && (words.length > 8 || _innerVerb.hasMatch(text)))) {
      return RowVerdict.ingredient;
    }
    if (_zestRow.hasMatch(text) &&
        words.length <= 9 &&
        !opensImperative &&
        !endsSentence) {
      return RowVerdict.ingredient;
    }
    if (opensImperative && words.length >= 3) return RowVerdict.step;
    if (endsSentence && words.length >= 4) return RowVerdict.step;
    if (!hasAmount) {
      if (words.length >= 7) return RowVerdict.step;
      if (words.length >= 4 && _innerVerb.hasMatch(text)) {
        return RowVerdict.step;
      }
      if (words.length >= 3 && text.endsWith(',')) return RowVerdict.step;
      if (words.length >= 2 && text.endsWith('-')) return RowVerdict.step;
    }
    return RowVerdict.undecided;
  }

  /// Whether a row with no amount can stay in the ingredient list: a short
  /// phrase with no verb in it ("salt", "smör till formen", "färska blåbär").
  static bool isPlausibleBareRow(String line) {
    final text = _unwrap(line);
    if (text.isEmpty) return false;
    // An amount anywhere ("crème fraiche, 2 dl") makes it a measured row.
    if (_anyAmount.hasMatch(text)) return true;
    final words = text.split(_whitespace);
    if (words.length > 5 || text.endsWith('.')) return false;
    final withoutOptional = text.replaceFirst(
      RegExp(r'^gärna\s+', caseSensitive: false),
      '',
    );
    if (_innerVerb.hasMatch(withoutOptional) ||
        _imperativeOpening.hasMatch(withoutOptional)) {
      return false;
    }
    if (_letter.allMatches(text).length < 3) return false;
    // A row that names no food at all is a word the reader cut loose.
    final lower = text.toLowerCase();
    return _foodWord.hasMatch(lower) ||
        IngredientCategorizer.categorize(lower) != ShoppingCategory.other;
  }

  // A unit right after the amount, or after what the reader made of it: OCR
  // turns "1" into "i", "z" or "%", and sometimes drops it.
  static bool _hasAmountAndUnit(String text, List<String> words) {
    if (_amountThenUnit.hasMatch(text)) return true;
    for (var i = 0; i < words.length && i < 2; i++) {
      final word = words[i].toLowerCase().replaceAll(RegExp(r'[,.]$'), '');
      if (!_unitWord.hasMatch(word)) {
        if (!_garbledAmount(words[i])) return false;
        continue;
      }
      if (i == 0) return false;
      return true;
    }
    return false;
  }

  /// Two rows that each state an amount and state different ones are two
  /// rows ("2 dl vetemjöl" in the dough, "4 dl vetemjöl" in the cream), not
  /// a row and its repeat.
  static bool differentAmounts(String a, String b) {
    final first = _leadingAmountText(a);
    final second = _leadingAmountText(b);
    return first.isNotEmpty && second.isNotEmpty && first != second;
  }

  static String _leadingAmountText(String row) {
    final m = RegExp(
      '^(?:ca\\.?\\s*)?($_number\\s*(?:$_unitAlternatives)?)(?![a-zåäö])',
      caseSensitive: false,
    ).firstMatch(_unwrap(row));
    return m == null
        ? ''
        : m.group(1)!.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  static String _unwrap(String line) {
    final text = line.trim().replaceFirst(_bulletPrefix, '');
    if (text.startsWith('(') && text.endsWith(')')) {
      return text.substring(1, text.length - 1).trim();
    }
    return text;
  }

  static bool _garbledAmount(String word) => _garbled.hasMatch(word);

  static final _garbled = RegExp(r'^(?:[iIlL|aAzZ%}¿≥]|\d[%}¿])$');
}

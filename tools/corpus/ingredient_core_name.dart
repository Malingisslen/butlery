/// What an ingredient IS, apart from how it is prepared or what may replace it.
///
/// The facit writes preparation and alternatives into the name, and not in one
/// fixed place: "rumsvarmt smör", "valnötter, grovt hackade", "smör eller
/// margarin". The app keeps them out of the name, because the name is what the
/// shopping list merges on and what the ingredient and nutrition lookups match.
/// Scoring names on their core keeps the yardstick from rewarding a parser that
/// copies the facit's wording into the name; whether the preparation and the
/// alternative came along is scored separately (`ingredientDetailTokens`).
library;

import 'corpus_metrics.dart';

/// Owned by the yardstick on purpose. Reusing the parser's own word list would
/// let a change to that list move the score without the parser reading better.
/// Colour, size and kind ("gul lök", "stor", "fast") stay in the core: they name
/// a different product, not a different preparation.
const preparationWords = {
  'avrunna',
  'avrunnen',
  'avrunnet',
  'bakad',
  'bakade',
  'bakat',
  'blancherad',
  'blancherade',
  'blancherat',
  'delad',
  'delade',
  'finhackad',
  'finhackade',
  'finhackat',
  'finriven',
  'finrivet',
  'finrivna',
  'finstrimlad',
  'finstrimlade',
  'grillad',
  'grillade',
  'grillat',
  'grovhackad',
  'grovhackade',
  'grovhackat',
  'grovriven',
  'grovrivet',
  'grovrivna',
  'hackad',
  'hackade',
  'hackat',
  'halverad',
  'halverade',
  'halverat',
  'krossad',
  'krossade',
  'krossat',
  'ljummen',
  'ljummet',
  'ljumna',
  'mjuk',
  'mjuka',
  'mjukt',
  'mosad',
  'mosade',
  'mosat',
  'nyriven',
  'nyrivet',
  'nyrivna',
  'pressad',
  'pressade',
  'pressat',
  'riven',
  'rivet',
  'rivna',
  'rostad',
  'rostade',
  'rostat',
  'rumstempererad',
  'rumstempererade',
  'rumstempererat',
  'rumsvarm',
  'rumsvarma',
  'rumsvarmt',
  'skalad',
  'skalade',
  'skalat',
  'skivad',
  'skivade',
  'skivat',
  'skuren',
  'skuret',
  'skurna',
  'smulad',
  'smulade',
  'smulat',
  'smält',
  'smälta',
  'stekt',
  'stekta',
  'strimlad',
  'strimlade',
  'strimlat',
  'tinad',
  'tinade',
  'tinat',
  'tärnad',
  'tärnade',
  'tärnat',
  'upphackad',
  'upphackade',
  'upphackat',
  'urkärnad',
  'urkärnade',
  'urkärnat',
  'gärna',
  'eventuellt',
};

/// Words that are a preparation after a comma ("potatis, kokt") and part of the
/// product before the name ("kokt skinka", "frysta bär", "varm choklad").
const _preparationAfterComma = {
  'fryst',
  'frysta',
  'kall',
  'kalla',
  'kallt',
  'kokt',
  'kokta',
  'varm',
  'varma',
  'varmt',
};

/// "Fint hackad" is a preparation, "fint salt" a product.
const _preparationAdverbs = {'fint', 'grovt', 'tunt'};

const _alternativeMarkers = {'eller', 'alternativt'};

bool _isPreparationOnly(String segment) {
  final tokens = normalizeText(segment).split(' ').where((t) => t.isNotEmpty);
  return tokens.isNotEmpty &&
      tokens.every(
        (t) =>
            preparationWords.contains(t) ||
            _preparationAfterComma.contains(t) ||
            _preparationAdverbs.contains(t),
      );
}

/// "Valnötter, grovt hackade" → "valnötter"; "smör eller margarin" → "smör";
/// "fint hackad gul lök" → "gul lök". Falls back to the whole normalized name
/// when nothing would be left, so two different all-preparation names never
/// collapse into the same empty key.
String ingredientCoreName(String name) {
  final withoutAsides = name.replaceAll(RegExp(r'\([^)]*\)'), ' ');
  final segments = withoutAsides
      .split(',')
      .where((s) => !_isPreparationOnly(s))
      .join(' ');

  final tokens = normalizeText(segments).split(' ');
  final cut = tokens.indexWhere(_alternativeMarkers.contains);
  final head = (cut < 0 ? tokens : tokens.sublist(0, cut))
      .where((t) => t.isNotEmpty)
      .toList();
  final kept = <String>[
    for (var i = 0; i < head.length; i++)
      if (!preparationWords.contains(head[i]) &&
          !(_preparationAdverbs.contains(head[i]) &&
              i + 1 < head.length &&
              preparationWords.contains(head[i + 1])))
        head[i],
  ];
  // "salt och/eller peppar" leaves a dangling "och" once the alternative is cut.
  while (kept.isNotEmpty && kept.last == 'och') {
    kept.removeLast();
  }
  return kept.isEmpty ? normalizeText(name) : kept.join(' ');
}

/// The words of [fullText] that are not part of the core of [name]: the
/// preparation, the alternative, the size and any other aside.
List<String> ingredientDetailTokens(String name, String fullText) {
  final core = <String, int>{};
  for (final t in tokenize(ingredientCoreName(name))) {
    core[t] = (core[t] ?? 0) + 1;
  }
  final out = <String>[];
  for (final t in tokenize(fullText)) {
    final c = core[t] ?? 0;
    if (c > 0) {
      core[t] = c - 1;
    } else {
      out.add(t);
    }
  }
  return out;
}

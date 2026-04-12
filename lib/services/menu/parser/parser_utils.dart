/// Shared low-level helpers for the parser sub-modules.
library;

import 'package:butlery/services/menu/parser/text_normalizer.dart';

int skipSpaces(String s, int from) {
  int i = from;
  while (i < s.length && s[i] == ' ') {
    i++;
  }
  return i;
}

String? readWord(String s, int from) {
  final m = _wordRe.firstMatch(s.substring(from));
  return m?.group(0);
}

bool isWordChar(int code) {
  return (code >= 97 && code <= 122) ||
      (code >= 65 && code <= 90) ||
      (code >= 48 && code <= 57) ||
      code == 0xE5 ||
      code == 0xE4 ||
      code == 0xF6;
}

/// Exact → diacritic-stripped → Levenshtein ≤1 fallback lookup.
String? lexiconLookup(String token, Map<String, String> map) {
  final exact = map[token];
  if (exact != null) return exact;
  final stripped = stripDiacritics(token);
  if (stripped != token) {
    final s = map[stripped];
    if (s != null) return s;
  }
  return levenshtein1Lookup(token, map);
}

final _wordRe = RegExp(r'^[a-zåäö]+');

// BUT-2372: one word per thing in the strings. design/ordlista.json lists the
// words and characters the Swedish text does not use; this test holds every
// value in lib/l10n/app_sv.arb to it, so a new string cannot bring them back.
// The English text (British spelling, "we" as the service voice) has its own
// rules in _englishRules below, and both languages are held to the same
// typography and plural rules.
// _residue names the keys that still break a rule because another track owns
// them; a key leaves the residue in the change that fixes it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _residue = <String, Set<String>>{};

const _letters = 'A-Za-zÅÄÖåäöÉé';

class _Rule {
  _Rule(this.name, this.pattern, {this.exceptions = const []});

  final String name;
  final RegExp pattern;
  final List<String> exceptions;

  bool breaks(String value) {
    var text = value.toLowerCase();
    for (final phrase in exceptions) {
      text = text.replaceAll(phrase.toLowerCase(), ' ');
    }
    return pattern.hasMatch(text);
  }
}

List<_Rule> _rules() {
  final glossary =
      jsonDecode(File('design/ordlista.json').readAsStringSync())
          as Map<String, dynamic>;
  return [
    for (final entry in glossary['ord'] as List)
      for (final word in (entry as Map<String, dynamic>)['aldrig'] as List)
        _Rule(
          word as String,
          // Dart's \b only knows ASCII, so word edges are explicit lookarounds.
          RegExp(
            '(?<![$_letters])${RegExp.escape(word.toLowerCase())}(?![$_letters])',
          ),
          exceptions: [...?(entry['undantag'] as List?)?.cast<String>()],
        ),
    for (final sign in glossary['tecken'] as List)
      _Rule(
        (sign as Map<String, dynamic>)['aldrig'] as String,
        RegExp(RegExp.escape(sign['aldrig'] as String)),
      ),
  ];
}

Map<String, String> _swedishValues() {
  final arb =
      jsonDecode(File('lib/l10n/app_sv.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final e in arb.entries)
      if (!e.key.startsWith('@') && e.value is String) e.key: e.value as String,
  };
}

void main() {
  final rules = _rules();
  final values = _swedishValues();

  Set<String> broken(String value) => {
    for (final rule in rules)
      if (rule.breaks(value)) rule.name,
  };

  test('the glossary reads as rules', () {
    expect(rules.map((r) => r.name), containsAll(['artikel', '...', '"']));
  });

  test('every rule catches the word it names and spares its exceptions', () {
    expect(broken('Ta bort artikel'), {'artikel'});
    expect(broken('Tom handlingslista'), {'handlingslista'});
    expect(broken('Matsedel & inköp'), {'matsedel'});
    expect(broken('Laddar...'), {'...'});
    expect(broken('Till "listan"'), {'"'});
    expect(broken('Försök igen imorgon'), {'imorgon'});
    expect(broken('Denna sida verkar vara en nyhetsartikel'), isEmpty);
    expect(broken('Enligt GDPR Artikel 20 har du rätt'), isEmpty);
    expect(broken('Laddar …'), isEmpty);
  });

  test('no Swedish string uses a word or character the glossary rules out', () {
    final offenders = [
      for (final e in values.entries)
        for (final name in broken(e.value))
          if (!(_residue[e.key]?.contains(name) ?? false))
            '${e.key}: "$name" in "${e.value}"',
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'Write it the way design/ordlista.json says.',
    );
  });

  test('the residue only shrinks: every row still breaks its rule', () {
    final stale = [
      for (final e in _residue.entries)
        for (final name in e.value)
          if (!broken(values[e.key] ?? '').contains(name))
            '${e.key} no longer has "$name". Remove it from _residue.',
    ];
    expect(stale, isEmpty);
  });

  group('English text', () {
    final english = _values('lib/l10n/app_en.arb');

    // `{slot}` is a placeholder name, not English text.
    Set<String> brokenEn(String value) => {
      for (final rule in _englishRules)
        if (rule.breaks(value.replaceAll(RegExp(r'\{\w+\}'), ' '))) rule.name,
    };

    test(
      'every English rule catches what it names and spares what it should',
      () {
        expect(brokenEn('Loading...'), {'...'});
        expect(brokenEn('Say "hello"'), {'"'});
        expect(brokenEn('Wait — then go'), {'—'});
        expect(brokenEn('Please analyze the favorite color'), {
          'analyze',
          'favorite',
          'color',
        });
        expect(brokenEn('Pick a slot'), {'slot'});
        expect(brokenEn('Log in with e-mail'), {'log in', 'e-mail'});
        expect(brokenEn('Add friend(s)'), {'(s)'});
        expect(brokenEn('Say “hello” – then go …'), isEmpty);
        expect(brokenEn('Already logged today'), isEmpty);
      },
    );

    test('no English string breaks the English rules', () {
      final offenders = [
        for (final e in english.entries)
          for (final name in brokenEn(e.value))
            '${e.key}: "$name" in "${e.value}"',
      ];
      expect(
        offenders,
        isEmpty,
        reason:
            'British spelling, “…” quotes, … for ellipsis, "we" as the service '
            'voice, one word per thing.',
      );
    });
  });

  group('typography in both languages', () {
    final all = {
      'sv': _values('lib/l10n/app_sv.arb'),
      'en': _values('lib/l10n/app_en.arb'),
    };

    test('a pause is an en dash, never an em dash or a spaced hyphen', () {
      final offenders = [
        for (final lang in all.entries)
          for (final e in lang.value.entries)
            if (e.value.contains('—') || e.value.contains(' - '))
              '${lang.key} ${e.key}: "${e.value}"',
      ];
      expect(offenders, isEmpty);
    });

    test('plurals are written as plurals, not as (s)', () {
      final offenders = [
        for (final lang in all.entries)
          for (final e in lang.value.entries)
            if (RegExp(r'\w\((?:s|ar|er|ner)\)').hasMatch(e.value))
              '${lang.key} ${e.key}: "${e.value}"',
      ];
      expect(offenders, isEmpty);
    });
  });

  group('plural', () {
    final sv = _arb('lib/l10n/app_sv.arb');
    final en = _arb('lib/l10n/app_en.arb');

    test(
      'the scanner finds a counted noun outside a plural and spares one inside',
      () {
        expect(
          _unpluralised('{count} bilder valda', {'count'}, _svNouns),
          isNotEmpty,
        );
        expect(
          _unpluralised(
            '{count, plural, =1{1 bild} other{{count} bilder}} valda',
            {'count'},
            _svNouns,
          ),
          isEmpty,
        );
        expect(_unpluralised('{count} recept', {'count'}, _svNouns), isEmpty);
        expect(_unpluralised('{count} items', {'count'}, _enNouns), isNotEmpty);
      },
    );

    for (final lang in [('sv', sv, _svNouns), ('en', en, _enNouns)]) {
      test('${lang.$1}: a number in front of a noun that has a plural form '
          'sits inside a plural', () {
        final numeric = _numericPlaceholders(sv);
        final offenders = [
          for (final e in lang.$2.entries)
            if (!e.key.startsWith('@') && e.value is String)
              for (final hit in _unpluralised(
                e.value as String,
                numeric[e.key] ?? const {},
                lang.$3,
              ))
                '${e.key}: "$hit" in "${e.value}"',
        ];
        expect(
          offenders,
          isEmpty,
          reason:
              'Write {n, plural, =1{1 vara} other{{n} varor}}; the noun changes '
              'with the number (content-style-guide.md, singular and plural).',
        );
      });
    }
  });

  group('English metadata', () {
    test('every key with an @ block in Swedish has one in English', () {
      final sv = _arb('lib/l10n/app_sv.arb');
      final en = _arb('lib/l10n/app_en.arb');
      final missing = [
        for (final k in sv.keys)
          if (k.startsWith('@') && !k.startsWith('@@') && !en.containsKey(k)) k,
      ];
      expect(missing, isEmpty);
    });

    test('both languages carry the same keys', () {
      final sv = _values('lib/l10n/app_sv.arb').keys.toSet();
      final en = _values('lib/l10n/app_en.arb').keys.toSet();
      expect(sv.difference(en), isEmpty);
      expect(en.difference(sv), isEmpty);
    });
  });
}

final _englishRules = <_Rule>[
  _Rule('...', RegExp(r'\.\.\.'), exceptions: ['/.../']),
  _Rule('"', RegExp('"')),
  _Rule('—', RegExp('—')),
  _Rule('e-mail', RegExp(r'e-mail')),
  _Rule('(s)', RegExp(r'\w\(s\)')),
  _Rule('log in', RegExp(r'\blog(?:ged)? (?:in|out)\b|\blogin\b')),
  _Rule('slot', RegExp(r'\bslots?\b')),
  _Rule('wk', RegExp(r'\bwk\b')),
  for (final word in const [
    'analyze',
    'analyzing',
    'analyzed',
    'favorite',
    'favorites',
    'license',
    'licenses',
    'neighbor',
    'neighbors',
    'organize',
    'organizing',
    'sulfite',
    'synchronization',
    'enrollment',
    'color',
    'colors',
    'center',
    'canceled',
    'gray',
    'behavior',
  ])
    _Rule(
      word,
      RegExp('(?<![A-Za-z])$word(?![A-Za-z])'),
      exceptions: ['open font license'],
    ),
];

// Plural forms whose singular is spelled differently. A word that reads the
// same in both numbers (recept, fält, steg, tecken) needs no plural.
const _svNouns = {
  'vänner',
  'bilder',
  'medlemmar',
  'taggar',
  'ingredienser',
  'förfrågningar',
  'kategorier',
  'personer',
  'målgrupper',
  'dagar',
  'veckor',
  'timmar',
  'minuter',
  'sekunder',
  'varor',
  'regler',
  'stjärnor',
  'sidor',
  'kommentarer',
  'ändringar',
  'inbjudningar',
  'uppladdningar',
  'samarbeten',
  'uppdateringar',
  'gånger',
  'röster',
  'månader',
  'inköpslistor',
  'rätter',
  'portioner',
  'händelser',
  'aktiviteter',
  'kollaboratörer',
  'grupper',
  'notiser',
  'listor',
  'menyer',
};
const _enNouns = {
  'items',
  'images',
  'recipes',
  'days',
  'members',
  'tags',
  'ingredients',
  'requests',
  'characters',
  'people',
  'weeks',
  'minutes',
  'hours',
  'seconds',
  'months',
  'years',
  'fields',
  'categories',
  'invitations',
  'steps',
  'rules',
  'participants',
  'pages',
  'stars',
  'users',
  'friends',
  'comments',
  'ratings',
  'dishes',
  'targets',
  'filters',
  'results',
  'likes',
  'changes',
  'collaborations',
  'updates',
  'uploads',
  'times',
  'alternatives',
  'votes',
  'servings',
  'portions',
  'lists',
  'places',
  'notifications',
  'messages',
  'groups',
  'photos',
  'guests',
  'suggestions',
  'events',
  'activities',
  'collaborators',
  'drafts',
  'options',
  'menus',
};

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Map<String, String> _values(String path) => {
  for (final e in _arb(path).entries)
    if (!e.key.startsWith('@') && e.value is String) e.key: e.value as String,
};

/// The placeholders typed int or num in the template's @ blocks.
Map<String, Set<String>> _numericPlaceholders(Map<String, dynamic> template) =>
    {
      for (final e in template.entries)
        if (e.key.startsWith('@') && !e.key.startsWith('@@'))
          e.key.substring(1): {
            for (final p
                in ((e.value as Map<String, dynamic>)['placeholders']
                            as Map<String, dynamic>? ??
                        const {})
                    .entries)
              if ((p.value as Map<String, dynamic>)['type'] == 'int' ||
                  (p.value as Map<String, dynamic>)['type'] == 'num')
                p.key,
          },
    };

/// Counted nouns that stand outside a plural branch: `{count} bilder`.
List<String> _unpluralised(
  String value,
  Set<String> numeric,
  Set<String> nouns,
) {
  final inside = List<bool>.filled(value.length, false);
  final stack = <bool>[];
  final branch = RegExp(r'(?:other|one|few|many|zero|=\d+)$');
  for (var i = 0; i < value.length; i++) {
    if (value[i] == '{') {
      stack.add(branch.hasMatch(value.substring(0, i)));
    } else if (value[i] == '}' && stack.isNotEmpty) {
      stack.removeLast();
    }
    inside[i] = stack.contains(true);
  }
  final found = <String>[];
  for (final ph in numeric) {
    final pattern = RegExp('\\{$ph\\}((?: [\\wåäöÅÄÖ-]+){1,2})');
    for (final m in pattern.allMatches(value)) {
      if (inside[m.start]) continue;
      final words = m.group(1)!.trim().split(' ');
      // A literal number (`av 7 dagar`) fixes the count: not a plural question.
      if (words.any((w) => RegExp(r'^\d+$').hasMatch(w))) continue;
      if (words.any(nouns.contains)) found.add(m.group(0)!);
    }
  }
  return found;
}

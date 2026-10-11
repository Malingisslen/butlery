// BUT-2372: one word per thing in the Swedish strings. design/ordlista.json
// lists the words and characters the app does not use; this test holds every
// value in lib/l10n/app_sv.arb to it, so a new string cannot bring them back.
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
}

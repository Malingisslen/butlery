// The admin view edits the word lists compiled into the app; the server and
// the rules name the same lists by key. This pins the app's catalogue to the
// data file, and the client-side word check to what the server accepts.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/tagging/config/occasion_lists.dart';

void main() {
  final data =
      jsonDecode(
            File(
              'lib/services/tagging/config/data/occasions.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final fileLists = <String, List<String>>{
    for (final group in data.entries)
      if (!group.key.startsWith('_'))
        for (final field in (group.value as Map<String, dynamic>).entries)
          if (field.value is List)
            '${group.key}.${field.key}': (field.value as List).cast<String>(),
  };

  test('the catalogue is every list in the data file, in file order', () {
    expect([for (final l in kOccasionLists) l.key], fileLists.keys.toList());
  });

  test('each list holds the words the data file gives it', () {
    for (final l in kOccasionLists) {
      expect(l.words, fileLists[l.key], reason: l.key);
    }
  });

  test('every list the file holds today passes the proposal check', () {
    for (final l in kOccasionLists) {
      expect(validateOccasionWords(l.words), isNull, reason: l.key);
    }
  });

  test('the key splits into group and field', () {
    const l = OccasionList('titleKeywords.starkSet', ['stark']);
    expect(l.group, 'titleKeywords');
    expect(l.field, 'starkSet');
  });

  group('parseOccasionWords', () {
    test('one word per line or comma, tidied, repeats dropped in order', () {
      expect(parseOccasionWords('  Jul \n\nlutfisk,  JUL\nfoie   gras\n'), [
        'jul',
        'lutfisk',
        'foie gras',
      ]);
    });

    test('blank input is no words', () {
      expect(parseOccasionWords(' \n , \n'), isEmpty);
    });
  });

  group('validateOccasionWords', () {
    test('accepts the shapes the file uses', () {
      expect(
        validateOccasionWords([
          "all'arrabbiata",
          'go-to',
          '20 min',
          'entrecôte',
          'jalapeño',
        ]),
        isNull,
      );
    });

    test('refuses what the server refuses', () {
      expect(validateOccasionWords([]), OccasionWordsError.empty);
      expect(
        validateOccasionWords(List.generate(201, (i) => 'o$i')),
        OccasionWordsError.tooMany,
      );
      expect(
        validateOccasionWords(['a' * 61]),
        OccasionWordsError.tooLong,
      );
      expect(validateOccasionWords(['a' * 60]), isNull);
      for (final bad in [
        'Jul',
        ' jul',
        'jul  skinka',
        '@malin',
        '`x`',
        r'$x',
        'a|b',
        '<b>',
        'jul\nskinka',
        'jul${String.fromCharCode(0x202e)}',
      ]) {
        expect(
          validateOccasionWords([bad]),
          OccasionWordsError.invalidWord,
          reason: bad,
        );
      }
      expect(
        validateOccasionWords(['jul', 'jul']),
        OccasionWordsError.duplicate,
      );
    });
  });
}

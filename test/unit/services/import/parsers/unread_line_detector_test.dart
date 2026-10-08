import 'dart:io';

import 'package:butlery/services/import/parsers/unread_line_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnreadLineDetector (BUT-2158)', () {
    test('a garbled amount before a unit is unread', () {
      for (final line in [
        '} dl potatismjöl',
        '2z dl vetemjöl',
        '1i2 tsk bakpulver',
        '% tsk salt',
        '1, dl vispgrädde',
        '≥ tsk chilipulver (obs! stark krydda)',
        'a tsk salt',
        '1 litet vitkålshuvud (ca * kilo)',
      ]) {
        expect(UnreadLineDetector.isUnread(line), isTrue, reason: line);
      }
    });

    test('the image reader\'s marker is unread wherever it stands', () {
      expect(UnreadLineDetector.isUnread('[oläsligt]'), isTrue);
      expect(UnreadLineDetector.isUnread('2 dl [oläsligt]'), isTrue);
    });

    test('readable lines are not unread', () {
      for (final line in [
        '1 dl mjölk',
        '2 msk socker',
        '1/2 tsk salt',
        '1 1/2 tsk bakpulver',
        '½ tsk kummin',
        '2½ dl vetemjöl',
        '8–9 dl dinkelmjöl',
        '2 - 3 dl vispgrädde',
        '2 -3 dl vispgrädde',
        '1/2 -3/4 l hallon',
        '0,5 dl olja',
        'ca 1 kilo lammbringa i bitar',
        'en nypa salt',
        '(1 msk likör)',
        'fisk i paket',
        '1 banan, i bitar',
        'ägg',
        'salt och peppar',
        'Mjölk:',
        '2 st ägg (L)',
        '400g burk krossade tomater',
        '2x400 g tomater',
        '1+1 msk smör',
        '',
      ]) {
        expect(UnreadLineDetector.isUnread(line), isFalse, reason: line);
      }
    });

    test(
      'the marker is the one the server prompt tells the reader to write',
      () {
        final source = File(
          'functions/src/llm/gemini-client.ts',
        ).readAsStringSync();
        final match = RegExp(
          r'^export const UNREADABLE_MARKER = "([^"]+)";',
          multiLine: true,
        ).firstMatch(source);
        expect(match, isNotNull);
        expect(match!.group(1), UnreadLineDetector.unreadMarker);
      },
    );

    test('an unreadable amount marked in the preparation is unread', () {
      // The server prompt puts the marker in `preparation` when the amount is
      // unreadable, and the app formats that line as "unit name (preparation)".
      expect(UnreadLineDetector.isUnread('dl mjölk ([oläsligt])'), isTrue);
    });
  });
}

/// CLI: measure [UnreadLineDetector] against the cookbook gold corpus
/// (BUT-2158).
///
///   dart run tools/corpus_unread_eval.dart
///   BUTLERY_CORPUS_DIR=/path/to/corpus dart run tools/corpus_unread_eval.dart
///
/// False alarms: verified gold ingredient lines the detector calls unread.
/// Every one of them is a correct line the review would show empty. Catches:
/// OCR lines that differ from their gold line (the closest OCR line by shared
/// characters) and that the detector calls unread. Each is printed so the
/// call can be checked by eye.
library;

import 'dart:convert';
import 'dart:io';

import 'package:butlery/services/import/parsers/unread_line_detector.dart';

import 'corpus/corpus_models.dart';
import 'corpus/corpus_paths.dart';

void main() {
  final paths = CorpusPaths.resolve();
  stdout.writeln('Corpus root: ${paths.root}');

  var goldLines = 0;
  final falseAlarms = <String>[];
  var differing = 0;
  final caught = <String>[];

  for (final bookDir in paths.books()) {
    final book = bookDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    for (final entry in paths.recipeEntries(book)) {
      final goldFile = File(entry.goldPath);
      if (!goldFile.existsSync()) continue;
      final GoldRecipe gold;
      try {
        gold = GoldRecipe.fromJson(
          jsonDecode(goldFile.readAsStringSync()) as Map<String, dynamic>,
        );
      } on FormatException {
        continue;
      }
      if (!gold.verified) continue;

      final ocrFile = File(entry.ocrTextPath);
      final ocrLines = ocrFile.existsSync()
          ? ocrFile
                .readAsLinesSync()
                .map((l) => l.trim())
                .where((l) => l.isNotEmpty)
                .toList()
          : const <String>[];

      for (final ingredient in gold.ingredients) {
        final line = ingredient.originalLine.trim();
        if (line.isEmpty) continue;
        goldLines++;
        if (UnreadLineDetector.isUnread(line)) falseAlarms.add(line);

        if (ocrLines.contains(line)) continue;
        final closest = _closest(line, ocrLines);
        if (closest == null) continue;
        differing++;
        if (UnreadLineDetector.isUnread(closest)) {
          caught.add('$closest   (gold: $line)');
        }
      }
    }
  }

  stdout
    ..writeln('Verified gold lines: $goldLines')
    ..writeln('False alarms: ${falseAlarms.length}')
    ..writeln('OCR lines differing from gold: $differing')
    ..writeln('Caught as unread: ${caught.length}');
  for (final f in falseAlarms) {
    stdout.writeln('  FALSE ALARM: $f');
  }
  for (final c in caught) {
    stdout.writeln('  caught: $c');
  }
}

/// The OCR line sharing the most characters with [gold], when the share is at
/// least 0.6 by the ratio 2·LCS / (|a| + |b|).
String? _closest(String gold, List<String> candidates) {
  String? best;
  var bestScore = 0.6;
  for (final c in candidates) {
    final score = _ratio(gold, c);
    if (score >= bestScore) {
      bestScore = score;
      best = c;
    }
  }
  return best;
}

double _ratio(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1;
  final lcs = _lcs(a, b);
  return 2 * lcs / (a.length + b.length);
}

int _lcs(String a, String b) {
  var prev = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    for (var j = 1; j <= b.length; j++) {
      cur[j] = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1)
          ? prev[j - 1] + 1
          : (cur[j - 1] > prev[j] ? cur[j - 1] : prev[j]);
    }
    prev = cur;
  }
  return prev[b.length];
}

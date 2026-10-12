// Every view has a row in design/screen-register.json tying it to its sketch
// frames and a committed sketch-against-app image. A view that was never
// compared is `ej-bedömd`; that count only shrinks, so a new view cannot
// arrive without being compared.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _statuses = {
  'godkänd',
  'avviker-beslutad',
  'ersatt',
  'skillnader-listade',
  'ej-bedömd',
};

const _notAssessedBaseline = 2;

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final views =
      _json('design/screen-register.json')['views'] as Map<String, dynamic>;
  final frames =
      _json('design/sketch-frames.json')['frames'] as Map<String, dynamic>;

  test('every *_view.dart under lib/views has a register row', () {
    final missing = [
      for (final e in Directory('lib/views').listSync(recursive: true))
        if (e is File && e.path.endsWith('_view.dart'))
          if (!views.containsKey(e.path.replaceAll(r'\', '/')))
            e.path.replaceAll(r'\', '/'),
    ]..sort();
    expect(
      missing,
      isEmpty,
      reason:
          'Add the view to design/screen-register.json with its sketch '
          'frames and a sketch-against-app image (design/skiss-mot-app/).',
    );
  });

  test('every register row names a file that exists and a valid status', () {
    final bad = [
      for (final e in views.entries)
        if (!File(e.key).existsSync())
          '${e.key}: file is gone, remove or rename the row'
        else if (!_statuses.contains((e.value as Map)['status']))
          '${e.key}: unknown status ${(e.value as Map)['status']}',
    ];
    expect(bad, isEmpty);
  });

  test('an assessed view has real sketch frames and an image beside them', () {
    final bad = <String>[];
    for (final e in views.entries) {
      final row = e.value as Map<String, dynamic>;
      if (row['status'] == 'ej-bedömd') continue;
      final rowFrames = (row['frames'] as List).cast<String>();
      final rowImages = (row['images'] as List).cast<String>();
      if (rowFrames.isEmpty) bad.add('${e.key}: no sketch frame');
      for (final f in rowFrames) {
        if (!frames.containsKey(f)) bad.add('${e.key}: unknown frame $f');
      }
      if (rowImages.isEmpty) bad.add('${e.key}: no sketch-against-app image');
      for (final i in rowImages) {
        if (!File(i).existsSync()) bad.add('${e.key}: image $i is missing');
      }
    }
    expect(bad, isEmpty);
  });

  test('the not-yet-assessed count only shrinks', () {
    final n = views.values
        .where((v) => (v as Map)['status'] == 'ej-bedömd')
        .length;
    expect(
      n,
      _notAssessedBaseline,
      reason: n > _notAssessedBaseline
          ? 'A view was added without being compared with its sketch.'
          : 'Lower _notAssessedBaseline to $n.',
    );
  });
}

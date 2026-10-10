// Host half of the BUT-1848 capture: pushes corpus pages to an Android phone,
// runs ML Kit on them there, and stores what came back beside the Windows
// capture, so `tools/corpus_split_eval.dart --engine=mlkit` can replay it.
//
//   flutter drive -d <phone> \
//     --driver=test_driver/mlkit_layout_capture.dart \
//     --target=integration_test/mlkit_layout_capture_test.dart
//
// Needs the corpus (`../butlery-corpus` or `BUTLERY_CORPUS_DIR`) and `adb` on
// PATH. Only pages with a Windows capture and no ML Kit capture yet are sent,
// at most `MLKIT_CAPTURE_LIMIT` (default 40) per run, so a dropped connection
// costs one batch: re-run until it reports nothing left.

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

import '../tools/corpus/corpus_paths.dart';

const _remoteDir = '/sdcard/Android/data/se.butlery.app/files/mlkit_capture';

Future<void> main() async {
  final paths = CorpusPaths.resolve();
  final limit =
      int.tryParse(Platform.environment['MLKIT_CAPTURE_LIMIT'] ?? '') ?? 40;
  final pending = _pending(paths);
  final batch = pending.take(limit).toList();
  stdout.writeln(
    'Corpus root: ${paths.root}\n'
    'Pages without an ML Kit capture: ${pending.length}; sending ${batch.length}',
  );

  await _waitForRemoteDir();
  for (final page in batch) {
    await _adb([
      'push',
      paths.pageImage(page.book, page.imageId),
      '$_remoteDir/${page.book}__${page.imageId}.jpg',
    ]);
  }
  final marker = File('${Directory.systemTemp.path}/mlkit_push.done')
    ..writeAsStringSync('');
  await _adb(['push', marker.path, '$_remoteDir/push.done']);

  await integrationDriver(
    timeout: const Duration(minutes: 50),
    responseDataCallback: (data) async {
      final captures = (data?['captures'] as Map?) ?? const {};
      for (final entry in captures.entries) {
        final key = entry.key as String;
        final sep = key.indexOf('__');
        final book = key.substring(0, sep);
        final imageId = key.substring(sep + 2);
        final payload =
            jsonDecode(
                  utf8.decode(gzip.decode(base64Decode(entry.value as String))),
                )
                as Map<String, dynamic>;
        File(
          paths.ocrLayout(book, imageId, engine: 'mlkit'),
        ).writeAsStringSync(jsonEncode(payload['layout']));
        File(
          '${paths.recipe(book, imageId)}/ocr-mlkit.txt',
        ).writeAsStringSync(payload['providerText'] as String);
      }
      stdout.writeln(
        'Stored ${captures.length} ML Kit captures; '
        '${pending.length - captures.length} pages left.',
      );
    },
  );
}

/// Every page the Windows capture covers that has no ML Kit capture yet, so
/// the two engines end up scored over the same pages.
List<({String book, String imageId})> _pending(CorpusPaths paths) {
  final pages = <({String book, String imageId})>[];
  for (final book in paths.books()) {
    final slug = book.uri.pathSegments.where((s) => s.isNotEmpty).last;
    for (final imageDir in book.listSync().whereType<Directory>()) {
      final imageId = imageDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (!File(paths.ocrLayout(slug, imageId)).existsSync()) continue;
      if (!File(paths.pageImage(slug, imageId)).existsSync()) continue;
      if (File(paths.ocrLayout(slug, imageId, engine: 'mlkit')).existsSync()) {
        continue;
      }
      pages.add((book: slug, imageId: imageId));
    }
  }
  return pages..sort(
    (a, b) => '${a.book}/${a.imageId}'.compareTo(
      '${b.book}/${b.imageId}',
    ),
  );
}

/// The app creates the dir on start; pushing before that would create it as
/// the shell user, which the app cannot read.
Future<void> _waitForRemoteDir() async {
  final deadline = DateTime.now().add(const Duration(minutes: 5));
  while (DateTime.now().isBefore(deadline)) {
    final r = await Process.run('adb', ['shell', 'ls', _remoteDir]);
    if (r.exitCode == 0) return;
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  throw StateError('The app never created $_remoteDir on the phone');
}

Future<void> _adb(List<String> args) async {
  final r = await Process.run('adb', args);
  if (r.exitCode != 0) {
    throw StateError('adb ${args.join(' ')} failed: ${r.stderr}');
  }
}

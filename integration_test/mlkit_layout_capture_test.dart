// Device half of the BUT-1848 capture: ML Kit's own geometry for every corpus
// page the host pushes, handed back through `reportData` so the driver
// (`test_driver/mlkit_layout_capture.dart`) can store it beside the Windows
// capture as `layout-mlkit.json`.
//
// Returned through the driver rather than pulled or streamed: the runner
// uninstalls the app (and its external dir) before a pull can run, and
// streaming text over debugPrint starved the run — both recorded in
// `ocr_engine_comparison_test.dart`. One response at the end is neither.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:butlery/services/ocr/device_text_recognizer_mlkit.dart';
import 'package:butlery/services/ocr_extraction_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'captures ML Kit geometry for the pushed corpus pages',
    () async {
      // Created by the app, never by `adb shell mkdir`: a dir the shell creates
      // is unreadable to the app (see ocr_engine_comparison_test.dart).
      final base = await getExternalStorageDirectory();
      expect(base, isNotNull, reason: 'No external storage dir on this device');
      final dir = Directory('${base!.path}/mlkit_capture')
        ..createSync(recursive: true);
      // Leftovers from a run that died before the app was uninstalled: a
      // stale marker would start this run before the host has pushed.
      for (final stale in dir.listSync().whereType<File>()) {
        stale.deleteSync();
      }
      debugPrint('MLKIT_CAPTURE_DIR_READY ${dir.path}');

      // The driver pushes this marker after the last image, so a half-finished
      // push is never read as the whole set.
      final done = File('${dir.path}/push.done');
      final deadline = DateTime.now().add(const Duration(minutes: 15));
      while (!done.existsSync() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      expect(
        done.existsSync(),
        isTrue,
        reason: 'The host never finished pushing',
      );

      final images =
          dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.jpg'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      expect(images, isNotEmpty, reason: 'No page images arrived');

      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      addTearDown(recognizer.close);
      final tmp = await getTemporaryDirectory();

      final captures = <String, String>{};
      for (final image in images) {
        final id = image.uri.pathSegments.last.replaceAll('.jpg', '');
        // What production feeds ML Kit, not the raw photo: the eval must replay
        // the bytes a user's import is read from.
        final input = File('${tmp.path}/mlkit_capture_input.jpg')
          ..writeAsBytesSync(
            OCRExtractionService.preprocessImageForOcr(image.readAsBytesSync()),
            flush: true,
          );
        final recognized = await recognizer.processImage(
          InputImage.fromFilePath(input.path),
        );
        // The lossless mapping, before the edge crop: the Windows capture is
        // stored at that stage too, and the eval's arms apply the crop
        // themselves.
        final page = MlKitTextRecognizer.toPageLayout(recognized);
        final payload = jsonEncode({
          'layout': page.toJson(),
          'providerText': recognized.text.trim(),
        });
        captures[id] = base64Encode(gzip.encode(utf8.encode(payload)));
        image.deleteSync();
        debugPrint('MLKIT_CAPTURED $id lines=${page.lines.length}');
      }

      binding.reportData = {'captures': captures};
    },
    timeout: const Timeout(Duration(minutes: 45)),
  );
}

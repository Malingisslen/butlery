// Device-only harness for the on-device OCR tier (tasks/butlery-ocr-sites-plan.md,
// step A3): does the free platform recognizer read a photographed cookbook page
// as well as the paid provider chain does?
//
// Why integration_test: ML Kit is a platform-channel plugin, so the headless
// flutter-test VM has no registrant for it — the same constraint that forced
// ner_golden_integration_test.dart onto a device.
//
// The scoring runs ON THE DEVICE and only a per-recipe number is printed. Three
// earlier shapes failed on 2026-08-02 and are recorded here so they are not
// retried:
//   1. write results to the app's external dir, pull afterwards — the runner
//      UNINSTALLS the app at the end, which deletes /sdcard/Android/data/<pkg>
//      and everything in it before a pull can run;
//   2. stream the recognized text line by line over debugPrint — per-page time
//      went 400ms → 6.8s and the run died after page 2, starved by the wireless
//      VM-service channel;
//   3. hold the app open in a "pull window" — works, but every extra minute is
//      another chance for wireless ADB to drop the socket (it dropped on ~half
//      of all attempts).
// Computing the score here reduces the output to ~10 short lines and needs no
// pull at all. The metric is `goldTokenRecall`, the SAME function the existing
// OCR baseline was measured with — a verdict from two different metrics would
// be worthless.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:butlery/services/ocr/device_text_recognizer_mlkit.dart';
import 'package:butlery/services/ocr_extraction_service.dart';

import '../tools/corpus/corpus_metrics.dart';
import '../tools/corpus/corpus_models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'on-device OCR scored against gold, next to the paid chain',
    () async {
      // The path comes from the platform, never hardcoded: a dir created by
      // `adb shell mkdir` under /sdcard/Android/data/<pkg> is owned by shell
      // with the app's UID outside its group, so the app reads it back as
      // Permission denied.
      final base = await getExternalStorageDirectory();
      expect(base, isNotNull, reason: 'No external storage dir on this device');
      final dir = Directory('${base!.path}/corpus');
      dir.createSync(recursive: true);
      debugPrint('MLKIT_DIR_READY ${dir.path}');

      // Wait for the host to push. Expected layout, flat:
      //   <imageId>.jpg            the page photo
      //   <imageId>.ocr.txt        what the paid chain read from it
      //   <imageId>__<label>.gold.json  one per verified recipe on that page
      List<File> filesWith(String suffix) =>
          dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith(suffix))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      var golds = <File>[];
      var images = <File>[];
      final deadline = DateTime.now().add(const Duration(seconds: 240));
      var lastTotal = -1;
      while (DateTime.now().isBefore(deadline)) {
        images = filesWith('.jpg');
        golds = filesWith('.gold.json');
        final total = images.length + golds.length;
        // Two consecutive equal counts, so a half-finished push is never read
        // as the complete set.
        if (total > 0 && total == lastTotal) break;
        lastTotal = total;
        debugPrint('MLKIT_WAITING jpg=${images.length} gold=${golds.length}');
        await Future<void>.delayed(const Duration(seconds: 4));
      }

      expect(
        images,
        isNotEmpty,
        reason: 'No page images arrived in ${dir.path}',
      );
      expect(golds, isNotEmpty, reason: 'No gold files arrived in ${dir.path}');

      final recognizer = MlKitTextRecognizer();
      addTearDown(recognizer.dispose);

      // imageId → recognized text
      final onDevice = <String, String>{};
      for (final image in images) {
        final id = _basename(image.path).replaceAll('.jpg', '');
        // Feed the engine what PRODUCTION feeds it, not the raw file. The
        // service preprocesses before every provider call (EXIF baked in,
        // long edge to 2048, greyscale, contrast, JPEG re-encode), and the
        // paid arm below is read from an ocr.txt captured through that same
        // chain. Comparing a raw read against a preprocessed one measures the
        // preprocessing, not the engines — and the margin here is fractions of
        // a point. (Digest: "eval input must match PRODUCTION input".)
        final sw = Stopwatch()..start();
        final preprocessed = OCRExtractionService.preprocessImageForOcr(
          await image.readAsBytes(),
        );
        final read = await recognizer.recognize(preprocessed);
        // The seam returns both strings + geometry since 2026-08-05. This
        // harness compares READING quality against the paid tiers, so it
        // takes the provider's own string — the same bytes it scored
        // before the seam widened, which keeps its numbers comparable to
        // the 96.1 vs 96.6 recorded in the deviation log.
        final text = read?.providerText;
        sw.stop();
        onDevice[id] = text ?? '';
        debugPrint(
          'MLKIT_READ $id chars=${text?.length ?? 0} ms=${sw.elapsedMilliseconds}',
        );
      }

      var pairs = 0;
      var sumDevice = 0.0;
      var sumPaid = 0.0;
      for (final goldFile in golds) {
        final name = _basename(goldFile.path).replaceAll('.gold.json', '');
        final imageId = name.split('__').first;

        final gold = _readGold(goldFile);
        if (gold == null || !gold.verified) {
          debugPrint('MLKIT_SKIP $name unreadable-or-unverified');
          continue;
        }

        final deviceText = onDevice[imageId];
        final paidFile = File('${dir.path}/$imageId.ocr.txt');
        if (deviceText == null || !paidFile.existsSync()) {
          debugPrint('MLKIT_SKIP $name missing-image-or-baseline');
          continue;
        }

        final dev = goldTokenRecall(gold, deviceText).recall;
        final paid = goldTokenRecall(gold, paidFile.readAsStringSync()).recall;
        pairs++;
        sumDevice += dev;
        sumPaid += paid;
        debugPrint(
          'MLKIT_SCORE $name on_device=${_p(dev)} paid_chain=${_p(paid)}',
        );
      }

      expect(pairs, greaterThan(0), reason: 'Nothing could be scored');
      final meanDev = sumDevice / pairs;
      final meanPaid = sumPaid / pairs;
      debugPrint(
        'MLKIT_MEAN recipes=$pairs on_device=${_p(meanDev)} '
        'paid_chain=${_p(meanPaid)} delta=${_p(meanDev - meanPaid)}',
      );
      debugPrint(
        meanDev >= meanPaid
            ? 'MLKIT_VERDICT on-device matches or beats the paid chain'
            : 'MLKIT_VERDICT on-device is WORSE — keep the flag off',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

String _p(double v) => (v * 100).toStringAsFixed(1);

String _basename(String path) => path.replaceAll('\\', '/').split('/').last;

GoldRecipe? _readGold(File file) {
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) return null;
    return GoldRecipe.fromJson(decoded.cast<String, dynamic>());
  } catch (e) {
    debugPrint('MLKIT_GOLD_PARSE_FAILED ${_basename(file.path)} $e');
    return null;
  }
}

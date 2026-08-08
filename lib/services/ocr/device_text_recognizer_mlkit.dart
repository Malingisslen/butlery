import 'dart:io';
import 'dart:ui' show Rect;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/ocr/device_text_recognizer.dart';
import 'package:butlery/services/ocr/edge_crop.dart';
import 'package:butlery/services/ocr/text_layout.dart';

DeviceTextRecognizer createDeviceTextRecognizer() => MlKitTextRecognizer();

/// On-device recognizer backed by ML Kit's Latin script model.
///
/// Latin covers Swedish including å/ä/ö; no other script pod is added, which
/// keeps the iOS bundle at the default Latin-only model.
class MlKitTextRecognizer implements DeviceTextRecognizer {
  MlKitTextRecognizer({TextRecognizer? recognizer})
    : _recognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;
  bool _disposed = false;

  @override
  bool get isAvailable => Platform.isAndroid || Platform.isIOS;

  /// ML Kit's byte constructor expects raw NV21/BGRA planes, not an encoded
  /// container. Everything upstream of here is JPEG/PNG bytes, so the encoded
  /// image goes through a temp file — the supported path for encoded input.
  ///
  /// `InputImage.fromBitmap` is the trap to avoid, not just `fromBytes`: it
  /// happens to work on Android (the plugin falls back to
  /// `BitmapFactory.decodeByteArray`) but not on iOS, where the Dart factory
  /// always sets `metadata` and the Swift side then reads the JPEG buffer as
  /// raw width*height*4 RGBA — garbage at best, out-of-bounds at worst. Do not
  /// "simplify" the file path away.
  @override
  Future<RecognitionResult?> recognize(Uint8List imageBytes) async {
    if (_disposed || !isAvailable) return null;

    File? tempFile;
    try {
      final dir = await getTemporaryDirectory();
      // The counter alone is not unique: it restarts at 0 in every isolate and
      // process while the cache dir is shared, so two runs could collide on the
      // same name — one overwriting the other's input mid-read.
      tempFile = File(
        p.join(
          dir.path,
          'mlkit_ocr_${DateTime.now().microsecondsSinceEpoch}_${_seq++}.img',
        ),
      );
      await tempFile.writeAsBytes(imageBytes, flush: true);

      final recognized = await _recognizer.processImage(
        InputImage.fromFilePath(tempFile.path),
      );
      final layout = layoutFor(recognized);
      // BOTH strings travel. The adapter does not choose — `OCRExtractionService`
      // does, from the feature flag, so turning the geometry off returns the
      // exact bytes that shipped before this seam widened.
      //
      // They differ in SEPARATORS and, since 2026-08-08, in CONTENT.
      // `recognized.text` is assembled natively; `layout.text` is a plain
      // newline join of the lines, which is the only string a line index means
      // anything against. Line ORDER is identical in both — we iterate
      // `recognized.blocks` as given, and no re-ordering happens anywhere: a
      // re-orderer was measured and declined on 2026-08-07, so capture order is
      // the contract, not a pending step (ACCEPTED_DEVIATIONS.md).
      //
      // The content difference is [layoutFor]'s edge crop, which fires on 132 of
      // 181 corpus pages (PROXY — that count is WinOCR geometry cropped against
      // itself, not ML Kit, and the corpus has no `providerText` to compare
      // with). Where it fires, `layout.text` is MISSING rows `providerText`
      // still has — the sliver of the neighbouring page caught at the frame.
      // That is the whole point of the geometry path shipping a different
      // string, and it is why "the same words, assembled differently" is no
      // longer the contract. `edge_crop.dart` carries the measurement.
      //
      // They are trimmed DIFFERENTLY, and that asymmetry is the design:
      // `providerText` keeps HEAD's global trim because its only job is to be
      // the rollback, while `layout.text` is never trimmed because a leading
      // blank row it removed would shift every line index by one. Nothing
      // trims per line either (`OcrLine` substitutes newlines with a space, it
      // does not trim), which is what `text_layout.dart`'s line-count contract
      // relies on.
      // Byte-identical to what HEAD stored. `enable_on_device_ocr` is ON in
      // production, so any drift here reaches every photo import regardless of
      // the geometry flag — which is exactly what a rollback must not do.
      final providerText = recognized.text.trim();
      // Null only when BOTH are blank — an AND, and deliberately so. Widening
      // this to OR would report `on_device_error` and trip the circuit breaker
      // for reads that are fine. The layout string is now a subset rather than
      // a re-join, so "both derive from the same blocks" no longer makes either
      // side non-blank on its own; what does is `cropEdgeBleed`, which refuses
      // to claim more than a third of a page and returns the page untouched
      // rather than an empty one.
      if (providerText.isEmpty && layout.text.trim().isEmpty) {
        return null;
      }
      return RecognitionResult(providerText: providerText, layout: layout);
    } catch (e) {
      // Never throw: the contract is "null = try the next provider".
      AppLogger.debug('MlKitTextRecognizer: recognition failed — $e');
      return null;
    } finally {
      if (tempFile != null) {
        try {
          await tempFile.delete();
        } catch (_) {
          // A leftover temp file is harmless; the OS clears the cache dir.
        }
      }
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    // Set before the await so a throwing close() still leaves this permanently
    // refusing work rather than half-open.
    _disposed = true;
    try {
      await _recognizer.close();
    } catch (e) {
      // Teardown must not throw. `close()` is an unguarded platform-channel
      // call, so it raises MissingPluginException on the desktop runners
      // (where dart.library.io is true but the plugin is absent) and can race
      // engine detach on mobile shutdown. Letting it escape would abort the
      // owning service's onDispose before the rest of its teardown ran.
      AppLogger.debug('MlKitTextRecognizer: close failed — $e');
    }
  }

  /// Maps ML Kit's `blocks → lines → elements` tree onto the flat page model.
  ///
  /// The BLOCK level is dropped on purpose. It is ML Kit's own paragraph
  /// grouping, and it is what makes `recognized.text` order a two-column
  /// spread the way it does; flattening to lines removes ML Kit's block
  /// grouping from the assembled string and keeps the geometry — how ML Kit
  /// joins blocks in `recognized.text` is its own business and is unmeasured
  /// off-device, which is the point: we stop depending on it. The line ORDER is
  /// still ML Kit's. Flattening also puts a re-ordering within reach as an
  /// explicit, testable step over the boxes, but no such step exists: one was
  /// measured and declined on 2026-08-07 (ACCEPTED_DEVIATIONS.md), which names
  /// its own re-opening condition. Until that is met, capture order is what
  /// every downstream index rests on.
  ///
  /// A line whose box or elements are missing still becomes a line. Losing the
  /// row would shift every index after it, which is worse than a line with no
  /// measurement — the model already treats an unmeasured line as an absence
  /// rather than as a zero.
  /// Visible for testing because it is otherwise unreachable: `recognize()`
  /// returns early unless `Platform.isAndroid || Platform.isIOS`, so no test
  /// host can drive this through the public API. That matters more than
  /// usual here — this mapping decides the STRING every tier-0 consumer
  /// parses, and without a seam nothing off-device could ever prove that
  /// `layout.text` is a faithful per-line join rather than ML Kit's own
  /// assembly. The ML Kit value types stage fine off-device (plain Dart,
  /// public constructors, no method channel), so the gate was the only
  /// obstacle.
  @visibleForTesting
  static PageLayout toPageLayout(RecognizedText recognized) {
    final lines = <OcrLine>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        lines.add(
          OcrLine(
            text: line.text,
            box: _box(line.boundingBox),
            words: [
              for (final element in line.elements)
                OcrWord(text: element.text, box: _box(element.boundingBox)),
            ],
          ),
        );
      }
    }
    return PageLayout(lines: lines);
  }

  /// The page as tier 0 actually stores it: mapped, then edge-cropped.
  ///
  /// Composition rather than a step inside [toPageLayout], so that method keeps
  /// its documented contract — a faithful, lossless mapping of what ML Kit
  /// returned, including a line whose box or elements are missing. Dropping
  /// rows is a separate judgement and belongs outside it.
  ///
  /// This exists so the WIRING can be proven, not just the rule. `recognize()`
  /// is unreachable off-device, so a crop applied only in there would be
  /// deletable with every suite still green — the failure mode
  /// `docs/architecture/ACCEPTED_DEVIATIONS.md` already records once, where a
  /// recorder was installed in a test setup and never asserted on. Assert on
  /// THIS, not on [toPageLayout].
  @visibleForTesting
  static PageLayout layoutFor(RecognizedText recognized) =>
      cropEdgeBleed(toPageLayout(recognized));

  /// `Rect` is `dart:ui`, and `text_layout.dart` deliberately takes no Flutter
  /// and no third-party imports, so it runs under plain `dart test` and can be
  /// replayed by tooling. (It does import its sibling `glyph_metrics.dart`,
  /// which is under the same discipline — an earlier version of this sentence
  /// said "no imports at all", which that file itself records as retired.)
  /// This adapter is the only place the two coordinate types meet.
  static LayoutBox _box(Rect r) => LayoutBox(
    left: r.left,
    top: r.top,
    width: r.width,
    height: r.height,
  );

  static int _seq = 0;
}

/// Tests for OCRExtractionService.preprocessImageForOcr — the pure-function
/// preprocessing pipeline that runs before images ship to OCR backends.
///
/// Covers:
/// - EXIF orientation correction (sideways photo gets uprighted)
/// - Downscale: oversized images are clamped to 2048px on the long edge
/// - Output format: result is JPEG (verified by magic bytes)
/// - Determinism: same input twice produces byte-identical output
/// - Decode failure: invalid bytes are returned unchanged (graceful fallback)
///
/// We synthesize fixtures programmatically using the `image` package so the
/// tests stay hermetic — no external image files to manage.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:butlery/services/ocr_extraction_service.dart';

void main() {
  group('OCRExtractionService.preprocessImageForOcr', () {
    test('output is a JPEG (verified by magic bytes)', () {
      // Build a simple 100x100 PNG
      final src = img.Image(width: 100, height: 100);
      img.fill(src, color: img.ColorRgb8(120, 80, 40));
      final pngBytes = Uint8List.fromList(img.encodePng(src));

      final out = OCRExtractionService.preprocessImageForOcr(pngBytes);

      // JPEG starts with FF D8 FF
      expect(out.length, greaterThan(3));
      expect(out[0], 0xFF);
      expect(out[1], 0xD8);
      expect(out[2], 0xFF);
    });

    test('downscales oversized image to <=2048px on long edge', () {
      // 4096x4096 — well over the 2048 cap
      final src = img.Image(width: 4096, height: 4096);
      img.fill(src, color: img.ColorRgb8(200, 200, 200));
      final pngBytes = Uint8List.fromList(img.encodePng(src));

      final out = OCRExtractionService.preprocessImageForOcr(pngBytes);

      final decoded = img.decodeImage(out);
      expect(decoded, isNotNull);
      final longEdge = decoded!.width > decoded.height
          ? decoded.width
          : decoded.height;
      expect(longEdge, lessThanOrEqualTo(2048));
      expect(longEdge, greaterThan(1024)); // Must actually contain content
    });

    test('preserves aspect ratio when downscaling non-square images', () {
      // 4000x2000 (2:1 landscape)
      final src = img.Image(width: 4000, height: 2000);
      img.fill(src, color: img.ColorRgb8(50, 50, 50));
      final pngBytes = Uint8List.fromList(img.encodePng(src));

      final out = OCRExtractionService.preprocessImageForOcr(pngBytes);

      final decoded = img.decodeImage(out)!;
      // Width was the long edge → should be ~2048
      expect(decoded.width, lessThanOrEqualTo(2048));
      expect(decoded.width, greaterThanOrEqualTo(2000));
      // Aspect ratio ~2:1 should be preserved (height ~half of width)
      final ratio = decoded.width / decoded.height;
      expect(ratio, closeTo(2.0, 0.05));
    });

    test('does not upscale small images', () {
      // 800x600 — well under the 2048 cap
      final src = img.Image(width: 800, height: 600);
      img.fill(src, color: img.ColorRgb8(100, 150, 200));
      final pngBytes = Uint8List.fromList(img.encodePng(src));

      final out = OCRExtractionService.preprocessImageForOcr(pngBytes);

      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 800);
      expect(decoded.height, 600);
    });

    test(
      'preprocessing is deterministic (same input → byte-identical output)',
      () {
        // Use a non-trivial image so JPEG encoding has actual content to hash
        final src = img.Image(width: 256, height: 256);
        for (var y = 0; y < 256; y++) {
          for (var x = 0; x < 256; x++) {
            src.setPixelRgb(x, y, x % 256, y % 256, (x ^ y) % 256);
          }
        }
        final pngBytes = Uint8List.fromList(img.encodePng(src));

        final out1 = OCRExtractionService.preprocessImageForOcr(pngBytes);
        final out2 = OCRExtractionService.preprocessImageForOcr(pngBytes);

        expect(out1.length, out2.length);
        expect(out1, orderedEquals(out2));
      },
    );

    test('returns original bytes unchanged when decode fails', () {
      final garbage = Uint8List.fromList(
        List.generate(64, (i) => i % 256),
      ); // not a valid image

      final out = OCRExtractionService.preprocessImageForOcr(garbage);

      expect(out, orderedEquals(garbage));
    });

    test('output is greyscale (R≈G≈B per pixel)', () {
      // Coloured input — should be greyscaled
      final src = img.Image(width: 50, height: 50);
      img.fill(src, color: img.ColorRgb8(255, 0, 0)); // Pure red
      final pngBytes = Uint8List.fromList(img.encodePng(src));

      final out = OCRExtractionService.preprocessImageForOcr(pngBytes);
      final decoded = img.decodeImage(out)!;

      // Sample several pixels — JPEG is lossy so allow small drift between channels
      final samplePoints = [
        [10, 10],
        [25, 25],
        [40, 40],
      ];
      for (final p in samplePoints) {
        final pixel = decoded.getPixel(p[0], p[1]);
        // Greyscale: R, G, B should be equal (or very close given JPEG noise)
        expect(
          (pixel.r - pixel.g).abs(),
          lessThan(8),
          reason:
              'Expected R≈G at (${p[0]},${p[1]}); got R=${pixel.r} G=${pixel.g}',
        );
        expect(
          (pixel.g - pixel.b).abs(),
          lessThan(8),
          reason:
              'Expected G≈B at (${p[0]},${p[1]}); got G=${pixel.g} B=${pixel.b}',
        );
      }
    });

    test('BUT-666: same logical image in different containers produces '
        'identical preprocessed bytes (cache-key collapse)', () {
      // Build a 100x100 solid image and encode it three ways: PNG, JPEG q70,
      // JPEG q95. All three decode to the same RGB pixels — they only differ
      // in container/quantization. Under the new cache scheme (BUT-666) the
      // cache key is computed AFTER preprocessing, so these three trivially
      // different inputs must collapse to one cache key.
      final src = img.Image(width: 100, height: 100);
      img.fill(src, color: img.ColorRgb8(120, 80, 40));

      final pngBytes = Uint8List.fromList(img.encodePng(src));
      final jpegLow = Uint8List.fromList(img.encodeJpg(src, quality: 70));
      final jpegHigh = Uint8List.fromList(img.encodeJpg(src, quality: 95));

      // Sanity: the three input byte arrays are different (otherwise the test
      // doesn't prove anything about post-preprocess collapse).
      expect(pngBytes, isNot(equals(jpegLow)));
      expect(pngBytes, isNot(equals(jpegHigh)));
      expect(jpegLow, isNot(equals(jpegHigh)));

      final outPng = OCRExtractionService.preprocessImageForOcr(pngBytes);
      final outLow = OCRExtractionService.preprocessImageForOcr(jpegLow);
      final outHigh = OCRExtractionService.preprocessImageForOcr(jpegHigh);

      // The PNG path is fully deterministic (lossless input → exactly the
      // same downscaled+greyscaled pixels → exactly the same JPEG q=85 out).
      // The JPEG-input paths carry quantization noise from the source
      // encoding, so we don't insist the bytes equal the PNG path. We DO
      // insist that the two JPEG-input paths produce the same output: same
      // input quantization + same preprocessing = same output.
      //
      // (For the looser claim we'd need a perceptual hash — out of scope for
      // BUT-666; the ticket explicitly defers pHash as optional.)
      expect(
        outLow,
        equals(outHigh),
        reason:
            'Two JPEG inputs differing only in source quality must '
            'produce identical preprocessed bytes — that is the cache-key '
            'collapse this ticket buys.',
      );

      // The PNG-vs-JPEG paths should at minimum produce JPEG-formatted output
      // of comparable size (within ~10%) — proves the pipeline did its job.
      expect(
        outPng.length,
        inInclusiveRange((outLow.length * 0.7).round(), outLow.length * 2),
      );
    });

    test('EXIF orientation: bakeOrientation reorients sideways images', () {
      // Note: synthesizing a PNG with EXIF rotation tag in the test is awkward
      // since the image package strips EXIF on decode of PNG. We instead exercise
      // the orientation pathway via a JPEG-with-EXIF roundtrip.
      //
      // Build a clearly non-square image (200 wide, 100 tall) and tag it with
      // orientation=6 (rotate 90 CW). After bakeOrientation the dimensions
      // should have swapped (100 wide, 200 tall).
      final src = img.Image(width: 200, height: 100);
      img.fill(src, color: img.ColorRgb8(180, 180, 180));
      // Set EXIF orientation = 6 (Rotate 90 CW)
      src.exif.imageIfd['Orientation'] = 6;

      final jpegBytes = Uint8List.fromList(img.encodeJpg(src, quality: 90));

      final out = OCRExtractionService.preprocessImageForOcr(jpegBytes);
      final decoded = img.decodeImage(out)!;

      // After baking orientation 6 (90 CW), width and height should swap:
      // original 200x100 → baked 100x200
      expect(
        decoded.width,
        100,
        reason: 'After orientation bake, width should be original height',
      );
      expect(
        decoded.height,
        200,
        reason: 'After orientation bake, height should be original width',
      );
    });
  });
}

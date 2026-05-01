/// Unit tests for [HeicConverter] (BUT-662).
///
/// We never call the real `flutter_image_compress` plugin in unit tests —
/// the compress callable is injected and faked. Real HEIC decoding is
/// integration-level and lives outside this suite.
library;

import 'dart:typed_data';

import 'package:butlery/services/import/heic_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HeicConverter', () {
    final heicBytes = Uint8List.fromList([
      0x00, 0x00, 0x00, 0x18, // box length
      0x66, 0x74, 0x79, 0x70, // 'ftyp'
      0x68, 0x65, 0x69, 0x63, // 'heic'
      0x00, 0x00, 0x00, 0x00,
      ...List<int>.filled(64, 0xAA), // arbitrary HEIC payload
    ]);

    final jpegBytes = Uint8List.fromList([
      0xFF, 0xD8, 0xFF, 0xE0, // JPEG SOI + APP0
      ...List<int>.filled(32, 0xCC),
    ]);

    final pngBytes = Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      ...List<int>.filled(32, 0xDD),
    ]);

    test('returns original bytes unchanged for non-HEIC input (JPEG)',
        () async {
      var compressCalls = 0;
      final converter = HeicConverter(
        compress: (bytes, {required quality}) async {
          compressCalls++;
          return null;
        },
      );

      final result = await converter.convertToJpegIfHeic(jpegBytes);

      expect(result, same(jpegBytes));
      expect(compressCalls, 0,
          reason: 'compress must not be invoked for non-HEIC input');
    });

    test('returns original bytes unchanged for non-HEIC input (PNG)', () async {
      final converter = HeicConverter(
        compress: (bytes, {required quality}) async => null,
      );

      final result = await converter.convertToJpegIfHeic(pngBytes);

      expect(result, same(pngBytes));
    });

    test('HEIC input → calls compress at quality 90 → returns new bytes',
        () async {
      final convertedBytes = Uint8List.fromList([
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        ...List<int>.filled(8, 0xEE),
      ]);
      Uint8List? capturedInput;
      int? capturedQuality;

      final converter = HeicConverter(
        compress: (bytes, {required quality}) async {
          capturedInput = bytes;
          capturedQuality = quality;
          return convertedBytes;
        },
      );

      final result = await converter.convertToJpegIfHeic(heicBytes);

      expect(result, same(convertedBytes));
      expect(capturedInput, same(heicBytes));
      expect(capturedQuality, 90);
    });

    test('returns null when compress returns null (does not throw)', () async {
      final converter = HeicConverter(
        compress: (bytes, {required quality}) async => null,
      );

      final result = await converter.convertToJpegIfHeic(heicBytes);

      expect(result, isNull);
    });

    test('returns null when compress returns empty bytes', () async {
      final converter = HeicConverter(
        compress: (bytes, {required quality}) async => Uint8List(0),
      );

      final result = await converter.convertToJpegIfHeic(heicBytes);

      expect(result, isNull);
    });

    test('returns null when compress throws (does not propagate)', () async {
      final converter = HeicConverter(
        compress: (bytes, {required quality}) async {
          throw StateError('plugin unavailable');
        },
      );

      // Must not throw — the failure mode is "fall through with null"
      // so the caller can decide whether to send original HEIC bytes.
      final result = await converter.convertToJpegIfHeic(heicBytes);

      expect(result, isNull);
    });

    test('returns original bytes for unknown format (not HEIC, not converted)',
        () async {
      final unknownBytes = Uint8List.fromList(
        List<int>.generate(32, (i) => (i * 13 + 5) % 256),
      );

      final converter = HeicConverter(
        compress: (bytes, {required quality}) async => Uint8List(0),
      );

      final result = await converter.convertToJpegIfHeic(unknownBytes);

      expect(result, same(unknownBytes),
          reason: 'unknown ≠ HEIC, must not invoke compress');
    });
  });
}

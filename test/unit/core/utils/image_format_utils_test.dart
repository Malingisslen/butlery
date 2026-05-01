import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/utils/image_format_utils.dart';

void main() {
  group('ImageFormatUtils', () {
    group('detectMimeType', () {
      test('detects JPEG', () {
        final bytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10];
        expect(ImageFormatUtils.detectMimeType(bytes), 'image/jpeg');
      });

      test('detects PNG', () {
        final bytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        expect(ImageFormatUtils.detectMimeType(bytes), 'image/png');
      });

      test('detects GIF', () {
        final bytes = [0x47, 0x49, 0x46, 0x38, 0x39, 0x61];
        expect(ImageFormatUtils.detectMimeType(bytes), 'image/gif');
      });

      test('detects WebP', () {
        // RIFF + 4 size bytes + WEBP
        final bytes = [
          0x52, 0x49, 0x46, 0x46, // RIFF
          0x00, 0x00, 0x00, 0x00, // size (don't care)
          0x57, 0x45, 0x42, 0x50, // WEBP
        ];
        expect(ImageFormatUtils.detectMimeType(bytes), 'image/webp');
      });

      test('returns null for unknown format', () {
        final bytes = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05];
        expect(ImageFormatUtils.detectMimeType(bytes), isNull);
      });

      test('returns null for too-short data', () {
        expect(ImageFormatUtils.detectMimeType([0xFF, 0xD8]), isNull);
      });

      test('returns null for empty data', () {
        expect(ImageFormatUtils.detectMimeType([]), isNull);
      });
    });

    group('isSupportedImage', () {
      test('returns true for JPEG', () {
        expect(
          ImageFormatUtils.isSupportedImage([0xFF, 0xD8, 0xFF, 0xE0]),
          isTrue,
        );
      });

      test('returns false for unknown', () {
        expect(
          ImageFormatUtils.isSupportedImage([0x00, 0x01, 0x02, 0x03]),
          isFalse,
        );
      });
    });

    group('detectMimeTypeWithFallback', () {
      test('uses magic bytes when available', () {
        final pngBytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        expect(
          ImageFormatUtils.detectMimeTypeWithFallback(pngBytes, 'photo.jpg'),
          'image/png', // Magic bytes win over extension
        );
      });

      test('falls back to extension for unknown bytes', () {
        final unknown = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05];
        expect(
          ImageFormatUtils.detectMimeTypeWithFallback(unknown, 'photo.png'),
          'image/png',
        );
      });

      test('defaults to JPEG for unknown extension', () {
        final unknown = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05];
        expect(
          ImageFormatUtils.detectMimeTypeWithFallback(unknown, 'file.xyz'),
          'image/jpeg',
        );
      });
    });

    group('mimeTypeFromExtension', () {
      test('recognizes .png', () {
        expect(ImageFormatUtils.mimeTypeFromExtension('test.png'), 'image/png');
      });

      test('recognizes .gif', () {
        expect(ImageFormatUtils.mimeTypeFromExtension('test.gif'), 'image/gif');
      });

      test('recognizes .webp', () {
        expect(
            ImageFormatUtils.mimeTypeFromExtension('test.webp'), 'image/webp');
      });

      test('defaults to JPEG', () {
        expect(
            ImageFormatUtils.mimeTypeFromExtension('test.jpg'), 'image/jpeg');
        expect(
            ImageFormatUtils.mimeTypeFromExtension('test.jpeg'), 'image/jpeg');
        expect(
            ImageFormatUtils.mimeTypeFromExtension('test.bmp'), 'image/jpeg');
      });

      test('recognizes .heic and .heif (BUT-662)', () {
        expect(
            ImageFormatUtils.mimeTypeFromExtension('photo.heic'), 'image/heic');
        expect(
            ImageFormatUtils.mimeTypeFromExtension('photo.heif'), 'image/heic');
      });
    });

    // BUT-662 — enum-returning structural detection. Used by the OCR
    // import path to gate HEIC→JPEG conversion and to tag analytics.
    group('detectFormat (BUT-662)', () {
      List<int> heicBytes(List<int> brand) {
        return <int>[
          0x00, 0x00, 0x00, 0x18, // box length (don't care)
          0x66, 0x74, 0x79, 0x70, // 'ftyp'
          ...brand, // brand fourcc at offset 8
          0x00, 0x00, 0x00, 0x00, // padding
        ];
      }

      test('detects HEIC by `heic` brand', () {
        expect(
          ImageFormatUtils.detectFormat(heicBytes([0x68, 0x65, 0x69, 0x63])),
          ImageFormat.heic,
        );
      });

      test('detects HEIC by `mif1` brand (most common iPhone)', () {
        expect(
          ImageFormatUtils.detectFormat(heicBytes([0x6D, 0x69, 0x66, 0x31])),
          ImageFormat.heic,
        );
      });

      test('detects HEIC by all 8 supported brand fourcc variants', () {
        const brands = <List<int>>[
          [0x68, 0x65, 0x69, 0x63], // 'heic'
          [0x68, 0x65, 0x69, 0x78], // 'heix'
          [0x68, 0x65, 0x76, 0x63], // 'hevc'
          [0x68, 0x65, 0x76, 0x78], // 'hevx'
          [0x6D, 0x69, 0x66, 0x31], // 'mif1'
          [0x6D, 0x73, 0x66, 0x31], // 'msf1'
          [0x68, 0x65, 0x69, 0x73], // 'heis'
          [0x68, 0x65, 0x76, 0x73], // 'hevs'
        ];
        for (final brand in brands) {
          expect(
            ImageFormatUtils.detectFormat(heicBytes(brand)),
            ImageFormat.heic,
            reason:
                'brand ${String.fromCharCodes(brand)} should be detected as HEIC',
          );
        }
      });

      test('does NOT match `ftyp` with non-HEIC brand', () {
        // Generic MP4 brand 'isom' at offset 8 — not HEIC.
        final bytes = heicBytes([0x69, 0x73, 0x6F, 0x6D]);
        expect(
          ImageFormatUtils.detectFormat(bytes),
          ImageFormat.unknown,
        );
      });

      test('returns unknown for HEIC-shaped bytes shorter than 12', () {
        final tooShort = <int>[
          0x00,
          0x00,
          0x00,
          0x18,
          0x66,
          0x74,
          0x79,
          0x70,
          0x68,
          0x65,
        ];
        expect(
          ImageFormatUtils.detectFormat(tooShort),
          ImageFormat.unknown,
        );
      });

      test('detects JPEG via enum API', () {
        expect(
          ImageFormatUtils.detectFormat([0xFF, 0xD8, 0xFF, 0xE0]),
          ImageFormat.jpeg,
        );
      });

      test('returns unknown for fewer than 4 bytes', () {
        expect(
          ImageFormatUtils.detectFormat([0xFF, 0xD8]),
          ImageFormat.unknown,
        );
      });
    });

    group('wireName (BUT-662)', () {
      test('maps every enum value to a stable lowercase string', () {
        expect(ImageFormatUtils.wireName(ImageFormat.jpeg), 'jpeg');
        expect(ImageFormatUtils.wireName(ImageFormat.png), 'png');
        expect(ImageFormatUtils.wireName(ImageFormat.heic), 'heic');
        expect(ImageFormatUtils.wireName(ImageFormat.webp), 'webp');
        expect(ImageFormatUtils.wireName(ImageFormat.gif), 'gif');
        expect(ImageFormatUtils.wireName(ImageFormat.unknown), 'unknown');
      });
    });

    group('detectMimeType — HEIC support (BUT-662)', () {
      test('detects HEIC and returns image/heic MIME', () {
        final bytes = <int>[
          0x00, 0x00, 0x00, 0x18,
          0x66, 0x74, 0x79, 0x70,
          0x6D, 0x69, 0x66, 0x31, // 'mif1'
        ];
        expect(ImageFormatUtils.detectMimeType(bytes), 'image/heic');
      });
    });
  });
}

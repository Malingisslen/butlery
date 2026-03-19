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
    });
  });
}

/// Unit tests for ImageFormatUtils — magic byte detection and MIME type resolution.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../test_support/base_unit_test.dart';
import 'package:butlery/core/utils/image_format_utils.dart';

void main() {
  group('ImageFormatUtils', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() => BaseUnitTest.resetMocks());

    group('detectMimeType', () {
      test('JPEG header detected', () {
        expect(
          ImageFormatUtils.detectMimeType([0xFF, 0xD8, 0xFF, 0xE0]),
          'image/jpeg',
        );
      });

      test('PNG header detected', () {
        expect(
          ImageFormatUtils.detectMimeType(
              [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
          'image/png',
        );
      });

      test('GIF header detected', () {
        expect(
          ImageFormatUtils.detectMimeType([0x47, 0x49, 0x46, 0x38]),
          'image/gif',
        );
      });

      test('WebP header detected', () {
        expect(
          ImageFormatUtils.detectMimeType([
            0x52,
            0x49,
            0x46,
            0x46,
            0x00,
            0x00,
            0x00,
            0x00,
            0x57,
            0x45,
            0x42,
            0x50,
          ]),
          'image/webp',
        );
      });

      test('short header returns null', () {
        expect(ImageFormatUtils.detectMimeType([0xFF, 0xD8]), isNull);
      });

      test('unknown bytes return null', () {
        expect(
            ImageFormatUtils.detectMimeType([0x00, 0x00, 0x00, 0x00]), isNull);
      });
    });

    group('isSupportedImage', () {
      test('returns true for known format', () {
        expect(
          ImageFormatUtils.isSupportedImage([0xFF, 0xD8, 0xFF, 0xE0]),
          isTrue,
        );
      });

      test('returns false for unknown format', () {
        expect(
          ImageFormatUtils.isSupportedImage([0x00, 0x00, 0x00, 0x00]),
          isFalse,
        );
      });
    });

    group('mimeTypeFromExtension', () {
      test('.png returns image/png', () {
        expect(
            ImageFormatUtils.mimeTypeFromExtension('photo.png'), 'image/png');
      });

      test('.gif returns image/gif', () {
        expect(ImageFormatUtils.mimeTypeFromExtension('anim.gif'), 'image/gif');
      });

      test('.webp returns image/webp', () {
        expect(
            ImageFormatUtils.mimeTypeFromExtension('pic.webp'), 'image/webp');
      });

      test('.jpg returns image/jpeg', () {
        expect(
            ImageFormatUtils.mimeTypeFromExtension('photo.jpg'), 'image/jpeg');
      });

      test('.jpeg returns image/jpeg', () {
        expect(
            ImageFormatUtils.mimeTypeFromExtension('photo.jpeg'), 'image/jpeg');
      });

      test('unknown extension defaults to image/jpeg', () {
        expect(
            ImageFormatUtils.mimeTypeFromExtension('file.bmp'), 'image/jpeg');
      });
    });

    group('detectMimeTypeWithFallback', () {
      test('uses header when recognized', () {
        expect(
          ImageFormatUtils.detectMimeTypeWithFallback(
            [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0],
            'image.jpg',
          ),
          'image/png',
        );
      });

      test('falls back to extension when header unknown', () {
        expect(
          ImageFormatUtils.detectMimeTypeWithFallback(
            [0x00, 0x00, 0x00, 0x00, 0, 0, 0, 0, 0, 0, 0, 0],
            'image.webp',
          ),
          'image/webp',
        );
      });
    });
  });
}

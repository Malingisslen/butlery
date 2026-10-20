/// Proves a JPEG leaves [stripJpegMetadata] without the Exif (GPS) block while
/// everything the picture needs to render stays byte-identical.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/jpeg_exif_stripper.dart';

import '../../../infrastructure/helpers/synthetic_jpeg.dart';

void main() {
  group('stripJpegMetadata', () {
    test('removes the Exif APP1 segment and its GPS payload', () {
      final result = stripJpegMetadata(syntheticJpeg());

      expect(hasMetadataSegment(result), isFalse);
      expect(containsBytes(result, gpsPayload), isFalse);
      expect(containsBytes(result, 'GPSLatitude'.codeUnits), isFalse);
    });

    test(
      'equals the same JPEG built without Exif, so nothing else changed',
      () {
        expect(
          stripJpegMetadata(syntheticJpeg()),
          orderedEquals(syntheticJpeg(withExif: false)),
        );
      },
    );

    test('keeps the ICC profile and the scan data byte-identical', () {
      final result = stripJpegMetadata(syntheticJpeg());

      expect(containsBytes(result, segment(0xE2, iccPayload)), isTrue);
      expect(containsBytes(result, scanData), isTrue);
    });

    test('removes APP13 (IPTC) and XMP carried in APP1', () {
      final input = jpegOf([
        [0xFF, 0xD8],
        segment(
          0xE1,
          'http://ns.adobe.com/xap/1.0/\u0000<x:xmpmeta/>'.codeUnits,
        ),
        segment(0xED, 'Photoshop 3.0'.codeUnits),
        segment(0xDA, [1, 1, 0, 0, 0x3F, 0]),
        scanData,
        [0xFF, 0xD9],
      ]);

      final result = stripJpegMetadata(input);

      expect(containsBytes(result, 'xmpmeta'.codeUnits), isFalse);
      expect(containsBytes(result, 'Photoshop'.codeUnits), isFalse);
      expect(containsBytes(result, scanData), isTrue);
    });

    test('a JPEG with no metadata comes back unchanged', () {
      final input = syntheticJpeg(withExif: false);

      expect(stripJpegMetadata(input), orderedEquals(input));
    });

    test('tolerates 0xFF fill bytes before a marker', () {
      final input = jpegOf([
        [0xFF, 0xD8],
        [0xFF, 0xFF],
        segment(0xE1, gpsPayload),
        [0xFF, 0xFF, 0xFF],
        segment(0xDA, [1, 1, 0, 0, 0x3F, 0]),
        scanData,
        [0xFF, 0xD9],
      ]);

      final result = stripJpegMetadata(input);

      expect(containsBytes(result, gpsPayload), isFalse);
      expect(containsBytes(result, scanData), isTrue);
    });

    test('keeps a standalone marker (no length) between segments', () {
      final input = jpegOf([
        [0xFF, 0xD8],
        [0xFF, 0x01],
        segment(0xE1, gpsPayload),
        segment(0xDA, [1, 1, 0, 0, 0x3F, 0]),
        scanData,
        [0xFF, 0xD9],
      ]);

      final result = stripJpegMetadata(input);

      expect(containsBytes(result, [0xFF, 0x01]), isTrue);
      expect(containsBytes(result, gpsPayload), isFalse);
    });

    test(
      'Exif-looking bytes inside the scan data are not parsed as a segment',
      () {
        final input = jpegOf([
          [0xFF, 0xD8],
          segment(0xDA, [1, 1, 0, 0, 0x3F, 0]),
          // 0xFF 0x00 is byte stuffing, so this is data, not an APP1 marker.
          [0x01, 0xFF, 0x00, 0xE1, 0x00, 0x04, 0x02],
          [0xFF, 0xD9],
        ]);

        expect(stripJpegMetadata(input), orderedEquals(input));
      },
    );

    test('drops a second file appended after the end-of-image marker', () {
      final input = jpegOf([syntheticJpeg(withExif: false), syntheticJpeg()]);

      final result = stripJpegMetadata(input);

      expect(containsBytes(result, gpsPayload), isFalse);
      expect(result, orderedEquals(syntheticJpeg(withExif: false)));
    });

    test('non-JPEG input is returned unchanged', () {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
      final text = Uint8List.fromList('hello'.codeUnits);

      expect(stripJpegMetadata(png), same(png));
      expect(stripJpegMetadata(text), same(text));
      expect(stripJpegMetadata(Uint8List(0)), isEmpty);
      expect(
        stripJpegMetadata(Uint8List.fromList([0xFF])),
        orderedEquals([0xFF]),
      );
    });

    test('a segment whose length field is too large loses its payload', () {
      final lying = segment(0xE1, gpsPayload);
      lying[2] = 0xFF;
      lying[3] = 0xFF;
      final input = jpegOf([
        [0xFF, 0xD8],
        lying,
      ]);

      final result = stripJpegMetadata(input);

      expect(containsBytes(result, gpsPayload), isFalse);
    });

    test(
      'a segment whose length field is too small never leaks the payload',
      () {
        final lying = segment(0xE1, gpsPayload);
        lying[2] = 0x00;
        lying[3] = 0x02;
        final input = jpegOf([
          [0xFF, 0xD8],
          lying,
          segment(0xDA, [1, 1, 0, 0, 0x3F, 0]),
          scanData,
          [0xFF, 0xD9],
        ]);

        final result = stripJpegMetadata(input);

        expect(containsBytes(result, gpsPayload), isFalse);
      },
    );

    test('truncated and garbage input never throws', () {
      final full = syntheticJpeg();
      for (var cut = 0; cut <= full.length; cut++) {
        final truncated = Uint8List.sublistView(full, 0, cut);
        expect(
          () => stripJpegMetadata(truncated),
          returnsNormally,
          reason: 'cut at $cut',
        );
        expect(
          containsBytes(stripJpegMetadata(truncated), gpsPayload),
          isFalse,
          reason: 'cut at $cut',
        );
      }

      final garbage = Uint8List.fromList(
        [0xFF, 0xD8, ...List.generate(300, (i) => (i * 37 + 11) & 0xFF)],
      );
      expect(() => stripJpegMetadata(garbage), returnsNormally);
    });

    test('a broken structure is cut at the break, not passed on whole', () {
      final input = jpegOf([
        [0xFF, 0xD8],
        segment(0xE0, 'JFIF'.codeUnits),
        [0x12, 0x34],
        segment(0xE1, gpsPayload),
      ]);

      final result = stripJpegMetadata(input);

      expect(containsBytes(result, gpsPayload), isFalse);
      expect(containsBytes(result, 'JFIF'.codeUnits), isTrue);
    });

    test('a damaged header segment never lets a later Exif through', () {
      final lying = segment(0xE0, 'JFIF'.codeUnits);
      lying[2] = 0xFF;
      lying[3] = 0xFF;
      final input = jpegOf([
        [0xFF, 0xD8],
        lying,
        segment(0xE1, gpsPayload),
      ]);

      expect(containsBytes(stripJpegMetadata(input), gpsPayload), isFalse);
    });

    test(
      'keeps JFIF, ICC and Adobe; drops other APP segments and comments',
      () {
        final marker = 'C2PA-or-vendor-location'.codeUnits;
        final input = jpegOf([
          [0xFF, 0xD8],
          segment(0xE0, 'JFIF'.codeUnits),
          segment(0xE2, iccPayload),
          segment(0xEE, 'Adobe'.codeUnits),
          segment(0xEB, marker),
          segment(0xE4, marker),
          segment(0xEF, marker),
          segment(0xFE, marker),
          segment(0xDB, [1, 2, 3]),
          [0xFF, 0xD9],
        ]);

        final result = stripJpegMetadata(input);

        expect(containsBytes(result, marker), isFalse);
        expect(containsBytes(result, 'JFIF'.codeUnits), isTrue);
        expect(containsBytes(result, segment(0xE2, iccPayload)), isTrue);
        expect(containsBytes(result, 'Adobe'.codeUnits), isTrue);
        expect(containsBytes(result, segment(0xDB, [1, 2, 3])), isTrue);
      },
    );

    group('Orientation', () {
      List<int> exifWith(int orientation, {bool little = false}) {
        List<int> u16(int v) =>
            little ? [v & 0xFF, v >> 8] : [v >> 8, v & 0xFF];
        return [
          ...'Exif'.codeUnits,
          0,
          0,
          ...(little ? 'II'.codeUnits : 'MM'.codeUnits),
          ...u16(42),
          ...(little ? [8, 0, 0, 0] : [0, 0, 0, 8]),
          ...u16(2),
          ...u16(0x010F),
          ...u16(2),
          ...(little ? [4, 0, 0, 0] : [0, 0, 0, 4]),
          ...(little ? [0, 0, 0, 0] : [0, 0, 0, 0]),
          ...u16(0x0112),
          ...u16(3),
          ...(little ? [1, 0, 0, 0] : [0, 0, 0, 1]),
          ...u16(orientation),
          0,
          0,
          0,
          0,
          0,
          0,
          ...'GPSLatitude=59.3293'.codeUnits,
        ];
      }

      Uint8List withOrientation(int orientation, {bool little = false}) =>
          jpegOf([
            [0xFF, 0xD8],
            segment(0xE1, exifWith(orientation, little: little)),
            segment(0xDB, [1, 2, 3]),
            [0xFF, 0xDA, 0x00, 0x02],
            scanData,
            [0xFF, 0xD9],
          ]);

      test(
        'a rotated photo keeps its Orientation but loses everything else',
        () {
          for (final little in [false, true]) {
            final result = stripJpegMetadata(
              withOrientation(6, little: little),
            );

            expect(containsBytes(result, 'GPSLatitude'.codeUnits), isFalse);
            expect(containsBytes(result, 'II'.codeUnits), isFalse);
            expect(
              containsBytes(result, [0x01, 0x12, 0x00, 0x03, 0, 0, 0, 1, 0, 6]),
              isTrue,
              reason: 'little-endian: $little',
            );
          }
        },
      );

      test('an upright photo (Orientation 1) gets no Exif at all', () {
        final result = stripJpegMetadata(withOrientation(1));

        expect(hasMetadataSegment(result), isFalse);
      });

      test('an out-of-range Orientation is dropped', () {
        expect(
          hasMetadataSegment(stripJpegMetadata(withOrientation(9))),
          isFalse,
        );
      });

      test('an Exif cut off inside the IFD yields no segment and no throw', () {
        final full = exifWith(6);
        for (var cut = 0; cut < full.length; cut++) {
          final input = jpegOf([
            [0xFF, 0xD8],
            segment(0xE1, full.sublist(0, cut)),
            [0xFF, 0xD9],
          ]);
          expect(
            containsBytes(stripJpegMetadata(input), 'GPSLatitude'.codeUnits),
            isFalse,
          );
        }
      });
    });
  });
}

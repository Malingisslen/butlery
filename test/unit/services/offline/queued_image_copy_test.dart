/// Proves the device copy the offline queue keeps carries no Exif segment even
/// when the platform re-encoder is unavailable (as it is under unit tests), so
/// a queued photo's location cannot sit on the device for days (plan G7).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/offline/queued_image_copy.dart';

import '../../../infrastructure/helpers/synthetic_jpeg.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('queued_copy_test');
  });

  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  test('fallback copy of a JPEG with GPS Exif has no APP1 segment', () async {
    final source = File('${dir.path}/camera.jpg')
      ..writeAsBytesSync(syntheticJpeg());

    final copy = await copyWithoutLocation(source, '${dir.path}/queued');

    final bytes = copy.readAsBytesSync();
    expect(copy.path, isNot(source.path));
    expect(hasMetadataSegment(bytes), isFalse);
    expect(containsBytes(bytes, gpsPayload), isFalse);
    expect(containsBytes(bytes, scanData), isTrue);
  });

  test('fallback still copies a non-JPEG picture unchanged', () async {
    final png = [0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4];
    final source = File('${dir.path}/pic.png')..writeAsBytesSync(png);

    final copy = await copyWithoutLocation(source, '${dir.path}/queued');

    expect(copy.path, endsWith('.png'));
    expect(copy.readAsBytesSync(), orderedEquals(png));
  });
}

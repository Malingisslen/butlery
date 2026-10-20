import 'dart:typed_data';

/// Recognisable payload standing in for a GPS IFD inside the Exif segment.
final Uint8List gpsPayload = Uint8List.fromList([
  ...'Exif'.codeUnits,
  0,
  0,
  ...'GPSLatitudeRef=N;GPSLatitude=59.3293;GPSLongitude=18.0686'.codeUnits,
]);

final Uint8List iccPayload = Uint8List.fromList([
  ...'ICC_PROFILE'.codeUnits,
  0,
  1,
  1,
  0xAA,
  0xBB,
  0xCC,
]);

/// Scan data containing byte stuffing (FF 00) and a restart marker so a
/// stripper that stops at the first 0xFF would visibly cut it short.
final Uint8List scanData = Uint8List.fromList([
  0x11,
  0x22,
  0xFF,
  0x00,
  0x33,
  0xFF,
  0xD0,
  0x44,
  0x55,
  0x66,
]);

Uint8List segment(int marker, List<int> payload) {
  final length = payload.length + 2;
  return Uint8List.fromList([
    0xFF,
    marker,
    length >> 8,
    length & 0xFF,
    ...payload,
  ]);
}

Uint8List jpegOf(List<List<int>> parts) =>
    Uint8List.fromList([for (final part in parts) ...part]);

/// SOI, JFIF, optional Exif APP1, ICC APP2, DQT, SOS with [scanData], EOI.
Uint8List syntheticJpeg({bool withExif = true}) => jpegOf([
  [0xFF, 0xD8],
  segment(0xE0, 'JFIF'.codeUnits),
  if (withExif) segment(0xE1, gpsPayload),
  segment(0xE2, iccPayload),
  segment(0xDB, [0, 1, 2, 3, 4, 5]),
  segment(0xDA, [1, 1, 0, 0, 0x3F, 0]),
  scanData,
  [0xFF, 0xD9],
]);

bool containsBytes(Uint8List haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

/// True when [bytes] holds an APP1 or APP13 marker segment at a segment
/// boundary, found by walking the JPEG rather than by byte search.
bool hasMetadataSegment(Uint8List bytes) {
  var pos = 2;
  while (pos + 4 <= bytes.length && bytes[pos] == 0xFF) {
    final marker = bytes[pos + 1];
    if (marker == 0xE1 || marker == 0xED) return true;
    if (marker == 0xDA) return false;
    pos += 2 + ((bytes[pos + 2] << 8) | bytes[pos + 3]);
  }
  return false;
}

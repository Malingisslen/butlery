// lib/core/utils/jpeg_exif_stripper.dart
//
// BUT-2294 follow-up: the platform re-encoder is the primary way a picture
// loses its location, but it cannot run in unit tests and it can fail on a
// device. This is the dependency-free second line.
library;

import 'dart:typed_data';

const int _markerPrefix = 0xFF;
const int _soi = 0xD8;
const int _eoi = 0xD9;
const int _sos = 0xDA;

// Every application segment and comment is dropped except the three a decoder
// needs to show the picture right: JFIF (APP0), ICC colour profile (APP2) and
// Adobe (APP14, decides CMYK/YCCK decoding). A keep-list, because which other
// APP segment a phone puts location or credentials in changes with the phone.
const Set<int> _keptApplicationMarkers = {0xE0, 0xE2, 0xEE};

bool _isMetadata(int marker) =>
    (marker >= 0xE0 &&
        marker <= 0xEF &&
        !_keptApplicationMarkers.contains(marker)) ||
    marker == 0xFE;

// Without the Orientation tag a portrait photo that was never re-encoded would
// show sideways, and it is the one Exif field that carries no location.
Uint8List? _orientationOnlyExif(Uint8List bytes, int dataStart, int dataEnd) {
  final n = dataEnd - dataStart;
  if (n < 14) return null;
  const header = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00];
  for (var i = 0; i < header.length; i++) {
    if (bytes[dataStart + i] != header[i]) return null;
  }
  final tiff = dataStart + 6;
  final little = bytes[tiff] == 0x49 && bytes[tiff + 1] == 0x49;
  if (!little && !(bytes[tiff] == 0x4D && bytes[tiff + 1] == 0x4D)) {
    return null;
  }
  int u16(int at) => little
      ? bytes[at] | (bytes[at + 1] << 8)
      : (bytes[at] << 8) | bytes[at + 1];
  int u32(int at) =>
      little ? u16(at) | (u16(at + 2) << 16) : (u16(at) << 16) | u16(at + 2);

  if (tiff + 8 > dataEnd || u16(tiff + 2) != 42) return null;
  final ifd = tiff + u32(tiff + 4);
  if (ifd < tiff || ifd + 2 > dataEnd) return null;
  final count = u16(ifd);
  for (var i = 0; i < count; i++) {
    final entry = ifd + 2 + i * 12;
    if (entry + 12 > dataEnd) return null;
    if (u16(entry) != 0x0112) continue;
    final orientation = u16(entry + 8);
    if (orientation < 2 || orientation > 8) return null;
    return Uint8List.fromList([
      _markerPrefix,
      0xE1,
      0x00,
      0x22,
      ...header,
      0x4D,
      0x4D,
      0x00,
      0x2A,
      0x00,
      0x00,
      0x00,
      0x08,
      0x00,
      0x01,
      0x01,
      0x12,
      0x00,
      0x03,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      orientation,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ]);
  }
  return null;
}

bool _isStandalone(int marker) =>
    marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8) || marker == _eoi;

/// Returns [bytes] with every application segment and comment removed except
/// JFIF, ICC and Adobe (plus a rebuilt Exif holding only a non-default
/// Orientation) when it is a JPEG, and [bytes] untouched otherwise.
///
/// Never throws. A JPEG whose structure breaks off is cut at the break rather
/// than passed on whole: the part already read is guaranteed clean, whereas
/// the unread rest could still hold the very block this exists to remove. A
/// picture losing its tail is the lesser harm than a location reaching a
/// friend. Bytes after the end-of-image marker are dropped for the same
/// reason (phone "motion photo" and multi-picture trailers hold whole second
/// files with their own Exif).
Uint8List stripJpegMetadata(Uint8List bytes) {
  if (bytes.length < 2 || bytes[0] != _markerPrefix || bytes[1] != _soi) {
    return bytes;
  }

  final out = BytesBuilder(copy: false)..add(const [_markerPrefix, _soi]);
  final end = bytes.length;
  var pos = 2;

  while (pos < end) {
    if (bytes[pos] != _markerPrefix) break;
    // Any number of 0xFF fill bytes may precede a marker code.
    while (pos < end && bytes[pos] == _markerPrefix) {
      pos++;
    }
    if (pos >= end) break;
    final marker = bytes[pos];
    pos++;

    if (marker == 0x00) break;

    if (_isStandalone(marker)) {
      out.add([_markerPrefix, marker]);
      if (marker == _eoi) break;
      continue;
    }

    if (pos + 2 > end) break;
    final length = (bytes[pos] << 8) | bytes[pos + 1];
    if (length < 2) break;
    final segmentEnd = pos + length;
    final truncated = segmentEnd > end;
    final isMetadata = _isMetadata(marker);

    if (truncated) break;

    if (!isMetadata) {
      out.add([_markerPrefix, marker]);
      out.add(Uint8List.sublistView(bytes, pos, segmentEnd));
    } else if (marker == 0xE1) {
      final kept = _orientationOnlyExif(bytes, pos + 2, segmentEnd);
      if (kept != null) out.add(kept);
    }
    pos = segmentEnd;

    if (marker == _sos) {
      // Entropy-coded data follows. Inside it 0xFF is followed by 0x00
      // (stuffing), RSTn or another 0xFF; any other code is the next marker.
      // Copying up to it verbatim, rather than to the end of the file, keeps
      // table segments of a multi-scan JPEG from being mistaken for data.
      final dataStart = pos;
      while (pos < end) {
        if (bytes[pos] == _markerPrefix && pos + 1 < end) {
          final next = bytes[pos + 1];
          if (next != 0x00 &&
              next != _markerPrefix &&
              !(next >= 0xD0 && next <= 0xD7)) {
            break;
          }
          if (next == _markerPrefix) {
            pos++;
            continue;
          }
          pos += 2;
          continue;
        }
        pos++;
      }
      out.add(Uint8List.sublistView(bytes, dataStart, pos));
    }
  }

  return out.toBytes();
}

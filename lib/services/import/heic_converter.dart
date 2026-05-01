/// HEIC → JPEG converter for the OCR import boundary (BUT-662).
///
/// iOS defaults to HEIC since iOS 11. Mistral's vision endpoint and our
/// other OCR providers accept HEIC inconsistently — explicit conversion
/// here removes the silent-failure class. If conversion fails we return
/// null and let the caller fall through to the original bytes (failure
/// mode is the same as today, just visible in analytics).
///
/// The compress callable is injected via [HeicCompressFn] typedef so unit
/// tests don't need to touch the real `flutter_image_compress` plugin.
library;

import 'dart:typed_data';

import 'package:butlery/core/utils/image_format_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Pluggable compress function. Production wiring uses
/// `FlutterImageCompress.compressWithList`; tests pass a fake.
typedef HeicCompressFn = Future<Uint8List?> Function(
  Uint8List bytes, {
  required int quality,
});

class HeicConverter {
  final HeicCompressFn _compress;

  HeicConverter({HeicCompressFn? compress})
      : _compress = compress ?? _defaultCompress;

  /// Returns JPEG bytes if [bytes] is HEIC and conversion succeeded;
  /// returns the original [bytes] unchanged for non-HEIC inputs;
  /// returns null on conversion failure (caller decides whether to fall
  /// through to original bytes or surface an error).
  Future<Uint8List?> convertToJpegIfHeic(Uint8List bytes) async {
    final format = ImageFormatUtils.detectFormat(bytes);
    if (format != ImageFormat.heic) {
      return bytes;
    }

    try {
      // Quality 90: high enough that OCR readability is unaffected, low
      // enough that bytes shrink ~30-50% from typical HEIC sizes.
      final converted = await _compress(bytes, quality: 90);
      if (converted == null || converted.isEmpty) {
        AppLogger.warning(
          'HeicConverter: compress returned ${converted == null ? "null" : "empty bytes"}; '
          'falling back to original HEIC bytes',
        );
        return null;
      }
      return converted;
    } catch (e, stack) {
      AppLogger.warning(
        'HeicConverter: HEIC→JPEG conversion threw ${e.runtimeType}: $e\n$stack',
      );
      return null;
    }
  }

  static Future<Uint8List?> _defaultCompress(
    Uint8List bytes, {
    required int quality,
  }) async {
    return FlutterImageCompress.compressWithList(
      bytes,
      quality: quality,
      format: CompressFormat.jpeg,
    );
  }
}

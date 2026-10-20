// lib/services/offline/queued_image_copy.dart
//
// BUT-2294: the copy of a picture the offline queue keeps on the device until
// it is sent.
library;

import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

import 'package:butlery/core/utils/logger.dart';

/// Writes a copy of [source] at [destinationBase] plus an extension and
/// returns it. The queue keeps the copy for as long as a picture waits, which
/// can be days, so it must not carry the place the photo was taken.
typedef QueuedImageCopier =
    Future<File> Function(File source, String destinationBase);

/// A JPEG copy without EXIF (location included), turned upright. A picture the
/// platform cannot re-encode is copied as it is: losing the user's photo to
/// protect its metadata would be the worse outcome.
Future<File> copyWithoutLocation(File source, String destinationBase) async {
  try {
    final stripped = await FlutterImageCompress.compressAndGetFile(
      source.path,
      '$destinationBase.jpg',
      quality: 90,
      format: CompressFormat.jpeg,
      autoCorrectionAngle: true,
      keepExif: false,
    );
    if (stripped != null) return File(stripped.path);
  } catch (e) {
    AppLogger.warning('Bilden kunde inte göras om utan platsdata: $e');
  }
  return source.copy('$destinationBase${p.extension(source.path)}');
}

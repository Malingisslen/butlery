import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/ocr/device_text_recognizer.dart';

DeviceTextRecognizer createDeviceTextRecognizer() => MlKitTextRecognizer();

/// On-device recognizer backed by ML Kit's Latin script model.
///
/// Latin covers Swedish including å/ä/ö; no other script pod is added, which
/// keeps the iOS bundle at the default Latin-only model.
class MlKitTextRecognizer implements DeviceTextRecognizer {
  MlKitTextRecognizer({TextRecognizer? recognizer})
    : _recognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;
  bool _disposed = false;

  @override
  bool get isAvailable => Platform.isAndroid || Platform.isIOS;

  /// ML Kit's byte constructor expects raw NV21/BGRA planes, not an encoded
  /// container. Everything upstream of here is JPEG/PNG bytes, so the encoded
  /// image goes through a temp file — the supported path for encoded input.
  ///
  /// `InputImage.fromBitmap` is the trap to avoid, not just `fromBytes`: it
  /// happens to work on Android (the plugin falls back to
  /// `BitmapFactory.decodeByteArray`) but not on iOS, where the Dart factory
  /// always sets `metadata` and the Swift side then reads the JPEG buffer as
  /// raw width*height*4 RGBA — garbage at best, out-of-bounds at worst. Do not
  /// "simplify" the file path away.
  @override
  Future<String?> recognize(Uint8List imageBytes) async {
    if (_disposed || !isAvailable) return null;

    File? tempFile;
    try {
      final dir = await getTemporaryDirectory();
      // The counter alone is not unique: it restarts at 0 in every isolate and
      // process while the cache dir is shared, so two runs could collide on the
      // same name — one overwriting the other's input mid-read.
      tempFile = File(
        p.join(
          dir.path,
          'mlkit_ocr_${DateTime.now().microsecondsSinceEpoch}_${_seq++}.img',
        ),
      );
      await tempFile.writeAsBytes(imageBytes, flush: true);

      final recognized = await _recognizer.processImage(
        InputImage.fromFilePath(tempFile.path),
      );
      final text = recognized.text.trim();
      return text.isEmpty ? null : text;
    } catch (e) {
      // Never throw: the contract is "null = try the next provider".
      AppLogger.debug('MlKitTextRecognizer: recognition failed — $e');
      return null;
    } finally {
      if (tempFile != null) {
        try {
          await tempFile.delete();
        } catch (_) {
          // A leftover temp file is harmless; the OS clears the cache dir.
        }
      }
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    // Set before the await so a throwing close() still leaves this permanently
    // refusing work rather than half-open.
    _disposed = true;
    try {
      await _recognizer.close();
    } catch (e) {
      // Teardown must not throw. `close()` is an unguarded platform-channel
      // call, so it raises MissingPluginException on the desktop runners
      // (where dart.library.io is true but the plugin is absent) and can race
      // engine detach on mobile shutdown. Letting it escape would abort the
      // owning service's onDispose before the rest of its teardown ran.
      AppLogger.debug('MlKitTextRecognizer: close failed — $e');
    }
  }

  static int _seq = 0;
}

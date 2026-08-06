import 'dart:typed_data';

import 'package:butlery/services/ocr/device_text_recognizer.dart';

/// Web factory. ML Kit is mobile-only, so the tier reports itself unavailable
/// and the existing paid provider chain runs unchanged on web.
DeviceTextRecognizer createDeviceTextRecognizer() =>
    const _UnavailableRecognizer();

class _UnavailableRecognizer implements DeviceTextRecognizer {
  const _UnavailableRecognizer();

  @override
  bool get isAvailable => false;

  @override
  Future<RecognitionResult?> recognize(Uint8List imageBytes) async => null;

  @override
  Future<void> dispose() async {}
}

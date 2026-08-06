import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/ocr/device_text_recognizer_stub.dart';

/// The WEB half of the conditional import in `ocr_extraction_service.dart`.
///
/// The service suite already pins "an unavailable recognizer is skipped, not
/// failed" — but it stages that unavailability with a fake, so nothing checked
/// the factory a `flutter build web` actually gets. This is the other half of
/// that composition, and it is the only test that can run against the web
/// implementation from a VM test host.
void main() {
  test('the web factory reports itself unavailable', () async {
    final recognizer = createDeviceTextRecognizer();
    addTearDown(recognizer.dispose);

    // If this ever answered true, every web import would call recognize(), get
    // null back, and have it recorded as an on-device ERROR: the tier-0 circuit
    // breaker would open after five imports and the failure copy would name
    // a provider that cannot exist on that platform.
    expect(recognizer.isAvailable, isFalse);
    // Interface conformance, not a live path: the service never calls an
    // unavailable recognizer. `DeviceTextRecognizer.recognize` promises "null
    // means fall through, never a crash", and this is the only implementation
    // of that promise no other test can reach.
    expect(await recognizer.recognize(Uint8List(0)), isNull);
  });
}

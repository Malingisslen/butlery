/// BUT-941: IncomingShareService channel-client tests.
///
/// Pure channel plumbing — no OCR, no Firestore. Proves the cold-start fetch
/// parses + sanitizes the native path list, and that a warm-start `onMedia`
/// call from the platform side emits on the stream.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/incoming_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('se.butlery.app/incoming_share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('getInitialSharedImages returns the native path list', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getInitialMedia') {
        return <Object?>['/a.jpg', '/b.png'];
      }
      return null;
    });

    final service = IncomingShareService(channel: channel);
    addTearDown(service.dispose);

    expect(await service.getInitialSharedImages(), ['/a.jpg', '/b.png']);
  });

  test('getInitialSharedImages drops empty / non-string entries', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return <Object?>['/ok.jpg', '', 42, null];
    });

    final service = IncomingShareService(channel: channel);
    addTearDown(service.dispose);

    expect(await service.getInitialSharedImages(), ['/ok.jpg']);
  });

  test('getInitialSharedImages returns empty on a PlatformException', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'boom');
    });

    final service = IncomingShareService(channel: channel);
    addTearDown(service.dispose);

    expect(await service.getInitialSharedImages(), isEmpty);
  });

  test('warm-start onMedia call emits on mediaStream', () async {
    final service = IncomingShareService(channel: channel);
    addTearDown(service.dispose);

    final emitted = expectLater(
      service.mediaStream,
      emits(['/warm1.jpg', '/warm2.jpg']),
    );

    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onMedia', ['/warm1.jpg', '/warm2.jpg']),
      ),
      (_) {},
    );

    await emitted;
  });

  test('warm-start with an empty/garbage payload does not emit', () async {
    final service = IncomingShareService(channel: channel);
    addTearDown(service.dispose);

    var emitted = false;
    final sub = service.mediaStream.listen((_) => emitted = true);
    addTearDown(sub.cancel);

    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onMedia', ['', null]),
      ),
      (_) {},
    );
    await pumpEventQueue();

    expect(emitted, isFalse, reason: 'guard blocks a spurious navigation');
  });

  test('non-Android platform is a no-op (returns empty)', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    final service = IncomingShareService(channel: channel);
    addTearDown(service.dispose);

    expect(await service.getInitialSharedImages(), isEmpty);
  });
}

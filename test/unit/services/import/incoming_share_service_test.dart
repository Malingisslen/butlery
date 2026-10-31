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

  test('a desktop platform is a no-op (returns empty)', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    final service = IncomingShareService(channel: channel);
    addTearDown(service.dispose);

    expect(await service.getInitialSharedImages(), isEmpty);
  });

  test('a desktop platform never asks the channel for shared text', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getInitialText') return 'https://www.ica.se/r';
      return null;
    });

    final service = IncomingShareService(channel: channel);
    addTearDown(service.dispose);

    expect(await service.getInitialSharedText(), isNull);
  });

  group('iOS (the share extension hands over through the app)', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    test('asks the channel for the share the app was opened with', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getInitialMedia') return <Object?>['/tmp/a.jpg'];
        if (call.method == 'getInitialText') return 'https://www.ica.se/r';
        return null;
      });

      final service = IncomingShareService(channel: channel);
      addTearDown(service.dispose);

      expect(await service.getInitialSharedImages(), ['/tmp/a.jpg']);
      expect(await service.getInitialSharedText(), 'https://www.ica.se/r');
    });

    test('a share pushed while the app runs reaches the streams', () async {
      final service = IncomingShareService(channel: channel);
      addTearDown(service.dispose);
      final texts = <String>[];
      final media = <List<String>>[];
      service.textStream.listen(texts.add);
      service.mediaStream.listen(media.add);

      Future<void> push(String method, Object arguments) =>
          messenger.handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(MethodCall(method, arguments)),
            (_) {},
          );
      await push('onText', 'https://www.ica.se/r');
      await push('onMedia', <Object?>['/tmp/a.jpg']);
      await pumpEventQueue();

      expect(texts, ['https://www.ica.se/r']);
      expect(media, [
        ['/tmp/a.jpg'],
      ]);
    });
  });

  group('shared text (BUT-2241)', () {
    test('getInitialSharedText returns the native text', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getInitialText') return 'https://www.ica.se/r';
        return null;
      });

      final service = IncomingShareService(channel: channel);
      addTearDown(service.dispose);

      expect(await service.getInitialSharedText(), 'https://www.ica.se/r');
    });

    test('getInitialSharedText is null for blank or missing text', () async {
      for (final native in <Object?>[null, '  ', 42]) {
        messenger.setMockMethodCallHandler(channel, (call) async => native);
        final service = IncomingShareService(channel: channel);
        addTearDown(service.dispose);

        expect(await service.getInitialSharedText(), isNull, reason: '$native');
      }
    });

    test('getInitialSharedText is null on a PlatformException', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'boom');
      });

      final service = IncomingShareService(channel: channel);
      addTearDown(service.dispose);

      expect(await service.getInitialSharedText(), isNull);
    });

    test('warm-start onText call emits on textStream', () async {
      final service = IncomingShareService(channel: channel);
      addTearDown(service.dispose);

      final emitted = expectLater(service.textStream, emits('2 dl mjölk'));

      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onText', '2 dl mjölk'),
        ),
        (_) {},
      );

      await emitted;
    });

    test('warm-start blank onText does not emit', () async {
      final service = IncomingShareService(channel: channel);
      addTearDown(service.dispose);

      var emitted = false;
      final sub = service.textStream.listen((_) => emitted = true);
      addTearDown(sub.cancel);

      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onText', '   '),
        ),
        (_) {},
      );
      await pumpEventQueue();

      expect(emitted, isFalse);
    });
  });
}

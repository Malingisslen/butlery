// test/infrastructure/helpers/announce_channel.dart
//
// BUT-1210: reusable harness for asserting against the a11y announce channel
// that `SemanticsService.announce` publishes onto.
//
// `SemanticsService.announce(message, dir)` encodes
//   {"type": "announce", "data": {"message": <String>, "textDirection": <int>}}
// with the Standard message codec and pushes it onto the platform message
// channel named `flutter/accessibility`. There is no public Dart-side API to
// observe those payloads, so this harness installs a mock *outgoing* decoded
// message handler on that channel via the test binding's binary messenger and
// records every announced message string.
//
// Honesty contract: this intercepts the REAL channel that the REAL
// `SemanticsService.announce` writes to. It does not stub or replace
// `SemanticsService`. A test that asserts a captured value is therefore proving
// that production code actually announced — not that a mock was called.
//
// Pair the captured strings with the live `AppLocalizations` value (resolve via
// the pumped tree), never a hardcoded literal, so a copy edit to the ARB does
// not break the assertion.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures `SemanticsService.announce` payloads for the lifetime of a test.
///
/// Usage:
/// ```dart
/// final announces = AnnounceChannel.arm(tester);
/// // ... drive the UI ...
/// expect(announces.messages, [l10n.a11yOcrComplete]);
/// announces.dispose(); // or rely on the auto-teardown registered by [arm]
/// ```
class AnnounceChannel {
  AnnounceChannel._(this._tester);

  final WidgetTester _tester;
  final List<String> _messages = <String>[];

  static const String _channelName = 'flutter/accessibility';
  static const StandardMessageCodec _codec = StandardMessageCodec();

  /// Every announced message string, in the order announced.
  List<String> get messages => List.unmodifiable(_messages);

  /// The most recently announced message, or null if nothing was announced.
  String? get last => _messages.isEmpty ? null : _messages.last;

  /// Number of announcements captured so far.
  int get count => _messages.length;

  /// Forget all captured messages without removing the interceptor — handy for
  /// asserting "no FURTHER announce" across a second interaction.
  void reset() => _messages.clear();

  /// Installs the interceptor on the accessibility channel and registers an
  /// `addTearDown` that removes it. Returns the live capture handle.
  static AnnounceChannel arm(WidgetTester tester) {
    final channel = AnnounceChannel._(tester);
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      const BasicMessageChannel<dynamic>(_channelName, _codec),
      (dynamic message) async {
        if (message is Map) {
          final type = message['type'];
          final data = message['data'];
          if (type == 'announce' && data is Map) {
            final text = data['message'];
            if (text is String) channel._messages.add(text);
          }
        }
        return null;
      },
    );

    addTearDown(channel.dispose);
    return channel;
  }

  /// Removes the interceptor. Safe to call more than once (idempotent) and is
  /// also registered as an `addTearDown` by [arm].
  void dispose() {
    _tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
      const BasicMessageChannel<dynamic>(_channelName, _codec),
      null,
    );
  }
}

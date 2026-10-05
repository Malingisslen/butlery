/// BUT-941: Dart side of the native incoming-share bridge.
///
/// Receives image file paths captured by the native share handler
/// (`MainActivity.kt` on Android; an iOS share extension lands in Stage 2)
/// and exposes them to the bootstrap handler that routes them into the
/// existing photo-import pipeline.
///
/// On web (and, until Stage 2, iOS) this is a no-op returning nothing.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:butlery/core/utils/logger.dart';

class IncomingShareService {
  IncomingShareService({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('se.butlery.app/incoming_share') {
    // Only Android delivers shares today; skip the handler elsewhere so the
    // stream simply never emits.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _channel.setMethodCallHandler(_handleNativeCall);
    }
  }

  final MethodChannel _channel;
  final StreamController<List<String>> _mediaController =
      StreamController<List<String>>.broadcast();
  final StreamController<String> _textController =
      StreamController<String>.broadcast();

  /// Warm-start shares (app already running). Emits the image path list.
  Stream<List<String>> get mediaStream => _mediaController.stream;

  /// Warm-start text shares (BUT-2241): a link or recipe text.
  Stream<String> get textStream => _textController.stream;

  /// Cold-start: the launch intent's shared images, if any. Returns an empty
  /// list on non-Android/web or when the app wasn't launched from a share.
  Future<List<String>> getInitialSharedImages() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const [];
    }
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getInitialMedia',
      );
      return _coercePaths(result);
    } on PlatformException catch (e) {
      AppLogger.warning('IncomingShareService.getInitialMedia failed: $e');
      return const [];
    }
  }

  /// Cold-start: the launch intent's shared text, or null.
  Future<String?> getInitialSharedText() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      return _coerceText(
        await _channel.invokeMethod<Object?>('getInitialText'),
      );
    } on PlatformException catch (e) {
      AppLogger.warning('IncomingShareService.getInitialText failed: $e');
      return null;
    }
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onText') {
      final text = _coerceText(call.arguments);
      if (text != null && !_textController.isClosed) {
        _textController.add(text);
      }
      return;
    }
    if (call.method == 'onMedia') {
      final paths = _coercePaths(call.arguments as List<dynamic>?);
      if (paths.isNotEmpty && !_mediaController.isClosed) {
        _mediaController.add(paths);
      }
    }
  }

  /// Native sends a `List<String>`; coerce defensively (the platform channel
  /// types it as `List<dynamic>`) and drop any non-string/empty entries.
  static List<String> _coercePaths(List<dynamic>? raw) {
    if (raw == null) return const [];
    return raw
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
  }

  static String? _coerceText(Object? raw) =>
      raw is String && raw.trim().isNotEmpty ? raw : null;

  void dispose() {
    if (!_mediaController.isClosed) {
      _mediaController.close();
    }
    if (!_textController.isClosed) {
      _textController.close();
    }
  }
}

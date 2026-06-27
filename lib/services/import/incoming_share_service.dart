/// BUT-941: Dart side of the native incoming-photo-share bridge.
///
/// Receives image file paths captured by the native share handler
/// (`MainActivity.kt` on Android; an iOS share extension lands in Stage 2)
/// and exposes them to the bootstrap handler that routes them into the
/// existing photo-import pipeline.
///
/// Two surfaces, mirroring the deep-link lifecycle:
///  - [getInitialSharedImages] — cold-start: the launch intent's images,
///    consumed once.
///  - [mediaStream] — warm-start: the user shares while the app is running.
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

  /// Warm-start shares (app already running). Emits the image path list.
  Stream<List<String>> get mediaStream => _mediaController.stream;

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

  Future<dynamic> _handleNativeCall(MethodCall call) async {
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

  void dispose() {
    if (!_mediaController.isClosed) {
      _mediaController.close();
    }
  }
}

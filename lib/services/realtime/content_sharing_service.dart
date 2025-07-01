// lib/services/realtime/content_sharing_service.dart

import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'event_bus_service.dart';

/// Event triggered when content has been shared.
class ContentSharedEvent {
  final String content;
  ContentSharedEvent(this.content);
}

/// Service responsible for handling outgoing share actions.
///
/// It wraps [Share.share] and notifies listeners through [EventBusService]
/// so other parts of the app can react to a share action.
class ContentSharingService {
  final EventBusService _eventBus;

  ContentSharingService({required EventBusService eventBus})
      : _eventBus = eventBus;

  /// Share arbitrary text with the platform share sheet and
  /// emit a [ContentSharedEvent] when done.
  Future<void> shareText(String text) async {
    try {
      await Share.share(text);
      _eventBus.publish(ContentSharedEvent(text));
    } catch (e) {
      debugPrint('❌ Failed to share text: $e');
    }
  }

  /// Share a link composed of [title] and [url].
  Future<void> shareLink(String title, String url) async {
    final payload = '$title\n$url';
    await shareText(payload);
  }
}

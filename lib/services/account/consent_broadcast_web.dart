import 'dart:js_interop';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:web/web.dart' as web;

/// BroadcastChannel name. Consumers in every tab hit the same channel.
const _channelName = 'butlery_consent_v1';

/// Sentinel payload posted on cache invalidation. The channel only carries
/// invalidation events today, so we don't need a discriminator — any
/// message means "clear your cache."
const _invalidatePayload = 'invalidate';

/// Lazy singleton — the channel must outlive any single ConsentService
/// instance for late subscribers to receive messages, but creating
/// multiple BroadcastChannels with the same name in one tab is wasteful.
web.BroadcastChannel? _channel;

web.BroadcastChannel _ensureChannel() {
  return _channel ??= web.BroadcastChannel(_channelName);
}

/// Web-only: post a cache-invalidation message to every other tab on this
/// origin. The originating tab does NOT receive its own message — the
/// browser elides it — so callers don't need to guard against echo.
void broadcastConsentInvalidation() {
  try {
    _ensureChannel().postMessage(_invalidatePayload.toJS);
  } catch (_) {
    // BroadcastChannel can fail if the page was closed mid-call or the
    // browser blocked it (Safari private mode etc.). Best-effort — local
    // cache clear has already happened in the caller.
  }
}

/// Web-only: register `onInvalidate` to fire when another tab broadcasts a
/// cache-invalidation message. Idempotent per channel — safe to call once
/// in service init.
void listenForConsentInvalidation(VoidCallback onInvalidate) {
  try {
    final channel = _ensureChannel();
    channel.onmessage = ((web.MessageEvent _) => onInvalidate()).toJS;
  } catch (_) {
    // Same failure mode as broadcast — best-effort.
  }
}

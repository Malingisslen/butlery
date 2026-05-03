import 'package:flutter/foundation.dart' show VoidCallback;

/// Native-platform no-op for cross-tab consent invalidation.
/// On Android/iOS/desktop a single ConsentService instance owns the cache
/// for the whole process — no other tab/process exists to invalidate.
void broadcastConsentInvalidation() {}

/// Native-platform no-op listener registration.
void listenForConsentInvalidation(VoidCallback onInvalidate) {}

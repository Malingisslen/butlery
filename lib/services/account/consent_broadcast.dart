/// Cross-tab consent cache invalidation (BUT-460).
///
/// On web, multiple tabs each hold their own [ConsentService] instance with
/// its own in-memory cache. Logout in tab A only clears tab A's cache —
/// tab B keeps stale consent until it reads from Firestore again. This
/// module bridges that gap via `BroadcastChannel` (web-only); native
/// platforms get a no-op implementation.
export 'consent_broadcast_stub.dart'
    if (dart.library.js_interop) 'consent_broadcast_web.dart';

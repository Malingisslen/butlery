/// Service for managing PWA install prompt on web platform.
/// Uses conditional imports to avoid dart:js_interop on non-web platforms.
export 'pwa_install_service_stub.dart'
    if (dart.library.js_interop) 'pwa_install_service_web.dart';

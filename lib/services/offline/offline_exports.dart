/// Conditional exports for offline services.
/// Uses native implementation on mobile/desktop, stubs on web.
library;

// Export the appropriate offline implementation based on platform
export 'offline_initialization.dart'
    if (dart.library.html) 'offline_initialization_stub.dart';

export 'offline_user_storage.dart'
    if (dart.library.html) 'offline_user_storage_stub.dart';

export 'offline_sync_manager.dart'
    if (dart.library.html) 'offline_sync_manager_stub.dart';

// Always export sync_result (no platform-specific code)
export 'sync_result.dart';

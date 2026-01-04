/// Conditional database export for cross-platform support.
/// Uses native SQLite on mobile/desktop, stub on web.
library;

export 'app_database.dart' if (dart.library.html) 'app_database_stub_web.dart';

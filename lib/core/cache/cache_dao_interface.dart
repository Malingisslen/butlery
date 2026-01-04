/// Conditional export for CacheDao - uses native on mobile/desktop, stub on web
library;

export 'package:butlery/core/storage/drift/daos/cache_dao.dart'
    if (dart.library.html) 'package:butlery/core/cache/cache_dao_stub.dart';

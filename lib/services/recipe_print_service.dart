/// Conditional export for recipe printing — web uses HTML, stub is no-op.
export 'recipe_print_service_stub.dart'
    if (dart.library.js_interop) 'recipe_print_service_web.dart';

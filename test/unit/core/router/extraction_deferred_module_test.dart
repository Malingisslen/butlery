/// BUT-2241: the route arguments decide whether Smart import starts by itself.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/router/modules/extraction_deferred_module.dart';
import 'package:butlery/core/router/shared_import_route.dart';
import 'package:butlery/views/smart_import_view.dart';

void main() {
  late ExtractionDeferredModule module;

  setUp(() async {
    module = ExtractionDeferredModule();
    await module.load();
  });

  SmartImportView build(Object? arguments) =>
      module.buildRoute(
            Routes.smartImport,
            RouteSettings(name: Routes.smartImport, arguments: arguments),
          )
          as SmartImportView;

  test('SmartImportRouteArgs reach the view with their autoStart', () {
    const url = 'https://www.ica.se/recept/x/';

    final started = build(const SmartImportRouteArgs(url));
    expect(started.initialUrl, url);
    expect(started.autoStart, isTrue);

    final prefilled = build(const SmartImportRouteArgs(url, autoStart: false));
    expect(prefilled.autoStart, isFalse);
  });

  test('a plain String only prefills', () {
    final view = build('https://www.ica.se/recept/x/');

    expect(view.initialUrl, 'https://www.ica.se/recept/x/');
    expect(view.autoStart, isFalse);
  });
}

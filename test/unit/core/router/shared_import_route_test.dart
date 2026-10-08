/// BUT-2241: where a shared text lands. A link starts Smart import on its own;
/// any other text opens the text import, filled in.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/router/shared_import_route.dart';

void main() {
  test('a bare link starts Smart import on that link', () {
    final route = routeForSharedText('https://www.ica.se/recept/pannkakor-1/');

    expect(route?.route, Routes.smartImport);
    final args = route?.arguments as SmartImportRouteArgs;
    expect(args.url, 'https://www.ica.se/recept/pannkakor-1/');
    expect(args.autoStart, isTrue);
  });

  test('a caption with a link inside starts Smart import on the link', () {
    final route = routeForSharedText(
      'Kolla in det här!\nhttps://www.arla.se/recept/kladdkaka/ via Chrome',
    );

    expect(route?.route, Routes.smartImport);
    expect(
      (route?.arguments as SmartImportRouteArgs).url,
      'https://www.arla.se/recept/kladdkaka/',
    );
  });

  test('text without a link opens the text import, trimmed', () {
    final route = routeForSharedText('  2 dl mjölk\n3 ägg\nVispa ihop.  ');

    expect(route?.route, Routes.fromSocialMedia);
    expect(route?.arguments, '2 dl mjölk\n3 ägg\nVispa ihop.');
  });

  test('punctuation closing a sentence around the link is not part of it', () {
    final route = routeForSharedText(
      'Receptet (https://www.ica.se/recept/x/). Testa!',
    );

    expect(
      (route?.arguments as SmartImportRouteArgs).url,
      'https://www.ica.se/recept/x/',
    );
  });

  test('autoStart false hands the link over to prefill only', () {
    final route = routeForSharedText(
      'https://www.ica.se/recept/x/',
      autoStart: false,
    );

    expect((route?.arguments as SmartImportRouteArgs).autoStart, isFalse);
  });

  test('the first link wins, and plain http counts', () {
    final route = routeForSharedText(
      'http://www.ica.se/recept/a/ eller https://www.arla.se/recept/b/',
    );

    expect(
      (route?.arguments as SmartImportRouteArgs).url,
      'http://www.ica.se/recept/a/',
    );
  });

  test('blank text goes nowhere', () {
    expect(routeForSharedText('   \n '), isNull);
  });
}

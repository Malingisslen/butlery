/// BUT-2241: where a shared text lands. A link starts Smart import on its own,
/// a recipe text keeps its link as the source, and any other text opens the
/// text import, filled in.
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

  test('a recipe text with its source link keeps the text and the link', () {
    const text =
        'Pannkakor\n3 dl mjöl\n6 dl mjölk\n3 ägg\nVispa ihop och stek.\n'
        'Källa: https://www.ica.se/recept/pannkakor-1/';
    final route = routeForSharedText('  $text  ');

    expect(route?.route, Routes.fromSocialMedia);
    final args = route?.arguments as SharedTextImportArgs;
    expect(args.text, text);
    expect(args.sourceUrl, 'https://www.ica.se/recept/pannkakor-1/');
  });

  test('three lines around the link are a recipe, two are a blurb', () {
    const link = 'https://www.ica.se/recept/x/';
    expect(
      routeForSharedText('Pannkakor\nMjöl, mjölk\n$link')?.route,
      Routes.smartImport,
    );
    expect(
      routeForSharedText(
        'Pannkakor\nMjöl, mjölk\nVispa och stek\n$link',
      )?.route,
      Routes.fromSocialMedia,
    );
  });

  test('a caption with hashtags is a blurb, not a recipe', () {
    final route = routeForSharedText(
      'Så steker du 5 st ägg #bake #cook #grill\n'
      'https://www.instagram.com/reel/abc/',
    );

    expect(route?.route, Routes.smartImport);
  });

  test('recipe words inside the link itself do not count as a recipe', () {
    final route = routeForSharedText(
      'https://www.ica.se/recept/stek-3-dl-mjolk-och-vispa-ihop-500-g/',
    );

    expect(route?.route, Routes.smartImport);
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

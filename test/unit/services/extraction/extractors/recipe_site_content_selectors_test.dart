// BUT-2075: the content step tries every selector it is given, from the
// first one. Structured data is read by its own scripts before that step, so
// nothing in the list is passed over by position.
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/extraction/extractors/recipe_site_content_extractor.dart';

class _MockController extends Mock implements InAppWebViewController {}

void main() {
  test('every selector is tried, in order', () async {
    final controller = _MockController();
    final scripts = <String>[];
    when(
      () => controller.evaluateJavascript(source: any(named: 'source')),
    ).thenAnswer((call) async {
      scripts.add(call.namedArguments[#source] as String);
      return null;
    });

    final extractor = RecipeSiteContentExtractor(
      isDisposed: () => false,
      selectors: const ['.first', '.second', '.third'],
    );

    expect(await extractor.extract(controller), isNull);

    final queried = [
      for (final s in scripts)
        RegExp(r"querySelector\('([^']+)'\)").firstMatch(s)?.group(1),
    ].whereType<String>().toList();
    // The microdata step's own query comes before the list.
    expect(queried.first, contains('itemtype'));
    expect(queried.skip(1), ['.first', '.second', '.third']);
  });
}

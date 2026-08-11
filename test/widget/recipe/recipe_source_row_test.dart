/// BUT-1819: the source row is drawn as a LINK only when the value is one.
///
/// A unit test of `isSafeExternalUrl` proves nothing about this call site — the
/// predicate could be perfect and the widget could still ignore it. So these
/// assert on the rendered tree.
///
/// The four fixtures are four different KINDS of stored value, deliberately:
/// `'Kopierat från: Pannkakor'` is what `recipeCopiedFrom` produces — a writer
/// that exists in `lib/` but has no live caller today, kept because the shape
/// (a colon, which makes `Uri.tryParse` return null) is the one the render
/// guard has to survive;
/// `'Butlery recipe collection'` is the English seed string THIS COMMIT
/// replaced, so nothing writes it any more but every account seeded before it
/// still holds one; the https URL is a user's imported source; and the
/// `javascript:` one is hostile imported input, which is the point of it.
/// Before this change all four rendered identically:
/// underlined, icon, `Semantics(link: true)`, tappable. Two of them could never
/// open, and one of them was dangerous.
library;

import 'package:butlery/views/recipe_detail/recipe_detail_shared_widgets.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  Future<void> pumpSource(WidgetTester tester, String? sourceUrl) async {
    final recipe = RecipeFactory.build(
      title: 'Pannkakor',
      sourceUrl: sourceUrl,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                RecipeDetailSharedWidgets.buildSourceRow(context, recipe),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// True when the source value is drawn with link affordances.
  bool renderedAsLink(WidgetTester tester) {
    final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
    return semantics.any((s) => s.properties.link == true);
  }

  group('source row', () {
    testWidgets('a real https URL is a link', (tester) async {
      await pumpSource(tester, 'https://ica.se/recept/pannkakor');

      expect(renderedAsLink(tester), isTrue);
      // The link branch shortens to the HOST. `textContaining('ica.se')` would
      // not prove that — the text branch prints the full URL, which contains
      // 'ica.se' too. The path must be gone.
      expect(find.text('Från ica.se'), findsOneWidget);
      expect(find.textContaining('/recept/'), findsNothing);
    });

    testWidgets('a javascript: source is NOT a link', (tester) async {
      // The security assertion. Before this change it rendered as a tappable
      // link, and the launcher did not check the scheme either.
      await pumpSource(tester, 'javascript:alert(1)');

      expect(renderedAsLink(tester), isFalse);
      expect(find.text('javascript:alert(1)'), findsOneWidget);
    });

    testWidgets('a legacy seeded provenance sentence is plain readable text', (
      tester,
    ) async {
      // This one used to render as an underlined, tappable "Från " — the word
      // and then nothing, because `Uri.parse` yields an empty host.
      await pumpSource(tester, 'Butlery recipe collection');

      expect(renderedAsLink(tester), isFalse);
      expect(find.text('Butlery recipe collection'), findsOneWidget);
    });

    testWidgets('a copied-recipe sentence is plain readable text', (
      tester,
    ) async {
      // And this one rendered as "Från Kopierat från: Pannkakor" — doubled,
      // because `tryParse` returns null and the fallback prints the whole
      // sentence. It is the SPACE before the colon that breaks the parse, not
      // the colon: `'Recept: 4 portioner'` parses fine.
      await pumpSource(tester, 'Kopierat från: Pannkakor');

      expect(renderedAsLink(tester), isFalse);
      expect(find.text('Kopierat från: Pannkakor'), findsOneWidget);
      expect(find.textContaining('Från Kopierat'), findsNothing);
    });

    testWidgets('no source at all renders no row', (tester) async {
      await pumpSource(tester, null);

      // A boundary case, not a mutation case: `url == null` has no compilable
      // mutant, because dropping it makes `Text(url)` a null-safety error. The
      // `''` test below is the one that kills the `url.isEmpty` half. Asserted
      // as "no Text in this subtree" because the pump renders `buildSourceRow`
      // and nothing else — the earlier `findsNothing` on a string no fixture
      // contained could not fail at all.
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('an empty source renders no row either', (tester) async {
      // The other half of the guard. Only `null` was covered, so `url.isEmpty`
      // could have been deleted with every test still green — and it is the
      // branch a blanked `javascript:` source lands in after sanitization.
      await pumpSource(tester, '');

      expect(find.byType(Text), findsNothing);
    });
  });
}

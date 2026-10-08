// P5-U05 (hem ERROR): an error in one section never empties the whole view
// (produktregler.md:297). The recipe section's error box says what happened,
// what was kept and offers Försök igen (produktregler.md:298).

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/views/mina_recept_view.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  final l10n = AppLocalizationsSv();

  test('an error with fetched recipes keeps the library', () {
    expect(
      MinaReceptSectionError.emptiesView(hasError: true, hasRecipes: true),
      isFalse,
    );
  });

  test('only an error with nothing to show takes the view', () {
    expect(
      MinaReceptSectionError.emptiesView(hasError: true, hasRecipes: false),
      isTrue,
    );
    expect(
      MinaReceptSectionError.emptiesView(hasError: false, hasRecipes: false),
      isFalse,
    );
  });

  testWidgets('the box says what happened, what was kept, and retries', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: MinaReceptSectionError(onRetry: () => retried++),
      ),
    );

    expect(find.text(l10n.minaReceptRefreshFailed), findsOneWidget);
    expect(find.text(l10n.minaReceptRefreshPreserved), findsOneWidget);
    await tester.tap(find.byKey(InlineError.actionKey));
    expect(retried, 1);
  });
}

// BUT-1338: Behavioural gate for FaqView.
//
// FaqView has NO ViewModel and NO ServiceLocator dependency. After BUT-1338 its
// Q&A copy is sourced from l10n (app_sv.arb / app_en.arb) instead of hardcoded
// strings. This test proves the 5 FAQ questions render from the Swedish locale,
// so a regression that drops a tile or mis-wires an l10n key is caught.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/views/faq_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('FaqView (BUT-1338)', () {
    testWidgets('renders all 5 FAQ questions from Swedish l10n', (
      tester,
    ) async {
      final sv = AppLocalizationsSv();

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const FaqView(),
        ),
      );
      await tester.pumpAndSettle();

      for (final question in [
        sv.faqQ1,
        sv.faqQ2,
        sv.faqQ3,
        sv.faqQ4,
        sv.faqQ5,
      ]) {
        expect(
          find.text(question),
          findsOneWidget,
          reason: 'Each FAQ question tile must render its Swedish l10n text.',
        );
      }
    });
  });
}

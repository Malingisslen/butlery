// The page shown when a deferred module fails to load draws the one shared
// top bar (beslutslogg.md:52, B-45), not the retired AdaptiveAppBar
// (package 7, P7-B1).

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/routing/deferred_route_loader.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('the module error page has the subpage top bar with its title', (
    tester,
  ) async {
    var retried = 0;
    var wentHome = 0;
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: ModuleLoadErrorScreen(
          error: StateError('boom'),
          onRetry: () => retried++,
          onGoHome: () => wentHome++,
        ),
      ),
    );
    await tester.pump();

    final sv = AppLocalizationsSv();
    expect(find.byType(ButleryTopBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ButleryTopBar),
        matching: find.text(sv.errorTitle),
      ),
      findsOneWidget,
    );
    // The raw error is never shown.
    expect(find.textContaining('boom'), findsNothing);

    await tester.tap(find.text(sv.commonRetry));
    await tester.tap(find.text(sv.navigationGoHome));
    expect(retried, 1);
    expect(wentHome, 1);
  });
}

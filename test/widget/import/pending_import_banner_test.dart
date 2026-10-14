import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/views/smart_import/import_widgets.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('the pending-import banner lays out under the app theme', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: PendingImportBanner(
          onRetry: () => retried = true,
          onDismiss: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Försök igen'));
    expect(retried, isTrue);
  });

  testWidgets('Släng dismisses the pending import without retrying it', (
    tester,
  ) async {
    var retried = 0;
    var dismissed = 0;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: PendingImportBanner(
          onRetry: () => retried++,
          onDismiss: () => dismissed++,
        ),
      ),
    );

    await tester.tap(find.text('Släng'));

    expect(dismissed, 1);
    expect(retried, 0);
  });
}

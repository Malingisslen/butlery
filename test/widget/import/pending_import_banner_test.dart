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
}

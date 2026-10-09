// BUT-2261: "Gör samarbetslista" with no friends explains why and offers the
// friends page, like the share flow, instead of only saying "Inga vänner".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/no_friends_dialog.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });
  tearDownAll(() async => BaseUnitTest.teardownUnit());

  testWidgets('explains and opens the friends page', (tester) async {
    String? pushed;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showNoFriendsDialog(context),
            child: const Text('open'),
          ),
        ),
        onGenerateRoute: (settings) {
          pushed = settings.name;
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('friends page')),
          );
        },
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Inga vänner'), findsOneWidget);
    expect(find.text('Stäng'), findsOneWidget);

    await tester.tap(find.text('Lägg till vänner'));
    await tester.pumpAndSettle();
    expect(pushed, Routes.friends);
    expect(find.text('friends page'), findsOneWidget);
  });
}

// Mounts a screen as a pushed route above a host page, for tests whose
// outcome is "the screen closed" or "a snackbar survived the close".
//
// A screen mounted directly as the app's home route has nothing under it:
// Navigator.pop cannot be told apart from "did not pop", and the Scaffold that
// renders the snackbar is torn down together with the screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_app.dart';

const pushedRouteHostText = 'host page';
const _openLabel = 'open pushed route';

/// The host page is visible only when the pushed screen is gone, because a
/// covered route is offstage and `find` skips it.
Finder get pushedRouteHost => find.text(pushedRouteHostText);

Future<void> pumpPushedRoute(
  WidgetTester tester, {
  required WidgetBuilder builder,
}) async {
  await tester.pumpWidget(
    createLocalizedTestApp(
      child: Builder(
        builder: (hostContext) => Column(
          children: [
            const Text(pushedRouteHostText),
            TextButton(
              onPressed: () => Navigator.of(hostContext).push(
                MaterialPageRoute<void>(builder: builder),
              ),
              child: const Text(_openLabel),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.tap(find.text(_openLabel));
  await tester.pumpAndSettle();
  expect(
    pushedRouteHost,
    findsNothing,
    reason: 'the screen under test must be a route above the host',
  );
}

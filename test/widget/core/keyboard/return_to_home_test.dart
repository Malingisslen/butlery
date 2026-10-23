import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/keyboard/app_actions.dart';

// Stands in for InitializationWrapper → AuthWrapper: a static GlobalKey on the
// home route, so a second copy of `/` is a duplicate-key error.
class _KeyedHome extends StatelessWidget {
  const _KeyedHome();

  static final GlobalKey shellKey = GlobalKey(debugLabel: 'shell');

  @override
  Widget build(BuildContext context) =>
      SizedBox(key: shellKey, child: const Text('home'));
}

Widget _app(GlobalKey<NavigatorState> navigatorKey, {String? initialRoute}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    initialRoute: initialRoute,
    home: const _KeyedHome(),
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => Text('page ${settings.name}'),
    ),
  );
}

void main() {
  setUp(() => mainTabSwitchRequest.value = 2);

  testWidgets('unwinds to the existing home instead of building a second one', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(navigatorKey));
    navigatorKey.currentState!
      ..pushNamed('/a')
      ..pushNamed('/b');
    await tester.pumpAndSettle();

    AppActions.returnToHome(navigatorKey.currentState!);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(navigatorKey.currentState!.canPop(), isFalse);
    expect(find.byKey(_KeyedHome.shellKey), findsOneWidget);
    expect(mainTabSwitchRequest.value, 0);
  });

  testWidgets('a stack without home underneath gets exactly one home', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(navigatorKey, initialRoute: Routes.auth));
    navigatorKey.currentState!.pushNamedAndRemoveUntil(
      Routes.auth,
      (_) => false,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_KeyedHome.shellKey), findsNothing);

    AppActions.returnToHome(navigatorKey.currentState!);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(navigatorKey.currentState!.canPop(), isFalse);
    expect(find.byKey(_KeyedHome.shellKey), findsOneWidget);
  });
}

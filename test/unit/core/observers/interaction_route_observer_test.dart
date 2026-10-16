import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/observers/interaction_route_observer.dart';
import 'package:butlery/services/feedback/interaction_logger.dart';

void main() {
  late InteractionLogger logger;
  late GlobalKey<NavigatorState> navKey;

  List<String> trail() =>
      logger.getRecentInteractions().map((e) => e.screenName).toList();

  Future<void> pumpApp(WidgetTester tester, {Widget? home}) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [InteractionRouteObserver(logger)],
        home: Scaffold(body: home ?? const SizedBox()),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    logger = InteractionLogger();
    navKey = GlobalKey<NavigatorState>();
  });

  testWidgets('a dropdown opened and closed leaves nothing in the trail', (
    tester,
  ) async {
    await pumpApp(
      tester,
      home: DropdownButton<int>(
        value: 1,
        items: const [
          DropdownMenuItem(value: 1, child: Text('1991')),
          DropdownMenuItem(value: 2, child: Text('1992')),
        ],
        onChanged: (_) {},
      ),
    );
    final before = trail();

    await tester.tap(find.text('1991'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1992').last);
    await tester.pumpAndSettle();

    expect(trail(), before);
  });

  testWidgets('a dialog is logged as "dialog" and its pop returns to the '
      'named screen beneath', (tester) async {
    await pumpApp(tester);
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/settings'),
        builder: (_) => const Scaffold(),
      ),
    );
    await tester.pumpAndSettle();

    showDialog<void>(
      context: navKey.currentContext!,
      builder: (_) => const AlertDialog(content: Text('x')),
    );
    await tester.pumpAndSettle();
    navKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(trail().sublist(trail().length - 2), ['dialog', '/settings']);
  });

  testWidgets('a bottom sheet is logged as "sheet"', (tester) async {
    await pumpApp(tester);

    showModalBottomSheet<void>(
      context: navKey.currentContext!,
      builder: (_) => const Text('sheet body'),
    );
    await tester.pumpAndSettle();

    expect(trail().last, 'sheet');
  });

  testWidgets('a page pushed without a name is logged as "page:unnamed"', (
    tester,
  ) async {
    await pumpApp(tester);

    navKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();

    expect(trail().last, 'page:unnamed');
  });
}

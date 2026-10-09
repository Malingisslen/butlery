/// produktregler.md § 18.1: the "!" hides under a dialog or sheet and in
/// cooking mode, and returns when they close.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/observers/feedback_route_observer.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/widgets/common/feedback_fab.dart';

import '../../infrastructure/factories/mock_factory.dart';

final _navKey = GlobalKey<NavigatorState>();

Widget _app(FeedbackRouteObserver observer) => MaterialApp(
  navigatorKey: _navKey,
  navigatorObservers: [observer],
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => Scaffold(body: Text(settings.name ?? 'home')),
  ),
  builder: (context, child) => Stack(
    children: [
      child!,
      FeedbackFAB(routeObserver: observer),
    ],
  ),
);

void main() {
  late FeedbackRouteObserver observer;

  setUp(() async {
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<AuthService>(
      MockFactory.createAuthService(isAuthenticated: true),
    );
    prod.ServiceLocator.initialize(DIContainer());
    observer = FeedbackRouteObserver();
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  testWidgets('hidden while a dialog is open, shown again when it closes', (
    tester,
  ) async {
    await tester.pumpWidget(_app(observer));
    await tester.pumpAndSettle();
    expect(find.text('!'), findsOneWidget);

    showDialog<void>(
      context: _navKey.currentContext!,
      builder: (_) => const AlertDialog(title: Text('Dialog')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dialog'), findsOneWidget);
    expect(find.text('!'), findsNothing);

    _navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('!'), findsOneWidget);
  });

  testWidgets('hidden while a bottom sheet is open', (tester) async {
    await tester.pumpWidget(_app(observer));
    await tester.pumpAndSettle();

    showModalBottomSheet<void>(
      context: _navKey.currentContext!,
      builder: (_) => const SizedBox(height: 100, child: Text('Ark')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ark'), findsOneWidget);
    expect(find.text('!'), findsNothing);

    _navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('!'), findsOneWidget);
  });

  testWidgets('hidden in cooking mode, back on the screen beneath it', (
    tester,
  ) async {
    await tester.pumpWidget(_app(observer));
    await tester.pumpAndSettle();

    _navKey.currentState!.pushNamed(Routes.cookingMode);
    await tester.pumpAndSettle();
    expect(find.text('!'), findsNothing);

    _navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('!'), findsOneWidget);
  });

  testWidgets('a dialog over cooking mode closing keeps the button hidden', (
    tester,
  ) async {
    await tester.pumpWidget(_app(observer));
    _navKey.currentState!.pushNamed(Routes.cookingMode);
    await tester.pumpAndSettle();

    showDialog<void>(
      context: _navKey.currentContext!,
      builder: (_) => const AlertDialog(title: Text('Dialog')),
    );
    await tester.pumpAndSettle();
    _navKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text('!'), findsNothing);
  });
}

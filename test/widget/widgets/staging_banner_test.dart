import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/bootstrap/firebase_env.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/staging_banner.dart';

const _statusBar = 24.0;

Future<double?> _pump(WidgetTester tester, FirebaseEnv env) async {
  double? childTopPadding;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: _statusBar)),
        child: StagingBanner(
          env: env,
          child: Builder(
            builder: (context) {
              childTopPadding = MediaQuery.paddingOf(context).top;
              return const Text('appen');
            },
          ),
        ),
      ),
    ),
  );
  return childTopPadding;
}

void main() {
  testWidgets('staging draws the project above the app', (tester) async {
    final staging = FirebaseEnv.resolve('staging', emulator: false);
    final childTop = await _pump(tester, staging);

    expect(find.text('STAGING · butlery-app-staging'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('STAGING · butlery-app-staging')).dy,
      lessThan(tester.getTopLeft(find.text('appen')).dy),
    );
    // The banner covers the status bar, so the app must not pad for it again.
    expect(childTop, 0);
  });

  testWidgets('production draws no banner and leaves the app alone', (
    tester,
  ) async {
    final production = FirebaseEnv.resolve('', emulator: false);
    final childTop = await _pump(tester, production);

    expect(find.textContaining('STAGING'), findsNothing);
    expect(childTop, _statusBar);
  });
}

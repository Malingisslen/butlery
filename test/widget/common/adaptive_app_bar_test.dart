/// BUT-706: pins the platform-adaptive top bar — a CupertinoNavigationBar on
/// iOS, a Material AppBar everywhere else — and that title + actions render in
/// both. Uses debugDefaultTargetPlatformOverride so the iOS branch is provable
/// without an iOS device. The override is reset inside each test body because
/// the framework verifies debug vars are unset before tearDown runs.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/adaptive_app_bar.dart';

void main() {
  Widget host() => const MaterialApp(
        home: Scaffold(
          appBar: AdaptiveAppBar(
            title: 'Statistik',
            actions: [Icon(Icons.share)],
          ),
          body: SizedBox.shrink(),
        ),
      );

  testWidgets('renders a CupertinoNavigationBar on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Statistik'), findsOneWidget);
    expect(find.byIcon(Icons.share), findsOneWidget,
        reason: 'actions are packed into the Cupertino trailing slot');

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('renders a Material AppBar on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(CupertinoNavigationBar), findsNothing);
    expect(find.text('Statistik'), findsOneWidget);
    expect(find.byIcon(Icons.share), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('renders on iOS with no actions (null trailing path)',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        appBar: AdaptiveAppBar(title: 'Statistik'),
        body: SizedBox.shrink(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    expect(find.text('Statistik'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('preferredSize is the slimmer iOS bar height on iOS',
      (tester) async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(const AdaptiveAppBar(title: 'x').preferredSize.height, 44.0);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
        const AdaptiveAppBar(title: 'x').preferredSize.height, kToolbarHeight);

    debugDefaultTargetPlatformOverride = null;
  });
}

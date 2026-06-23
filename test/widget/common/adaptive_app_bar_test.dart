/// BUT-706: pins the platform-adaptive top bar — a CupertinoNavigationBar on
/// iOS, a Material AppBar everywhere else — and that title + actions render in
/// both. Uses debugDefaultTargetPlatformOverride so the iOS branch is provable
/// without an iOS device. The override is reset inside each test body because
/// the framework verifies debug vars are unset before tearDown runs.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
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

  testWidgets(
      'Material branch applies backgroundColor/foregroundColor/titleStyle',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        appBar: AdaptiveAppBar(
          title: 'Branded',
          backgroundColor: Color(0xFF112233),
          foregroundColor: Color(0xFFFFEEDD),
          titleStyle: TextStyle(fontSize: 21),
        ),
        body: SizedBox.shrink(),
      ),
    ));
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFF112233));
    expect(appBar.foregroundColor, const Color(0xFFFFEEDD));
    expect(tester.widget<Text>(find.text('Branded')).style?.fontSize, 21);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
      'iOS branch applies backgroundColor + foregroundColor title colour',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        appBar: AdaptiveAppBar(
          title: 'Branded',
          backgroundColor: Color(0xFF112233),
          foregroundColor: Color(0xFFFFEEDD),
        ),
        body: SizedBox.shrink(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<CupertinoNavigationBar>(find.byType(CupertinoNavigationBar))
          .backgroundColor,
      const Color(0xFF112233),
    );
    expect(tester.widget<Text>(find.text('Branded')).style?.color,
        const Color(0xFFFFEEDD));

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
      'iOS branch tints the Cupertino primaryColor with foregroundColor '
      'so the back chevron / trailing controls are branded', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    // A trailing action that reports the primaryColor it sees, proving the
    // CupertinoTheme override wraps the bar's subtree (not just the title).
    Color? seenPrimary;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AdaptiveAppBar(
          title: 'Branded',
          foregroundColor: const Color(0xFFFFEEDD),
          actions: [
            Builder(builder: (context) {
              seenPrimary = CupertinoTheme.of(context).primaryColor;
              return const Icon(CupertinoIcons.share);
            }),
          ],
        ),
        body: const SizedBox.shrink(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(seenPrimary, const Color(0xFFFFEEDD));

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('null title renders a bar with no title', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        appBar: AdaptiveAppBar(title: null),
        body: SizedBox.shrink(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.widget<AppBar>(find.byType(AppBar)).title, isNull);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a long title is single-line ellipsized', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    const longTitle = 'A very very very long screen title that would overflow';
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        appBar: AdaptiveAppBar(title: longTitle),
        body: SizedBox.shrink(),
      ),
    ));
    await tester.pumpAndSettle();

    final titleText = tester.widget<Text>(find.text(longTitle));
    expect(titleText.maxLines, 1);
    expect(titleText.overflow, TextOverflow.ellipsis);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a bottom forces a Material AppBar even on iOS, height included',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    const bottom = PreferredSize(
      preferredSize: Size.fromHeight(40),
      child: SizedBox(height: 40),
    );
    const bar = AdaptiveAppBar(title: 'Tabs', bottom: bottom);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(appBar: bar, body: SizedBox.shrink()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoNavigationBar), findsNothing,
        reason: 'no Cupertino slot for a bottom — Material on all platforms');
    expect(tester.widget<AppBar>(find.byType(AppBar)).bottom, same(bottom));
    expect(bar.preferredSize.height, kToolbarHeight + 40);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Material passes iconTheme/actionsIconTheme/systemOverlayStyle',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    const iconTheme = IconThemeData(color: Color(0xFF010203));
    const actionsIconTheme = IconThemeData(color: Color(0xFF040506));
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        appBar: AdaptiveAppBar(
          title: 'X',
          iconTheme: iconTheme,
          actionsIconTheme: actionsIconTheme,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          elevation: 0,
          scrolledUnderElevation: 4,
        ),
        body: SizedBox.shrink(),
      ),
    ));
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.iconTheme, iconTheme);
    expect(appBar.actionsIconTheme, actionsIconTheme);
    expect(appBar.systemOverlayStyle, SystemUiOverlayStyle.light);
    expect(appBar.elevation, 0);
    expect(appBar.scrolledUnderElevation, 4);

    debugDefaultTargetPlatformOverride = null;
  });
}

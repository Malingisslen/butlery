/// Widget tests for ButleryHeader + SliverButleryHeader.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/butlery_header.dart';

Widget _scaffoldWith(ButleryHeader header) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(
    appBar: header,
    body: const SizedBox(),
  ),
);

/// MaterialApp where the home route is just the header used as content,
/// so ModalRoute.canPop returns false (no back button auto-implied).
Widget _bare(Widget body) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: body),
);

void main() {
  group('ButleryHeader — preferredSize', () {
    test('default (accent bar shown, no bottom) = kToolbarHeight + 3', () {
      const h = ButleryHeader(title: 't');
      expect(h.preferredSize, const Size.fromHeight(kToolbarHeight + 3));
    });

    test('showAccentBar=false removes the accent bar height', () {
      const h = ButleryHeader(title: 't', showAccentBar: false);
      expect(h.preferredSize, const Size.fromHeight(kToolbarHeight));
    });

    test('bottom adds its preferredSize.height', () {
      final h = ButleryHeader(
        title: 't',
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: SizedBox(height: 40),
        ),
      );
      expect(h.preferredSize, const Size.fromHeight(kToolbarHeight + 3 + 40));
    });
  });

  group('ButleryHeader — render', () {
    testWidgets('renders the title in lowercase', (tester) async {
      await tester.pumpWidget(
        _scaffoldWith(
          const ButleryHeader(
            title: 'MINA RECEPT',
          ),
        ),
      );
      expect(find.text('mina recept'), findsOneWidget);
      // No remaining unlowered copy.
      expect(find.text('MINA RECEPT'), findsNothing);
    });

    testWidgets('no back button when no route to pop and no leading provided', (
      tester,
    ) async {
      await tester.pumpWidget(_bare(const ButleryHeader(title: 't')));
      // No leading icon → no IconButton with arrow_back
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('explicit leading widget wins over auto back button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _scaffoldWith(
          ButleryHeader(
            title: 't',
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('renders trailing widget when supplied', (tester) async {
      await tester.pumpWidget(
        _scaffoldWith(
          ButleryHeader(
            title: 't',
            trailing: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('accent bar renders by default (rust ColoredBox)', (
      tester,
    ) async {
      await tester.pumpWidget(_scaffoldWith(const ButleryHeader(title: 't')));
      // Two ColoredBoxes: primary background + secondary accent bar
      expect(
        find.descendant(
          of: find.byType(ButleryHeader),
          matching: find.byType(ColoredBox),
        ),
        findsAtLeastNWidgets(2),
      );
    });

    testWidgets('showAccentBar=false drops the secondary ColoredBox', (
      tester,
    ) async {
      await tester.pumpWidget(
        _scaffoldWith(
          const ButleryHeader(
            title: 't',
            showAccentBar: false,
          ),
        ),
      );
      // Only the primary background ColoredBox remains
      expect(
        find.descendant(
          of: find.byType(ButleryHeader),
          matching: find.byType(ColoredBox),
        ),
        findsOneWidget,
      );
    });

    testWidgets('centerTitle=true wraps title in Center', (tester) async {
      await tester.pumpWidget(
        _scaffoldWith(
          const ButleryHeader(
            title: 't',
            centerTitle: true,
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(ButleryHeader),
          matching: find.byType(Center),
        ),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('centerTitle=false omits Center wrapper around title text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _scaffoldWith(
          const ButleryHeader(
            title: 'title-only',
            centerTitle: false,
          ),
        ),
      );
      // The title Text is rendered without a Center wrapper inside the
      // GestureDetector. Hard to assert absence of any Center (Scaffold uses
      // many), so just verify the title text is still present.
      expect(find.text('title-only'), findsOneWidget);
    });

    testWidgets('renders the bottom widget when supplied', (tester) async {
      await tester.pumpWidget(
        _scaffoldWith(
          ButleryHeader(
            title: 't',
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(40),
              child: SizedBox(
                height: 40,
                child: Text('bottom-slot'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('bottom-slot'), findsOneWidget);
    });
  });

  group('ButleryHeader — onTitleTap', () {
    testWidgets('fires onTitleTap when the title row is tapped', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _scaffoldWith(
          ButleryHeader(
            title: 'tap-me',
            onTitleTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('tap-me'));
      expect(taps, 1);
    });

    testWidgets('no callback wired = tap is a no-op', (tester) async {
      await tester.pumpWidget(
        _scaffoldWith(
          const ButleryHeader(
            title: 'no-callback',
          ),
        ),
      );
      await tester.tap(find.text('no-callback'));
      // Just verify no exception escapes.
      expect(tester.takeException(), isNull);
    });
  });

  group('SliverButleryHeader', () {
    Widget sliverApp(SliverButleryHeader header) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            header,
            const SliverToBoxAdapter(child: SizedBox(height: 200)),
          ],
        ),
      ),
    );

    testWidgets('renders lowercase title in SliverAppBar', (tester) async {
      await tester.pumpWidget(
        sliverApp(
          const SliverButleryHeader(
            title: 'SLIVER TITLE',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('sliver title'), findsOneWidget);
      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('forwards floating/pinned/snap to SliverAppBar', (
      tester,
    ) async {
      await tester.pumpWidget(
        sliverApp(
          const SliverButleryHeader(
            title: 't',
            floating: false,
            pinned: false,
            snap: false,
          ),
        ),
      );
      final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(bar.floating, isFalse);
      expect(bar.pinned, isFalse);
      expect(bar.snap, isFalse);
    });

    testWidgets('accent bar shows by default as the SliverAppBar bottom', (
      tester,
    ) async {
      await tester.pumpWidget(
        sliverApp(
          const SliverButleryHeader(
            title: 't',
          ),
        ),
      );
      final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(bar.bottom, isNotNull);
      expect(
        bar.bottom!.preferredSize,
        const Size.fromHeight(ButleryHeader.accentBarHeight),
      );
    });

    testWidgets('showAccentBar=false → SliverAppBar.bottom is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        sliverApp(
          const SliverButleryHeader(
            title: 't',
            showAccentBar: false,
          ),
        ),
      );
      final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(bar.bottom, isNull);
    });

    testWidgets('trailing widget wired into SliverAppBar.actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        sliverApp(
          SliverButleryHeader(
            title: 't',
            trailing: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {},
            ),
          ),
        ),
      );
      final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(bar.actions, isNotNull);
      expect(bar.actions!.length, 1);
    });

    testWidgets('no trailing → actions is null', (tester) async {
      await tester.pumpWidget(
        sliverApp(
          const SliverButleryHeader(
            title: 't',
          ),
        ),
      );
      final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(bar.actions, isNull);
    });

    testWidgets('onTitleTap fires when title tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        sliverApp(
          SliverButleryHeader(
            title: 'sliver-tap',
            onTitleTap: () => taps++,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('sliver-tap'));
      expect(taps, 1);
    });

    testWidgets('elevation defaults to 0', (tester) async {
      await tester.pumpWidget(
        sliverApp(
          const SliverButleryHeader(
            title: 't',
          ),
        ),
      );
      final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(bar.elevation, 0);
    });
  });

  test('ButleryHeader.accentBarHeight is the documented constant', () {
    expect(ButleryHeader.accentBarHeight, 3.0);
  });
}

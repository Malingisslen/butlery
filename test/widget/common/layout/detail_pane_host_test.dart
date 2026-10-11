// BUT-723: DetailPaneHost on a phone, in portrait and on a tablet held in
// landscape. Pages are stand-ins; the app router is not built here.

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/layout/detail_pane.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

final _sv = AppLocalizationsSv();

Route<dynamic>? _routes(RouteSettings settings) {
  final name = settings.name;
  if (name == '/leaf') {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => Scaffold(
        body: const Text('leaf page'),
        bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
      ),
    );
  }
  if (name == '/simple') {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => LayoutScaffolds.simpleLayout(
        body: const Text('simple page'),
        showBottomNav: true,
      ),
    );
  }
  if (name == '/a' || name == '/b' || name == '/inner') {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text('page $name')),
        body: name == '/b' || name == '/inner'
            ? const SizedBox.shrink()
            : TextButton(
                onPressed: () => openDetail(context, '/inner'),
                child: const Text('push inner'),
              ),
      ),
    );
  }
  return null;
}

class _Master extends StatelessWidget {
  const _Master();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const Text('the list'),
        TextButton(
          onPressed: () => openDetail(context, '/a', selectionKey: 'a'),
          child: const Text('open a'),
        ),
        TextButton(
          onPressed: () => openDetail(context, '/b', selectionKey: 'b'),
          child: const Text('open b'),
        ),
        TextButton(
          onPressed: () => DetailPaneScope.maybeOf(context)?.offerFirst(
            const RouteSettings(name: '/b'),
            key: 'b',
          ),
          child: const Text('offer b'),
        ),
        Builder(
          builder: (context) => Text(
            DetailPaneScope.maybeOf(context)?.isSelected('a') ?? false
                ? 'a marked'
                : 'a unmarked',
          ),
        ),
      ],
    ),
  );
}

Widget _app({Widget? master}) => MaterialApp(
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.lightTheme,
  onGenerateRoute: _routes,
  home: DetailPaneHost(
    master: master ?? const _Master(),
    onGenerateRoute: _routes,
  ),
);

void _size(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

DetailPaneController _controller(WidgetTester tester) =>
    DetailPaneScope.maybeOf(tester.element(find.text('the list')))!;

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Iterable<String> _labelsUnder(SemanticsNode node) sync* {
  if (node.label.isNotEmpty) yield node.label;
  final children = <SemanticsNode>[];
  node.visitChildren((c) {
    children.add(c);
    return true;
  });
  for (final c in children) {
    yield* _labelsUnder(c);
  }
}

void main() {
  for (final size in const [Size(360, 800), Size(800, 1280)]) {
    testWidgets('${size.width.toInt()} x ${size.height.toInt()}: a tap '
        'pushes a full-screen page', (tester) async {
      _size(tester, size.width, size.height);
      await tester.pumpWidget(_app());

      expect(
        DetailPaneScope.maybeOf(tester.element(find.text('the list'))),
        isNull,
      );

      await _tap(tester, 'open a');

      expect(find.text('page /a'), findsOneWidget);
      expect(find.text('the list'), findsNothing);
    });
  }

  group('1280 x 800', () {
    testWidgets('shows list and detail, and a tap swaps the detail', (
      tester,
    ) async {
      _size(tester, 1280, 800);
      await tester.pumpWidget(_app());

      await _tap(tester, 'open a');
      expect(find.text('the list'), findsOneWidget);
      expect(find.text('page /a'), findsOneWidget);
      expect(find.text('a marked'), findsOneWidget);

      await _tap(tester, 'open b');
      expect(find.text('the list'), findsOneWidget);
      expect(find.text('page /b'), findsOneWidget);
      expect(find.text('page /a'), findsNothing);
      expect(find.text('a unmarked'), findsOneWidget);
    });

    testWidgets('an empty surface until something is offered or picked', (
      tester,
    ) async {
      _size(tester, 1280, 800);
      await tester.pumpWidget(_app());

      expect(find.byType(Navigator), findsOneWidget);
      expect(find.textContaining('page /'), findsNothing);
    });

    testWidgets('an offer shows before any tap and a pick is never replaced', (
      tester,
    ) async {
      _size(tester, 1280, 800);
      await tester.pumpWidget(_app());

      await _tap(tester, 'offer b');
      expect(find.text('page /b'), findsOneWidget);

      await _tap(tester, 'open a');
      expect(find.text('page /a'), findsOneWidget);

      await _tap(tester, 'offer b');
      expect(find.text('page /a'), findsOneWidget);
      expect(find.text('page /b'), findsNothing);
    });

    testWidgets('a push from inside the detail stays on the right and '
        'system back pops it there first', (tester) async {
      _size(tester, 1280, 800);
      await tester.pumpWidget(_app());
      await _tap(tester, 'open a');

      await _tap(tester, 'push inner');
      expect(find.text('page /inner'), findsOneWidget);
      expect(find.text('the list'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('page /inner'), findsNothing);
      expect(find.text('page /a'), findsOneWidget);
      expect(find.text('the list'), findsOneWidget);
    });

    testWidgets('on the first page, system back leaves the host', (
      tester,
    ) async {
      _size(tester, 1280, 800);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('sv'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DetailPaneHost(
                    master: const _Master(),
                    onGenerateRoute: _routes,
                  ),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await _tap(tester, 'go');
      await _tap(tester, 'open a');
      expect(find.text('page /a'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('go'), findsOneWidget);
      expect(find.text('the list'), findsNothing);
    });

    testWidgets('Helskärm hides the list, and back brings it back first', (
      tester,
    ) async {
      _size(tester, 1280, 800);
      await tester.pumpWidget(_app());
      await _tap(tester, 'open a');
      await _tap(tester, 'push inner');

      _controller(tester).setExpanded(true);
      await tester.pumpAndSettle();
      expect(find.text('the list'), findsNothing);
      expect(find.text('the list', skipOffstage: false), findsOneWidget);
      expect(find.text('page /inner'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(_controller(tester).expanded, isFalse);
      expect(find.text('the list'), findsOneWidget);
      expect(find.text('page /inner'), findsOneWidget);
    });

    testWidgets('the two sides are separate, labelled semantics containers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      _size(tester, 1280, 800);
      await tester.pumpWidget(_app());
      await _tap(tester, 'open a');

      final list = tester.getSemantics(
        find.bySemanticsLabel(_sv.a11yDetailPaneList),
      );
      final detail = tester.getSemantics(
        find.bySemanticsLabel(_sv.a11yDetailPaneDetail),
      );

      expect(_labelsUnder(list), contains('the list'));
      expect(_labelsUnder(list), isNot(contains('page /a')));
      expect(_labelsUnder(detail), contains('page /a'));
      expect(_labelsUnder(detail), isNot(contains('the list')));
      handle.dispose();
    });

    testWidgets('a page that pops its only route empties the right side', (
      tester,
    ) async {
      _size(tester, 1280, 800);
      await tester.pumpWidget(_app());
      await _tap(tester, 'open a');
      _controller(tester).setExpanded(true);
      await tester.pumpAndSettle();

      // What a save or a delete does: a bare pop on the pane's first page.
      Navigator.of(tester.element(find.text('page /a'))).pop();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('page /a'), findsNothing);
      expect(find.text('the list'), findsOneWidget);
      expect(_controller(tester).selected, isNull);
      expect(_controller(tester).expanded, isFalse);
      expect(find.text('a unmarked'), findsOneWidget);

      await _tap(tester, 'open a');
      expect(find.text('page /a'), findsOneWidget);
    });

    testWidgets('a page that replaces the stack keeps the selection and '
        'shows the new page', (tester) async {
      _size(tester, 1280, 800);
      await tester.pumpWidget(_app());
      await _tap(tester, 'open a');
      Navigator.of(
        tester.element(find.text('page /a')),
      ).pushNamedAndRemoveUntil('/b', (_) => false);
      await tester.pumpAndSettle();

      expect(find.text('page /b'), findsOneWidget);
      expect(_controller(tester).selected, isNotNull);
    });

    testWidgets('popping a page pushed on top keeps the selection', (
      tester,
    ) async {
      _size(tester, 1280, 800);
      await tester.pumpWidget(_app());
      await _tap(tester, 'open a');
      await _tap(tester, 'push inner');
      Navigator.of(tester.element(find.text('page /inner'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('page /a'), findsOneWidget);
      expect(_controller(tester).isSelected('a'), isTrue);
    });

    testWidgets('a leaf page beside the list draws no bottom row; on its own '
        'it does', (tester) async {
      _size(tester, 1280, 800);
      await tester.pumpWidget(_app());
      _controller(tester).open(const RouteSettings(name: '/leaf'), key: 'l');
      await tester.pumpAndSettle();
      expect(find.text('leaf page'), findsOneWidget);
      expect(find.byType(ButleryBottomNavigation), findsNothing);

      _size(tester, 360, 800);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('sv'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: const Text('leaf page'),
              bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ButleryBottomNavigation), findsOneWidget);
    });

    testWidgets('a simple-layout page beside the list draws no bottom row; '
        'on its own it does', (tester) async {
      _size(tester, 1280, 800);
      await tester.pumpWidget(_app());
      _controller(tester).open(const RouteSettings(name: '/simple'), key: 's');
      await tester.pumpAndSettle();
      expect(find.text('simple page'), findsOneWidget);
      expect(find.byType(ButleryBottomNavigation), findsNothing);

      _size(tester, 360, 800);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('sv'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.lightTheme,
          home: LayoutScaffolds.simpleLayout(
            body: const Text('simple page'),
            showBottomNav: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ButleryBottomNavigation), findsOneWidget);
    });
  });
}

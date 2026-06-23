/// Widget tests for TabbedScaffold.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/scaffolds/tabbed_scaffold.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: child,
);

class _TestApp extends StatefulWidget {
  const _TestApp({required this.tabs, required this.tabViews, this.title});
  final List<Tab> tabs;
  final List<Widget> tabViews;
  final String? title;
  @override
  State<_TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<_TestApp>
    with SingleTickerProviderStateMixin {
  late TabController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TabController(length: widget.tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TabbedScaffold(
      title: widget.title,
      tabs: widget.tabs,
      tabViews: widget.tabViews,
      controller: _controller,
    );
  }
}

void main() {
  testWidgets('renders TabBar with the supplied tabs', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _TestApp(
          title: 'Test',
          tabs: const [
            Tab(text: 'A'),
            Tab(text: 'B'),
          ],
          tabViews: const [Text('view A'), Text('view B')],
        ),
      ),
    );
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
  });

  testWidgets('renders TabBarView with the supplied tabViews', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _TestApp(
          title: 'Test',
          tabs: const [
            Tab(text: 'A'),
            Tab(text: 'B'),
          ],
          tabViews: const [Text('view A'), Text('view B')],
        ),
      ),
    );
    expect(find.byType(TabBarView), findsOneWidget);
    expect(find.text('view A'), findsOneWidget);
  });

  testWidgets('switching tabs shows the matching view', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _TestApp(
          title: 'Test',
          tabs: const [
            Tab(text: 'A'),
            Tab(text: 'B'),
          ],
          tabViews: const [Text('view A'), Text('view B')],
        ),
      ),
    );
    expect(find.text('view A'), findsOneWidget);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(find.text('view B'), findsOneWidget);
  });

  testWidgets('asserts when tabs.length != tabViews.length', (tester) async {
    expect(
      () => TabbedScaffold(
        title: 'X',
        tabs: const [Tab(text: 'A')],
        tabViews: const [Text('v1'), Text('v2')], // mismatch
      ),
      throwsAssertionError,
    );
  });

  testWidgets('title is rendered in the AppBar when provided', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _TestApp(
          title: 'Recipes',
          tabs: const [Tab(text: 'A')],
          tabViews: const [Text('view A')],
        ),
      ),
    );
    expect(find.text('Recipes'), findsOneWidget);
  });

  testWidgets('floatingActionButton forwards to BaseScaffold', (tester) async {
    final fab = FloatingActionButton(
      onPressed: () {},
      child: const Icon(Icons.add),
    );
    await tester.pumpWidget(
      _wrap(
        DefaultTabController(
          length: 1,
          child: TabbedScaffold(
            title: 'X',
            tabs: const [Tab(text: 'A')],
            tabViews: const [Text('view A')],
            floatingActionButton: fab,
          ),
        ),
      ),
    );
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('actions list forwards to BaseScaffold AppBar', (tester) async {
    await tester.pumpWidget(
      _wrap(
        DefaultTabController(
          length: 1,
          child: TabbedScaffold(
            title: 'X',
            tabs: const [Tab(text: 'A')],
            tabViews: const [Text('view A')],
            actions: [
              IconButton(icon: const Icon(Icons.search), onPressed: () {}),
            ],
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.search), findsOneWidget);
  });
}

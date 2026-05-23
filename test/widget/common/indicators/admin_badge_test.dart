/// Widget tests for AdminBadge.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/indicators/admin_badge.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders default Swedish admin label when no label given',
      (tester) async {
    await tester.pumpWidget(_wrap(const AdminBadge()));
    // Default label is AppLocale.current.adminYouAreAdmin — verify the
    // text is rendered (any non-empty Swedish string).
    expect(find.byIcon(Icons.admin_panel_settings), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, isNotEmpty);
  });

  testWidgets('renders provided label when set', (tester) async {
    await tester.pumpWidget(_wrap(const AdminBadge(label: 'Custom admin')));
    expect(find.text('Custom admin'), findsOneWidget);
  });

  testWidgets('uses admin_panel_settings icon', (tester) async {
    await tester.pumpWidget(_wrap(const AdminBadge()));
    expect(find.byIcon(Icons.admin_panel_settings), findsOneWidget);
  });

  testWidgets('container has rounded border decoration with primary tint',
      (tester) async {
    await tester.pumpWidget(_wrap(const AdminBadge()));
    final container = tester.widget<Container>(find.byType(Container).first);
    final deco = container.decoration! as BoxDecoration;
    expect(deco.borderRadius, isNotNull);
    expect(deco.color, isNotNull);
  });

  testWidgets('Row uses min size (chip-like, not full-width)', (tester) async {
    await tester.pumpWidget(_wrap(const AdminBadge()));
    final row = tester.widget<Row>(find.byType(Row));
    expect(row.mainAxisSize, MainAxisSize.min);
  });

  testWidgets('icon + text are styled with the theme primary color',
      (tester) async {
    final theme = ThemeData(
      colorScheme: const ColorScheme.light(primary: Colors.deepPurple),
    );
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: const Scaffold(body: AdminBadge(label: 'Admin')),
    ));
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, Colors.deepPurple);
    final text = tester.widget<Text>(find.text('Admin'));
    expect(text.style!.color, Colors.deepPurple);
  });
}

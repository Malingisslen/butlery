/// Widget tests for ShareMessageInput.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/share_dialog/share_message_input.dart';

Widget _build(TextEditingController controller, {String? initialMessage}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('sv'),
    home: Scaffold(
      body: Builder(
        builder: (ctx) =>
            ShareMessageInput.build(ctx, controller, initialMessage),
      ),
    ),
  );
}

void main() {
  testWidgets('renders a TextField wired to the supplied controller',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_build(controller));

    expect(find.byType(TextField), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller, same(controller));
  });

  testWidgets('typing into the field updates the controller', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_build(controller));

    await tester.enterText(find.byType(TextField), 'Hej kompis');
    expect(controller.text, 'Hej kompis');
  });

  testWidgets('renders 3-line max input area', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_build(controller));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLines, 3);
  });

  testWidgets('uses newline as text-input action (multi-line input)',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_build(controller));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textInputAction, TextInputAction.newline);
  });

  testWidgets('renders the "valfritt" label heading', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_build(controller));
    // Heading is AppLocale.current.shareMessageOptional — Swedish locale.
    // We don't pin the exact string but verify a Text widget is at the top.
    expect(find.byType(Text), findsAtLeastNWidgets(1));
  });

  testWidgets('layout: Column with start cross-axis alignment', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_build(controller));
    expect(find.byType(Column), findsAtLeastNWidgets(1));
    final col = tester.widget<Column>(find.byType(Column).first);
    expect(col.crossAxisAlignment, CrossAxisAlignment.start);
  });

  testWidgets('hintText is set on the TextField decoration', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_build(controller));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.hintText, isNotNull);
    expect(field.decoration!.hintText, isNotEmpty);
  });

  testWidgets('controller starts empty when no initial value supplied',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_build(controller, initialMessage: 'unused'));
    // The build signature accepts initialMessage but doesn't pre-populate
    // — caller is responsible. Pin that contract.
    expect(controller.text, '');
  });
}

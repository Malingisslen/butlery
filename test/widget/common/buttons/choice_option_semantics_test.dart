/// A choice pill is announced as a button and a screen reader can activate it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/buttons/choice_option.dart';

import '../../../test_support/semantics_announcement.dart';

void main() {
  testWidgets('the pill node has a tap action that picks the value', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var picked = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ChoiceOption(
            label: 'Middag',
            selected: false,
            onSelected: () => picked++,
          ),
        ),
      ),
    );

    final node = find.bySemanticsLabel('Middag');
    expectActivatable(tester, node);

    tester.semantics.tap(find.semantics.byLabel('Middag'));
    expect(picked, 1);
    handle.dispose();
  });
}

// What a shared surface shows for the people on it: their initials, and one
// "+N" for everyone past the cap or not named.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/avatar_stack.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Future<void> pump(WidgetTester tester, AvatarStack stack) async {
    await tester.pumpWidget(createLocalizedTestApp(child: stack));
    await tester.pump();
  }

  const five = ['Anna Berg', 'Bo Ek', 'Cilla Dahl', 'David Falk', 'Eva Gren'];

  testWidgets('names past maxShown show the first initials and one +N that '
      'counts the hidden names plus the unnamed members', (tester) async {
    await pump(tester, const AvatarStack(names: five, extra: 2));

    expect(find.text('AB'), findsOneWidget);
    expect(find.text('BE'), findsOneWidget);
    expect(find.text('CD'), findsOneWidget);
    // Two names are hidden and two members have no name.
    expect(find.text('+4'), findsOneWidget);
    expect(find.text('DF'), findsNothing);
    expect(find.text('EG'), findsNothing);
  });

  testWidgets('no more names than maxShown and nobody unnamed shows no +N', (
    tester,
  ) async {
    await pump(tester, const AvatarStack(names: ['Anna Berg', 'Bo Ek']));

    expect(find.text('AB'), findsOneWidget);
    expect(find.text('BE'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('unnamed members alone are one +N', (tester) async {
    await pump(tester, const AvatarStack(names: [], extra: 2));

    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('maxShown is honoured', (tester) async {
    await pump(
      tester,
      const AvatarStack(
        names: ['Anna Berg', 'Bo Ek', 'Cilla Dahl'],
        maxShown: 1,
      ),
    );

    expect(find.text('AB'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('no names and nobody else draws nothing', (tester) async {
    await pump(tester, const AvatarStack(names: []));

    expect(find.byType(Text), findsNothing);
    expect(tester.getSize(find.byType(AvatarStack)), Size.zero);
  });

  testWidgets('the initials are hidden from the semantics tree', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const AvatarStack(names: five, extra: 2));

    // Positive control: they are drawn.
    expect(find.text('AB'), findsOneWidget);
    expect(find.bySemanticsLabel('AB'), findsNothing);
    expect(find.bySemanticsLabel('+4'), findsNothing);
    handle.dispose();
  });
}

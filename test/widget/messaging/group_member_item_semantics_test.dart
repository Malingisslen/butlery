import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/messaging/components/group_member_item.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/semantics_announcement.dart';

void main() {
  Finder nameFinder() => find.bySemanticsLabel(RegExp('Anna Lindgren'));

  Future<void> pump(WidgetTester tester, {VoidCallback? onTap}) {
    return tester.pumpWidget(
      createLocalizedTestApp(
        child: GroupMemberItem(
          displayName: 'Anna Lindgren',
          onTap: onTap,
          semanticsLabel: onTap == null ? null : 'Visa profil',
        ),
      ),
    );
  }

  void expectNameOnce(WidgetTester tester) {
    final lines = announcedLines(tester, nameFinder());
    expect(lines.where((l) => l.contains('Anna Lindgren')), hasLength(1));
    expect(lines.where((l) => l.contains('Profilbild')), isEmpty);
  }

  testWidgets('a plain member row announces the name once', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    expectNameOnce(tester);
    handle.dispose();
  });

  testWidgets('a tappable member row announces the name once and activates', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, onTap: () {});

    expectNameOnce(tester);
    expectActivatable(tester, nameFinder());
    expect(announcedLines(tester, nameFinder()), contains('Visa profil'));
    expect(nameFinder(), findsOneWidget);
    handle.dispose();
  });
}

// At 200 % text the admin table keeps its header cells apart, and an admin
// tab's title keeps its words whole beside its actions.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/admin/widgets/admin_tab_header.dart';
import 'package:butlery/widgets/admin/admin_table.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/word_break_finder.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('table header cells are a gap apart', (tester) async {
    await pump(
      tester,
      const Scaffold(
        body: AdminTable(
          columns: [
            AdminTableColumn(label: 'Lyckade'),
            AdminTableColumn(label: 'Misslyckade'),
          ],
          rows: [
            AdminTableRow(cells: ['12', '3']),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final first = tester.getRect(find.byType(FittedBox).at(0));
    final second = tester.getRect(find.byType(FittedBox).at(1));
    expect(
      second.left - first.right,
      greaterThanOrEqualTo(AppDimensions.space8),
    );
  });

  testWidgets('a tab title wraps between words beside two actions', (
    tester,
  ) async {
    await pump(
      tester,
      AdminTabPage(
        title: 'Importhälsa',
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.download)),
        ],
        body: const SizedBox.shrink(),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(findMidWordBreaks(tester), isEmpty);
  });
}

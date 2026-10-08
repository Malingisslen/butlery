/// BUT-2140: the receipt after a merge into the week's list. When the list had
/// been changed on another device before the write, the receipt says so and
/// that nothing was overwritten (flows-roles-budget.md:18, the user is always
/// told about a conflict), and Ångra stays.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/veckomeny_view.dart';

final _sv = AppLocalizationsSv();

MenuShoppingMergeReceipt _receipt({required bool concurrentChange}) =>
    MenuShoppingMergeReceipt(
      listId: 'week-list',
      listName: 'Inköpslista v.24',
      addedItemIds: const ['a', 'b', 'c'],
      removedItems: const [],
      previousMenuItemIds: const [],
      replaced: false,
      createdList: false,
      concurrentChange: concurrentChange,
    );

Widget _app(void Function(BuildContext context) onTap) => MaterialApp(
  theme: AppTheme.lightTheme,
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => onTap(context),
        child: const Text('go'),
      ),
    ),
  ),
);

void main() {
  group(
    'TR::FLOW::02::lägga-till::listan-ändrad-av-annan-person-samtidigt',
    () {
      testWidgets('a change on another device is named in the receipt, and '
          'Ångra is still offered', (tester) async {
        var undone = 0;
        await tester.pumpWidget(
          _app(
            (context) => showShoppingMergeReceipt(
              context,
              _receipt(concurrentChange: true),
              onUndo: () => undone++,
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Listan hade ändrats på en annan enhet. Dina 3 varor lades till '
            'och inget skrevs över.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(_sv.shoppingMergeAdded(3, 'Inköpslista v.24')),
          findsNothing,
        );

        await tester.tap(find.text(_sv.commonUndo));
        await tester.pump();
        expect(undone, 1);
      });

      testWidgets('without a change elsewhere the ordinary receipt shows', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            (context) => showShoppingMergeReceipt(
              context,
              _receipt(concurrentChange: false),
              onUndo: () {},
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();

        expect(
          find.text(_sv.shoppingMergeAdded(3, 'Inköpslista v.24')),
          findsOneWidget,
        );
        expect(find.textContaining('annan enhet'), findsNothing);
      });
    },
  );
}

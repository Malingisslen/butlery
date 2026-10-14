// A tag in Egna taggar is a ButleryListRow: name, its subtitle, and in
// selection mode a tap that toggles it.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/personal_tags/personal_tag_selection_manager.dart';
import 'package:butlery/views/personal_tags/personal_tag_widgets.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../recipe/fake_personal_tag_viewmodel.dart';

final _now = DateTime(2026, 10, 2);

PersonalTagRule _rule(String id, {bool enabled = true}) => PersonalTagRule(
  id: id,
  name: 'Fisk',
  conditions: const [],
  isEnabled: enabled,
  createdAt: _now,
  updatedAt: _now,
);

PersonalTag _tag(String id, String name, {List<PersonalTagRule>? rules}) =>
    PersonalTag(
      id: id,
      name: name,
      createdAt: _now,
      updatedAt: _now,
      rules: rules ?? const [],
    );

void main() {
  late PersonalTagSelectionManager selection;
  late FakePersonalTagViewModel vm;

  setUp(() {
    selection = PersonalTagSelectionManager();
    vm = FakePersonalTagViewModel();
    addTearDown(selection.dispose);
    addTearDown(vm.dispose);
  });

  Future<void> pump(WidgetTester tester, List<PersonalTag> tags) async {
    vm.setState(tags: tags, usageCounts: const {'Aktiv': 34, 'Utan': 0});
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('sv', 'SE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ChangeNotifierProvider<PersonalTagSelectionManager>.value(
          value: selection,
          child: Scaffold(
            body: ListView(
              children: [
                PersonalTagSection(tags: vm.tags, viewModel: vm),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the subtitle joins recipe and rule counts', (tester) async {
    await pump(tester, [
      _tag('a', 'Aktiv', rules: [_rule('r1'), _rule('r2', enabled: false)]),
    ]);

    expect(find.text('34 recept · 1 av 2 regler på'), findsOneWidget);
  });

  testWidgets('a tag nothing uses says so instead of an empty subtitle', (
    tester,
  ) async {
    await pump(tester, [_tag('b', 'Utan')]);

    expect(find.text('Ingen användning'), findsOneWidget);
  });

  testWidgets('a tap in selection mode toggles the tag, not its page', (
    tester,
  ) async {
    await pump(tester, [_tag('a', 'Aktiv')]);
    selection.enterSelection('x');
    await tester.pump();
    expect(find.byIcon(ButleryIcons.circle), findsOneWidget);

    await tester.tap(find.text('Aktiv'));
    await tester.pump();

    expect(selection.isSelected('a'), isTrue);
    expect(find.byIcon(ButleryIcons.circleCheck), findsOneWidget);
  });
}

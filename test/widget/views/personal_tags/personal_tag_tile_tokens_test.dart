// BUT-2183 5n: the personal tag tile's avatar leaves the old opacity steps. A
// tag whose rules are switched on is the success surface tint with an
// onSuccessContainer glyph; a tag without active rules is the raised surface
// with an onSurface glyph. Each test runs in both modes and asserts the fill
// and the glyph colour.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/personal_tags/personal_tag_selection_manager.dart';
import 'package:butlery/views/personal_tags/personal_tag_widgets.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../recipe/fake_personal_tag_viewmodel.dart';

final _now = DateTime(2026, 10, 2);

PersonalTag _tag(String id, String name, {bool withActiveRule = false}) =>
    PersonalTag(
      id: id,
      name: name,
      createdAt: _now,
      updatedAt: _now,
      rules: withActiveRule
          ? [
              PersonalTagRule(
                id: 'r-$id',
                name: 'Fisk',
                conditions: const [],
                createdAt: _now,
                updatedAt: _now,
              ),
            ]
          : const [],
    );

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  final vm = FakePersonalTagViewModel()
    ..setState(
      tags: [
        _tag('a', 'Aktiv', withActiveRule: true),
        _tag('b', 'Utan'),
      ],
      usageCounts: const {'Aktiv': 2, 'Utan': 1},
    );
  addTearDown(vm.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ChangeNotifierProvider<PersonalTagSelectionManager>(
        create: (_) => PersonalTagSelectionManager(),
        child: Scaffold(
          body: ListView(
            children: [
              for (final tag in vm.tags)
                PersonalTagTile(
                  key: ValueKey(tag.id),
                  tag: tag,
                  viewModel: vm,
                ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _inTile(String name, Finder what) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
  matching: what,
);

void main() {
  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;
    final modeColors = ModeColors.of(theme.brightness);

    group('personal tag tile avatar, $mode', () {
      testWidgets(
        'a tag with active rules is the success tint with an '
        'onSuccessContainer glyph',
        (tester) async {
          await _pump(tester, theme);

          final avatar = tester.widget<CircleAvatar>(
            _inTile('Aktiv', find.byType(CircleAvatar)),
          );
          expect(avatar.backgroundColor, modeColors.surfaceTintSuccess);
          final glyph = tester.widget<Icon>(
            _inTile('Aktiv', find.byIcon(ButleryIcons.tag)),
          );
          expect(glyph.color, modeColors.onSuccessContainer);
        },
      );

      testWidgets(
        'a tag without active rules is the raised surface with an onSurface '
        'glyph',
        (tester) async {
          await _pump(tester, theme);

          final avatar = tester.widget<CircleAvatar>(
            _inTile('Utan', find.byType(CircleAvatar)),
          );
          expect(avatar.backgroundColor, cs.surfaceContainerHighest);
          final glyph = tester.widget<Icon>(
            _inTile('Utan', find.byIcon(ButleryIcons.tag)),
          );
          expect(glyph.color, cs.onSurface);
        },
      );
    });
  }
}

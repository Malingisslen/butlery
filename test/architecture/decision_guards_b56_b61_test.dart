// Guards for the design decisions B-56 to B-61 (design/beslutslogg.md). Each
// test fails when a view drifts back to the pattern the decision retired, so a
// decision cannot be undone by accident. They read source and tokens only.

import 'dart:convert';
import 'dart:io';

import 'package:butlery/core/validators/password_rule.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';
import 'package:flutter_test/flutter_test.dart';

String _source(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is gone; update the guard');
  return file
      .readAsStringSync()
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');
}

List<File> _libFiles() => [
  for (final e in Directory('lib').listSync(recursive: true))
    if (e is File &&
        e.path.endsWith('.dart') &&
        !e.path.replaceAll(r'\', '/').startsWith('lib/l10n/'))
      e,
];

void _usesAll(String decision, Map<String, List<String>> expected) {
  for (final entry in expected.entries) {
    final code = _source(entry.key);
    for (final name in entry.value) {
      expect(
        RegExp('\\b$name\\b').hasMatch(code),
        isTrue,
        reason: '$decision: ${entry.key} no longer uses $name',
      );
    }
  }
}

// Views that already gave their subpage bar a colour when the guard was
// written. The list only shrinks; a new entry means B-60 was undone.
const _ownBarColourToday = <String>[
  'lib/views/edit_recipe_view.dart',
  'lib/views/ingredient_search/ingredient_search_view.dart',
  'lib/views/sync/sync_queue_view.dart',
  'lib/widgets/common/image/fullscreen_image_viewer.dart',
];

void main() {
  group('B-56 veckomenyn är en tabell', () {
    test('grupp- och placeringsvyn ritar samma CalendarWeekGrid', () {
      _usesAll('B-56', {
        'lib/widgets/menu/group_weekly_menu_widget.dart': ['CalendarWeekGrid'],
        'lib/views/menu_placement/placement_widgets.dart': ['CalendarWeekGrid'],
      });
    });

    test('veckomenyn ritar sina celler ur de delade kalendercellerna', () {
      _usesAll('B-56', {
        'lib/widgets/menu/calendar_weekly_menu_widget.dart': [
          'calendar_cells',
          'calendar_header',
        ],
      });
      final code = _source('lib/widgets/menu/calendar_weekly_menu_widget.dart');
      expect(
        code.contains('presence_overview'),
        isTrue,
        reason: 'B-56: närvaron ligger i ett ark, inte på varje plats',
      );
    });
  });

  group('B-57 socialt', () {
    test('vyer med egen nedre åtgärd eller formulär göms bottenmenyn på', () {
      for (final path in const [
        'lib/views/social/public_profile_view.dart',
        'lib/views/messaging/create_group_conversation_view.dart',
        'lib/views/social/user_profile_edit_view.dart',
        'lib/views/social/group_detail_view.dart',
      ]) {
        expect(
          _source(path).contains('showTabBar: false'),
          isTrue,
          reason: 'B-57: $path ska sakna bottenmeny',
        );
      }
    });

    test('vännens profil behåller bottenmenyn', () {
      expect(
        _source(
          'lib/views/social/friend_profile_view.dart',
        ).contains('showTabBar: false'),
        isFalse,
        reason: 'B-57: vännens profil har bottenmenyn kvar',
      );
    });

    test('Delat med mig har flikarna Recept, Menyer och Listor', () {
      _usesAll('B-57', {
        'lib/views/social/shared_with_me/shared_content_tabs.dart': [
          'UnderlineTabs',
          'sharedTabRecipes',
          'sharedTabMenus',
          'sharedTabShoppingLists',
        ],
      });
      final arb =
          jsonDecode(File('lib/l10n/app_sv.arb').readAsStringSync())
              as Map<String, dynamic>;
      expect(arb['sharedTabRecipes'], startsWith('Recept'));
      expect(arb['sharedTabMenus'], startsWith('Menyer'));
      expect(arb['sharedTabShoppingLists'], startsWith('Listor'));
    });

    test('personer ritas som runda avatarer, inte som rutor', () {
      final code = _source('lib/widgets/image/avatar_image_widget.dart');
      expect(
        code.contains('BoxShape.circle') ||
            code.contains('ClipOval') ||
            code.contains('CircleAvatar'),
        isTrue,
        reason: 'B-57: AvatarImageWidget ska vara rund',
      );
    });
  });

  group('B-58 lösenordsregeln', () {
    test('tolv tecken eller tre ord, inget annat', () {
      expect(PasswordRule.minLength, 12);
      expect(PasswordRule.minWords, 3);
      expect(PasswordRule.accepts('elva tecken'), isFalse);
      expect(PasswordRule.accepts('tolv tecken!'), isTrue);
      expect(PasswordRule.accepts('hund katt fisk'), isTrue);
      expect(PasswordRule.accepts('a b c'), isFalse);
    });

    test('varje ställe som sätter ett lösenord frågar PasswordRule', () {
      _usesAll('B-58', {
        'lib/viewmodels/auth_viewmodel.dart': ['PasswordRule'],
        'lib/viewmodels/password_reset_viewmodel.dart': ['PasswordRule'],
        'lib/viewmodels/account_security_viewmodel.dart': ['PasswordRule'],
        'lib/views/more/sign_in_method_dialogs.dart': ['PasswordRule'],
      });
    });

    test('ingen egen längdgräns för lösenord utanför regeln', () {
      final ownLimit = RegExp(
        r'[Pp]assword\w*\.(trim\(\)\.)?length\s*(<|<=|>|>=)\s*\d+',
      );
      final found = <String>[];
      for (final file in _libFiles()) {
        final path = file.path.replaceAll(r'\', '/');
        if (path == 'lib/core/validators/password_rule.dart') continue;
        if (ownLimit.hasMatch(_source(path))) found.add(path);
      }
      expect(found, isEmpty, reason: 'B-58: använd PasswordRule.accepts');
    });

    test('inloggning kontrollerar bara att fältet inte är tomt', () {
      final code = _source('lib/viewmodels/auth_viewmodel.dart');
      expect(
        code.contains('isNewPassword && !PasswordRule.accepts'),
        isTrue,
        reason: 'B-58: regeln gäller bara nya lösenord',
      );
    });

    test('hjälptexten säger tolv tecken eller tre ord', () {
      final arb =
          jsonDecode(File('lib/l10n/app_sv.arb').readAsStringSync())
              as Map<String, dynamic>;
      final text = arb['validationPasswordRule'] as String;
      expect(text, allOf(contains('tolv'), contains('tre ord')));
    });
  });

  group('B-59 importvyerna delar komponenter', () {
    test('varje importvy bygger på sina delade komponenter', () {
      _usesAll('B-59', {
        'lib/views/importera_fran_arkiv_view.dart': ['CheckRow'],
        'lib/views/social/create_shared_shopping_list_view.dart': [
          'PersonCheckRow',
        ],
        'lib/widgets/import/batch_import_preview.dart': ['StatusRow'],
        'lib/widgets/import/voice_section_card.dart': ['VoiceMicButton'],
        'lib/views/photo_import_view.dart': ['ImageSourceButtons'],
        'lib/widgets/image/editable_image_widget.dart': ['ImageTileRow'],
      });
    });
  });

  group('B-60 ljust toppfält på undersidor', () {
    test('undersidan ritar surface och onSurface, inget grönt band', () {
      final code = _source('lib/widgets/common/butlery_top_bar.dart');
      expect(code.contains('backgroundColor ?? cs.surface'), isTrue);
      expect(code.contains('foregroundColor ?? cs.onSurface'), isTrue);
    });

    test('lightBar finns inte längre', () {
      final found = [
        for (final file in _libFiles())
          if (file.readAsStringSync().contains('lightBar')) file.path,
      ];
      expect(
        found,
        isEmpty,
        reason: 'B-60: det finns ingen annan färg att välja',
      );
    });

    test('undersidan har saffransstrecket och linjen som standard', () {
      final page = _source('lib/widgets/common/layout/butlery_page.dart');
      expect(page.contains('this.ruleUnderBar = true'), isTrue);
      final bar = _source('lib/widgets/common/butlery_top_bar.dart');
      expect(bar.contains('this.accentRule = true'), isTrue);
    });

    test('ingen vy ger undersidans fält en egen bakgrundsfärg', () {
      final found = <String>[];
      final ownColour = RegExp(
        r'ButleryTopBar\.undersida\([^)]*backgroundColor\s*:',
      );
      for (final file in _libFiles()) {
        final path = file.path.replaceAll(r'\', '/');
        if (ownColour.hasMatch(_source(path))) found.add(path);
      }
      found.sort();
      expect(found, _ownBarColourToday, reason: 'B-60: ljust överallt');
    });
  });

  group('B-61 kryssrutan är 20 px', () {
    final checkbox =
        (jsonDecode(File('design/tokens.json').readAsStringSync())
                as Map<String, dynamic>)['controls']['checkbox']
            as Map<String, dynamic>;

    test('tokens låser 20 px, radie 6, kant 1,5 och träffyta 48', () {
      expect(checkbox['size'], 20);
      expect(checkbox['radius'], 6);
      expect(checkbox['border'], 1.5);
      expect(checkbox['hitbox'], 48);
    });

    test('komponenten ritar tokens mått', () {
      expect(ButleryCheckbox.boxSize, (checkbox['size'] as num).toDouble());
    });
  });
}

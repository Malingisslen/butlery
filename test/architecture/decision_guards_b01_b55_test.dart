// Guards for the older design decisions (B-03 to B-54, kept as test names)
// that nothing else in test/ pins. Each fails when code drifts back to what
// the decision retired. Newer decisions live in decision_guards_b56_b61_test.

import 'dart:convert';
import 'dart:io';

import 'package:butlery/theme/app_dimensions.dart';
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

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<String> _libPaths() => [
  for (final e in Directory('lib').listSync(recursive: true))
    if (e is File &&
        e.path.endsWith('.dart') &&
        !e.path.replaceAll(r'\', '/').startsWith('lib/l10n/'))
      e.path.replaceAll(r'\', '/'),
];

List<String> _filesMatching(Pattern pattern) => [
  for (final path in _libPaths())
    if (_source(path).contains(pattern)) path,
]..sort();

void main() {
  final tokens = _json('design/tokens.json');

  test('B-03 träffytan är 48 dp, inte 44', () {
    expect((tokens['touchTarget'] as Map)['min'], 48);
    expect(AppDimensions.minTouchTarget, 48);
  });

  test('B-36 rumsskalan har sex steg och 20 som layoutmarginal', () {
    final space = tokens['space'] as Map<String, dynamic>;
    expect(space['scale'], [4, 8, 12, 16, 24, 32]);
    expect((space['layoutMargin'] as Map)['320'], 20);
  });

  test('B-38 radieskalan är 0 · 2 · 8 · 12 · 999', () {
    final radius = (tokens['space'] as Map)['radius'] as Map;
    expect(radius, {
      'sharp': 0,
      'knob': 2,
      'control': 8,
      'card': 12,
      'pill': 999,
    });
  });

  test('B-16 #66755C finns inte kvar i koden eller som färg', () {
    final found = <String>[];
    for (final path in _libPaths()) {
      if (RegExp('66755C', caseSensitive: false).hasMatch(_source(path))) {
        found.add(path);
      }
    }
    expect(found, isEmpty);
    final tokenLines = [
      for (final line in File('design/tokens.json').readAsLinesSync())
        if (RegExp('66755C', caseSensitive: false).hasMatch(line)) line,
    ];
    expect(tokenLines.length, 1);
    expect(tokenLines.single, contains('"removed"'));
  });

  test('B-17 navigationsetiketten heter Meny', () {
    final arb = _json('lib/l10n/app_sv.arb');
    expect(arb['navigationMenu'], 'Meny');
  });

  test('B-07 och B-50 inga kostikoner finns i ikonfamiljen', () {
    final decision = _json('design/icons.json')['diet_icons'] as Map;
    expect(decision['decision'], 'Butlery har inga kostikoner.');
    final diet = RegExp(
      r'gluten|vegan|vegetar|lakto|laktos|dairy|allerg',
      caseSensitive: false,
    );
    final found = [
      for (final e in Directory('design/assets/icons').listSync())
        if (e is File && diet.hasMatch(e.uri.pathSegments.last))
          e.uri.pathSegments.last,
    ];
    expect(found, isEmpty, reason: 'kost visas som ord, aldrig som glyf');
  });

  test(
    'B-19 clochen är varumärke: startytorna och veckomenyns färdigmoment',
    () {
      final found = _filesMatching(RegExp(r'\bButleryCloche\s*\('));
      expect(found, [
        'lib/widgets/common/brand/butlery_cloche.dart',
        'lib/widgets/common/brand/butlery_cloche_lift.dart',
        'lib/widgets/common/brand/start_splash.dart',
      ]);
      final lifts = _filesMatching(RegExp(r'\bButleryClocheLift\s*\('));
      expect(lifts, [
        'lib/views/onboarding/onboarding_setup_page.dart',
        'lib/widgets/common/brand/butlery_cloche_lift.dart',
        'lib/widgets/menu/veckomeny_cloche_reveal.dart',
      ]);
    },
  );

  test('B-46 Välj öppnar flervalet på de ytor som har det', () {
    for (final path in const [
      'lib/views/mina_recept/selection_app_bar.dart',
      'lib/views/personal_tags_view.dart',
      'lib/views/unified_shopping_view.dart',
      'lib/views/social/group_detail/group_members_list.dart',
    ]) {
      expect(
        _source(path).contains('ButlerySelectButton'),
        isTrue,
        reason: 'B-46: $path har tappat Välj',
      );
    }
  });

  test('B-47 svep-tipset ritas där det beslutades', () {
    for (final path in const [
      'lib/views/mina_recept_view.dart',
      'lib/views/cooking_mode_view.dart',
      'lib/views/social/collaborative_shopping/collaborative_shopping_items.dart',
    ]) {
      expect(_source(path).contains('SwipeHintBanner'), isTrue, reason: path);
    }
  });

  group('B-54 bottenmenyn syns på varje sida från en flik', () {
    test('undersidan har menyn som standard', () {
      final page = _source('lib/widgets/common/layout/butlery_page.dart');
      expect(page.contains('this.showTabBar = true'), isTrue);
    });

    test('bara kända fokusvyer och helskärmsformulär göms menyn på', () {
      expect(
        _filesMatching('showTabBar: false'),
        [
          'lib/views/account/pending_deletion_view.dart',
          'lib/views/auth/mfa_challenge_view.dart',
          'lib/views/edit_recipe_view.dart',
          'lib/views/family/family_member_form_view.dart',
          'lib/views/fran_sociala_medier_view.dart',
          'lib/views/menu_placement_view.dart',
          'lib/views/messaging/chat_view/chat_view_facade.dart',
          'lib/views/messaging/create_group_conversation_view.dart',
          'lib/views/quick_capture_view.dart',
          'lib/views/settings/appeal_form_view.dart',
          'lib/views/skriv_sjalv_recept_view.dart',
          'lib/views/social/create_shared_shopping_list_view.dart',
          'lib/views/social/group_detail_view.dart',
          'lib/views/social/public_profile_view.dart',
          'lib/views/social/user_profile_edit_view.dart',
          'lib/widgets/common/feedback_form_dialog.dart',
        ],
        reason: 'B-54: en ny vy som göms menyn behöver ett beslut',
      );
    });
  });
}

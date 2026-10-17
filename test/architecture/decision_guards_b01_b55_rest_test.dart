// More guards for the older design decisions (B-nn names are kept as test
// names). These cover what decision_guards_b01_b55_test leaves out: type and
// icon sources, colour token pairs, retired widgets, view modes and the
// decisions that live in a token or an enum.

import 'dart:io';

import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/decision_guard_support.dart';

void main() {
  final tokens = guardJson('design/tokens.json');
  final semantic = tokens['semantic'] as Map<String, dynamic>;
  final palette = tokens['palette'] as Map<String, dynamic>;
  final arb = guardJson('lib/l10n/app_sv.arb');

  group('B-01 Butlery Sans är enda typsnittet med äkta kursiv', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final fontsBlock = pubspec.substring(pubspec.indexOf('\n  fonts:'));

    test('pubspec deklarerar bara familjen ButlerySans', () {
      expect(
        RegExp(r'- family: (\w+)').allMatches(fontsBlock).map((m) => m[1]),
        ['ButlerySans'],
      );
    });

    test(
      'sex stilar: regular, semibold och bold, var och en med äkta kursiv',
      () {
        final assets = RegExp(
          r'asset: (\S+)',
        ).allMatches(fontsBlock).map((m) => m[1]!).toList();
        expect(assets, [
          for (final style in [
            'Regular',
            'Italic',
            'Semibold',
            'SemiboldItalic',
            'Bold',
            'BoldItalic',
          ])
            'assets/fonts/ButlerySans-0.626-$style.ttf',
        ]);
        for (final a in assets) {
          expect(File(a).existsSync(), isTrue, reason: a);
        }
      },
    );

    test('ingen vy väljer en annan fontFamily än temats', () {
      final offenders = [
        for (final path in guardLibPaths())
          for (final m in RegExp(
            r"fontFamily:\s*'([^']+)'",
          ).allMatches(guardSource(path)))
            '$path ${m[1]}',
      ];
      expect(offenders, ['lib/app/butlery_app.dart monospace']);
    });
  });

  test('B-02 ikonerna är en egen familj, inget ikonbibliotek i pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final dependencies = pubspec.substring(
      pubspec.indexOf('\ndependencies:'),
      pubspec.indexOf('\ndev_dependencies:'),
    );
    for (final lib in const [
      'lucide',
      'font_awesome',
      'phosphor',
      'feather',
      'material_symbols',
      'iconsax',
      'ionicons',
      'cupertino_icons',
      'eva_icons',
      'remixicon',
    ]) {
      expect(dependencies.contains(lib), isFalse, reason: 'B-02: $lib');
    }
  });

  test('B-08 allergener har tre tillstånd: säker, osäker, okänd', () {
    expect(TriState.values.map((v) => v.name), ['contains', 'free', 'unknown']);
  });

  test('B-12 en medlems ändring av någon annans recept blir ett förslag', () {
    expect(
      guardSource('lib/viewmodels/recipe_form_viewmodel.dart'),
      contains('suggestsChange'),
    );
    final edit = guardSource('lib/views/edit_recipe_view.dart');
    expect(edit, contains('suggestsChange'));
    expect(edit, contains('recipeSuggestChange'));
  });

  group('B-14 och B-15 saffran bär aldrig text', () {
    test('pressad saffransknapp har papperstext med minst 4,5:1', () {
      final pressedText = semantic['text.onActionPrimaryPressed'] as Map;
      final pressedBg = semantic['action.primaryPressed'] as Map;
      for (final mode in ['light', 'dark']) {
        expect(
          pressedText[mode],
          palette['paper'],
          reason: 'B-14: papper, aldrig ink',
        );
        expect(
          guardContrast(pressedText[mode] as String, pressedBg[mode] as String),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test(
      'ingen textfärg i tokens är saffran, och mörkt accenttext är #DCA968',
      () {
        for (final entry in semantic.entries.where(
          (e) => e.key.startsWith('text.'),
        )) {
          final values = entry.value as Map;
          for (final mode in ['light', 'dark']) {
            expect(
              (values[mode] as String).toUpperCase(),
              isNot((palette['saffron'] as String).toUpperCase()),
              reason: 'B-15: ${entry.key} $mode',
            );
          }
        }
        final accent = semantic['text.accent'] as Map;
        expect(accent['dark'], '#DCA968');
        expect(
          guardContrast(
            '#DCA968',
            (semantic['surface.base'] as Map)['dark'] as String,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(AppColorsDark.rustLight, const Color(0xFFDCA968));
      },
    );
  });

  test('B-18 ingen spinner och ingen shimmer i koden', () {
    final offenders = guardLibFilesMatching(
      RegExp(r'CircularProgressIndicator|RefreshProgressIndicator|Shimmer'),
    );
    expect(offenders, isEmpty);
    expect(
      File('pubspec.yaml').readAsStringSync().contains('shimmer'),
      isFalse,
    );
  });

  test('B-32 och B-42 licenstexterna för typsnittet följer med bygget', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final file in ['OFL-1.1.txt', 'THIRD_PARTY_NOTICES.txt']) {
      expect(File('assets/fonts/$file').existsSync(), isTrue);
      expect(
        pubspec.contains('- assets/fonts/$file'),
        isTrue,
        reason: 'B-32: $file ska ligga bland assets',
      );
    }
  });

  test('B-33 inköpslistan har tre lägen: platt, Min del och avdelning', () {
    expect(ShoppingViewMode.values.map((v) => v.name), [
      'all',
      'myPart',
      'byZone',
    ]);
  });

  test(
    'B-34 en kapplöpning informerar utan att erbjuda Ångra eller ta ändå',
    () {
      final text = arb['nagonAnnanTogDen'] as String;
      expect(text, contains('tog den'));
      for (final offer in [
        'Ångra',
        'ta ändå',
        'Ta ändå',
        'ta över',
        'Ta över',
      ]) {
        expect(text.contains(offer), isFalse, reason: 'B-34: $offer');
      }
    },
  );

  test('B-39 introduktionen har fyra sidor', () {
    expect(
      RegExp(
        r'_pageCount\s*=\s*4\b',
      ).hasMatch(guardSource('lib/views/onboarding/onboarding_view.dart')),
      isTrue,
    );
  });

  group('B-40 och B-41 kalendern', () {
    test('närvaroraden är 48 dp med avatarer 26 och högst tre ansikten', () {
      final presence =
          (tokens['controls'] as Map)['calendarPresenceRow'] as Map;
      expect(presence['height'], 48);
      expect(presence['avatar'], 26);
      expect(presence['maxFaces'], 3);
      expect((tokens['controls'] as Map)['avatarScale'], contains(26));
    });

    test('kalendercellen har rollen 11/600 och ingen text är 8 eller 9 px', () {
      final role =
          ((tokens['typography'] as Map)['roles'] as Map)['calendarCell']
              as Map;
      expect(role['size'], 11);
      expect(role['weight'], 600);
      expect(AppTextStyles.calendarCell.fontSize, 11);
      expect(AppTextStyles.calendarCell.fontWeight, FontWeight.w600);
      expect(
        guardLibFilesMatching(RegExp(r'fontSize:\s*(8|9)(\.0)?\s*[,)]')),
        isEmpty,
        reason: 'B-41: 8 och 9 px utgår helt',
      );
    });
  });

  test('B-44 emoji finns bara som reaktion, aldrig i Butlerys egen text', () {
    final emoji = RegExp(
      '[\u{1F300}-\u{1FAFF}\u{1F000}-\u{1F2FF}\u2600-\u27BF\u2B50\u23F1\uFE0F]',
      unicode: true,
    );
    // share_service legitimately draws the plain symbols ★ ☑ ☐ (U+2605, U+2610,
    // U+2611), so its scan drops the dingbat block the ARB scan keeps.
    final pictograph = RegExp(
      '[\u{1F300}-\u{1FAFF}\u{1F000}-\u{1F2FF}\u2B50\u23F1\uFE0F]',
      unicode: true,
    );
    for (final file in ['app_sv.arb', 'app_en.arb']) {
      final found = [
        for (final e in guardJson('lib/l10n/$file').entries)
          if (!e.key.startsWith('@') &&
              e.value is String &&
              emoji.hasMatch(e.value as String))
            e.key,
      ];
      expect(found, isEmpty, reason: 'B-44: $file');
    }
    const ownTextSources = [
      'lib/services/share_service.dart',
      'lib/services/unified/operations/personal_shopping_operations.dart',
      'lib/models/messaging/message.dart',
      'lib/models/messaging/message_type.dart',
      'lib/models/shared_menu.dart',
      'lib/models/realtime/realtime_resource.dart',
      'lib/models/unified/unified_shopping_list.dart',
      'lib/widgets/messaging/poll_message_widget.dart',
      'lib/widgets/messaging/reply_banner.dart',
      'lib/models/realtime/realtime_recipe.dart',
      'lib/widgets/common/search_filter/filter_models.dart',
      'lib/viewmodels/shopping/shopping_analytics_manager.dart',
      'lib/models/unified/unified_shopping_item.dart',
      'lib/widgets/common/indicators/connection_dot.dart',
      'lib/widgets/common/indicators/realtime_status_widgets.dart',
      'lib/widgets/social/collaborative/components/collaborative_connection_widgets.dart',
    ];
    expect(
      [
        for (final path in ownTextSources)
          if (pictograph.hasMatch(guardSource(path))) path,
      ],
      isEmpty,
      reason: 'B-44: texter som Butlery bygger själv',
    );
  });

  test(
    'B-45 ett gemensamt toppfält, ingen Cupertino-gren och inget AdaptiveAppBar',
    () {
      expect(
        guardLibFilesMatching(
          RegExp(
            r'AdaptiveAppBar|CupertinoNavigationBar|CupertinoSliverNavigationBar',
          ),
        ),
        isEmpty,
      );
    },
  );

  test('B-48 röst är en av nio importkällor', () {
    final known = ImportSource.values.where((s) => s != ImportSource.unknown);
    expect(known, hasLength(9));
    expect(ImportSource.values, contains(ImportSource.voice));
  });

  group('B-52 Mer har ingen egen Inställningar-nivå', () {
    test('/settings öppnar Appinställningar', () {
      expect(
        RegExp(
          r'case Routes\.settings:\s*return _buildRoute\(\s*const AppSettingsView\(',
        ).hasMatch(guardSource('lib/core/router/app_router.dart')),
        isTrue,
      );
    });

    test('Mers områden ritas med de delade raderna och sektionerna', () {
      for (final path in const [
        'lib/views/more/account_area_view.dart',
        'lib/views/more/privacy_area_view.dart',
        'lib/views/more/help_area_view.dart',
        'lib/views/more/more_view.dart',
      ]) {
        final code = guardSource(path);
        expect(
          code.contains('ButleryListRow') ||
              code.contains('ButleryListSection'),
          isTrue,
          reason: 'B-52: $path',
        );
      }
    });
  });

  test(
    'B-55 listor och skafferi ritas med de delade rad- och bandkomponenterna',
    () {
      for (final entry in {
        'ShoppingRow(':
            'lib/views/unified_shopping/widgets/shopping_item_tiles.dart',
        'SectionBand(':
            'lib/views/unified_shopping/widgets/shopping_list_content.dart',
      }.entries) {
        expect(
          guardSource(entry.value),
          contains(entry.key),
          reason: 'B-55: ${entry.value}',
        );
      }
      expect(
        guardSource('lib/views/pantry/pantry_view.dart'),
        contains('SectionBand('),
      );
    },
  );
}

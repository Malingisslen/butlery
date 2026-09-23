// Package 4 (P4-U01, P4-U02): the shared components adopt the design system.
//
// B-18 (beslutslogg.md:25) and produktregler.md:163: no spinner, no sliding
// bar; the plate line plus text. B-45 (beslutslogg.md:52): one top bar on
// both platforms, so the shared scaffolds draw ButleryTopBar, never a
// Material AppBar, AdaptiveAppBar or ButleryHeader. Komponentark v1:750: a
// snackbar action is never "OK".
//
// This test reddens when a spinner or an old bar comes back into one of the
// files these units cleaned.
//
// P4-U18 closes the package with a census over all of lib: the residue lists
// below name what other units left, and they only shrink.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';

/// Files P4-U01 and P4-U02 moved to the plate line.
const _plateLineFiles = [
  'lib/widgets/common/buttons/action_buttons.dart',
  'lib/widgets/common/dialogs/base_dialog.dart',
  'lib/widgets/common/dialogs/confirmation_dialogs.dart',
  'lib/widgets/common/scaffolds/form_scaffold.dart',
  'lib/widgets/common/input/debounced_button.dart',
  'lib/app/auth/auth_wrapper.dart',
  'lib/app/butlery_app.dart',
  'lib/core/providers/application_provider.dart',
  'lib/core/base/base_action_handler.dart',
  'lib/core/dialogs/dialog_factory.dart',
  'lib/core/utils/snackbar_utils.dart',
  'lib/core/router/app_router.dart',
  'lib/widgets/common/butlery_top_bar.dart',
  'lib/widgets/common/indicators/progress_overlay.dart',
  'lib/widgets/common/indicators/adaptive_activity_indicator.dart',
  'lib/widgets/common/indicators/batch_activity_bar.dart',
  'lib/widgets/common/loading/loading_widgets.dart',
  'lib/widgets/common/dialogs/retag_progress_dialog.dart',
  'lib/widgets/common/routing/deferred_route_loader.dart',
  'lib/widgets/common/service/service_widgets.dart',
  'lib/widgets/common/layout/layout_scaffolds.dart',
  'lib/widgets/common/layout_components.dart',
  'lib/widgets/common/scaffolds/base_scaffold.dart',
  'lib/widgets/common/scaffolds/loading_scaffold.dart',
  'lib/widgets/common/scaffolds/list_scaffold.dart',
  'lib/widgets/common/scaffolds/tabbed_scaffold.dart',
  'lib/widgets/common/scaffolds/empty_state_scaffold.dart',
  'lib/widgets/common/scaffolds/error_scaffold.dart',
];

/// The shared scaffolds that draw the canonical subpage top bar.
const _scaffoldFiles = [
  'lib/widgets/common/layout/layout_scaffolds.dart',
  'lib/widgets/common/layout_components.dart',
  'lib/widgets/common/scaffolds/base_scaffold.dart',
  'lib/widgets/common/scaffolds/loading_scaffold.dart',
  'lib/widgets/common/scaffolds/list_scaffold.dart',
  'lib/widgets/common/scaffolds/tabbed_scaffold.dart',
  'lib/widgets/common/scaffolds/empty_state_scaffold.dart',
  'lib/widgets/common/scaffolds/error_scaffold.dart',
  'lib/widgets/common/scaffolds/form_scaffold.dart',
];

String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//.*'), '');

List<String> _offenders(List<String> files, RegExp pattern) => [
  for (final path in files)
    if (pattern.hasMatch(_code(path))) path,
];

void main() {
  test('no spinner or sliding bar in the cleaned files (B-18)', () {
    expect(
      _offenders(
        _plateLineFiles,
        RegExp(
          r'\b(CircularProgressIndicator|LinearProgressIndicator|'
          r'CupertinoActivityIndicator|LoadingIndicator)\s*\(',
        ),
      ),
      isEmpty,
    );
  });

  test('a busy button never falls back to a generic loading word', () {
    expect(
      _offenders([
        'lib/widgets/common/buttons/action_buttons.dart',
        'lib/widgets/common/dialogs/base_dialog.dart',
        'lib/widgets/common/scaffolds/form_scaffold.dart',
      ], RegExp(r'commonLoading|commonWorking')),
      isEmpty,
    );
  });

  test('the shared scaffolds draw ButleryTopBar only (B-45)', () {
    expect(
      _offenders(
        _scaffoldFiles,
        RegExp(r'\b(AdaptiveAppBar|ButleryHeader)\s*\(|[^\w.]AppBar\s*\('),
      ),
      isEmpty,
    );
  });

  test('no snackbar action says OK (Komponentark v1:750)', () {
    final code = _code('lib/core/utils/snackbar_utils.dart');
    expect(code.contains("'OK'"), isFalse);
    expect(code.contains('commonOk'), isFalse);
  });

  group('package 4 census (P4-U18)', () {
    test('no spinner or pea pod anywhere in lib (B-18, produktregler:163)', () {
      expect(
        _offenders(
          _libFiles().where((f) => !_package7Components.contains(f)).toList(),
          _spinner,
        ),
        everyElement(isIn(_spinnerResidue)),
      );
    });

    test('views draw ButleryTopBar, never an old or bare bar (B-45)', () {
      expect(
        _offenders(
          _libFiles().where((f) => f.startsWith('lib/views/')).toList(),
          RegExp(
            r'\b(AdaptiveAppBar|MainViewHeader|ButleryHeader)\s*\(|'
            r'(?<![\w.])AppBar\s*\(',
          ),
        ),
        everyElement(isIn(_barResidue)),
      );
    });

    test('every loading state says what is fetched (produktregler §6.6)', () {
      expect(
        _offenders(_libFiles(), RegExp(r'StateWidget\.loading\(\s*\)')),
        isEmpty,
      );
      // A generic word is not "what is being fetched".
      expect(
        _offenders(
          _libFiles(),
          RegExp(
            _loadingSite + r'(commonLoading|loadingGeneric|dialogLoading)\b',
          ),
        ),
        isEmpty,
      );
    });

    test('loading texts end in " …", never "..." (content-style-guide:63)', () {
      final sv =
          jsonDecode(File('lib/l10n/app_sv.arb').readAsStringSync())
              as Map<String, dynamic>;
      final site = RegExp(_loadingSite + r'(\w+)');
      final keys = <String>{
        for (final path in _libFiles())
          for (final m in site.allMatches(_code(path))) m.group(3)!,
      };
      expect(keys, isNotEmpty);
      expect([
        for (final k in keys)
          if (sv[k] is! String || !(sv[k] as String).endsWith(' …')) k,
      ], isEmpty);
      for (final k in [
        'commonLoading',
        'loadingGeneric',
        'dialogLoading',
        'loadingRecipes',
        'statusSaving',
      ]) {
        expect(sv[k], endsWith(' …'), reason: k);
      }
    });

    test('a view file carries one hero style (Saffranshierarki, D4)', () {
      final many = [
        for (final path in _libFiles().where((f) => f.startsWith('lib/views/')))
          if (RegExp(r'heroButtonStyle').allMatches(_code(path)).length > 1)
            path,
      ];
      expect(many, everyElement(isIn(_exclusiveHeroFiles)));
    });

    test('no new ad-hoc snackbar colour (Komponentark v1:745-750)', () {
      expect(
        _offenders(
          _libFiles(),
          RegExp(
            r'SnackBar\s*\((?:(?!SnackBar\s*\()[\s\S]){0,600}?backgroundColor',
          ),
        ),
        everyElement(isIn(_snackBarResidue)),
      );
    });

    test('tabs carry the saffron plate line (Komponentark v1:106-112)', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final tabs = theme.tabBarTheme;
        final indicator = tabs.indicator! as UnderlineTabIndicator;
        // tokens.json:165-168 progressIndicator, #CE7C1E in both modes.
        expect(indicator.borderSide.color, const Color(0xFFCE7C1E));
        expect(indicator.borderSide.width, 3);
        expect(tabs.indicatorSize, TabBarIndicatorSize.label);
        expect(tabs.labelColor, theme.colorScheme.onSurface);
        expect(tabs.unselectedLabelColor, theme.colorScheme.onSurfaceVariant);
        // Komponentark v1:112-113: selected 700, resting 600.
        expect(tabs.labelStyle!.fontWeight, FontWeight.w700);
        expect(tabs.unselectedLabelStyle!.fontWeight, FontWeight.w600);
      }
    });

    test(
      'the theme draws no focus tint (Grafisk manual v6:209)',
      () {
        for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
          expect(theme.focusColor.a, 0);
        }
      },
      skip:
          'ThemeData.focusColor is still saffron. About 145 lib files have '
          'an InkWell or ListTile whose only keyboard focus cue is that '
          'tint, and D3 forbids removing a cue before the ring is on the '
          'same control. Open item from P4-U18.',
    );
  });
}

/// A loading call site followed by an l10n key: group 3 is the key.
const _loadingSite =
    r'(StateWidget\.loading\(\s*message:|loadingMessage:)\s*'
    r'(context\.)?l10n\.';

/// Every Dart file under lib, generated localisations excepted.
List<String> _libFiles() => [
  for (final e in Directory('lib').listSync(recursive: true))
    if (e is File && e.path.endsWith('.dart')) e.path.replaceAll(r'\', '/'),
].where((p) => !p.startsWith('lib/l10n/')).toList();

final _spinner = RegExp(
  r'\b(CircularProgressIndicator|LinearProgressIndicator|'
  r'CupertinoActivityIndicator|LoadingIndicator|PeaLoadingAnimation|'
  r'PeaLoadingOverlay)\s*\(',
);

/// The component files package 7 deletes, and the plate line itself, which
/// is drawn on a LinearProgressIndicator.
const _package7Components = {
  'lib/widgets/common/indicators/loading_indicator.dart',
  'lib/widgets/common/indicators/pea_loading_animation.dart',
  'lib/widgets/common/indicators/plate_line.dart',
  'lib/widgets/common/adaptive_app_bar.dart',
  'lib/widgets/common/butlery_header.dart',
  'lib/widgets/common/main_view_header.dart',
};

/// Spinners package 4 left behind, each in a file another unit owns. The
/// list only shrinks: a new file here is a regression.
const _spinnerResidue = [
  'lib/views/personal_tags/personal_tag_bulk_dialogs.dart', // P4-U16
  'lib/views/personal_tags/personal_tag_dialogs.dart', // P4-U16
  'lib/widgets/tagging/personal_tag_rule_dialog.dart', // P4-U16
  'lib/widgets/tagging/personal_tag_selector.dart', // P4-U16
  'lib/widgets/common/dialogs/unknown_ingredient_dialog.dart', // P4-U16
  'lib/widgets/common/dialogs/slot_picker_dialog.dart', // P4-U09
];

/// Old bars left in views. Only shrinks.
const _barResidue = [
  'lib/views/recipe_detail/fullscreen_image_viewer.dart', // P4-U05
];

/// View files with two hero styles in branches that never show together:
/// start cooking versus save a copy of someone else's recipe, and two
/// different empty states in one file.
const _exclusiveHeroFiles = [
  'lib/views/recipe_detail_view.dart',
  'lib/views/mina_recept/empty_state_widgets.dart',
];

/// Snackbars that still set their own colour (tracks T6 and T7). Only
/// shrinks.
const _snackBarResidue = [
  'lib/views/cooking_mode_view.dart',
  'lib/views/recipe_detail/recipe_detail_comments.dart',
  'lib/views/recipe_detail/recipe_detail_content.dart',
  'lib/widgets/common/universal_share_dialog.dart',
  'lib/widgets/common/dialogs/retag_progress_dialog.dart',
  'lib/widgets/common/feedback/snackbar_widgets.dart',
  'lib/widgets/common/input/shopping_list_actions.dart',
  'lib/widgets/common/input/shopping_list_selector.dart',
  'lib/widgets/common/profile/handlers/gdpr_consent_handler.dart',
  'lib/widgets/common/profile/utils/result_displayer.dart',
  'lib/widgets/image/image_picker_dialogs.dart',
  'lib/widgets/image/image_picker_widget.dart',
  'lib/widgets/legal/legal_contact_footer.dart',
  'lib/widgets/menu/menu_content_widgets.dart',
];

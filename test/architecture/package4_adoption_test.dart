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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
}

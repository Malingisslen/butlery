// BUT-2480: the app never signs the user out
// because of elapsed time. Decision: Malin 2026-10-30, ADR-0039.
//
// This is a source search. It catches names, ARB keys and new files that call
// sign-out, but it cannot prove that no indirect call chain ties a sign-out to
// time; test 3 narrows that gap by banning timers in every file that signs out.
// All patterns are case-sensitive on purpose: `SessionEnded` in the upload
// queue is unrelated and must stay.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/design_migration_census.dart' show stripComments;

final _retiredNames = <String, RegExp>{
  'SessionTimeout*': RegExp(r'\bSessionTimeout\w*'),
  'SessionActivity*': RegExp(r'\bSessionActivity\w*'),
  'logoutDueToInactivity': RegExp(r'\blogoutDueToInactivity\b'),
  'SessionEndNotice': RegExp(r'\bSessionEndNotice\b'),
  'SessionReturnPath': RegExp(r'\bSessionReturnPath\b'),
  'sessionTimeout*': RegExp(r'\bsessionTimeout\w*'),
};

// Measured 2026-10-30 after the removal: every file under lib/ that calls
// signOut, forceSignOut or a logout wrapper.
const _approvedSignOutFiles = <String>{
  'lib/repositories/firebase/firebase_auth_repository.dart',
  'lib/services/account/account_deletion_service.dart',
  'lib/services/auth/provider_sign_in_platform.dart',
  'lib/services/auth_service.dart',
  'lib/services/guest/guest_start_coordinator.dart',
  'lib/viewmodels/auth/provider_terms_viewmodel.dart',
  'lib/viewmodels/auth_viewmodel.dart',
  'lib/viewmodels/password_reset_viewmodel.dart',
  'lib/viewmodels/profile/profile_viewmodel.dart',
  'lib/views/account/data_export_view.dart',
  'lib/views/onboarding/onboarding_age_gate_blocked_view.dart',
  'lib/views/onboarding/onboarding_view.dart',
  'lib/widgets/common/profile/handlers/auth_action_handler.dart',
};

final _signOutCall = RegExp(r'\.\s*(signOut|forceSignOut|logout)\s*\(');
final _timer = RegExp(
  r'\bTimer\s*\(|\bTimer\s*\.\s*periodic|\bFuture\s*\.\s*delayed|\bStream\s*\.\s*periodic',
);

List<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

String _rel(File f) => f.path.replaceAll(r'\', '/');

void main() {
  test(
    'BUT-2480 ingen utloggning vid inaktivitet: de borttagna namnen och filerna '
    'kommer inte tillbaka',
    () {
      // Red means the inactivity timeout or its scaffolding came back.
      final hits = <String>[];
      for (final f in _dartFiles()) {
        final path = _rel(f);
        final name = path.split('/').last;
        if (name.startsWith('session_timeout') ||
            name.startsWith('session_activity')) {
          hits.add('$path: file name');
        }
        if (path.startsWith('lib/l10n/')) continue;
        final code = stripComments(f.readAsStringSync());
        _retiredNames.forEach((label, re) {
          if (re.hasMatch(code)) hits.add('$path: $label');
        });
      }
      expect(hits, isEmpty);
    },
  );

  test(
    'BUT-2480 ingen utloggning vid inaktivitet: bara godkända filer loggar ut',
    () {
      // Red means a new route to sign-out exists and must be reviewed against
      // Malin's decision that only she ends her session.
      final found = <String>{
        for (final f in _dartFiles())
          if (_signOutCall.hasMatch(stripComments(f.readAsStringSync())))
            _rel(f),
      };
      expect(found, _approvedSignOutFiles);
    },
  );

  test(
    'BUT-2480 ingen utloggning vid inaktivitet: ingen godkänd fil har en timer',
    () {
      // Red means someone may have tied a sign-out to time.
      final withTimer = <String>[
        for (final path in _approvedSignOutFiles)
          if (_timer.hasMatch(stripComments(File(path).readAsStringSync())))
            path,
      ];
      expect(withTimer, isEmpty);
    },
  );

  test(
    'BUT-2480 ingen utloggning vid inaktivitet: ingen text utlovar en timeout',
    () {
      // Red means the warning dialog or the "signed out while idle" notice
      // came back.
      final prefixes = RegExp(
        r'^(sessionExpiring|sessionEnded|sessionContinue)',
      );
      final offending = <String>[];
      for (final lang in ['sv', 'en']) {
        final arb =
            jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
                as Map<String, dynamic>;
        for (final key in arb.keys) {
          if (prefixes.hasMatch(key)) offending.add('app_$lang.arb: $key');
        }
      }
      expect(offending, isEmpty);
    },
  );
}

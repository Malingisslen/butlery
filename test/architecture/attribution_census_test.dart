// BUT-2009: nothing that writes attribution reads the Firebase Auth name or
// photo.
//
// `User.displayName` / `photoURL` are the Google or Apple account's, which the
// user never chose to show in the app; `on-profile-updated.ts` and account
// deletion maintain only the PROFILE copies. A writer that stamps the Auth
// values onto a document other people read therefore leaks an unconsented name
// that nothing can rename or erase. Writers take their name and photo from
// `AttributionSource` (or `UserService.profileDisplayName` /
// `profileAvatarUrl`).
//
// This scan lists every place `lib/` reads an Auth-sourced name or photo. Each
// is allowlisted below with the reason it is not attribution. A new hit fails
// the suite: either route it through the profile, or add it here with a reason
// a reviewer can check. Comment-only lines are not code and are skipped.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _authReads = <String, RegExp>{
  'currentUser?.displayName': RegExp(r'currentUser\?\.displayName'),
  'currentUser.displayName': RegExp(r'currentUser\.displayName'),
  'currentUser!.displayName': RegExp(r'currentUser!\.displayName'),
  '.photoURL': RegExp(r'\.photoURL\b'),
  'currentUser?.avatarUrl': RegExp(r'currentUser\?\.avatarUrl'),
  'currentUser.avatarUrl': RegExp(r'currentUser\.avatarUrl'),
  'currentUser!.avatarUrl': RegExp(r'currentUser!\.avatarUrl'),
  'permissionService.currentUserDisplayName': RegExp(
    r'ermissionService\??\.currentUserDisplayName',
  ),
};

class _Allowed {
  const _Allowed(this.file, this.snippet, this.reason);

  final String file;

  /// Must occur in the offending line, so a second, different read in the
  /// same file is still a new hit.
  final String snippet;
  final String reason;
}

const _allowed = <_Allowed>[
  _Allowed(
    'lib/services/auth_service.dart',
    'currentUserDisplayName => _currentUser?.displayName',
    'the sign-in surface exposing the Auth account itself',
  ),
  _Allowed(
    'lib/services/auth_service.dart',
    'currentUserPhotoUrl => _currentUser?.photoURL',
    'the sign-in surface exposing the Auth account itself',
  ),
  _Allowed(
    'lib/services/user_service.dart',
    'authName = _authRepository.currentUser?.displayName',
    'currentDisplayName, the display-only fallback; writers use '
        'attributionDisplayName',
  ),
  _Allowed(
    'lib/services/permission_service.dart',
    'avatarUrl: firebaseUser.photoURL',
    'synthesizes the Auth-derived UserProfile, the thing writers must not use',
  ),
  _Allowed(
    'lib/services/permission_service.dart',
    '_authRepository.currentUser?.displayName',
    'the currentUserDisplayName getter definition; no writer calls it',
  ),
  _Allowed(
    'lib/viewmodels/social_recipe/social_profile_manager.dart',
    '_currentUser?.displayName',
    '_currentUser is a UserProfile (the profile), not the Auth user',
  ),
  _Allowed(
    'lib/viewmodels/social_recipe/social_profile_manager.dart',
    '_currentUser?.avatarUrl',
    '_currentUser is a UserProfile (the profile), not the Auth user',
  ),
];

class _Hit {
  _Hit(this.file, this.lineNo, this.line, this.pattern);

  final String file;
  final int lineNo;
  final String line;
  final String pattern;

  @override
  String toString() => '$file:$lineNo [$pattern] ${line.trim()}';
}

List<_Hit> _scan(Iterable<File> files) {
  final hits = <_Hit>[];
  for (final file in files) {
    final path = file.path.replaceAll('\\', '/');
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final code = lines[i];
      if (code.trimLeft().startsWith('//')) continue;
      for (final entry in _authReads.entries) {
        if (entry.value.hasMatch(code)) {
          hits.add(_Hit(path, i + 1, code, entry.key));
          break;
        }
      }
    }
  }
  return hits;
}

Iterable<File> _libFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where(
      (f) =>
          f.path.endsWith('.dart') &&
          !f.path.replaceAll('\\', '/').startsWith('lib/l10n/'),
    );

void main() {
  test('the scan recognises every Auth read it is meant to catch', () {
    final dir = Directory.systemTemp.createTempSync('attribution_census');
    addTearDown(() => dir.deleteSync(recursive: true));
    final probe = File('${dir.path}/probe.dart')
      ..writeAsStringSync(
        [
          'a(authRepository.currentUser?.displayName);',
          'a(authRepository.currentUser.displayName);',
          'a(authRepository.currentUser!.displayName);',
          'a(user.photoURL);',
          'a(permissionService.currentUser?.avatarUrl);',
          'a(permissionService.currentUser.avatarUrl);',
          'a(_permissionService.currentUser!.avatarUrl);',
          'a(_permissionService.currentUserDisplayName);',
          '// currentUser?.displayName in a comment',
        ].join('\n'),
      );

    final found = _scan([probe]);

    expect(found.map((h) => h.lineNo), [1, 2, 3, 4, 5, 6, 7, 8]);
  });

  test('every Auth-sourced name or photo read in lib/ is a known, '
      'non-attribution site', () {
    final unexplained = [
      for (final hit in _scan(_libFiles()))
        if (!_allowed.any(
          (a) => a.file == hit.file && hit.line.contains(a.snippet),
        ))
          hit,
    ];

    expect(
      unexplained,
      isEmpty,
      reason:
          'A writer must take the name and photo from AttributionSource, not '
          'the Firebase Auth account. If a new read is not attribution, '
          'allowlist it in this file with the reason.',
    );
  });

  test('the allowlist holds no entry that no longer matches code', () {
    final hits = _scan(_libFiles());
    final stale = [
      for (final a in _allowed)
        if (!hits.any((h) => h.file == a.file && h.line.contains(a.snippet)))
          '${a.file}: ${a.snippet}',
    ];

    expect(stale, isEmpty, reason: 'remove allowlist entries for deleted code');
  });
}

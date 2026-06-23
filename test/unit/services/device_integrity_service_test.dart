/// Pins the BUT-426 release-config guard.
///
/// Production caller passes [kReleaseMode] + [defaultTargetPlatform] +
/// the dart-define-resolved freeRASP credentials into
/// [assertReleaseConfig]. We can't compile a test in release mode, but we
/// CAN exercise the function directly with `isReleaseMode: true` and
/// verify the platform-gated cases.
library;

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/device_integrity_service.dart';

const _placeholderTeamId = 'BUTLERY_TEAM';
const _realTeamId = 'real-team-id-9X3K';
const _realCertHash = '1V4sCqD8sS+CuMNYsixjbTUz0FE7FOMULGCvw2n4380=';

void main() {
  group('assertReleaseConfig (BUT-426)', () {
    test('debug build with placeholders is allowed (local dev path)', () {
      expect(
        () => assertReleaseConfig(
          isReleaseMode: false,
          runtimePlatform: TargetPlatform.iOS,
          teamId: _placeholderTeamId,
          androidCertHash: kAndroidPlaceholderCertHash,
        ),
        returnsNormally,
      );
    });

    test('release build crashes if Android cert hash is the placeholder', () {
      expect(
        () => assertReleaseConfig(
          isReleaseMode: true,
          runtimePlatform: TargetPlatform.android,
          teamId: _realTeamId,
          androidCertHash: kAndroidPlaceholderCertHash,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('BUT-426'),
              contains('FREE_RASP_ANDROID_CERT_HASH'),
              contains('docs/ops/freerasp-runbook.md'),
            ),
          ),
        ),
      );
    });

    test(
      'iOS release with placeholder teamId crashes (Apple enrollment gate)',
      () {
        expect(
          () => assertReleaseConfig(
            isReleaseMode: true,
            runtimePlatform: TargetPlatform.iOS,
            teamId: _placeholderTeamId,
            androidCertHash: _realCertHash,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('BUT-426'),
                contains('FREE_RASP_TEAM_ID'),
                contains('iOS release'),
              ),
            ),
          ),
        );
      },
    );

    test('Android release with placeholder iOS teamId is ALLOWED', () {
      // The whole point of the platform gate: we ship Android today
      // without Apple Developer Program enrollment. The iOS placeholder
      // only matters when actually running on iOS.
      expect(
        () => assertReleaseConfig(
          isReleaseMode: true,
          runtimePlatform: TargetPlatform.android,
          teamId: _placeholderTeamId,
          androidCertHash: _realCertHash,
        ),
        returnsNormally,
      );
    });

    test(
      'release build with both real values is allowed on either platform',
      () {
        for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
          expect(
            () => assertReleaseConfig(
              isReleaseMode: true,
              runtimePlatform: platform,
              teamId: _realTeamId,
              androidCertHash: _realCertHash,
            ),
            returnsNormally,
            reason: 'platform=$platform',
          );
        }
      },
    );
  });
}

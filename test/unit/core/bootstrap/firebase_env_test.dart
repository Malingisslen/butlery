import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/bootstrap/emulator_bootstrap.dart';
import 'package:butlery/core/bootstrap/firebase_env.dart';
import 'package:butlery/firebase_options_staging.dart' as staging_options;

void main() {
  group('FirebaseEnv.resolve', () {
    test('no ENV means production', () {
      final env = FirebaseEnv.resolve('', emulator: false);
      expect(env.environment, FirebaseEnvironment.production);
      expect(env.projectId, 'butlery-prod');
    });

    test(
      'ENV=production, as the release .env files write it, is production',
      () {
        expect(
          FirebaseEnv.resolve('production', emulator: false).projectId,
          'butlery-prod',
        );
      },
    );

    test('ENV=staging selects the staging project', () {
      final env = FirebaseEnv.resolve('staging', emulator: false);
      expect(env.environment, FirebaseEnvironment.staging);
      expect(env.projectId, 'butlery-app-staging');
    });

    test('an unknown ENV stops the start instead of falling back', () {
      for (final define in ['prod', 'Staging', 'dev', ' staging']) {
        expect(
          () => FirebaseEnv.resolve(define, emulator: false),
          throwsStateError,
          reason: define,
        );
      }
    });

    test('the emulator wins over staging', () {
      final env = FirebaseEnv.resolve('staging', emulator: true);
      expect(env.environment, FirebaseEnvironment.emulator);
      expect(env.projectId, EmulatorBootstrap.projectId);
    });

    test('the emulator still refuses an unknown ENV', () {
      expect(
        () => FirebaseEnv.resolve('typo', emulator: true),
        throwsStateError,
      );
    });

    test('this test build, compiled with no ENV, is production', () {
      expect(FirebaseEnv.current.environment, FirebaseEnvironment.production);
    });
  });

  group('per-environment values', () {
    final production = FirebaseEnv.resolve('', emulator: false);
    final staging = FirebaseEnv.resolve('staging', emulator: false);
    final emulator = FirebaseEnv.resolve('staging', emulator: true);

    test('only staging shows the banner, and it names the project', () {
      expect(production.showBanner, isFalse);
      expect(emulator.showBanner, isFalse);
      expect(staging.showBanner, isTrue);
      expect(staging.bannerLabel, 'STAGING · butlery-app-staging');
    });

    test('only staging turns telemetry off', () {
      expect(production.allowsTelemetry, isTrue);
      expect(staging.allowsTelemetry, isFalse);
    });

    test('the auth link host is the project\'s own Hosting domain', () {
      expect(production.authLinkHost, 'butlery-prod.firebaseapp.com');
      expect(staging.authLinkHost, 'butlery-app-staging.firebaseapp.com');
      expect(emulator.authLinkHost, production.authLinkHost);
    });

    test('the Android package matches the flavor applicationId', () {
      expect(production.androidPackageName, 'se.butlery.app');
      expect(staging.androidPackageName, 'se.butlery.app.staging');
    });

    test('production options point at the production project', () {
      expect(production.options().projectId, production.projectId);
    });

    test('staging options point at the staging project', () {
      expect(staging.options().projectId, staging.projectId);
    });

    test('staging web options point at the staging project', () {
      expect(
        staging_options.DefaultFirebaseOptions.web.projectId,
        staging.projectId,
      );
      expect(
        staging_options.DefaultFirebaseOptions.web.authDomain,
        staging.authLinkHost,
      );
    });

    test('emulator options are built on production and moved to demo', () {
      final options = emulator.options(releaseMode: false, isWeb: true);
      expect(options.projectId, EmulatorBootstrap.projectId);
      expect(options.appId, production.options().appId);
    });
  });
}

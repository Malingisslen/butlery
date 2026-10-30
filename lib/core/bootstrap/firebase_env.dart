/// Which Firebase project a build talks to, chosen at compile time with
/// `--dart-define=ENV`.
///
/// No define means production, so a plain `flutter run` reaches production
/// with no flags. `ENV=staging` selects `butlery-app-staging`; on Android it
/// must be paired with the `staging` flavor, whose package id and
/// google-services.json belong to that project. Any other value stops the
/// start: a typo must not silently fall back to production.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/bootstrap/emulator_bootstrap.dart';
import 'package:butlery/firebase_options.dart' as production_options;
import 'package:butlery/firebase_options_staging.dart' as staging_options;

enum FirebaseEnvironment { production, staging, emulator }

class FirebaseEnv {
  const FirebaseEnv._({
    required this.environment,
    required this.projectId,
    required this.authLinkHost,
    required this.androidPackageName,
  });

  static const String productionProjectId = 'butlery-prod';
  static const String stagingProjectId = 'butlery-app-staging';

  static const FirebaseEnv _production = FirebaseEnv._(
    environment: FirebaseEnvironment.production,
    projectId: productionProjectId,
    authLinkHost: '$productionProjectId.firebaseapp.com',
    androidPackageName: 'se.butlery.app',
  );

  static const FirebaseEnv _staging = FirebaseEnv._(
    environment: FirebaseEnvironment.staging,
    projectId: stagingProjectId,
    authLinkHost: '$stagingProjectId.firebaseapp.com',
    androidPackageName: 'se.butlery.app.staging',
  );

  // The emulator runs on web against a demo project; the auth link host and
  // package are production's because its options are built on production's.
  static const FirebaseEnv _emulator = FirebaseEnv._(
    environment: FirebaseEnvironment.emulator,
    projectId: EmulatorBootstrap.projectId,
    authLinkHost: '$productionProjectId.firebaseapp.com',
    androidPackageName: 'se.butlery.app',
  );

  static const String _define = String.fromEnvironment('ENV');

  /// The environment this build was compiled for. Throws on an unknown `ENV`.
  static final FirebaseEnv current = resolve(
    _define,
    emulator: EmulatorBootstrap.enabled,
  );

  /// The local emulator wins over every `ENV`, so a local test run can never
  /// write to a real project. `production` is accepted because the release
  /// pipelines' `.env` files spell it out.
  static FirebaseEnv resolve(String define, {required bool emulator}) {
    final FirebaseEnv selected = switch (define) {
      '' || 'production' => _production,
      'staging' => _staging,
      _ => throw StateError(
        'Unknown --dart-define=ENV="$define". Use no ENV for production or '
        'ENV=staging.',
      ),
    };
    return emulator ? _emulator : selected;
  }

  final FirebaseEnvironment environment;
  final String projectId;

  /// The Hosting domain the password-reset mail link is built on. Must match
  /// the flavor's `authLinkHost` manifest placeholder.
  final String authLinkHost;

  /// Must match the flavor's applicationId.
  final String androidPackageName;

  bool get isStaging => environment == FirebaseEnvironment.staging;

  /// A build label for whoever holds the phone, so it is not localised.
  bool get showBanner => isStaging;
  String get bannerLabel => 'STAGING · $projectId';

  /// Analytics and Crashlytics stay off in staging so no device identifiers
  /// from test phones are collected.
  bool get allowsTelemetry => !isStaging;

  FirebaseOptions options({
    bool releaseMode = kReleaseMode,
    bool isWeb = kIsWeb,
  }) => switch (environment) {
    FirebaseEnvironment.production =>
      production_options.DefaultFirebaseOptions.currentPlatform,
    FirebaseEnvironment.staging =>
      staging_options.DefaultFirebaseOptions.currentPlatform,
    FirebaseEnvironment.emulator => EmulatorBootstrap.options(
      production_options.DefaultFirebaseOptions.currentPlatform,
      releaseMode: releaseMode,
      isWeb: isWeb,
    ),
  };
}

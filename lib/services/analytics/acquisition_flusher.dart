/// Writes the pending campaign channel once the person is a registered,
/// consenting user (BUT-2406).
///
/// Nothing is read from Google Play, and nothing is written, before analytics
/// consent. Guests are skipped: the tally counts only accounts with a sign-in.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/interfaces/acquisition_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics/acquisition_milestone.dart';
import 'package:butlery/services/analytics/pending_acquisition.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/utils/shared_preferences_safe.dart';

typedef InstallReferrerReader = Future<String?> Function();

Future<String?> _readPlayInstallReferrer() async {
  final details = await PlayInstallReferrer.installReferrer;
  return details.installReferrer;
}

class AcquisitionFlusher {
  static const String _referrerReadPrefix = 'acquisition_referrer_read_v1';

  final AuthRepository? _auth;
  final ConsentService? _consent;
  final AcquisitionRepository? _repository;
  final AnalyticsService? _analytics;
  final InstallReferrerReader? _readReferrer;

  static bool _running = false;

  /// [readReferrer] is null on platforms without a Play referrer.
  AcquisitionFlusher({
    required AuthRepository? auth,
    required ConsentService? consent,
    required AcquisitionRepository? repository,
    required AnalyticsService? analytics,
    InstallReferrerReader? readReferrer,
  }) : _auth = auth,
       _consent = consent,
       _repository = repository,
       _analytics = analytics,
       _readReferrer = readReferrer;

  factory AcquisitionFlusher.forPlatform({
    required AuthRepository? auth,
    required ConsentService? consent,
    required AcquisitionRepository? repository,
    required AnalyticsService? analytics,
  }) {
    final isAndroidApp =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return AcquisitionFlusher(
      auth: auth,
      consent: consent,
      repository: repository,
      analytics: analytics,
      readReferrer: isAndroidApp ? _readPlayInstallReferrer : null,
    );
  }

  Future<void> flush() async {
    if (_running) return;
    _running = true;
    try {
      final user = _auth?.currentUser;
      if (user == null || user.isAnonymous) return;

      final consented = await ConsentService.checkSafely(
        _consent,
        ConsentPurpose.analytics,
        logTag: 'AcquisitionFlusher',
      );
      if (!consented) return;

      await _readReferrerOnce();

      final channel = PendingAcquisition.current;
      if (channel == null) return;

      await AcquisitionMilestone.recordIfFirst(
        analytics: _analytics,
        repository: _repository,
        consentService: _consent,
        userId: user.uid,
        utmSource: channel.source,
        utmMedium: channel.medium,
      );
      PendingAcquisition.clear();
    } catch (e) {
      AppLogger.warning('AcquisitionFlusher: skipped ($e)');
    } finally {
      _running = false;
    }
  }

  Future<void> _readReferrerOnce() async {
    final read = _readReferrer;
    if (read == null) return;
    final prefs = await tryGetSharedPreferences(logTag: 'AcquisitionFlusher');
    const key = _referrerReadPrefix;
    if (prefs == null || prefs.getBool(key) == true) return;
    try {
      PendingAcquisition.rememberInstallReferrer(
        AcquisitionChannel.fromInstallReferrer(await read()),
      );
    } catch (e) {
      // The raw referrer string is never logged: it can carry click ids.
      AppLogger.debug('AcquisitionFlusher: no install referrer available');
    }
    await prefs.setBool(key, true);
  }
}

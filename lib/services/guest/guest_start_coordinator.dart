import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/account/age_verification_service.dart';
import 'package:butlery/services/auth/guest_auth_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';

enum GuestStartOutcome {
  /// A guest is signed in, age-checked, with the starter recipes.
  started,

  /// Under the age floor. Either refused before any account existed, or the
  /// server refused and deleted the account it had just checked.
  tooYoung,

  /// Something failed; no guest is left signed in.
  failed,
}

/// Runs "Prova utan konto" from the birth year to Hem (BUT-920).
///
/// The sign-in swaps the sign-in screen for the signed-in tree, which
/// disposes the screen that started it, so the steps after the sign-in run
/// here and not in a widget. While [isRunning], the app shows a waiting
/// screen instead of Hem, so nobody reaches Hem before the age check. A
/// failure the starting screen did not live to show waits in
/// [takePendingFailure] for the sign-in screen that replaces it.
///
/// Deliberately not a `BaseService`: it orchestrates other services and
/// holds no Firebase handle of its own.
class GuestStartCoordinator extends ChangeNotifier {
  GuestStartCoordinator({
    required GuestAuthService Function() guestAuth,
    required AuthService authService,
    required AgeVerificationService Function() ageVerification,
    required Future<bool> Function() eraseGuest,
    required Future<void> Function(String uid) seedStarterRecipes,
  }) : _guestAuth = guestAuth,
       _authService = authService,
       _ageVerification = ageVerification,
       _eraseGuest = eraseGuest,
       _seedStarterRecipes = seedStarterRecipes;

  final GuestAuthService Function() _guestAuth;
  final AuthService _authService;
  final AgeVerificationService Function() _ageVerification;
  final Future<bool> Function() _eraseGuest;
  final Future<void> Function(String uid) _seedStarterRecipes;

  Future<GuestStartOutcome>? _running;
  GuestStartOutcome? _pendingFailure;

  bool get isRunning => _running != null;

  /// Year granularity, counted as the youngest age the year allows, the same
  /// rule onboarding applies.
  static bool isOldEnough(int birthYear) =>
      clock.now().year - birthYear >= OnboardingViewModel.minAgeYears;

  /// The last failure, once; null when there is none to show.
  GuestStartOutcome? takePendingFailure() {
    final failure = _pendingFailure;
    _pendingFailure = null;
    return failure;
  }

  /// Starts a guest for [birthYear]. A second call while one runs joins it.
  Future<GuestStartOutcome> start(int birthYear) {
    if (!isOldEnough(birthYear)) {
      return Future.value(GuestStartOutcome.tooYoung);
    }
    final running = _running;
    if (running != null) return running;
    _pendingFailure = null;
    final future = _run(birthYear).then((outcome) {
      if (outcome != GuestStartOutcome.started) _pendingFailure = outcome;
      return outcome;
    });
    _running = future;
    notifyListeners();
    return future.whenComplete(() {
      _running = null;
      notifyListeners();
    });
  }

  Future<GuestStartOutcome> _run(int birthYear) async {
    if (!await _guestAuth().signInAsGuest()) {
      // A step after the anonymous sign-in can fail and leave a guest whose
      // age was never checked.
      if (_authService.currentUserId != null) await _removeUncheckedGuest();
      return GuestStartOutcome.failed;
    }

    final AgeVerificationResult result;
    try {
      result = await _ageVerification().verifyAge(birthYear);
    } catch (e) {
      AppLogger.error('Guest start: the age check failed', e);
      await _removeUncheckedGuest();
      return GuestStartOutcome.failed;
    }

    if (!result.compliant) {
      // The server has deleted the account already; only the local session
      // is left to end.
      await _authService.signOut();
      return GuestStartOutcome.tooYoung;
    }

    final uid = _authService.currentUserId;
    if (uid != null) {
      try {
        await _seedStarterRecipes(uid);
      } catch (e) {
        AppLogger.warning('Guest start: seeding failed: $e');
      }
    }
    return GuestStartOutcome.started;
  }

  /// A guest whose age was never checked must not stay. The server erasure
  /// also removes the profile the sign-in created. When it cannot be reached
  /// the account is only signed out: the Auth record is left for the
  /// inactive-guest cleanup, which erases it with everything under it, where
  /// a client-side Auth delete would strand the profile beyond that
  /// cleanup's reach.
  Future<void> _removeUncheckedGuest() async {
    var erased = false;
    try {
      erased = await _eraseGuest();
    } catch (e) {
      AppLogger.warning('Guest start: erasing the unchecked guest failed: $e');
    }
    if (!erased || _authService.currentUser != null) {
      await _authService.signOut();
    }
  }
}

// lib/views/auth/mfa_challenge_view.dart
//
// P6-U09 — the second-factor challenge at sign-in (Skarmar v12 etapp 3
// #authmfa; produktregler.md:745-749, § 14.2).
//
// Before this view, nothing in the app handled Firebase's multi-factor
// exception, so an account with two-step verification could not sign in.
//
// What the drawing fixes: a masked hint ("numret som slutar på •• 47"; the
// app never knows the whole number), the code valid for 60 seconds with the
// time left, one field for six digits that tolerates being filled by the
// phone, "Verifiera" and "Skicka en ny kod". Automatic verification may
// finish the sign-in while the user is typing; the view then moves on and
// treats that as success, never as an error. The backup path the drawing
// asks for is "Använd en reservkod".

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';

/// How the challenge ended.
enum MfaChallengeResult {
  /// Signed in with the second factor.
  signedIn,

  /// Signed in after a backup code removed the phone factor. The user must
  /// be told to add a phone again.
  signedInWithBackupCode,
}

class MfaChallengeView extends StatefulWidget {
  const MfaChallengeView({
    super.key,
    required this.challenge,
    required this.email,
    required this.password,
    this.mfaService,
    this.authService,
    this.codeLifetime = const Duration(seconds: 60),
  });

  final MfaResolverInfo challenge;

  /// Kept in memory only, for the backup-code path, where the server proves
  /// the password again. Never logged.
  final String email;
  final String password;

  final AuthMfaService? mfaService;
  final AuthService? authService;

  /// "Koden gäller i 60 sekunder" — the SMS timeout (auth_mfa_service.dart).
  final Duration codeLifetime;

  @override
  State<MfaChallengeView> createState() => _MfaChallengeViewState();
}

class _MfaChallengeViewState extends State<MfaChallengeView> {
  late final AuthMfaService _mfa =
      widget.mfaService ?? ServiceLocator.get<AuthMfaService>();
  late final AuthService _auth =
      widget.authService ?? ServiceLocator.get<AuthService>();

  final _codeController = TextEditingController();
  final _backupController = TextEditingController();

  String? _verificationId;
  Timer? _countdown;
  int _secondsLeft = 0;
  bool _busy = false;
  bool _done = false;
  bool _backupMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Verifiera follows the field: off until six digits are there.
    _codeController.addListener(_onCodeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sendCode();
    });
  }

  void _onCodeChanged() {
    if (mounted) setState(() {});
  }

  bool get _codeComplete => _codeController.text.trim().length == 6;

  @override
  void dispose() {
    _countdown?.cancel();
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    _backupController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdown?.cancel();
    setState(() => _secondsLeft = widget.codeLifetime.inSeconds);
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : 0);
      if (_secondsLeft == 0) timer.cancel();
    });
  }

  Future<void> _sendCode() async {
    setState(() => _error = null);
    await _mfa.startMfaSignIn(
      widget.challenge,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        _verificationId = verificationId;
        _startCountdown();
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _error = _messageFor(error.code));
      },
      onAutoVerified: _finish,
    );
  }

  String _messageFor(String code) {
    final l10n = context.l10n;
    return switch (code) {
      'invalid-verification-code' => l10n.mfaChallengeWrongCode,
      'session-expired' || 'code-expired' => l10n.mfaChallengeExpired,
      'too-many-requests' || 'quota-exceeded' => l10n.mfaQuotaExceeded,
      _ => l10n.mfaChallengeFailed,
    };
  }

  /// The one exit to "signed in", whichever way got there. Runs once.
  Future<void> _finish() async {
    if (_done || !mounted) return;
    _done = true;
    _countdown?.cancel();
    final ok = await _auth.finishMfaSignIn();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(MfaChallengeResult.signedIn);
    } else {
      setState(() {
        _done = false;
        _error = context.l10n.mfaChallengeFailed;
      });
    }
  }

  Future<void> _verify() async {
    if (_done) return; // the phone already verified; nothing to do
    final code = _codeController.text.trim();
    final verificationId = _verificationId;
    if (code.length != 6 || verificationId == null) {
      setState(() => _error = context.l10n.mfaEnterCode);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await _mfa.completeMfaSignIn(
      widget.challenge,
      verificationId,
      code,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    // Automatic verification may have signed in while the user typed; the
    // late manual attempt then fails on a used session. That is success.
    if (ok || _auth.currentUser != null || _done) {
      await _finish();
      return;
    }
    setState(
      () => _error = _mfa.errorMessage ?? context.l10n.mfaChallengeWrongCode,
    );
  }

  Future<void> _useBackupCode() async {
    final code = _backupController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = context.l10n.mfaBackupCodeEnter);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final outcome = await _mfa.recoverWithBackupCode(
      email: widget.email,
      password: widget.password,
      code: code,
    );
    if (!mounted) return;
    if (outcome == MfaRecoveryOutcome.recovered) {
      // The phone factor is gone: an ordinary sign-in works.
      final signedIn = await _auth.signInWithEmail(
        email: widget.email,
        password: widget.password,
      );
      if (!mounted) return;
      if (signedIn) {
        _done = true;
        _countdown?.cancel();
        Navigator.of(context).pop(MfaChallengeResult.signedInWithBackupCode);
        return;
      }
    }
    final l10n = context.l10n;
    setState(() {
      _busy = false;
      _error = switch (outcome) {
        MfaRecoveryOutcome.rejected => l10n.mfaBackupCodeRejected,
        MfaRecoveryOutcome.locked => l10n.mfaBackupCodeLocked,
        _ => l10n.mfaBackupCodeUnavailable,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tail = maskedPhoneTail(widget.challenge.phoneHint);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_done) _auth.clearPendingMfa();
      },
      child: Scaffold(
        appBar: ButleryTopBar.undersida(title: l10n.mfaChallengeTitle),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.layoutMarginOf(context),
              vertical: AppDimensions.space16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _backupMode
                  ? _buildBackup(context, cs)
                  : _buildChallenge(context, cs, tail),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChallenge(
    BuildContext context,
    ColorScheme cs,
    String? tail,
  ) {
    final l10n = context.l10n;
    return [
      Text(
        l10n.mfaChallengeHeading,
        style: AppTextStyles.headlineSmall.copyWith(color: cs.onSurface),
      ),
      const SizedBox(height: AppDimensions.spacingSm),
      Text(
        tail == null
            ? l10n.mfaChallengeSentUnknown
            : l10n.mfaChallengeSentTo('•• $tail'),
        key: const ValueKey('mfaChallenge.hint'),
        style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
      ),
      const SizedBox(height: AppDimensions.spacingLg),
      // One field for six digits, read as one control (T-06): the phone's
      // autofill lands in it, and a filled-in code is not an error.
      TextField(
        key: const ValueKey('mfaChallenge.code'),
        controller: _codeController,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 6,
        textAlign: TextAlign.center,
        style: AppTextStyles.headlineSmall.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: 8,
        ),
        decoration: InputDecoration(
          labelText: l10n.mfaSixDigitCode,
          border: const OutlineInputBorder(),
          counterText: '',
        ),
        onSubmitted: (_) => _verify(),
      ),
      const SizedBox(height: AppDimensions.spacingSm),
      Semantics(
        liveRegion: true,
        child: Text(
          _secondsLeft > 0
              ? l10n.mfaChallengeTimeLeft(
                  widget.codeLifetime.inSeconds,
                  _secondsLeft,
                )
              : l10n.mfaChallengeCodeGone,
          key: const ValueKey('mfaChallenge.timer'),
          style: AppTextStyles.bodySmall.copyWith(
            color: cs.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: AppDimensions.spacingSm),
        Text(
          _error!,
          key: const ValueKey('mfaChallenge.error'),
          style: AppTextStyles.bodySmall.copyWith(color: cs.error),
        ),
      ],
      const SizedBox(height: AppDimensions.spacingLg),
      HeroButton(
        key: const ValueKey('mfaChallenge.verify'),
        label: l10n.mfaVerify,
        // "Verifiera, avstängd till dess sex siffror är ifyllda"
        // (Skarmar v12 etapp 3 #authmfa, data-a11y-state disabled).
        onPressed: _busy || !_codeComplete ? null : _verify,
        busy: _busy,
        expand: true,
      ),
      const SizedBox(height: AppDimensions.spacingSm),
      TextButton(
        key: const ValueKey('mfaChallenge.resend'),
        onPressed: _busy ? null : _sendCode,
        child: Text(l10n.mfaChallengeResend),
      ),
      TextButton(
        key: const ValueKey('mfaChallenge.useBackup'),
        onPressed: _busy
            ? null
            : () => setState(() {
                _backupMode = true;
                _error = null;
              }),
        child: Text(l10n.mfaBackupCodeUse),
      ),
    ];
  }

  List<Widget> _buildBackup(BuildContext context, ColorScheme cs) {
    final l10n = context.l10n;
    return [
      Text(
        l10n.mfaBackupCodeHeading,
        style: AppTextStyles.headlineSmall.copyWith(color: cs.onSurface),
      ),
      const SizedBox(height: AppDimensions.spacingSm),
      Text(
        l10n.mfaBackupCodeExplanation,
        style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
      ),
      const SizedBox(height: AppDimensions.spacingLg),
      TextField(
        key: const ValueKey('mfaChallenge.backupCode'),
        controller: _backupController,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        enableSuggestions: false,
        maxLength: 11,
        decoration: InputDecoration(
          labelText: l10n.mfaBackupCodeLabel,
          hintText: 'ABCDE-FGHJK',
          border: const OutlineInputBorder(),
          counterText: '',
        ),
        onSubmitted: (_) => _useBackupCode(),
      ),
      if (_error != null) ...[
        const SizedBox(height: AppDimensions.spacingSm),
        Text(
          _error!,
          key: const ValueKey('mfaChallenge.error'),
          style: AppTextStyles.bodySmall.copyWith(color: cs.error),
        ),
      ],
      const SizedBox(height: AppDimensions.spacingLg),
      HeroButton(
        key: const ValueKey('mfaChallenge.backupSubmit'),
        label: l10n.mfaBackupCodeSubmit,
        onPressed: _busy ? null : _useBackupCode,
        busy: _busy,
        expand: true,
      ),
      const SizedBox(height: AppDimensions.spacingSm),
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                _backupMode = false;
                _error = null;
              }),
        child: Text(l10n.mfaBackupCodeBack),
      ),
    ];
  }
}

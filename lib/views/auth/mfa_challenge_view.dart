// lib/views/auth/mfa_challenge_view.dart
//
// P6-U09 — the second-factor challenge at sign-in (Skarmar v12 etapp 3
// #authmfa; produktregler.md:745-749, § 14.2).
//
// Before this view, nothing in the app handled Firebase's multi-factor
// exception, so an account with two-step verification could not sign in.
//
// The code comes from the user's authenticator app (Malin chose it over SMS
// on 2026-10-10), so the drawing's SMS parts — the masked number, the
// 60-second timer, "Skicka en ny kod" and automatic verification — are not
// built. What remains: one field for six digits, "Verifiera", and the backup
// path "Använd en reservkod".

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

  /// Signed in after a backup code removed the second factor. The user must
  /// be told to switch two-step verification on again.
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
  });

  final MfaResolverInfo challenge;

  /// Kept in memory only, for the backup-code path, where the server proves
  /// the password again. Never logged.
  final String email;
  final String password;

  final AuthMfaService? mfaService;
  final AuthService? authService;

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

  bool _busy = false;
  bool _done = false;
  bool _backupMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Verifiera follows the field: off until six digits are there.
    _codeController.addListener(_onCodeChanged);
  }

  void _onCodeChanged() {
    if (mounted) setState(() {});
  }

  bool get _codeComplete => _codeController.text.trim().length == 6;

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    _backupController.dispose();
    super.dispose();
  }

  /// The one exit to "signed in", whichever way got there. Runs once.
  Future<void> _finish() async {
    if (_done || !mounted) return;
    _done = true;
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
    // The field's onSubmitted reaches here even while the button is off.
    if (_busy || _done) return;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = context.l10n.mfaEnterCode);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await _mfa.completeMfaSignIn(widget.challenge, code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      await _finish();
      return;
    }
    setState(
      () => _error = _mfa.errorMessage ?? context.l10n.mfaChallengeWrongCode,
    );
  }

  Future<void> _useBackupCode() async {
    if (_busy || _done) return;
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
      // The second factor is gone: an ordinary sign-in works.
      final signedIn = await _auth.signInWithEmail(
        email: widget.email,
        password: widget.password,
      );
      if (!mounted) return;
      if (signedIn) {
        _done = true;
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
                  : _buildChallenge(context, cs),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChallenge(BuildContext context, ColorScheme cs) {
    final l10n = context.l10n;
    return [
      Text(
        l10n.mfaChallengeHeading,
        style: AppTextStyles.headlineSmall.copyWith(color: cs.onSurface),
      ),
      const SizedBox(height: AppDimensions.spacingSm),
      Text(
        l10n.mfaChallengeAppPrompt,
        key: const ValueKey('mfaChallenge.hint'),
        style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
      ),
      const SizedBox(height: AppDimensions.spacingLg),
      // One field for six digits, read as one control (T-06), so a code
      // pasted from the app lands whole.
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

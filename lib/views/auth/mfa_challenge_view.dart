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
import 'package:url_launcher/url_launcher.dart';

import 'package:butlery/core/constants/support_mail.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/services/auth/auth_provider_flows.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/styled/butlery_code_field.dart';
import 'package:butlery/widgets/styled/labeled_field.dart';

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
    this.email,
    this.password,
    this.provider,
    this.forReauthentication = false,
    this.mfaService,
    this.authService,
  }) : assert(
         provider != null ||
             forReauthentication ||
             (email != null && password != null),
       );

  final MfaResolverInfo challenge;

  /// Kept in memory only, for the backup-code path, where the server proves
  /// the password again. Never logged. Null after a Google/Apple sign-in.
  final String? email;
  final String? password;

  /// Set when the first factor was Google or Apple (BUT-916): the backup
  /// code is then proved through that provider, or sent to support where
  /// this device cannot prove it (C8).
  final SignInProvider? provider;

  /// The second factor of a re-authentication before a sensitive change:
  /// no sign-in sequence, no login analytics and no backup codes, since a
  /// backup code would switch the second factor off.
  final bool forReauthentication;

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

  /// The backup code worked and two-step verification is off, but the
  /// sign-in after it did not finish. Only the sign-in is tried again.
  bool _signInAfterRecoveryPending = false;
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
    if (widget.forReauthentication) {
      _auth.clearPendingMfa();
      Navigator.of(context).pop(MfaChallengeResult.signedIn);
      return;
    }
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
    final ok = await _mfa.completeMfaSignIn(
      widget.challenge,
      code,
      method: widget.forReauthentication
          ? null
          : widget.provider?.analyticsMethod ?? 'email',
    );
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
    final provider = widget.provider;
    final MfaRecoveryOutcome outcome;
    if (provider == null) {
      outcome = await _mfa.recoverWithBackupCode(
        email: widget.email!,
        password: widget.password!,
        code: code,
      );
    } else {
      // The server proves the first factor again through the provider's
      // own token, as it proves the password for an e-mail account.
      final proof = await _auth.providerRecoveryProof(provider);
      if (!mounted) return;
      if (proof == null) {
        setState(() => _busy = false);
        return;
      }
      outcome = await _mfa.recoverWithProviderBackupCode(
        proof: proof,
        code: code,
      );
    }
    if (!mounted) return;
    if (outcome == MfaRecoveryOutcome.recovered) {
      await _signInAfterRecovery();
      return;
    }
    final l10n = context.l10n;
    setState(() {
      _busy = false;
      _error = switch (outcome) {
        MfaRecoveryOutcome.rejected when provider != null =>
          l10n.mfaBackupCodeProviderRejected,
        MfaRecoveryOutcome.rejected => l10n.mfaBackupCodeRejected,
        MfaRecoveryOutcome.locked => l10n.mfaBackupCodeLocked,
        _ => l10n.mfaBackupCodeUnavailable,
      };
    });
  }

  /// The second factor is gone: an ordinary sign-in works. One that is
  /// cancelled or fails leaves the account without two-step verification,
  /// so the view says that rather than that nothing changed.
  Future<void> _signInAfterRecovery() async {
    if (_done) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final provider = widget.provider;
    final signedIn = provider == null
        ? await _auth.signInWithEmail(
            email: widget.email!,
            password: widget.password!,
          )
        : await _auth.signInWithProvider(provider) ==
              ProviderSignInOutcome.signedIn;
    if (!mounted) return;
    if (signedIn) {
      _done = true;
      Navigator.of(context).pop(MfaChallengeResult.signedInWithBackupCode);
      return;
    }
    setState(() {
      _busy = false;
      _signInAfterRecoveryPending = true;
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
              children: switch ((_backupMode, widget.provider)) {
                _ when _signInAfterRecoveryPending => _buildSignInAgain(
                  context,
                  cs,
                ),
                (false, _) => _buildChallenge(context, cs),
                (true, final SignInProvider provider)
                    when !_auth.canRecoverThroughProvider(provider) =>
                  _buildSupport(context, cs, provider),
                (true, _) => _buildBackup(context, cs),
              },
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
      ButleryCodeField(
        key: const ValueKey('mfaChallenge.code'),
        controller: _codeController,
        label: l10n.mfaSixDigitCode,
        hasError: _error != null,
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
      if (!widget.forReauthentication) ...[
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
      ],
    ];
  }

  /// Where a backup code cannot be proved on this device (Apple on Android
  /// and the web, Google on the web): support helps instead (C8).
  List<Widget> _buildSupport(
    BuildContext context,
    ColorScheme cs,
    SignInProvider provider,
  ) {
    final l10n = context.l10n;
    return [
      Text(
        l10n.mfaBackupCodeHeading,
        style: AppTextStyles.headlineSmall.copyWith(color: cs.onSurface),
      ),
      const SizedBox(height: AppDimensions.spacingSm),
      Text(
        l10n.mfaBackupCodeProviderSupport(
          AuthProviderFlows.providerName(provider),
        ),
        key: const ValueKey('mfaChallenge.support'),
        style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
      ),
      const SizedBox(height: AppDimensions.spacingLg),
      HeroButton(
        key: const ValueKey('mfaChallenge.contactSupport'),
        label: l10n.mfaBackupCodeContactSupport,
        onPressed: () => _mailSupport(l10n.mfaBackupCodeSupportSubject),
        expand: true,
      ),
      const SizedBox(height: AppDimensions.spacingSm),
      TextButton(
        onPressed: () => setState(() => _backupMode = false),
        child: Text(l10n.mfaBackupCodeBack),
      ),
    ];
  }

  Future<void> _mailSupport(String subject) async {
    final fallback = context.l10n.mfaBackupCodeNoEmail(privacyMailAddress);
    final uri = Uri.parse(
      'mailto:$privacyMailAddress?subject=${Uri.encodeComponent(subject)}',
    );
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (e) {
      AppLogger.warning('Support mail could not open: ${e.runtimeType}');
    }
    if (!opened && mounted) SnackBarUtils.showFailure(context, what: fallback);
  }

  List<Widget> _buildSignInAgain(BuildContext context, ColorScheme cs) {
    final l10n = context.l10n;
    final provider = widget.provider;
    final name = provider == null
        ? null
        : AuthProviderFlows.providerName(provider);
    return [
      Text(
        l10n.mfaBackupCodeHeading,
        style: AppTextStyles.headlineSmall.copyWith(color: cs.onSurface),
      ),
      const SizedBox(height: AppDimensions.spacingSm),
      Text(
        name == null
            ? l10n.mfaBackupCodeRecoveredSignInAgainPassword
            : l10n.mfaBackupCodeRecoveredSignInAgain(name),
        key: const ValueKey('mfaChallenge.signInAgainHint'),
        style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
      ),
      const SizedBox(height: AppDimensions.spacingLg),
      HeroButton(
        key: const ValueKey('mfaChallenge.signInAgain'),
        label: name == null
            ? l10n.mfaBackupCodeSignInAgain
            : l10n.mfaBackupCodeSignInAgainWith(name),
        onPressed: _busy ? null : _signInAfterRecovery,
        busy: _busy,
        expand: true,
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
      LabeledField(
        label: l10n.mfaBackupCodeLabel,
        child: TextField(
          key: const ValueKey('mfaChallenge.backupCode'),
          controller: _backupController,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 11,
          decoration: const InputDecoration(
            hintText: 'ABCDE-FGHJK',
            counterText: '',
          ),
          onSubmitted: (_) => _useBackupCode(),
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

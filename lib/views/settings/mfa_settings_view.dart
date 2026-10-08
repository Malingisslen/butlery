import 'package:flutter/material.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/views/settings/mfa_backup_codes_dialog.dart';
import 'package:butlery/views/settings/mfa_enrollment_forms.dart';
import 'package:butlery/widgets/styled/styled_card.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// View for managing Multi-Factor Authentication settings.
///
/// Turning two-step verification ON is still hidden (produktbeslut PQ-16 = A,
/// 2026-09-23; Linear BUT-2142). P6-U09 built the sign-in challenge
/// (MfaChallengeView), the ten backup codes shown and acknowledged before
/// the phone is enrolled (below), and the recovery with a code
/// (functions/src/account/mfa-backup-codes.ts). The switch stays off until
/// those callables are deployed with their `IDENTITY_TOOLKIT_API_KEY`
/// parameter and have passed the security review: a recovery that cannot
/// run is the lock-out §14.2 forbids (produktregler.md:749). Someone who
/// already has it on still sees the registered method and can remove it.
class MfaSettingsView extends StatefulWidget {
  const MfaSettingsView({this.offersEnrollment = false, super.key});

  /// Whether the view offers to turn two-step verification on (the phone
  /// form and "Skicka kod"). False in the app until the sign-in challenge
  /// and the fallback exist (PQ-16, BUT-2142); tests build the form with it.
  final bool offersEnrollment;

  @override
  State<MfaSettingsView> createState() => _MfaSettingsViewState();
}

class _MfaSettingsViewState extends State<MfaSettingsView> {
  final AuthMfaService _authService = ServiceLocator.get<AuthMfaService>();
  final TextEditingController _countryCodeController = TextEditingController(
    text: '+46',
  );
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = false;
  bool _hasMfa = false;
  bool _isEnrolling = false;
  bool _verifyingCode = false;
  String? _verificationId;
  String _sentTo = '';
  String? _errorMessage;
  List<MfaFactorInfo> _enrolledFactors = [];

  @override
  void initState() {
    super.initState();
    _loadMfaStatus();
  }

  @override
  void dispose() {
    // Leaving on the code step abandons an enrollment whose codes already
    // exist on the server; discardBackupCodes never throws. Not while the
    // code is being verified: the factor may still land, and clearing its
    // codes then would leave two-step verification on with none.
    if (_isEnrolling && !_verifyingCode) _authService.discardBackupCodes();
    _countryCodeController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadMfaStatus() async {
    setState(() => _isLoading = true);

    try {
      _hasMfa = await _authService.hasMfaEnabled();
      _enrolledFactors = await _authService.getEnrolledFactors();
    } catch (e) {
      AppLogger.error('Failed to load MFA status: $e');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  MfaPhoneParse _parsePhone() => parseMfaPhone(
    countryCode: _countryCodeController.text,
    national: _phoneController.text,
  );

  String _phoneProblemMessage(MfaPhoneProblem problem) {
    switch (problem) {
      case MfaPhoneProblem.countryCode:
        return context.l10n.mfaCountryCodeInvalid;
      case MfaPhoneProblem.number:
        return context.l10n.mfaPhoneDigitsOnly;
      case MfaPhoneProblem.tooLong:
        return context.l10n.mfaPhoneTooLong;
    }
  }

  Future<void> _startEnrollment() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _errorMessage = context.l10n.mfaEnterPhoneNumber);
      return;
    }
    // Validated before the password is asked for: a number Firebase would
    // refuse must not cost the user a re-authentication and ten new codes.
    final parsed = _parsePhone();
    final number = parsed.number;
    if (number == null) {
      setState(() => _errorMessage = _phoneProblemMessage(parsed.problem!));
      return;
    }

    // Re-authenticate before enrolling MFA (sensitive operation)
    final reauthSuccess = await AuthActionHandler.reauthenticate(
      context,
      onError: (msg) => setState(() {
        _errorMessage = msg;
      }),
    );
    if (!reauthSuccess || !mounted) return;

    // Ten one-time codes BEFORE the protection applies: "Reservkoder hör i
    // påslagningen — tio engångskoder innan skyddet gäller"
    // (produktregler.md:748; Skarmar v12 etapp 6 #mfaaktiv). No codes, or
    // codes not acknowledged, and nothing is enrolled.
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final codes = await _authService.generateBackupCodes();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (codes == null) {
      setState(() {
        _errorMessage =
            _authService.errorMessage ?? context.l10n.mfaBackupCodesFailed;
      });
      return;
    }
    final acknowledged = await MfaBackupCodesDialog.show(context, codes);
    if (!acknowledged) {
      // Codes exist on the server but no factor will ever use them.
      await _authService.discardBackupCodes();
      return;
    }
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _authService.startMfaEnrollment(
      number.e164,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _sentTo = number.display;
          _isEnrolling = true;
          _isLoading = false;
        });
      },
      onError: (error) {
        // Runs even if the view is gone: the codes must not outlive a
        // failed enrollment.
        _authService.discardBackupCodes();
        if (!mounted) return;
        // Back to the phone step: with the codes gone, the code form must not
        // stay open to finish an enrollment that has none.
        setState(() {
          _errorMessage = _mapErrorMessage(error.code);
          _isLoading = false;
          _isEnrolling = false;
          _verificationId = null;
          _codeController.clear();
        });
      },
      onAutoVerified: () {
        if (!mounted) return;
        setState(() {
          _isEnrolling = false;
          _isLoading = false;
        });
        _loadMfaStatus();
        _showSuccessSnackBar(context.l10n.mfaActivated);
      },
    );
  }

  Future<void> _completeEnrollment() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _verificationId == null) {
      setState(() => _errorMessage = context.l10n.mfaEnterCode);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _verifyingCode = true;
    final bool success;
    try {
      success = await _authService.completeMfaEnrollment(
        _verificationId!,
        code,
      );
    } finally {
      _verifyingCode = false;
    }

    if (!mounted) return;

    if (success) {
      _codeController.clear();
      _phoneController.clear();
      _countryCodeController.text = '+46';
      setState(() {
        _isEnrolling = false;
        _verificationId = null;
      });
      await _loadMfaStatus();
      if (mounted) _showSuccessSnackBar(context.l10n.mfaActivated);
    } else {
      setState(() {
        _errorMessage =
            _authService.errorMessage ?? context.l10n.mfaVerificationFailed;
      });
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _unenrollMfa(MfaFactorInfo factor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.mfaRemoveTitle),
        content: Text(context.l10n.mfaRemoveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.commonRemove),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Re-authenticate before unenrolling MFA (sensitive operation)
    final reauthSuccess = await AuthActionHandler.reauthenticate(
      context,
      onError: (msg) => setState(() {
        _errorMessage = msg;
        _isLoading = false;
      }),
    );
    if (!reauthSuccess) return;

    setState(() => _isLoading = true);

    final success = await _authService.unenrollMfa(factor);

    if (!mounted) return;

    if (success) {
      await _loadMfaStatus();
      if (mounted) _showSuccessSnackBar(context.l10n.mfaDeactivated);
    } else {
      setState(() {
        _errorMessage =
            _authService.errorMessage ?? context.l10n.mfaCouldNotRemove;
      });
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _cancelCodeEntry() async {
    setState(() {
      _isEnrolling = false;
      _verificationId = null;
      _errorMessage = null;
      _codeController.clear();
    });
    // The codes were made for this attempt and no factor will use them.
    await _authService.discardBackupCodes();
  }

  void _showSuccessSnackBar(String message) {
    SnackBarUtils.showSuccess(context, message);
  }

  String _mapErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return context.l10n.mfaInvalidPhoneNumber;
      case 'quota-exceeded':
        return context.l10n.mfaQuotaExceeded;
      case 'invalid-verification-code':
        return context.l10n.mfaInvalidCode;
      case 'unverified-email':
        return context.l10n.mfaErrorUnverifiedEmail;
      case 'second-factor-already-in-use':
        return context.l10n.mfaErrorSecondFactorInUse;
      case 'requires-recent-login':
        return context.l10n.mfaErrorRequiresRecentLogin;
      default:
        return context.l10n.errorGeneric;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ButleryTopBar.undersida(
        title: context.l10n.mfaTitle,
        backTo: context.l10n.accountSecurityTitle,
      ),
      body: _isLoading && !_isEnrolling
          ? StateWidget.loading(message: context.l10n.loadingMfaSettings)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.spacingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: AppDimensions.spacingLg),
                      if (_hasMfa)
                        _buildEnrolledSection()
                      else if (widget.offersEnrollment)
                        _buildEnrollSection(),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppDimensions.spacingMd),
                        MfaErrorBanner(message: _errorMessage!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Row(
          children: [
            ButleryIcon(
              _hasMfa ? ButleryIcons.shieldCheck : ButleryIcons.shield,
              color: _hasMfa
                  ? context.modeColors.success
                  : context.modeColors.warning,
              size: 40,
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hasMfa
                        ? context.l10n.mfaEnabled
                        : context.l10n.mfaDisabled,
                    style: AppTextStyles.titleBold,
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  // Without the form, "Aktivera MFA för extra säkerhet" would
                  // point at something the view no longer offers
                  // (PQ-16).
                  if (_hasMfa || widget.offersEnrollment)
                    Text(
                      _hasMfa
                          ? context.l10n.mfaAccountProtected
                          : context.l10n.mfaEnableForSecurity,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrolledSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.mfaRegisteredMethods,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        ..._enrolledFactors.map(
          (factor) => Card(
            child: ListTile(
              leading: const ButleryIcon(ButleryIcons.smartphone),
              title: Text(factor.displayName ?? context.l10n.mfaPhone),
              subtitle: Text(
                context.l10n.mfaRegistered(
                  _formatEnrollmentTime(factor.enrollmentTimestamp),
                ),
              ),
              trailing: IconButton(
                icon: ButleryIcon(
                  ButleryIcons.trash2,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _unenrollMfa(factor),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnrollSection() {
    if (_isEnrolling) {
      return MfaCodeVerificationForm(
        sentTo: _sentTo,
        codeController: _codeController,
        busy: _isLoading,
        onCancel: _cancelCodeEntry,
        onVerify: _completeEnrollment,
      );
    }
    return MfaPhoneInputForm(
      countryCodeController: _countryCodeController,
      phoneController: _phoneController,
      busy: _isLoading,
      onSend: _startEnrollment,
    );
  }

  // firebase_auth reports the enrollment time in seconds on every platform.
  String _formatEnrollmentTime(double? timestamp) {
    if (timestamp == null) return context.l10n.commonUnknown;
    final date = DateTime.fromMillisecondsSinceEpoch(
      (timestamp * 1000).toInt(),
    );
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

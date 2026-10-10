import 'package:flutter/foundation.dart';
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
/// The ten backup codes are shown and acknowledged before the authenticator
/// app is enrolled (below), because without them a lost phone locks the
/// account; the way back in is the recovery with a code
/// (functions/src/account/mfa-backup-codes.ts).
class MfaSettingsView extends StatefulWidget {
  const MfaSettingsView({super.key});

  @override
  State<MfaSettingsView> createState() => _MfaSettingsViewState();
}

class _MfaSettingsViewState extends State<MfaSettingsView> {
  final AuthMfaService _authService = ServiceLocator.get<AuthMfaService>();
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = false;
  bool _hasMfa = false;
  bool _isEnrolling = false;
  bool _verifyingCode = false;
  MfaTotpSetup? _setup;
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

  Future<void> _startEnrollment() async {
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
    final setup = await _authService.startMfaEnrollment();
    if (setup == null) {
      // Runs even if the view is gone: the codes must not outlive a failed
      // enrollment.
      await _authService.discardBackupCodes();
      if (!mounted) return;
      setState(() {
        _errorMessage =
            _authService.errorMessage ?? context.l10n.mfaSetupFailed;
        _isLoading = false;
      });
      return;
    }
    if (!mounted) {
      await _authService.discardBackupCodes();
      return;
    }
    setState(() {
      _setup = setup;
      _isEnrolling = true;
      _isLoading = false;
    });
  }

  Future<void> _openInApp() async {
    final setup = _setup;
    if (setup == null) return;
    final opened = await _authService.openInAuthenticatorApp(setup);
    if (!opened && mounted) {
      setState(() => _errorMessage = context.l10n.mfaSetupOpenFailed);
    }
  }

  void _copyKey() {
    final setup = _setup;
    if (setup == null) return;
    copyMfaSecret(setup.secretKey);
    SnackBarUtils.showInfo(context, context.l10n.mfaSetupKeyCopied);
  }

  Future<void> _completeEnrollment() async {
    final code = _codeController.text.trim();
    final setup = _setup;
    if (code.length != 6 || setup == null) {
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
      success = await _authService.completeMfaEnrollment(setup, code);
    } finally {
      _verifyingCode = false;
    }

    if (!mounted) return;

    if (success) {
      _codeController.clear();
      setState(() {
        _isEnrolling = false;
        _setup = null;
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
    // Same rule as dispose: while the code is verified the factor may still
    // land, and clearing its codes would leave it with none.
    if (_verifyingCode) return;
    setState(() {
      _isEnrolling = false;
      _setup = null;
      _errorMessage = null;
      _codeController.clear();
    });
    // The codes were made for this attempt and no factor will use them.
    await _authService.discardBackupCodes();
  }

  void _showSuccessSnackBar(String message) {
    SnackBarUtils.showSuccess(context, message);
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
                      else
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
              title: Text(factor.displayName ?? context.l10n.mfaAppTitle),
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
    final setup = _setup;
    if (_isEnrolling && setup != null) {
      return MfaTotpSetupForm(
        secretKey: setup.secretKey,
        canOpenApp: !kIsWeb,
        codeController: _codeController,
        busy: _isLoading,
        onOpenApp: _openInApp,
        onCopyKey: _copyKey,
        onCancel: _isLoading ? null : _cancelCodeEntry,
        onConfirm: _completeEnrollment,
      );
    }
    return MfaEnrollStartForm(busy: _isLoading, onStart: _startEnrollment);
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

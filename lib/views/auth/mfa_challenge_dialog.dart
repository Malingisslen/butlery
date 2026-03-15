import 'package:flutter/material.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/widgets/styled/styled_button.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Dialog for handling MFA challenge during sign-in.
/// Shows when a user with MFA enabled attempts to log in.
class MfaChallengeDialog extends StatefulWidget {
  final MfaResolverInfo resolver;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const MfaChallengeDialog({
    super.key,
    required this.resolver,
    required this.onSuccess,
    required this.onCancel,
  });

  /// Show the MFA challenge dialog.
  /// Returns true if MFA was completed successfully.
  static Future<bool> show(
    BuildContext context,
    MfaResolverInfo resolver,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MfaChallengeDialog(
        resolver: resolver,
        onSuccess: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
    return result ?? false;
  }

  @override
  State<MfaChallengeDialog> createState() => _MfaChallengeDialogState();
}

class _MfaChallengeDialogState extends State<MfaChallengeDialog> {
  final AuthMfaService _authService = ServiceLocator.get<AuthMfaService>();
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  String? _verificationId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startVerification();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _startVerification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _authService.startMfaSignIn(
      widget.resolver,
      onCodeSent: (verificationId) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _isLoading = false;
        });
      },
      onError: (error) {
        AppLogger.error('MFA verification error: ${error.code}');
        setState(() {
          _errorMessage = _mapErrorMessage(error.code);
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _verificationId == null) {
      setState(() => _errorMessage = context.l10n.mfaEnterCode);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await _authService.completeMfaSignIn(
      widget.resolver,
      _verificationId!,
      code,
    );

    if (success) {
      widget.onSuccess();
    } else {
      setState(() {
        _errorMessage =
            _authService.errorMessage ?? context.l10n.mfaVerificationFailed;
        _isLoading = false;
      });
    }
  }

  String _mapErrorMessage(String code) {
    switch (code) {
      case 'invalid-verification-code':
        return context.l10n.mfaInvalidCode;
      case 'session-expired':
        return context.l10n.mfaSessionExpired;
      case 'quota-exceeded':
        return context.l10n.mfaQuotaExceeded;
      case 'no-phone-factor':
        return context.l10n.mfaNoPhoneFactor;
      default:
        return context.l10n.errorGeneric;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.security,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Text(context.l10n.mfaTitle),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_codeSent) ...[
              Text(context.l10n.mfaSendingCode),
              if (widget.resolver.phoneHint != null) ...[
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  context.l10n.mfaSendingTo(widget.resolver.phoneHint!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_isLoading) ...[
                const SizedBox(height: AppDimensions.spacingMd),
                const Center(child: CircularProgressIndicator()),
              ],
            ] else ...[
              Text(
                context.l10n.mfaCodeSentTo(
                    widget.resolver.phoneHint ?? context.l10n.mfaYourPhone),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.mfaSixDigitCode,
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
                onSubmitted: (_) => _verifyCode(),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: AppDimensions.spacingL),
              Container(
                padding: AppDimensions.paddingAll8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        size: AppDimensions.iconSizeM),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : widget.onCancel,
          child: Text(context.l10n.commonCancel),
        ),
        if (_codeSent)
          TextButton(
            onPressed: _isLoading ? null : _startVerification,
            child: Text(context.l10n.mfaResend),
          ),
        if (_codeSent)
          StyledButton.primary(
            text: context.l10n.mfaVerify,
            onPressed: _isLoading ? null : _verifyCode,
            isLoading: _isLoading,
          ),
      ],
    );
  }
}

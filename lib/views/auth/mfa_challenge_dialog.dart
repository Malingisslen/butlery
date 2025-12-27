import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/widgets/styled/styled_button.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/logger.dart';

/// Dialog for handling MFA challenge during sign-in.
/// Shows when a user with MFA enabled attempts to log in.
class MfaChallengeDialog extends StatefulWidget {
  final MultiFactorResolver resolver;
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
    MultiFactorResolver resolver,
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
  final AuthService _authService = GetIt.instance<AuthService>();
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  String? _verificationId;
  String? _errorMessage;
  String? _phoneHint;

  @override
  void initState() {
    super.initState();
    _extractPhoneHint();
    _startVerification();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _extractPhoneHint() {
    final phoneInfo =
        widget.resolver.hints.whereType<PhoneMultiFactorInfo>().firstOrNull;
    if (phoneInfo != null) {
      _phoneHint = phoneInfo.phoneNumber;
    }
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
      setState(() => _errorMessage = 'Ange verifieringskoden');
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
        _errorMessage = _authService.errorMessage ?? 'Verifiering misslyckades';
        _isLoading = false;
      });
    }
  }

  String _mapErrorMessage(String code) {
    switch (code) {
      case 'invalid-verification-code':
        return 'Ogiltig kod. Försök igen.';
      case 'session-expired':
        return 'Sessionen har gått ut. Försök logga in igen.';
      case 'quota-exceeded':
        return 'För många försök. Försök igen senare.';
      case 'no-phone-factor':
        return 'Ingen telefonverifiering konfigurerad.';
      default:
        return 'Ett fel uppstod. Försök igen.';
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
          const Text('Tvåfaktorsverifiering'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_codeSent) ...[
              const Text('Skickar verifieringskod...'),
              if (_phoneHint != null) ...[
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  'Till: $_phoneHint',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_isLoading) ...[
                const SizedBox(height: AppDimensions.spacingMd),
                const Center(child: CircularProgressIndicator()),
              ],
            ] else ...[
              Text(
                'En verifieringskod har skickats till ${_phoneHint ?? "ditt telefonnummer"}.',
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '6-siffrig kod',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                onSubmitted: (_) => _verifyCode(),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: AppDimensions.spacingL),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 20),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
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
          child: const Text('Avbryt'),
        ),
        if (_codeSent)
          TextButton(
            onPressed: _isLoading ? null : _startVerification,
            child: const Text('Skicka igen'),
          ),
        if (_codeSent)
          StyledButton.primary(
            text: 'Verifiera',
            onPressed: _isLoading ? null : _verifyCode,
            isLoading: _isLoading,
          ),
      ],
    );
  }
}

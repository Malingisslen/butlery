import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/styled/styled_button.dart';
import 'package:butlery/widgets/styled/styled_card.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// View for managing Multi-Factor Authentication settings.
/// Allows users to enroll or unenroll phone-based MFA.
class MfaSettingsView extends StatefulWidget {
  const MfaSettingsView({super.key});

  @override
  State<MfaSettingsView> createState() => _MfaSettingsViewState();
}

class _MfaSettingsViewState extends State<MfaSettingsView> {
  final AuthService _authService = GetIt.instance<AuthService>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = false;
  bool _hasMfa = false;
  bool _isEnrolling = false;
  String? _verificationId;
  String? _errorMessage;
  List<MultiFactorInfo> _enrolledFactors = [];

  @override
  void initState() {
    super.initState();
    _loadMfaStatus();
  }

  @override
  void dispose() {
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

    setState(() => _isLoading = false);
  }

  Future<void> _startEnrollment() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = context.l10n.mfaEnterPhoneNumber);
      return;
    }

    // Ensure phone number has country code
    final formattedPhone = phone.startsWith('+') ? phone : '+46$phone';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _authService.startMfaEnrollment(
      formattedPhone,
      onCodeSent: (verificationId) {
        setState(() {
          _verificationId = verificationId;
          _isEnrolling = true;
          _isLoading = false;
        });
      },
      onError: (error) {
        setState(() {
          _errorMessage = _mapErrorMessage(error.code);
          _isLoading = false;
        });
      },
      onAutoVerified: () {
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

    final success = await _authService.completeMfaEnrollment(
      _verificationId!,
      code,
    );

    if (success) {
      _codeController.clear();
      _phoneController.clear();
      setState(() {
        _isEnrolling = false;
        _verificationId = null;
      });
      await _loadMfaStatus();
      _showSuccessSnackBar('MFA aktiverat!');
    } else {
      setState(() {
        _errorMessage =
            _authService.errorMessage ?? context.l10n.mfaVerificationFailed;
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _unenrollMfa(MultiFactorInfo factor) async {
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
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(context.l10n.commonRemove),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final success = await _authService.unenrollMfa(factor);

    if (success) {
      await _loadMfaStatus();
      _showSuccessSnackBar(context.l10n.mfaDeactivated);
    } else {
      setState(() {
        _errorMessage =
            _authService.errorMessage ?? context.l10n.mfaCouldNotRemove;
      });
    }

    setState(() => _isLoading = false);
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  String _mapErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return context.l10n.mfaInvalidPhoneNumber;
      case 'quota-exceeded':
        return context.l10n.mfaQuotaExceeded;
      case 'invalid-verification-code':
        return context.l10n.mfaInvalidCode;
      default:
        return context.l10n.errorGeneric;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.mfaTitle),
      ),
      body: _isLoading && !_isEnrolling
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                    _buildErrorMessage(),
                  ],
                ],
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
            Icon(
              _hasMfa ? Icons.verified_user : Icons.security,
              color: _hasMfa ? AppColors.success : AppColors.warning,
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
        ..._enrolledFactors.map((factor) => Card(
              child: ListTile(
                leading: const Icon(Icons.phone_android),
                title: Text(factor.displayName ?? context.l10n.mfaPhone),
                subtitle: Text(context.l10n.mfaRegistered(
                    _formatEnrollmentTime(factor.enrollmentTimestamp))),
                trailing: IconButton(
                  icon:
                      const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => _unenrollMfa(factor),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildEnrollSection() {
    if (_isEnrolling) {
      return _buildCodeVerificationForm();
    }
    return _buildPhoneInputForm();
  }

  Widget _buildPhoneInputForm() {
    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.mfaAddPhoneNumber,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(context.l10n.mfaSmsDescription),
            const SizedBox(height: AppDimensions.spacingMd),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: context.l10n.mfaPhoneNumber,
                hintText: '+46701234567',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            SizedBox(
              width: double.infinity,
              child: StyledButton.primary(
                text: context.l10n.mfaSendCode,
                onPressed: _isLoading ? null : _startEnrollment,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeVerificationForm() {
    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.mfaEnterVerificationCode,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(context.l10n.mfaCodeSentTo(_phoneController.text)),
            const SizedBox(height: AppDimensions.spacingMd),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: context.l10n.mfaSixDigitCode,
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Row(
              children: [
                Expanded(
                  child: StyledButton.secondary(
                    text: context.l10n.commonCancel,
                    onPressed: () {
                      setState(() {
                        _isEnrolling = false;
                        _verificationId = null;
                        _codeController.clear();
                      });
                    },
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingL),
                Expanded(
                  child: StyledButton.primary(
                    text: context.l10n.mfaVerify,
                    onPressed: _isLoading ? null : _completeEnrollment,
                    isLoading: _isLoading,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.onErrorContainer),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  String _formatEnrollmentTime(double? timestamp) {
    if (timestamp == null) return context.l10n.commonUnknown;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

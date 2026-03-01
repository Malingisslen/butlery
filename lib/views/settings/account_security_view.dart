import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/account_security_viewmodel.dart';
import 'package:butlery/views/settings/mfa_settings_view.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

class AccountSecurityView extends StatefulWidget {
  const AccountSecurityView({super.key});

  @override
  State<AccountSecurityView> createState() => _AccountSecurityViewState();
}

class _AccountSecurityViewState extends State<AccountSecurityView> {
  final _viewModel = AccountSecurityViewModel();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailPasswordController = TextEditingController();
  final _newEmailController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureEmailPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _emailPasswordController.dispose();
    _newEmailController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    final success = await _viewModel.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.accountSecurityPasswordChanged)),
      );
    } else if (_viewModel.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_viewModel.error!),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleChangeEmail() async {
    final success = await _viewModel.changeEmail(
      currentPassword: _emailPasswordController.text,
      newEmail: _newEmailController.text,
    );

    if (!mounted) return;

    if (success) {
      _emailPasswordController.clear();
      _newEmailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.accountSecurityEmailVerificationSent),
        ),
      );
    } else if (_viewModel.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_viewModel.error!),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.accountSecurityTitle)),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPasswordSection(),
                    const SizedBox(height: AppDimensions.spacingXl),
                    const Divider(),
                    const SizedBox(height: AppDimensions.spacingXl),
                    _buildEmailSection(),
                    const SizedBox(height: AppDimensions.spacingXl),
                    const Divider(),
                    const SizedBox(height: AppDimensions.spacingXl),
                    _buildMfaSection(),
                    const SizedBox(height: AppDimensions.spacingXl),
                    const Divider(),
                    const SizedBox(height: AppDimensions.spacingXl),
                    _buildLegalSection(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPasswordSection() {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lock_outline, color: cs.primary),
            const SizedBox(width: AppDimensions.spacingSm),
            Text(
              context.l10n.accountSecurityChangePassword,
              style: AppTextStyles.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        TextField(
          controller: _currentPasswordController,
          obscureText: _obscureCurrentPassword,
          decoration: InputDecoration(
            labelText: context.l10n.accountSecurityCurrentPassword,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscureCurrentPassword
                  ? Icons.visibility_off
                  : Icons.visibility),
              tooltip: _obscureCurrentPassword
                  ? context.l10n.a11yShowPassword
                  : context.l10n.a11yHidePassword,
              onPressed: () => setState(
                  () => _obscureCurrentPassword = !_obscureCurrentPassword),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          decoration: InputDecoration(
            labelText: context.l10n.accountSecurityNewPassword,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscureNewPassword
                  ? Icons.visibility_off
                  : Icons.visibility),
              tooltip: _obscureNewPassword
                  ? context.l10n.a11yShowPassword
                  : context.l10n.a11yHidePassword,
              onPressed: () =>
                  setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: context.l10n.accountSecurityConfirmPassword,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword
                  ? Icons.visibility_off
                  : Icons.visibility),
              tooltip: _obscureConfirmPassword
                  ? context.l10n.a11yShowPassword
                  : context.l10n.a11yHidePassword,
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _viewModel.isLoading ? null : _handleChangePassword,
            child: _viewModel.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.accountSecurityChangePassword),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailSection() {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.email_outlined, color: cs.primary),
            const SizedBox(width: AppDimensions.spacingSm),
            Text(
              context.l10n.accountSecurityChangeEmail,
              style: AppTextStyles.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        if (_viewModel.currentEmail != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
            child: Text(
              _viewModel.currentEmail!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        TextField(
          controller: _emailPasswordController,
          obscureText: _obscureEmailPassword,
          decoration: InputDecoration(
            labelText: context.l10n.accountSecurityCurrentPassword,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscureEmailPassword
                  ? Icons.visibility_off
                  : Icons.visibility),
              tooltip: _obscureEmailPassword
                  ? context.l10n.a11yShowPassword
                  : context.l10n.a11yHidePassword,
              onPressed: () => setState(
                  () => _obscureEmailPassword = !_obscureEmailPassword),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        TextField(
          controller: _newEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: context.l10n.accountSecurityNewEmail,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _viewModel.isLoading ? null : _handleChangeEmail,
            child: _viewModel.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.accountSecurityChangeEmail),
          ),
        ),
      ],
    );
  }

  Widget _buildMfaSection() {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.security, color: cs.primary),
            const SizedBox(width: AppDimensions.spacingSm),
            Text(
              context.l10n.accountSecurityMfaSettings,
              style: AppTextStyles.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        ListTile(
          leading: Icon(Icons.phone_android, color: cs.primary),
          title: Text(
            context.l10n.accountSecurityMfaSettings,
            style: AppTextStyles.titleMedium,
          ),
          trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          contentPadding: EdgeInsets.zero,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MfaSettingsView(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLegalSection() {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.gavel_outlined, color: cs.primary),
            const SizedBox(width: AppDimensions.spacingSm),
            Text(
              context.l10n.legalTermsOfService,
              style: AppTextStyles.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(context.l10n.legalTermsOfService),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, Routes.termsOfService),
        ),
        ListTile(
          leading: const Icon(Icons.people_outline),
          title: Text(context.l10n.legalCommunityGuidelines),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, Routes.communityGuidelines),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: Text(context.l10n.legalOpenSourceLicenses),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Butlery',
          ),
        ),
      ],
    );
  }
}

/// Central settings hub with grouped categories.
import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

class SettingsHubView extends StatelessWidget {
  const SettingsHubView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.commonSettings),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.paddingM,
              ),
              children: [
                _SectionHeader(title: context.l10n.settingsSectionFood),
                _SettingsTile(
                  icon: Icons.restaurant_menu,
                  title: context.l10n.allergenSettingsTitle,
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.settingsAllergens),
                ),
                _SettingsTile(
                  icon: Icons.label_outline,
                  title: context.l10n.personalTagsViewTitle,
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.settingsPersonalTags),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                _SectionHeader(
                    title: context.l10n.settingsSectionNotifications),
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: context.l10n.notificationTitle,
                  onTap: () => Navigator.pushNamed(
                      context, Routes.settingsNotifications),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                _SectionHeader(title: context.l10n.settingsSectionAccount),
                _SettingsTile(
                  icon: Icons.security,
                  title: context.l10n.accountSecurityTitle,
                  onTap: () => Navigator.pushNamed(
                      context, Routes.settingsAccountSecurity),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                _SectionHeader(title: context.l10n.settingsSectionAbout),
                _SettingsTile(
                  icon: Icons.help_outline,
                  title: context.l10n.profileFaq,
                  onTap: () => Navigator.pushNamed(context, Routes.faq),
                ),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: context.l10n.legalTermsOfService,
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.termsOfService),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  child: Text(
                    'Butlery',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingS,
      ),
      child: Text(
        title,
        style: AppTextStyles.metadataEmphasized.copyWith(
          color: cs.primary,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.onSurfaceVariant),
      title: Text(title, style: AppTextStyles.bodyMedium),
      trailing: Icon(Icons.chevron_right, color: cs.outline),
      onTap: onTap,
    );
  }
}

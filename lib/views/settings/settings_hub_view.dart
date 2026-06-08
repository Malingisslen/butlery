/// Central settings hub with grouped categories.
import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/providers/locale_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';
import 'package:butlery/widgets/common/profile/handlers/backup_restore_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsHubView extends StatelessWidget {
  const SettingsHubView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reportService = ServiceLocator.get<ReportService>();

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
                  subtitle: context.l10n.allergenSettingsHubSubtitle,
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
                // BUT-970: surface backup_service from ProfileMenu into formal
                // Settings (it was already wired via BackupRestoreHandler, just
                // not discoverable from /settings).
                _SettingsTile(
                  icon: Icons.download_outlined,
                  title: context.l10n.profileDownloadBackup,
                  onTap: () => BackupRestoreHandler.handleBackup(context),
                ),
                _SettingsTile(
                  icon: Icons.upload_outlined,
                  title: context.l10n.profileRestoreFromBackup,
                  onTap: () => BackupRestoreHandler.handleRestore(context),
                ),
                // BUT-913: GDPR-required Sign-out + Delete-Account surfaces.
                // Handlers already exist on AuthActionHandler (used by
                // ProfileMenu bottom-sheet) — this just makes them findable
                // from /settings.
                _SettingsTile(
                  icon: Icons.logout,
                  title: context.l10n.profileLogout,
                  onTap: () => AuthActionHandler.handleLogout(context),
                ),
                _DangerSettingsTile(
                  icon: Icons.delete_forever,
                  title: context.l10n.profileDeleteAccount,
                  onTap: () => AuthActionHandler.handleDeleteAccount(context),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                _SectionHeader(title: context.l10n.settingsSectionLanguage),
                const LanguageTile(),
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
                _SettingsTile(
                  icon: Icons.mail_outline,
                  title: context.l10n.appealEmailLinkLabel,
                  onTap: () => _launchAppealEmail(context),
                ),
                // Admin-only entry point. StreamBuilder on admins/{uid}
                // existence — non-admins never see this tile.
                StreamBuilder<bool>(
                  stream: reportService.watchIsAdmin(),
                  builder: (context, snap) {
                    if (snap.data != true) return const SizedBox.shrink();
                    return _SettingsTile(
                      icon: Icons.shield_outlined,
                      title: context.l10n.moderatorReviewTitle,
                      onTap: () =>
                          Navigator.pushNamed(context, Routes.moderatorReview),
                    );
                  },
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

  Future<void> _launchAppealEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'appeals@butlery.app',
      queryParameters: {
        'subject': context.l10n.appealEmailSubject,
        'body': context.l10n.appealEmailBodyTemplate,
      },
    );
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.appealEmailLaunchFailed)),
        );
      }
    } catch (e) {
      AppLogger.error('[SettingsHub] Failed to launch appeal mailto', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.appealEmailLaunchFailed)),
        );
      }
    }
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
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: AppTextStyles.metadataEmphasized.copyWith(
            color: cs.primary,
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.onSurfaceVariant),
      title: Text(title, style: AppTextStyles.bodyMedium),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style:
                  AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant))
          : null,
      trailing: Icon(Icons.chevron_right, color: cs.outline),
      onTap: onTap,
    );
  }
}

/// BUT-913: Variant for destructive actions (Delete Account). Renders icon
/// and title in the error color so the irreversibility is visually flagged
/// before the confirmation dialog opens. Same tap semantics otherwise.
class _DangerSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DangerSettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.error),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(color: cs.error),
      ),
      trailing: Icon(Icons.chevron_right, color: cs.outline),
      onTap: onTap,
    );
  }
}

/// Language tile that listens to LocaleProvider so the subtitle updates
/// immediately after a switch (no need to back out + re-enter settings).
///
/// Public (rather than `_LanguageTile`) so widget tests can render it in
/// isolation without spinning up the full `SettingsHubView` dependency graph
/// (`ReportService.watchIsAdmin()` stream, route table, etc.).
class LanguageTile extends StatefulWidget {
  const LanguageTile({super.key});

  @override
  State<LanguageTile> createState() => _LanguageTileState();
}

class _LanguageTileState extends State<LanguageTile> {
  late final LocaleProvider _localeProvider;

  @override
  void initState() {
    super.initState();
    _localeProvider = ServiceLocator.get<LocaleProvider>();
    _localeProvider.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    _localeProvider.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.language, color: cs.onSurfaceVariant),
      title: Text(context.l10n.settingsLanguageTitle,
          style: AppTextStyles.bodyMedium),
      subtitle: Text(
        LocaleProvider.getLocaleName(_localeProvider.locale.languageCode),
        style: AppTextStyles.bodySmall.copyWith(color: cs.outline),
      ),
      trailing: Icon(Icons.chevron_right, color: cs.outline),
      onTap: () => _showLanguagePicker(context),
    );
  }

  Future<void> _showLanguagePicker(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final current = _localeProvider.locale.languageCode;
        return AlertDialog(
          title: Text(context.l10n.settingsLanguageDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: LocaleProvider.supportedLocales
                .map((code) => ListTile(
                      title: Text(LocaleProvider.getLocaleName(code)),
                      trailing:
                          code == current ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.of(ctx).pop(code),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.l10n.commonCancel),
            ),
          ],
        );
      },
    );
    if (selected != null && selected != _localeProvider.locale.languageCode) {
      await _localeProvider.setLocale(selected);
    }
  }
}

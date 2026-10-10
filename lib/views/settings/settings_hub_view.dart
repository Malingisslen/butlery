/// Central settings hub with grouped categories.
import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/appeal_mail.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/settings/widgets/household_allergen_filter_tile.dart';
import 'package:butlery/views/settings/widgets/meal_allergen_scope_tile.dart';
import 'package:butlery/views/settings/widgets/household_allergen_sharing_tile.dart';
import 'package:butlery/views/settings/widgets/language_tile.dart';
import 'package:butlery/views/settings/widgets/nutrition_strip_tile.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';
import 'package:butlery/widgets/common/profile/handlers/backup_restore_handler.dart';
import 'package:butlery/widgets/common/profile/handlers/gdpr_consent_handler.dart';

class SettingsHubView extends StatelessWidget {
  const SettingsHubView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reportService = ServiceLocator.get<ReportService>();

    return Scaffold(
      appBar: ButleryTopBar.undersida(
        title: context.l10n.commonSettings,
      ),
      bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
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
                  icon: ButleryIcons.users,
                  title: context.l10n.familyTitle,
                  subtitle: context.l10n.familyHubSubtitle,
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.settingsFamily),
                ),
                _SettingsTile(
                  icon: ButleryIcons.utensils,
                  title: context.l10n.allergenSettingsTitle,
                  subtitle: context.l10n.allergenSettingsHubSubtitle,
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.settingsAllergens),
                ),
                // BUT-1465: opt out of household-wide allergen filtering in
                // menus. Self-gates on hasHousehold (hidden when no household).
                const HouseholdAllergenFilterTile(),
                // BUT-2362: lunch and middag follow who is home. Self-gates
                // on a household and on the filter above being on.
                const MealAllergenScopeTile(),
                // BUT-643: kcal / protein / carbs / fat strip on recipes.
                const NutritionStripTile(),
                // BUT-1693: share your OWN list so the menu stops guessing for
                // you. Self-gates on the feature flag AND on there being a
                // household to share into — hidden otherwise.
                const HouseholdAllergenSharingTile(),
                // BUT-1594: household-size default that pre-sets recipe
                // portions and scales the weekly menu. (Was "Meny och smak"
                // with cuisine/skill tuning until BUT-1594 removed those.)
                _SettingsTile(
                  icon: ButleryIcons.users,
                  title: context.l10n.settingsHouseholdSizeTitle,
                  subtitle: context.l10n.settingsHouseholdSizeSubtitle,
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.settingsHousehold),
                ),
                _SettingsTile(
                  icon: ButleryIcons.tag,
                  title: context.l10n.personalTagsViewTitle,
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.settingsPersonalTags),
                ),
                // BUT-1306: auto-add checked-off shopping items to the pantry.
                const AutoAddPantryTile(),
                const SizedBox(height: AppDimensions.spacingMd),
                _SectionHeader(
                  title: context.l10n.settingsSectionNotifications,
                ),
                _SettingsTile(
                  icon: ButleryIcons.bell,
                  title: context.l10n.notificationTitle,
                  onTap: () => Navigator.pushNamed(
                    context,
                    Routes.settingsNotifications,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                _SectionHeader(title: context.l10n.settingsSectionAccount),
                _SettingsTile(
                  icon: ButleryIcons.shield,
                  title: context.l10n.accountSecurityTitle,
                  onTap: () => Navigator.pushNamed(
                    context,
                    Routes.settingsAccountSecurity,
                  ),
                ),
                // BUT-970: surface backup_service from ProfileMenu into formal
                // Settings (it was already wired via BackupRestoreHandler, just
                // not discoverable from /settings). BUT-2150: this is a plain
                // page, not a modal, so nothing closes before the result.
                _SettingsTile(
                  icon: ButleryIcons.download,
                  title: context.l10n.profileDownloadBackup,
                  onTap: () => BackupRestoreHandler.handleBackup(
                    context,
                    closeModal: false,
                  ),
                ),
                _SettingsTile(
                  icon: ButleryIcons.trash2,
                  title: context.l10n.trashTitle,
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.settingsTrash),
                ),
                _SettingsTile(
                  icon: ButleryIcons.upload,
                  title: context.l10n.profileRestoreFromBackup,
                  onTap: () => BackupRestoreHandler.handleRestore(
                    context,
                    closeModal: false,
                  ),
                ),
                // BUT-913: GDPR-required Sign-out + Delete-Account surfaces.
                // Handlers already exist on AuthActionHandler (used by
                // ProfileMenu bottom-sheet) — this just makes them findable
                // from /settings.
                _SettingsTile(
                  icon: ButleryIcons.logOut,
                  title: context.l10n.profileLogout,
                  onTap: () => AuthActionHandler.handleLogout(context),
                ),
                _DangerSettingsTile(
                  icon: ButleryIcons.trash2,
                  title: context.l10n.profileDeleteAccount,
                  onTap: () => AuthActionHandler.handleDeleteAccount(context),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                // BUT-2261: people look for these under Inställningar, not only in
                // the profile menu.
                _SectionHeader(title: context.l10n.settingsSectionPrivacy),
                _SettingsTile(
                  icon: ButleryIcons.shield,
                  title: context.l10n.profilePrivacyPolicy,
                  onTap: () => GdprConsentHandler.handlePrivacyPolicy(
                    context,
                    closeModal: false,
                  ),
                ),
                _SettingsTile(
                  icon: ButleryIcons.shield,
                  title: context.l10n.profileManageConsent,
                  onTap: () => GdprConsentHandler.handleManageConsent(
                    context,
                    closeModal: false,
                  ),
                ),
                _SettingsTile(
                  icon: ButleryIcons.export,
                  title: context.l10n.profileExportData,
                  subtitle: context.l10n.profileExportDataSubtitle,
                  onTap: () => GdprConsentHandler.handleExportData(
                    context,
                    closeModal: false,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                _SectionHeader(title: context.l10n.settingsSectionLanguage),
                const LanguageTile(),
                const SizedBox(height: AppDimensions.spacingMd),
                _SectionHeader(title: context.l10n.settingsSectionAbout),
                _SettingsTile(
                  icon: ButleryIcons.info,
                  title: context.l10n.settingsAboutTitle,
                  subtitle: context.l10n.settingsAboutSubtitle,
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.settingsAbout),
                ),
                _SettingsTile(
                  icon: ButleryIcons.circleHelp,
                  title: context.l10n.profileFaq,
                  onTap: () => Navigator.pushNamed(context, Routes.faq),
                ),
                _SettingsTile(
                  icon: ButleryIcons.file,
                  title: context.l10n.legalTermsOfService,
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.termsOfService),
                ),
                _SettingsTile(
                  icon: ButleryIcons.mail,
                  title: context.l10n.appealEmailLinkLabel,
                  onTap: () => launchAppealMail(
                    context,
                    buildAppealMailUri(
                      subject: context.l10n.appealEmailSubject,
                      body: context.l10n.appealEmailBodyTemplate,
                    ),
                  ),
                ),
                // Admin-only entry point. StreamBuilder on admins/{uid}
                // existence — non-admins never see this tile.
                StreamBuilder<bool>(
                  stream: reportService.watchIsAdmin(),
                  builder: (context, snap) {
                    if (snap.data != true) return const SizedBox.shrink();
                    return _SettingsTile(
                      icon: ButleryIcons.shield,
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
                      color: cs.onSurfaceVariant,
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
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: AppTextStyles.metadataEmphasized.copyWith(
            color: cs.onSurface,
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
      leading: ButleryIcon(icon, color: cs.onSurfaceVariant),
      title: Text(title, style: AppTextStyles.bodyMedium),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            )
          : null,
      trailing: ButleryIcon(ButleryIcons.chevronRight, color: cs.outline),
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
      leading: ButleryIcon(icon, color: cs.error),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(color: cs.error),
      ),
      trailing: ButleryIcon(ButleryIcons.chevronRight, color: cs.outline),
      onTap: onTap,
    );
  }
}

/// BUT-1306: Settings switch that toggles `autoAddBoughtToPantry`. Listens to
/// [UserService] so it reflects changes made elsewhere (e.g. the one-time
/// first-checkoff prompt enabling it). Reads/writes the complete user profile
/// via UserService per the data-source rule — never PermissionService.
///
/// Public (not `_AutoAddPantryTile`) so widget tests can render it in isolation
/// without the full [SettingsHubView] dependency graph.
class AutoAddPantryTile extends StatefulWidget {
  const AutoAddPantryTile({super.key});

  @override
  State<AutoAddPantryTile> createState() => _AutoAddPantryTileState();
}

class _AutoAddPantryTileState extends State<AutoAddPantryTile> {
  late final UserService _userService;

  @override
  void initState() {
    super.initState();
    _userService = ServiceLocator.get<UserService>();
    _userService.addListener(_onUserChanged);
  }

  @override
  void dispose() {
    _userService.removeListener(_onUserChanged);
    super.dispose();
  }

  void _onUserChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onChanged(bool value) async {
    await _userService.setAutoAddToPantry(value);
    // setState driven by the UserService notifyListeners → _onUserChanged.
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled =
        _userService.currentUserProfile?.autoAddBoughtToPantry ?? false;
    return SwitchListTile(
      secondary: ButleryIcon(
        ButleryIcons.refrigerator,
        color: cs.onSurfaceVariant,
      ),
      title: Text(
        context.l10n.settingsAutoAddPantryTitle,
        style: AppTextStyles.bodyMedium,
      ),
      subtitle: Text(
        context.l10n.settingsAutoAddPantrySubtitle,
        style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
      ),
      value: enabled,
      onChanged: _onChanged,
    );
  }
}

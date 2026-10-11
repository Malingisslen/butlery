// lib/views/more/app_settings_view.dart
//
// Appinställningar under Mer: how the app looks and behaves on this phone
// (Mer, omtänkt, 2026-10-10). Language and theme left Redigera profil for
// here; '/settings' opens this page. Every choice saves at once and says so
// in a snackbar.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/providers/locale_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/theme_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/more/more_area_scaffold.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';

class AppSettingsView extends StatefulWidget {
  const AppSettingsView({super.key});

  @override
  State<AppSettingsView> createState() => _AppSettingsViewState();
}

class _AppSettingsViewState extends State<AppSettingsView> {
  late final LocaleProvider _localeProvider;
  late final ThemeService _themeService;

  @override
  void initState() {
    super.initState();
    _localeProvider = ServiceLocator.get<LocaleProvider>();
    _themeService = ServiceLocator.get<ThemeService>();
    _localeProvider.addListener(_onChanged);
    _themeService.addListener(_onChanged);
  }

  @override
  void dispose() {
    _localeProvider.removeListener(_onChanged);
    _themeService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  List<(ThemeMode, String)> _themeOptions(BuildContext context) => [
    (ThemeMode.system, context.l10n.profileThemeSystem),
    (ThemeMode.light, context.l10n.profileThemeLight),
    (ThemeMode.dark, context.l10n.profileThemeDark),
  ];

  Future<void> _pickLanguage() async {
    final picked = await showButleryChoiceSheet<String>(
      context,
      title: context.l10n.settingsLanguageTitle,
      options: [
        for (final code in LocaleProvider.supportedLocales)
          (code, LocaleProvider.getLocaleName(code)),
      ],
      selected: _localeProvider.locale.languageCode,
    );
    if (picked == null || picked == _localeProvider.locale.languageCode) {
      return;
    }
    await _localeProvider.setLocale(picked);
    if (!mounted) return;
    SnackBarUtils.showSuccess(
      context,
      context.l10n.profileLanguageChangedTo(
        LocaleProvider.getLocaleName(picked),
      ),
    );
  }

  Future<void> _pickTheme() async {
    final options = _themeOptions(context);
    final picked = await showButleryChoiceSheet<ThemeMode>(
      context,
      title: context.l10n.profileTheme,
      options: options,
      selected: _themeService.themeMode,
    );
    if (picked == null || picked == _themeService.themeMode) return;
    await _themeService.setThemeMode(picked);
    if (!mounted) return;
    final label = options.firstWhere((o) => o.$1 == picked).$2;
    SnackBarUtils.showSuccess(
      context,
      context.l10n.profileThemeChangedTo(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final themeLabel = _themeOptions(
      context,
    ).firstWhere((o) => o.$1 == _themeService.themeMode).$2;
    return MoreAreaScaffold(
      title: l10n.settingsAppTitle,
      sections: [
        ButleryListSection(
          title: l10n.settingsAppearanceSection,
          rows: [
            ButleryListRow(
              label: l10n.settingsLanguageTitle,
              value: LocaleProvider.getLocaleName(
                _localeProvider.locale.languageCode,
              ),
              onTap: _pickLanguage,
            ),
            ButleryListRow(
              label: l10n.profileTheme,
              value: themeLabel,
              onTap: _pickTheme,
            ),
          ],
        ),
        ButleryListSection(
          title: l10n.moreNotifications,
          rows: [
            ButleryListRow(
              label: l10n.settingsNotificationSettings,
              onTap: () =>
                  Navigator.pushNamed(context, Routes.settingsNotifications),
            ),
          ],
        ),
        ButleryListSection(
          title: l10n.settingsShoppingSection,
          rows: const [AutoAddPantryRow()],
        ),
      ],
    );
  }
}

/// BUT-1306: the switch for `autoAddBoughtToPantry`. Listens to
/// [UserService] so it follows a change made elsewhere (the one-time prompt
/// at the first check-off turns it on). Reads and writes the user profile
/// through UserService, never PermissionService.
class AutoAddPantryRow extends StatefulWidget {
  const AutoAddPantryRow({super.key});

  @override
  State<AutoAddPantryRow> createState() => _AutoAddPantryRowState();
}

class _AutoAddPantryRowState extends State<AutoAddPantryRow> {
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

  @override
  Widget build(BuildContext context) {
    return ButleryListRow.toggle(
      label: context.l10n.settingsAutoAddPantryTitle,
      subtitle: context.l10n.settingsAutoAddPantrySubtitle,
      checked: _userService.currentUserProfile?.autoAddBoughtToPantry ?? false,
      // The rebuild comes from UserService's notifyListeners.
      onChanged: _userService.setAutoAddToPantry,
    );
  }
}

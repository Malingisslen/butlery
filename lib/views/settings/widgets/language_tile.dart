import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/providers/locale_provider.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

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
      leading: ButleryIcon(ButleryIcons.globe, color: cs.onSurfaceVariant),
      title: Text(
        context.l10n.settingsLanguageTitle,
        style: AppTextStyles.bodyMedium,
      ),
      subtitle: Text(
        LocaleProvider.getLocaleName(_localeProvider.locale.languageCode),
        style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: ButleryIcon(ButleryIcons.chevronRight, color: cs.outline),
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
                .map(
                  (code) => ListTile(
                    title: Text(LocaleProvider.getLocaleName(code)),
                    trailing: code == current
                        ? const ButleryIcon(ButleryIcons.check)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(code),
                  ),
                )
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

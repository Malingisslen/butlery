import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/version_info.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';

class AboutButleryView extends StatelessWidget {
  const AboutButleryView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final version = VersionInfo.appVersion;

    return Scaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.settingsAboutTitle,
        centerTitle: true,
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
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  child: Column(
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Butlery',
                          style: AppTextStyles.headlineSmall,
                        ),
                      ),
                      // VersionInfo keeps 'unknown' when the platform call
                      // fails; a version line that says so helps nobody.
                      if (version != 'unknown') ...[
                        const SizedBox(height: AppDimensions.spacingSm),
                        Text(
                          context.l10n.settingsAboutVersion(version),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.article_outlined, color: cs.primary),
                  title: Text(
                    context.l10n.settingsLicensesTitle,
                    style: AppTextStyles.titleMedium,
                  ),
                  subtitle: Text(context.l10n.settingsLicensesSubtitle),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: cs.onSurfaceVariant,
                  ),
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.settingsLicenses),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

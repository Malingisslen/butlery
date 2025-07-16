// lib/views/lagg_till_recept_view.dart

import 'package:flutter/material.dart';
import '../widgets/common/layout_components.dart';
import '../widgets/common/utility_components.dart';
import '../services/dialog_service.dart';
import '../theme/app_theme.dart';

/// ✨ 100% THEME-CENTRALISERAD LÄGG TILL RECEPT VY - MIGRERAD TILL UtilityComponents
class LaggTillReceptView extends StatelessWidget {
  const LaggTillReceptView({super.key});

  void _navigate(BuildContext context, String routeName) {
    Navigator.pushNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          DialogService.showExitDialogAndExit(context);
        }
      },
      child: LayoutComponents.mainMenu(
        currentIndex: 1,
        body: Padding(
          padding: AppTheme.sectionPadding,
          child: ListView(
            children: [
              Text(
                'Hur vill du lägga till ditt recept?',
                style: AppTheme.sectionTitleStyle,
              ),
              AppTheme.extraLargeGap,

              // ✅ MIGRERAD: ActionButton.primary → UtilityComponents.primaryButton
              UtilityComponents.primaryButton(
                context,
                label: 'INSTAGRAM',
                icon: Icons.camera_alt,
                onPressed: () => _navigate(context, '/franSocialaMedier'),
                isExpanded: true,
              ),
              AppTheme.mediumGap,

              // ✅ MIGRERAD: ActionButton.primary → UtilityComponents.primaryButton
              UtilityComponents.primaryButton(
                context,
                label: 'FACEBOOK',
                icon: Icons.facebook,
                onPressed: () => _navigate(context, '/franSocialaMedier'),
                isExpanded: true,
              ),
              AppTheme.mediumGap,

              // ✅ MIGRERAD: ActionButton.primary → UtilityComponents.primaryButton
              UtilityComponents.primaryButton(
                context,
                label: 'TIKTOK',
                icon: Icons.music_note,
                onPressed: () => _navigate(context, '/franSocialaMedier'),
                isExpanded: true,
              ),
              AppTheme.mediumGap,

              // ✅ MIGRERAD: ActionButton.primary → UtilityComponents.primaryButton
              UtilityComponents.primaryButton(
                context,
                label: 'FOTO',
                icon: Icons.photo,
                onPressed: () => _navigate(context, '/photoImport'),
                isExpanded: true,
              ),
              AppTheme.mediumGap,

              // ✅ MIGRERAD: ActionButton.primary → UtilityComponents.primaryButton
              UtilityComponents.primaryButton(
                context,
                label: 'LÄNK',
                icon: Icons.link,
                onPressed: () => _navigate(context, '/importViaUrl'),
                isExpanded: true,
              ),
              AppTheme.mediumGap,

              // ✅ MIGRERAD: ActionButton.primary → UtilityComponents.primaryButton
              UtilityComponents.primaryButton(
                context,
                label: 'SKRIV SJÄLV',
                icon: Icons.edit,
                onPressed: () => _navigate(context, '/skrivSjalv'),
                isExpanded: true,
              ),
              AppTheme.mediumGap,

              // ✅ MIGRERAD: ActionButton.primary → UtilityComponents.primaryButton
              UtilityComponents.primaryButton(
                context,
                label: 'ARKIV',
                icon: Icons.archive,
                onPressed: () => _navigate(context, '/importFranArkiv'),
                isExpanded: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

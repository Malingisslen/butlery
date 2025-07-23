// lib/views/lagg_till_recept_view.dart

import 'package:flutter/material.dart';
import '../widgets/common/layout_components.dart';
import '../widgets/common/utility_components.dart';
import '../services/dialog_service.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';

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
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hur vill du lägga till ditt recept?',
                  style: AppTextStyles.headlineSmall,
                ),
              const SizedBox(height: AppDimensions.spacingL),

              // 2x3 Grid using layout component
              LayoutComponents.squareButtonGrid(
                context,
                buttons: [
                  {
                    'label': 'INSTAGRAM',
                    'icon': Icons.camera_alt,
                    'onPressed': () => _navigate(context, '/franSocialaMedier'),
                  },
                  {
                    'label': 'FACEBOOK',
                    'icon': Icons.facebook,
                    'onPressed': () => _navigate(context, '/franSocialaMedier'),
                  },
                  {
                    'label': 'TIKTOK',
                    'icon': Icons.music_note,
                    'onPressed': () => _navigate(context, '/franSocialaMedier'),
                  },
                  {
                    'label': 'FOTO',
                    'icon': Icons.photo,
                    'onPressed': () => _navigate(context, '/photoImport'),
                  },
                  {
                    'label': 'LÄNK',
                    'icon': Icons.link,
                    'onPressed': () => _navigate(context, '/importViaUrl'),
                  },
                  {
                    'label': 'SKRIV SJÄLV',
                    'icon': Icons.edit,
                    'onPressed': () => _navigate(context, '/skrivSjalv'),
                  },
                ],
              ),
              
              const SizedBox(height: AppDimensions.spacingL),

              // Large bottom button for Archive
              UtilityComponents.largeButton(
                context,
                label: 'ARKIV',
                icon: Icons.archive,
                onPressed: () => _navigate(context, '/importFranArkiv'),
                margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingL + AppDimensions.spacingS),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

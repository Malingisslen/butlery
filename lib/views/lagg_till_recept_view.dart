// lib/views/lagg_till_recept_view.dart

import 'package:flutter/material.dart';
import '../widgets/main_layout_menu.dart';
import '../widgets/action_button.dart';
import '../theme/app_theme.dart';

/// ✨ 100% THEME-CENTRALISERAD LÄGG TILL RECEPT VY
class LaggTillReceptView extends StatelessWidget {
  const LaggTillReceptView({super.key});

  void _navigate(BuildContext context, String routeName) {
    Navigator.pushNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    return MainLayoutMenu(
      currentIndex: 1,
      body: Padding(
        padding: AppTheme.sectionPadding, // ✅ SEMANTISK PADDING (24px)
        child: ListView(
          children: [
            Text(
              'Hur vill du lägga till ditt recept?',
              style: AppTheme.sectionTitleStyle, // ✅ SEMANTISK STYLE
            ),
            AppTheme.extraLargeGap, // ✅ SEMANTISK GAP (32px)
            // Använder ActionButton för konsistens
            ActionButton.primary(
              label: 'INSTAGRAM',
              icon: Icons.camera_alt,
              onPressed: () => _navigate(context, '/franSocialaMedier'),
              isExpanded: true,
            ),
            AppTheme.mediumGap, // ✅ SEMANTISK GAP

            ActionButton.primary(
              label: 'FACEBOOK',
              icon: Icons.facebook,
              onPressed: () => _navigate(context, '/franSocialaMedier'),
              isExpanded: true,
            ),
            AppTheme.mediumGap, // ✅ SEMANTISK GAP

            ActionButton.primary(
              label: 'TIKTOK',
              icon: Icons.music_note,
              onPressed: () => _navigate(context, '/franSocialaMedier'),
              isExpanded: true,
            ),
            AppTheme.mediumGap, // ✅ SEMANTISK GAP

            ActionButton.primary(
              label: 'FOTO',
              icon: Icons.photo,
              onPressed: () => _navigate(context, '/photoImport'),
              isExpanded: true,
            ),
            AppTheme.mediumGap, // ✅ SEMANTISK GAP

            ActionButton.primary(
              label: 'LÄNK',
              icon: Icons.link,
              onPressed: () => _navigate(context, '/importViaUrl'),
              isExpanded: true,
            ),
            AppTheme.mediumGap, // ✅ SEMANTISK GAP

            ActionButton.primary(
              label: 'SKRIV SJÄLV',
              icon: Icons.edit,
              onPressed: () => _navigate(context, '/skrivSjalv'),
              isExpanded: true,
            ),
            AppTheme.mediumGap, // ✅ SEMANTISK GAP

            ActionButton.primary(
              label: 'FRÅN BUTLERYS ARKIV',
              icon: Icons.archive,
              onPressed: () => _navigate(context, '/importFranArkiv'),
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }
}

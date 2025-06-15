// lib/views/lagg_till_recept_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // För SystemNavigator
import '../widgets/main_layout_menu.dart';
import '../widgets/action_button.dart';
import '../theme/app_theme.dart';

// Exit dialog funktion
Future<void> _showExitDialog(BuildContext context) async {
  final shouldExit = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Avsluta Butlery?'),
          content: const Text('Vill du verkligen avsluta appen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Avbryt'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('Avsluta'),
            ),
          ],
        ),
  );

  if (shouldExit == true && context.mounted) {
    SystemNavigator.pop();
  }
}

/// ✨ 100% THEME-CENTRALISERAD LÄGG TILL RECEPT VY
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
          _showExitDialog(context);
        }
      },
      child: MainLayoutMenu(
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
